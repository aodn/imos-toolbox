"""Vemco parser implementation (initial Logger Vue CSV support)."""

from __future__ import annotations

import csv
import re
from datetime import datetime
from pathlib import Path
from typing import Iterable

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser

_SOURCE_DEVICE = re.compile(r"^Source Device:\s*([\w-]+)-(\d+)$", re.IGNORECASE)
_STUDY_START = re.compile(r"^Study Start Time:\s*(.+)$", re.IGNORECASE)
_STUDY_STOP = re.compile(r"^Study Stop Time:\s*(.+)$", re.IGNORECASE)
_SAMPLE_INTERVAL = re.compile(r"^Sample Interval:\s*(\d+):(\d+):(\d+)$", re.IGNORECASE)


class VemcoParser(BaseParser):
    """Parser for Vemco Minilog CSV exports."""

    parser_name = "Vemco"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("Vemco parser currently expects exactly one input file")

        source_file = file_list[0]
        if source_file.suffix.lower() != ".csv":
            raise ValueError("Vemco parser currently supports .csv files only")

        proc_header, data_header, rows = _read_vemco_csv(source_file)
        times, values_by_var = _parse_vemco_data(data_header, rows)

        if len(times) == 0:
            raise ValueError(f"No valid Vemco samples found in {source_file}")

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
            "instrument_make": "Vemco",
            "instrument_model": str(proc_header.get("instrument_model", "Vemco Unknown")),
            "instrument_firmware": str(proc_header.get("instrument_firmware", "")),
            "instrument_serial_no": str(proc_header.get("instrument_serial_no", "")),
            "parser": self.parser_name,
            "source_format": "csv",
        }

        sample_interval = proc_header.get("sampleInterval")
        if isinstance(sample_interval, (int, float)):
            attrs["instrument_sample_interval"] = float(sample_interval)
        elif len(times) > 1:
            attrs["instrument_sample_interval"] = float(np.median(np.diff(np.asarray(times, dtype=float))) * 24.0 * 3600.0)

        dataset.set_attrs(attrs)
        return dataset


def _read_vemco_csv(source_file: Path) -> tuple[dict[str, str | float], list[str], list[list[str]]]:
    lines = source_file.read_text(encoding="utf-8", errors="ignore").splitlines()

    header_lines: list[str] = []
    data_header_line = ""
    data_start = 0
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if not stripped:
            continue
        if re.match(r"^Date", stripped, flags=re.IGNORECASE):
            data_header_line = stripped
            data_start = idx + 1
            break
        header_lines.append(stripped)

    if not data_header_line:
        raise ValueError(f"Vemco data header line not found in {source_file}")

    data_header = [token.strip() for token in data_header_line.split(",")]

    reader = csv.reader(lines[data_start:])
    rows = [row for row in reader if row and any(token.strip() for token in row)]
    proc_header = _parse_processed_header(header_lines, data_header)
    return proc_header, data_header, rows


def _parse_processed_header(header_lines: list[str], data_header: list[str]) -> dict[str, str | float]:
    header: dict[str, str | float] = {
        "columns": ",".join(data_header),
        "nHeaderLines": float(len(header_lines) + 1),
    }

    for line in header_lines:
        match = _SOURCE_DEVICE.match(line)
        if match:
            header["instrument_model"] = match.group(1)
            header["instrument_serial_no"] = match.group(2)
            continue

        match = _STUDY_START.match(line)
        if match:
            dt = _parse_study_datetime(match.group(1))
            if dt is not None:
                header["startTime"] = _datetime_to_matlab_datenum(dt)
            continue

        match = _STUDY_STOP.match(line)
        if match:
            dt = _parse_study_datetime(match.group(1))
            if dt is not None:
                header["stopTime"] = _datetime_to_matlab_datenum(dt)
            continue

        match = _SAMPLE_INTERVAL.match(line)
        if match:
            hours = int(match.group(1))
            minutes = int(match.group(2))
            seconds = int(match.group(3))
            header["sampleInterval"] = float(hours * 3600 + minutes * 60 + seconds)

    return header


def _parse_vemco_data(columns: list[str], rows: list[list[str]]) -> tuple[np.ndarray, dict[str, np.ndarray]]:
    if len(columns) < 2:
        raise ValueError("Vemco data header must include Date and Time columns")

    date_idx = 0
    time_idx = 1
    process_indices = [idx for idx in range(len(columns)) if idx not in (date_idx, time_idx)]

    times: list[float] = []
    by_var_lists: dict[str, list[float]] = {}

    for row in rows:
        if len(row) < 2:
            continue

        date_text = row[date_idx].strip()
        time_text = row[time_idx].strip()
        try:
            timestamp = _parse_data_datetime(date_text, time_text)
        except ValueError:
            continue

        parsed_values: dict[str, float] = {}
        for col_idx in process_indices:
            if col_idx >= len(row):
                continue
            var_name = _convert_column_name(columns[col_idx])
            if not var_name:
                continue
            token = row[col_idx].strip()
            try:
                parsed_values[var_name] = float(token)
            except ValueError:
                parsed_values[var_name] = np.nan

        times.append(_datetime_to_matlab_datenum(timestamp))
        for var_name in by_var_lists:
            by_var_lists[var_name].append(np.nan)

        for var_name, value in parsed_values.items():
            if var_name not in by_var_lists:
                by_var_lists[var_name] = [np.nan] * (len(times) - 1)
                by_var_lists[var_name].append(value)
            else:
                by_var_lists[var_name][-1] = value

    by_var = {name: np.asarray(values, dtype=float) for name, values in by_var_lists.items()}
    return np.asarray(times, dtype=float), by_var


def _convert_column_name(column_name: str) -> str:
    cleaned = _sanitize_column(column_name)
    if cleaned in {"Temperature0x280xFFFDC0x29", "Temperature0x280xB0C0x29"}:
        return "TEMP"

    lowered = column_name.lower()
    if lowered.startswith("temperature"):
        return "TEMP"

    return ""


def _sanitize_column(value: str) -> str:
    output = value
    for ch in [" ", "(", ")", "-", "/", ",", ".", "°"]:
        output = output.replace(ch, "")
    output = output.replace("μ", "u")
    output = output.replace("µ", "u")
    return output


def _parse_data_datetime(date_text: str, time_text: str) -> datetime:
    formats = [
        "%Y-%m-%d %H:%M:%S",
        "%Y/%m/%d %H:%M:%S",
        "%d-%b-%Y %H:%M:%S",
    ]
    text = f"{date_text} {time_text}"
    for fmt in formats:
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            continue
    raise ValueError(f"Unsupported Vemco date/time format: {text}")


def _parse_study_datetime(text: str) -> datetime | None:
    formats = ["%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M:%S"]
    for fmt in formats:
        try:
            return datetime.strptime(text.strip(), fmt)
        except ValueError:
            continue
    return None


def _datetime_to_matlab_datenum(value: datetime) -> float:
    ordinal = value.toordinal()
    frac = (value - datetime(value.year, value.month, value.day)).total_seconds() / 86400.0
    return ordinal + 366 + frac