"""RCM parser implementation (initial Aanderaa tab-delimited TXT support)."""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Iterable

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser

_COLUMN_MAP = {
    "BatteryVoltage": ("BAT_VOLT", 1.0),
    "AbsSpeed": ("CSPD", 0.01),
    "Direction": ("CDIR_MAG", 1.0),
    "North": ("VCUR_MAG", 0.01),
    "East": ("UCUR_MAG", 0.01),
    "Heading": ("HEADING_MAG", 1.0),
    "TiltX": ("ROLL", 1.0),
    "TiltY": ("PITCH", 1.0),
    "SPStd": ("CSPD_STD", 0.01),
    "Strength": ("ABSI", 1.0),
}


class RCMParser(BaseParser):
    """Parser for Aanderaa RCM-8 / old SeaGuard text files."""

    parser_name = "RCM"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("RCM parser currently expects exactly one input file")

        source_file = file_list[0]
        if source_file.suffix.lower() != ".txt":
            raise ValueError("RCM parser currently supports .txt files only")

        columns, rows = _read_rcm_txt(source_file)
        times, values_by_var = _parse_rows(columns, rows)

        if len(times) == 0:
            raise ValueError(f"No valid RCM samples found in {source_file}")

        dataset = IMOSDataset.empty()
        obs_dim = "obs"
        dataset.add_dimension(obs_dim, np.arange(len(times)))
        dataset.add_variable(name="TIME", data=np.asarray(times, dtype=float), dims=[obs_dim])
        dataset.add_variable(name="TIMESERIES", data=np.asarray(1, dtype=np.int32), dims=[])
        dataset.add_variable(name="LATITUDE", data=np.asarray(np.nan, dtype=float), dims=[])
        dataset.add_variable(name="LONGITUDE", data=np.asarray(np.nan, dtype=float), dims=[])
        dataset.add_variable(name="NOMINAL_DEPTH", data=np.asarray(np.nan, dtype=float), dims=[])

        for var_name, values in values_by_var.items():
            if len(values) < len(times):
                values = np.concatenate([values, np.full(len(times) - len(values), np.nan)])
            dataset.add_variable(name=var_name, data=np.asarray(values[: len(times)], dtype=float), dims=[obs_dim])

        attrs: dict[str, str | float] = {
            "toolbox_input_file": str(source_file),
            "featureType": mode,
            "instrument_make": "Aanderaa",
            "instrument_model": "Sea Guard",
            "instrument_firmware": "",
            "instrument_serial_no": "",
            "parser": self.parser_name,
            "source_format": "txt",
        }
        if len(times) > 1:
            attrs["instrument_sample_interval"] = float(np.median(np.diff(np.asarray(times, dtype=float))) * 24.0 * 3600.0)

        dataset.set_attrs(attrs)
        return dataset


def _read_rcm_txt(source_file: Path) -> tuple[list[str], list[list[str]]]:
    lines = source_file.read_text(encoding="utf-8", errors="ignore").splitlines()
    if len(lines) < 3:
        raise ValueError(f"RCM file too short: {source_file}")

    data_header_line = lines[1]
    columns = [token.strip() for token in data_header_line.split("\t")]
    rows = [[token.strip() for token in line.split("\t")] for line in lines[2:] if line.strip()]
    return columns, rows


def _parse_rows(columns: list[str], rows: list[list[str]]) -> tuple[np.ndarray, dict[str, np.ndarray]]:
    if len(columns) < 2:
        raise ValueError("RCM data header invalid")

    date_idx = 1
    proc_indices = [idx for idx in range(len(columns)) if idx != date_idx]

    times: list[float] = []
    values_by_var: dict[str, list[float]] = {}

    for row in rows:
        if len(row) <= date_idx:
            continue
        dt = _parse_datetime(row[date_idx])
        if dt is None:
            continue

        parsed_values: dict[str, float] = {}
        for idx in proc_indices:
            if idx >= len(row):
                continue
            mapped = _COLUMN_MAP.get(columns[idx])
            if not mapped:
                continue
            var_name, scale = mapped
            try:
                value = float(row[idx]) * scale
            except ValueError:
                value = np.nan
            parsed_values[var_name] = value

        times.append(_datetime_to_matlab_datenum(dt))

        for key in values_by_var:
            values_by_var[key].append(np.nan)
        for key, value in parsed_values.items():
            if key not in values_by_var:
                values_by_var[key] = [np.nan] * (len(times) - 1)
                values_by_var[key].append(value)
            else:
                values_by_var[key][-1] = value

    return np.asarray(times, dtype=float), {k: np.asarray(v, dtype=float) for k, v in values_by_var.items()}


def _parse_datetime(value: str) -> datetime | None:
    for fmt in ("%d.%m.%y %H:%M:%S", "%d.%m.%Y %H:%M:%S"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    return None


def _datetime_to_matlab_datenum(value: datetime) -> float:
    ordinal = value.toordinal()
    frac = (value - datetime(value.year, value.month, value.day)).total_seconds() / 86400.0
    return ordinal + 366 + frac
