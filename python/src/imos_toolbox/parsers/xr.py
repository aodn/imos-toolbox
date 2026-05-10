"""XR parser implementation (initial XR420/XR620 text export support)."""

from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path
from typing import Iterable

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser

_CLASSIC_INSTRUMENT_LINE = re.compile(r"^(\S+)\s+(\S+)\s+([\d.]+)\s+(\d+)\s*$")
_CLASSIC_LOGGING_START = re.compile(r"^Logging start\s+(\d\d/\d\d/\d\d \d\d:\d\d:\d\d)$", re.IGNORECASE)
_CLASSIC_LOGGING_END = re.compile(r"^Logging end\s+(\d\d/\d\d/\d\d \d\d:\d\d:\d\d)$", re.IGNORECASE)
_CLASSIC_SAMPLE_PERIOD = re.compile(r"^Sample period\s+(\d\d:\d\d:\d\d)$", re.IGNORECASE)
_CLASSIC_CORRECTION = re.compile(r"^Correction to conductivity:\s*(.*)$", re.IGNORECASE)
_CLASSIC_AVERAGING = re.compile(r"^Averaging:\s*(\d+)", re.IGNORECASE)
_CLASSIC_BURST = re.compile(r"^Wave burst sample rate:\s*(\d+)", re.IGNORECASE)

_RUSKIN_MODEL = re.compile(r"^Model=+\s*(\S+)$", re.IGNORECASE)
_RUSKIN_FIRMWARE = re.compile(r"^Firmware=+\s*(\S+)$", re.IGNORECASE)
_RUSKIN_SERIAL = re.compile(r"^Serial=+\s*(\S+)$", re.IGNORECASE)
_RUSKIN_LOGGING_START_DATE = re.compile(r"^LoggingStartDate=+\s*(\S+)$", re.IGNORECASE)
_RUSKIN_LOGGING_START_TIME = re.compile(r"^LoggingStartTime=+\s*(.+)$", re.IGNORECASE)
_RUSKIN_LOGGING_END_DATE = re.compile(r"^LoggingEndDate=+\s*(\S+)$", re.IGNORECASE)
_RUSKIN_LOGGING_END_TIME = re.compile(r"^LoggingEndTime=+\s*(.+)$", re.IGNORECASE)
_RUSKIN_SAMPLING_HZ = re.compile(r"^LoggingSamplingPeriod=+\s*(\d+)Hz$", re.IGNORECASE)
_RUSKIN_SAMPLING_HMS = re.compile(r"^LoggingSamplingPeriod=+\s*(\d\d:\d\d:\d\d)$", re.IGNORECASE)

_XR_CLASSIC_MAP = {
    "COND": ("CNDC", 0.1),
    "TEMP": ("TEMP", 1.0),
    "PRES": ("PRES", 1.0),
    "DEPTH": ("DEPTH", 1.0),
    "FLCA": ("CPHL", 1.0),
    "D_O2": ("DOXS", 1.0),
    "TURBA": ("TURB", 1.0),
}

_XR_RUSKIN_MAP = {
    "COND": ("CNDC", 0.1),
    "TEMP": ("TEMP", 1.0),
    "TEMP02": ("TEMP", 1.0),
    "TEMP12": ("TEMP", 1.0),
    "PRES": ("PRES", 1.0),
    "PRES08": ("PRES", 1.0),
    "PRES20": ("PRES", 1.0),
    "PRES21": ("PRES", 1.0),
    "FLC": ("CPHL", 1.0),
    "TURB": ("TURB", 1.0),
    "R_D_O2": ("DOXS", 1.0),
    "DEPTH": ("DEPTH", 1.0),
    "DPTH01": ("DEPTH", 1.0),
    "SALIN": ("PSAL", 1.0),
    "SPECCOND": ("SPEC_CNDC", 1 / 10000.0),
    "SOSUN": ("SSPD", 1.0),
    "RDO2C": ("DOXY", 1.0),
    "D_O2": ("DOXS", 1.0),
    "DO2C": ("DOX", 1.0),
}

_XR_SKIP_FIELDS = {"R_TEMP", "DENSANOM"}


class XRParser(BaseParser):
    """Parser for RBR XR series text exports."""

    parser_name = "XR"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("XR parser currently expects exactly one input file")

        source_file = file_list[0]
        first_line = source_file.read_text(encoding="utf-8", errors="ignore").splitlines()[0].strip()

        if source_file.suffix.lower() == ".dat" and first_line.startswith("RBR"):
            return _parse_classic_xr(source_file, mode, self.parser_name)
        return _parse_ruskin_xr(source_file, mode, self.parser_name)


