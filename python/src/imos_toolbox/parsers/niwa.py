"""NIWA parser implementation (initial .DAT3 ASCII support)."""

from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path
from typing import Iterable

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser

_PARAM_MAP = {
    "con": "CNDC",
    "tem": "TEMP",
    "pre": "PRES_REL",
    "sal": "PSAL",
}


class NIWAParser(BaseParser):
    """Parser for NIWA ASCII DAT3 exports."""

    parser_name = "NIWA"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("NIWA parser currently expects exactly one input file")

        source_file = file_list[0]
        header_lines, params, _units, rows = _read_dat3(source_file)
        times, values_by_var = _parse_rows(params, rows)

        if len(times) == 0:
            raise ValueError(f"No valid NIWA samples found in {source_file}")

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
            var_attrs: dict[str, float] = {}
            if var_name == "PRES_REL":
                var_attrs["applied_offset"] = float(-14.7 * 0.689476)
            dataset.add_variable(
                name=var_name,
                data=np.asarray(values[: len(times)], dtype=float),
                dims=[obs_dim],
                attrs=var_attrs,
            )

        metadata_attrs: dict[str, str | float] = {
            "toolbox_input_file": str(source_file),
            "featureType": mode,
            "instrument_make": "NIWA ASCII .DAT3",
            "instrument_model": _extract_model(header_lines),
            "instrument_firmware": "",
            "instrument_serial_no": _extract_serial(header_lines),
            "parser": self.parser_name,
            "source_format": source_file.suffix.lower().lstrip("."),
        }

        sample_interval = _extract_sample_interval(header_lines)
        if sample_interval is not None:
            metadata_attrs["instrument_sample_interval"] = sample_interval
        elif len(times) > 1:
            metadata_attrs["instrument_sample_interval"] = float(np.median(np.diff(np.asarray(times, dtype=float))) * 24.0 * 3600.0)

        lineage = _extract_lineage(header_lines)
        if lineage:
            metadata_attrs["lineage"] = lineage

        dataset.set_attrs(metadata_attrs)
        return dataset


def _read_dat3(source_file: Path) -> tuple[list[str], list[str], list[str], list[list[str]]]:
    lines = source_file.read_text(encoding="utf-8", errors="ignore").splitlines()
    if len(lines) < 21:
        raise ValueError(f"NIWA DAT3 file too short: {source_file}")

    header_lines = [line[:78].rstrip() for line in lines[:18]]
    params = lines[18].split()
    units = lines[19].split()
    rows = [line.split() for line in lines[20:] if line.strip()]

    return header_lines, params, units, rows


def _parse_rows(params: list[str], rows: list[list[str]]) -> tuple[np.ndarray, dict[str, np.ndarray]]:
    if len(params) < 2:
        raise ValueError("NIWA DAT3 parameters line is invalid")

    times: list[float] = []
    values_by_var: dict[str, list[float]] = {}

    for row in rows:
        if len(row) < 2:
            continue

        dt = _parse_datetime(row[0], row[1])
        if dt is None:
            continue

        parsed_values: dict[str, float] = {}
        for param_idx in range(1, len(params)):
            row_idx = param_idx + 1
            if row_idx >= len(row):
                continue
            code = params[param_idx].lower()
            var_name = _PARAM_MAP.get(code)
            if not var_name:
                continue
            try:
                value = float(row[row_idx])
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


def _parse_datetime(date_text: str, time_text: str) -> datetime | None:
    formats = [
        "%Y-%m-%d %H:%M:%S",
        "%d/%m/%Y %H:%M:%S",
        "%Y/%m/%d %H:%M:%S",
        "%d-%m-%Y %H:%M:%S",
    ]
    text = f"{date_text} {time_text}"
    for fmt in formats:
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            continue
    return None


def _extract_model(header_lines: list[str]) -> str:
    if len(header_lines) > 1 and header_lines[1].strip():
        return header_lines[1].split()[0]
    return ""


def _extract_serial(header_lines: list[str]) -> str:
    if len(header_lines) > 1 and header_lines[1].strip():
        tokens = header_lines[1].split()
        if len(tokens) > 1:
            return tokens[1]
    return ""


def _extract_sample_interval(header_lines: list[str]) -> float | None:
    if len(header_lines) <= 6:
        return None
    numbers = re.findall(r"[-+]?\d*\.?\d+", header_lines[6])
    if len(numbers) < 4:
        return None
    days = float(numbers[0])
    hours = float(numbers[1])
    minutes = float(numbers[2])
    seconds = float(numbers[3])
    return days * 24.0 * 3600.0 + hours * 3600.0 + minutes * 60.0 + seconds


def _extract_lineage(header_lines: list[str]) -> str:
    lineage_parts = [line.strip() for line in header_lines[8:18] if line.strip()]
    if not lineage_parts:
        return ""
    text = ". ".join(lineage_parts)
    if not text.endswith("."):
        text += "."
    return text.replace("..", ".")


def _datetime_to_matlab_datenum(value: datetime) -> float:
    ordinal = value.toordinal()
    frac = (value - datetime(value.year, value.month, value.day)).total_seconds() / 86400.0
    return ordinal + 366 + frac