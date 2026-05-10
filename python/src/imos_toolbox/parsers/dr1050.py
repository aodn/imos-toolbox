"""DR1050 parser implementation (initial text export support)."""

from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path
from typing import Iterable

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser

_INSTRUMENT_LINE = re.compile(r"^(\S+)\s+(\S+)\s+([\d.]+)\s+(\d+)\s*$")
_LOGGING_START = re.compile(r"^Logging start\s+(\d\d/\d\d/\d\d \d\d:\d\d:\d\d)$", re.IGNORECASE)
_LOGGING_END = re.compile(r"^Logging end\s+(\d\d/\d\d/\d\d \d\d:\d\d:\d\d)$", re.IGNORECASE)
_SAMPLE_PERIOD = re.compile(r"^Sample period\s+(\d\d:\d\d:\d\d)$", re.IGNORECASE)
_COMMENT = re.compile(r"^COMMENT:\s*(.*)$", re.IGNORECASE)
_CHANNELS = re.compile(r"^Number of channels =\s*(\d)+, number of samples =\s*(\d)+$", re.IGNORECASE)


class DR1050Parser(BaseParser):
    """Parser for RBR DR1050 text files."""

    parser_name = "DR1050"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("DR1050 parser currently expects exactly one input file")

        source_file = file_list[0]
        header, columns, samples = _read_dr1050_file(source_file)

        if not columns or not samples:
            raise ValueError(f"No DR1050 sample data found in {source_file}")

        n_samples = len(samples)
        times = _build_time_vector(header, n_samples)

        dataset = IMOSDataset.empty()
        obs_dim = "obs"
        dataset.add_dimension(obs_dim, np.arange(n_samples))
        dataset.add_variable(name="TIME", data=np.asarray(times, dtype=float), dims=[obs_dim])
        dataset.add_variable(name="TIMESERIES", data=np.asarray(1, dtype=np.int32), dims=[])
        dataset.add_variable(name="LATITUDE", data=np.asarray(np.nan, dtype=float), dims=[])
        dataset.add_variable(name="LONGITUDE", data=np.asarray(np.nan, dtype=float), dims=[])
        dataset.add_variable(name="NOMINAL_DEPTH", data=np.asarray(np.nan, dtype=float), dims=[])

        pres_idx = _find_column_index(columns, "Pres")
        if pres_idx is not None:
            pres_values = np.asarray([row[pres_idx] for row in samples], dtype=float)
            dataset.add_variable(name="PRES", data=pres_values, dims=[obs_dim])

        attrs = {
            "toolbox_input_file": str(source_file),
            "featureType": mode,
            "instrument_make": header.get("make", "RBR"),
            "instrument_model": header.get("model", "DR1050"),
            "parser": self.parser_name,
            "source_format": source_file.suffix.lower().lstrip("."),
        }
        if "firmware" in header:
            attrs["instrument_firmware"] = header["firmware"]
        if "serial" in header:
            attrs["instrument_serial_no"] = header["serial"]
        comment = header.get("comment")
        if isinstance(comment, str):
            attrs["comment"] = _normalise_comment(comment)
        interval_days = header.get("interval_days", 0.0)
        if isinstance(interval_days, (float, int)) and interval_days > 0:
            attrs["instrument_sample_interval"] = float(interval_days) * 24.0 * 3600.0
        elif n_samples > 1:
            attrs["instrument_sample_interval"] = float(np.median(np.diff(np.asarray(times, dtype=float))) * 24.0 * 3600.0)

        dataset.set_attrs(attrs)
        return dataset


def _read_dr1050_file(source_file: Path) -> tuple[dict[str, float | str], list[str], list[list[float]]]:
    lines = source_file.read_text(encoding="utf-8", errors="ignore").splitlines()

    header_lines: list[str] = []
    data_start = 0
    for idx, line in enumerate(lines):
        if line.strip() == "":
            data_start = idx + 1
            break
        header_lines.append(line.rstrip("\n"))
    else:
        data_start = len(lines)

    header = _parse_header(header_lines)

    if data_start >= len(lines):
        return header, [], []

    col_line = lines[data_start].strip()
    columns = col_line.split()

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

    return header, columns, samples


def _parse_header(lines: list[str]) -> dict[str, float | str]:
    header: dict[str, float | str] = {}
    for line in lines:
        text = line.strip()
        if not text:
            continue

        match = _INSTRUMENT_LINE.match(text)
        if match:
            header["make"] = match.group(1)
            header["model"] = match.group(2)
            header["firmware"] = match.group(3)
            header["serial"] = match.group(4)
            continue

        match = _LOGGING_START.match(text)
        if match:
            header["start"] = _datetime_to_matlab_datenum(datetime.strptime(match.group(1), "%y/%m/%d %H:%M:%S"))
            continue

        match = _LOGGING_END.match(text)
        if match:
            header["end"] = _datetime_to_matlab_datenum(datetime.strptime(match.group(1), "%y/%m/%d %H:%M:%S"))
            continue

        match = _SAMPLE_PERIOD.match(text)
        if match:
            header["interval_days"] = _parse_time_as_days(match.group(1))
            continue

        match = _COMMENT.match(text)
        if match:
            header["comment"] = match.group(1).strip()
            continue

        match = _CHANNELS.match(text)
        if match:
            header["channels"] = float(match.group(1))
            header["samples"] = float(match.group(2))

    return header


def _build_time_vector(header: dict[str, float | str], n_samples: int) -> np.ndarray:
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


def _find_column_index(columns: list[str], name: str) -> int | None:
    target = name.upper()
    for idx, column in enumerate(columns):
        if column.upper() == target:
            return idx
    return None


def _parse_time_as_days(value: str) -> float:
    hours, minutes, seconds = value.split(":")
    total_seconds = int(hours) * 3600 + int(minutes) * 60 + int(seconds)
    return total_seconds / 86400.0


def _normalise_comment(comment: str) -> str:
    if comment.endswith("."):
        return comment
    return f"{comment}."


def _datetime_to_matlab_datenum(value: datetime) -> float:
    ordinal = value.toordinal()
    frac = (value - datetime(value.year, value.month, value.day)).total_seconds() / 86400.0
    return ordinal + 366 + frac