def _parse_classic_xr(source_file: Path, mode: str, parser_name: str) -> IMOSDataset:
    lines = source_file.read_text(encoding="utf-8", errors="ignore").splitlines()

    header_lines: list[str] = []
    data_start = 0
    for idx, line in enumerate(lines):
        if line.strip() == "":
            data_start = idx + 1
            break
        header_lines.append(line)
    else:
        data_start = len(lines)

    header = _parse_classic_header(header_lines)
    if data_start >= len(lines):
        raise ValueError(f"No XR classic data block found in {source_file}")

    columns = [token.replace("-", "") for token in lines[data_start].strip().split()]
    samples: list[list[float]] = []
    for line in lines[data_start + 1 :]:
        stripped = line.strip()
        if not stripped:
            continue
        tokens = stripped.split()
        if len(tokens) < len(columns):
            continue
        try:
            samples.append([float(token) for token in tokens[: len(columns)]])
        except ValueError:
            continue

    if not samples:
        raise ValueError(f"No XR classic samples found in {source_file}")

    time_values = _build_classic_time_vector(header, len(samples))
    values_by_var = _map_samples(columns, samples, _XR_CLASSIC_MAP)

    attrs: dict[str, str | float] = {
        "toolbox_input_file": str(source_file),
        "featureType": mode,
        "instrument_make": str(header.get("make", "RBR")),
        "instrument_model": str(header.get("model", "XR")),
        "parser": parser_name,
        "source_format": source_file.suffix.lower().lstrip("."),
    }
    _set_optional_attr(attrs, "instrument_firmware", header.get("firmware"))
    _set_optional_attr(attrs, "instrument_serial_no", header.get("serial"))
    _set_optional_attr(attrs, "correction", header.get("correction"))

    averaging = header.get("averaging_time_period")
    if isinstance(averaging, (int, float)):
        attrs["instrument_average_interval"] = float(averaging)

    burst_rate = header.get("burst_sample_rate")
    if isinstance(burst_rate, (int, float)):
        attrs["burst_sample_rate"] = float(burst_rate)

    if len(time_values) > 1:
        attrs["instrument_sample_interval"] = float(np.median(np.diff(time_values)) * 24.0 * 3600.0)

    return _build_dataset(time_values, values_by_var, attrs)


def _parse_ruskin_xr(source_file: Path, mode: str, parser_name: str) -> IMOSDataset:
    lines = source_file.read_text(encoding="utf-8", errors="ignore").splitlines()

    header_lines: list[str] = []
    variables_line = ""
    data_start = 0

    for idx, line in enumerate(lines):
        if "Date & Time" in line:
            variables_line = line.strip()
            data_start = idx + 1
            break
        header_lines.append(line.strip())
    else:
        raise ValueError(f"XR Ruskin header with 'Date & Time' not found in {source_file}")

    header = _parse_ruskin_header(header_lines)
    columns = _parse_ruskin_columns(variables_line)
    if len(columns) < 3:
        raise ValueError(f"XR Ruskin variables header invalid in {source_file}")

    data_columns = columns[2:]
    times: list[float] = []
    samples: list[list[float]] = []

    for line in lines[data_start:]:
        stripped = line.strip()
        if not stripped:
            continue
        tokens = stripped.split()
        if len(tokens) < 2:
            continue

        date_token = tokens[0]
        time_token = tokens[1]
        try:
            dt = _parse_ruskin_datetime(date_token, time_token)
        except ValueError:
            continue

        numeric_tokens = tokens[2:]
        if len(numeric_tokens) < len(data_columns):
            numeric_tokens = [*numeric_tokens, *(["nan"] * (len(data_columns) - len(numeric_tokens)))]

        row: list[float] = []
        for token in numeric_tokens[: len(data_columns)]:
            if token.lower() == "null":
                row.append(np.nan)
                continue
            try:
                row.append(float(token))
            except ValueError:
                row.append(np.nan)

        times.append(_datetime_to_matlab_datenum(dt))
        samples.append(row)

    if not samples:
        raise ValueError(f"No XR Ruskin samples found in {source_file}")

    values_by_var = _map_samples(data_columns, samples, _XR_RUSKIN_MAP)

    attrs: dict[str, str | float] = {
        "toolbox_input_file": str(source_file),
        "featureType": mode,
        "instrument_make": str(header.get("make", "RBR")),
        "instrument_model": str(header.get("model", "XR")),
        "parser": parser_name,
        "source_format": source_file.suffix.lower().lstrip("."),
    }
    _set_optional_attr(attrs, "instrument_firmware", header.get("firmware"))
    _set_optional_attr(attrs, "instrument_serial_no", header.get("serial"))
    _set_optional_attr(attrs, "correction", header.get("correction"))

    if len(times) > 1:
        attrs["instrument_sample_interval"] = float(np.median(np.diff(np.asarray(times, dtype=float))) * 24.0 * 3600.0)

    return _build_dataset(np.asarray(times, dtype=float), values_by_var, attrs)


