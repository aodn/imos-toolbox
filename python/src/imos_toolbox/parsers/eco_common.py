"""Shared parsing helpers for WetLabs ECO-family instruments."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

import numpy as np

from imos_toolbox.model import IMOSDataset


@dataclass
class ECOColumn:
    type: str
    scale: float | None = None
    offset: float | None = None
    meas_wavelength: float | None = None
    disp_wavelength: float | None = None
    im: float | None = None
    a0: float | None = None
    a1: float | None = None


@dataclass
class ECODeviceInfo:
    instrument: str
    serial: str
    columns: list[ECOColumn]


def read_eco_device(path: Path) -> ECODeviceInfo:
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    if not lines:
        raise ValueError(f"Empty .dev file: {path}")

    header = lines[0].replace("\t", "").strip()
    instrument, serial = _split_header(header)

    start_idx = None
    n_columns = None
    for idx, line in enumerate(lines[1:], start=1):
        if "columns=" in line.lower():
            token = line.lower().split("columns=", 1)[1].strip()
            token = "".join(ch for ch in token if ch.isdigit())
            if token:
                n_columns = int(token)
                start_idx = idx + 1
                break

    columns: list[ECOColumn] = []
    if n_columns is None or start_idx is None:
        return ECODeviceInfo(instrument=instrument, serial=serial, columns=columns)

    for col_id in range(1, n_columns + 1):
        col_line_idx = None
        col_line = ""
        for idx in range(start_idx, len(lines)):
            line = lines[idx].strip()
            if line.upper().endswith(f"={col_id}"):
                col_line_idx = idx
                col_line = line
                break

        if not col_line:
            columns.append(ECOColumn(type="N/U"))
            continue

        col_type = col_line.split("=", 1)[0].strip().upper()
        column = ECOColumn(type=col_type)

        fields = [part.strip() for part in col_line.split("\t") if part.strip()]
        if len(fields) >= 2:
            column.scale = _to_float(fields[1])
        if len(fields) >= 3:
            column.offset = _to_float(fields[2])
        if len(fields) >= 4:
            column.meas_wavelength = _to_float(fields[3])
        if len(fields) >= 5:
            column.disp_wavelength = _to_float(fields[4])

        if col_type == "PAR" and col_line_idx is not None:
            for search_idx in range(col_line_idx + 1, min(col_line_idx + 15, len(lines))):
                line = lines[search_idx]
                if column.im is None and "im=" in line.lower():
                    column.im = _extract_assignment_number(line, "im")
                if column.a0 is None and "a0=" in line.lower():
                    column.a0 = _extract_assignment_number(line, "a0")
                if column.a1 is None and "a1=" in line.lower():
                    column.a1 = _extract_assignment_number(line, "a1")
                if column.im is not None and column.a0 is not None and column.a1 is not None:
                    break

        columns.append(column)

    return ECODeviceInfo(instrument=instrument, serial=serial, columns=columns)


def parse_eco_triplet_raw(source_file: Path, device: ECODeviceInfo, mode: str, parser_name: str) -> IMOSDataset:
    lines = source_file.read_text(encoding="utf-8", errors="ignore").splitlines()
    if len(lines) < 2:
        raise ValueError(f"No data rows found in {source_file}")

    data_lines = [line for line in lines[1:] if line.strip()]
    n_columns = len(device.columns) if device.columns else 0
    if n_columns < 2:
        raise ValueError(f"Device columns missing/insufficient in {source_file}")

    times: list[float] = []
    samples: list[list[float]] = [[] for _ in range(n_columns)]

    for line in data_lines:
        parts = [part.strip() for part in line.split("\t")]
        if len(parts) < n_columns:
            continue

        try:
            dt = datetime.strptime(parts[0], "%m/%d/%y")
            tm = datetime.strptime(parts[1], "%H:%M:%S")
            combined = datetime(dt.year, dt.month, dt.day, tm.hour, tm.minute, tm.second)
        except ValueError:
            continue

        numeric: list[float] = []
        valid = True
        for idx in range(2, n_columns):
            try:
                numeric.append(float(parts[idx]))
            except ValueError:
                valid = False
                break
        if not valid:
            continue

        times.append(_datetime_to_matlab_datenum(combined))
        for idx, value in enumerate(numeric, start=2):
            samples[idx].append(value)

    if not times:
        raise ValueError(f"No valid ECO raw samples found in {source_file}")

    values_by_var: dict[str, np.ndarray] = {}
    for idx in range(2, n_columns):
        var_name, converted = convert_eco_raw_var(device.columns[idx], np.asarray(samples[idx], dtype=float))
        if var_name:
            values_by_var[var_name] = converted

    return _build_dataset(source_file, mode, parser_name, device, times, values_by_var, "raw")


def parse_ecobb9_raw(source_file: Path, device: ECODeviceInfo, mode: str, parser_name: str) -> IMOSDataset:
    lines = [line for line in source_file.read_text(encoding="utf-8", errors="ignore").splitlines() if line.strip()]
    if not lines:
        raise ValueError(f"No data rows found in {source_file}")

    n_columns = len(device.columns) if device.columns else 0
    if n_columns < 2:
        raise ValueError(f"Device columns missing/insufficient in {source_file}")

    start_time = _infer_filename_time(source_file)
    samples: list[list[float]] = [[] for _ in range(n_columns)]

    for line in lines:
        parts = [part.strip() for part in line.split("\t")]
        if len(parts) < n_columns:
            continue
        numeric: list[float] = []
        valid = True
        for idx in range(1, n_columns):
            try:
                numeric.append(float(parts[idx]))
            except ValueError:
                valid = False
                break
        if not valid:
            continue
        for idx, value in enumerate(numeric, start=1):
            samples[idx].append(value)

    n_samples = len(samples[1])
    if n_samples == 0:
        raise ValueError(f"No valid ECO BB9 samples found in {source_file}")

    times = [
        _datetime_to_matlab_datenum(start_time + timedelta(seconds=offset))
        for offset in range(n_samples)
    ]

    values_by_var: dict[str, np.ndarray] = {}
    for idx in range(1, n_columns):
        var_name, converted = convert_eco_raw_var(device.columns[idx], np.asarray(samples[idx], dtype=float))
        if var_name:
            values_by_var[var_name] = converted

    return _build_dataset(source_file, mode, parser_name, device, times, values_by_var, "raw")


def parse_wetstar_raw(source_file: Path, device: ECODeviceInfo, mode: str, parser_name: str) -> IMOSDataset:
    lines = [line.strip() for line in source_file.read_text(encoding="utf-8", errors="ignore").splitlines() if line.strip()]
    if not lines:
        raise ValueError(f"No data rows found in {source_file}")

    samples = []
    for line in lines:
        try:
            samples.append(float(line))
        except ValueError:
            continue

    if not samples:
        raise ValueError(f"No valid WetStar samples found in {source_file}")

    start_time = _infer_filename_time(source_file)
    n_samples = len(samples)
    # MATLAB uses linspace over one hour inclusive.
    if n_samples == 1:
        times = [_datetime_to_matlab_datenum(start_time)]
    else:
        step = 3600.0 / (n_samples - 1)
        times = [
            _datetime_to_matlab_datenum(start_time + timedelta(seconds=step * idx))
            for idx in range(n_samples)
        ]

    column = device.columns[0] if device.columns else ECOColumn(type="CHL")
    var_name, converted = convert_eco_raw_var(column, np.asarray(samples, dtype=float))
    values_by_var = {var_name: converted} if var_name else {}

    return _build_dataset(source_file, mode, parser_name, device, times, values_by_var, "raw")


def convert_eco_raw_var(column: ECOColumn, sample: np.ndarray) -> tuple[str, np.ndarray]:
    column_type = column.type.upper()

    if column_type in {"N/U", "DATE", "TIME", "DKDC"}:
        return "", np.array([])

    if column_type == "PAR" and column.im is not None and column.a0 is not None and column.a1 is not None:
        data = column.im * np.power(10.0, (sample - column.a0) / column.a1)
        return "PAR", data

    if column_type == "CHL":
        return "CPHL", _scale_offset(sample, column)
    if column_type == "CDOM":
        return "CDOM", _scale_offset(sample, column)
    if column_type == "NTU":
        return "TURB", _scale_offset(sample, column)
    if column_type == "LAMBDA":
        wavelength = int(column.meas_wavelength) if column.meas_wavelength is not None else 0
        return f"VSF{wavelength}", _scale_offset(sample, column)

    return f"ECO3_{column_type}", _scale_offset(sample, column)


def _scale_offset(values: np.ndarray, column: ECOColumn) -> np.ndarray:
    output = values.astype(float)
    if column.offset is not None:
        output = output - column.offset
    if column.scale is not None:
        output = output * column.scale
    return output


def _build_dataset(
    source_file: Path,
    mode: str,
    parser_name: str,
    device: ECODeviceInfo,
    times: list[float],
    values_by_var: dict[str, np.ndarray],
    source_format: str,
) -> IMOSDataset:
    dataset = IMOSDataset.empty()
    obs_dim = "obs"
    dataset.add_dimension(obs_dim, np.arange(len(times)))
    dataset.add_variable(name="TIME", data=np.asarray(times, dtype=float), dims=[obs_dim])

    for var_name, values in values_by_var.items():
        dataset.add_variable(name=var_name, data=values, dims=[obs_dim])

    dataset.set_attrs(
        {
            "toolbox_input_file": str(source_file),
            "featureType": mode,
            "instrument_make": "WET Labs",
            "instrument_model": device.instrument or "ECO",
            "instrument_serial_no": device.serial,
            "parser": parser_name,
            "source_format": source_format,
        }
    )

    return dataset


def _split_header(header: str) -> tuple[str, str]:
    if "-" in header:
        instrument, serial = header.split("-", 1)
    else:
        instrument, serial = header, ""
    serial = serial.split("_", 1)[0].strip()
    return instrument.strip(), serial


def _to_float(value: str) -> float | None:
    try:
        return float(value)
    except ValueError:
        return None


def _extract_assignment_number(line: str, key: str) -> float | None:
    token = line.lower().split(f"{key}=", 1)
    if len(token) < 2:
        return None
    number = token[1].strip().split()[0]
    return _to_float(number)


def _infer_filename_time(path: Path) -> datetime:
    stem = path.stem
    if len(stem) < 13:
        raise ValueError(f"Cannot infer timestamp from filename: {path.name}")

    candidates = [part for part in stem.split("_") if len(part) == 8 and part.isdigit()]
    time_candidates = [part for part in stem.split("_") if len(part) == 4 and part.isdigit()]

    if candidates and time_candidates:
        token = f"{candidates[0]}_{time_candidates[0]}"
    else:
        token = stem[-13:]

    return datetime.strptime(token, "%Y%m%d_%H%M")


def _datetime_to_matlab_datenum(value: datetime) -> float:
    ordinal = value.toordinal()
    frac = (value - datetime(value.year, value.month, value.day)).total_seconds() / 86400.0
    return ordinal + 366 + frac