def _parse_classic_header(lines: list[str]) -> dict[str, str | float]:
    header: dict[str, str | float] = {}
    for line in lines:
        text = line.strip()
        if not text:
            continue

        match = _CLASSIC_INSTRUMENT_LINE.match(text)
        if match:
            header["make"] = match.group(1)
            header["model"] = match.group(2)
            header["firmware"] = match.group(3)
            header["serial"] = match.group(4)
            continue

        match = _CLASSIC_LOGGING_START.match(text)
        if match:
            header["start"] = _datetime_to_matlab_datenum(datetime.strptime(match.group(1), "%y/%m/%d %H:%M:%S"))
            continue

        match = _CLASSIC_LOGGING_END.match(text)
        if match:
            header["end"] = _datetime_to_matlab_datenum(datetime.strptime(match.group(1), "%y/%m/%d %H:%M:%S"))
            continue

        match = _CLASSIC_SAMPLE_PERIOD.match(text)
        if match:
            header["interval_days"] = _parse_time_as_days(match.group(1))
            continue

        match = _CLASSIC_CORRECTION.match(text)
        if match:
            header["correction"] = match.group(1).strip()
            continue

        match = _CLASSIC_AVERAGING.match(text)
        if match:
            header["averaging_time_period"] = float(match.group(1))
            continue

        match = _CLASSIC_BURST.match(text)
        if match:
            header["burst_sample_rate"] = float(match.group(1))

    return header


def _parse_ruskin_header(lines: list[str]) -> dict[str, str | float]:
    header: dict[str, str | float] = {"make": "RBR"}
    start_date = ""
    start_time = ""
    end_date = ""
    end_time = ""

    for line in lines:
        text = line.strip()
        if not text:
            continue

        match = _RUSKIN_MODEL.match(text)
        if match:
            header["model"] = match.group(1)
            continue
        match = _RUSKIN_FIRMWARE.match(text)
        if match:
            header["firmware"] = match.group(1)
            continue
        match = _RUSKIN_SERIAL.match(text)
        if match:
            header["serial"] = match.group(1)
            continue

        match = _RUSKIN_LOGGING_START_DATE.match(text)
        if match:
            start_date = match.group(1)
            continue
        match = _RUSKIN_LOGGING_START_TIME.match(text)
        if match:
            start_time = match.group(1).strip()
            continue
        match = _RUSKIN_LOGGING_END_DATE.match(text)
        if match:
            end_date = match.group(1)
            continue
        match = _RUSKIN_LOGGING_END_TIME.match(text)
        if match:
            end_time = match.group(1).strip()
            continue

        match = _RUSKIN_SAMPLING_HZ.match(text)
        if match:
            hz = float(match.group(1))
            if hz > 0:
                header["interval_seconds"] = 1.0 / hz
            continue

        match = _RUSKIN_SAMPLING_HMS.match(text)
        if match:
            header["interval_seconds"] = _parse_time_as_seconds(match.group(1))

    if start_date and start_time:
        header["start"] = _parse_ruskin_header_datetime(start_date, start_time)
    elif not start_date and start_time:
        header["start"] = _datetime_to_matlab_datenum(datetime.strptime(start_time, "%d-%b-%Y %H:%M:%S.%f"))

    if end_date and end_time:
        header["end"] = _parse_ruskin_header_datetime(end_date, end_time)
    elif not end_date and end_time:
        header["end"] = _datetime_to_matlab_datenum(datetime.strptime(end_time, "%d-%b-%Y %H:%M:%S.%f"))

    return header


def _parse_ruskin_columns(variables_line: str) -> list[str]:
    transformed = re.sub(r"\s+\&\s+|\s+", "|", variables_line.strip())
    raw_columns = [token.strip() for token in transformed.split("|") if token.strip()]
    cleaned = []
    for token in raw_columns:
        value = token.replace("-", "")
        value = value.replace(" ", "")
        value = value.replace("(", "")
        value = value.replace(")", "")
        value = value.replace("&", "")
        cleaned.append(value)
    return cleaned


def _map_samples(columns: list[str], samples: list[list[float]], mapping: dict[str, tuple[str, float]]) -> dict[str, np.ndarray]:
    values_by_var: dict[str, np.ndarray] = {}
    for col_idx, original_name in enumerate(columns):
        key = original_name.upper()
        if key in _XR_SKIP_FIELDS:
            continue

        mapped_name, scale = mapping.get(key, (original_name, 1.0))
        if not mapped_name:
            continue

        column_values = [row[col_idx] for row in samples if col_idx < len(row)]
        if not column_values:
            continue

        scaled = np.asarray(column_values, dtype=float) * float(scale)
        values_by_var[mapped_name] = scaled
    return values_by_var


def _build_classic_time_vector(header: dict[str, str | float], n_samples: int) -> np.ndarray:
    start = float(header.get("start", 0.0))
    interval_days = float(header.get("interval_days", 0.0))
    end = float(header.get("end", start))

    if n_samples <= 0:
        return np.asarray([], dtype=float)
    if interval_days > 0:
        return start + np.arange(n_samples, dtype=float) * interval_days
    if n_samples == 1:
        return np.asarray([start], dtype=float)
    return np.linspace(start, end, n_samples, dtype=float)


def _build_dataset(time_values: np.ndarray, values_by_var: dict[str, np.ndarray], attrs: dict[str, str | float]) -> IMOSDataset:
    dataset = IMOSDataset.empty()
    obs_dim = "obs"
    dataset.add_dimension(obs_dim, np.arange(len(time_values)))
    dataset.add_variable(name="TIME", data=np.asarray(time_values, dtype=float), dims=[obs_dim])
    dataset.add_variable(name="TIMESERIES", data=np.asarray(1, dtype=np.int32), dims=[])
    dataset.add_variable(name="LATITUDE", data=np.asarray(np.nan, dtype=float), dims=[])
    dataset.add_variable(name="LONGITUDE", data=np.asarray(np.nan, dtype=float), dims=[])
    dataset.add_variable(name="NOMINAL_DEPTH", data=np.asarray(np.nan, dtype=float), dims=[])

    for var_name, values in values_by_var.items():
        if len(values) < len(time_values):
            values = np.concatenate([values, np.full(len(time_values) - len(values), np.nan)])
        dataset.add_variable(name=var_name, data=np.asarray(values[: len(time_values)], dtype=float), dims=[obs_dim])

    dataset.set_attrs(attrs)
    return dataset


def _parse_ruskin_datetime(date_token: str, time_token: str) -> datetime:
    formats = [
        "%y/%m/%d %H:%M:%S.%f",
        "%y/%m/%d %H:%M:%S",
        "%Y/%b/%d %H:%M:%S.%f",
        "%Y/%b/%d %H:%M:%S",
        "%d-%b-%Y %H:%M:%S.%f",
        "%Y-%m-%d %H:%M:%S.%f",
        "%Y-%m-%d %H:%M:%S",
    ]
    text = f"{date_token} {time_token}"
    for fmt in formats:
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            continue
    raise ValueError(f"Unsupported XR date/time format: {text}")


def _parse_ruskin_header_datetime(date_text: str, time_text: str) -> float:
    formats = ["%y/%m/%d %H:%M:%S.%f", "%Y/%b/%d %H:%M:%S.%f", "%Y/%b/%d %H:%M:%S"]
    text = f"{date_text} {time_text}"
    for fmt in formats:
        try:
            return _datetime_to_matlab_datenum(datetime.strptime(text, fmt))
        except ValueError:
            continue
    raise ValueError(f"Unsupported XR header datetime format: {text}")


def _parse_time_as_days(value: str) -> float:
    return _parse_time_as_seconds(value) / 86400.0


def _parse_time_as_seconds(value: str) -> float:
    hours, minutes, seconds = value.split(":")
    return float(int(hours) * 3600 + int(minutes) * 60 + int(seconds))


def _set_optional_attr(attrs: dict[str, str | float], key: str, value: str | float | None) -> None:
    if value is None:
        return
    attrs[key] = value


def _datetime_to_matlab_datenum(value: datetime) -> float:
    ordinal = value.toordinal()
    frac = (value - datetime(value.year, value.month, value.day)).total_seconds() / 86400.0
    return ordinal + 366 + frac