"""Aquatec parser implementation (initial AQUAlogger key-value format support)."""

from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path
from typing import Iterable

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser


class AquatecParser(BaseParser):
    """Parser for Aquatec AQUAlogger exports."""

    parser_name = "aquatec"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("aquatec parser currently expects exactly one input file")

        source_file = file_list[0]
        if source_file.suffix.lower() not in {".txt", ".dat", ".csv"}:
            raise ValueError("aquatec parser currently supports .txt/.dat/.csv files")

        meta, heading, data_lines = _read_sections(source_file)
        if not data_lines:
            raise ValueError(f"No Aquatec DATA rows found in {source_file}")

        time_values, temp_values, pres_values = _parse_data_rows(data_lines, heading)
        if len(time_values) == 0:
            raise ValueError(f"No valid Aquatec rows found in {source_file}")

        dataset = IMOSDataset.empty()
        obs_dim = "obs"
        dataset.add_dimension(obs_dim, np.arange(len(time_values)))
        dataset.add_variable(name="TIME", data=np.asarray(time_values, dtype=float), dims=[obs_dim])
        dataset.add_variable(name="TIMESERIES", data=np.asarray(1, dtype=np.int32), dims=[])
        dataset.add_variable(name="LATITUDE", data=np.asarray(np.nan, dtype=float), dims=[])
        dataset.add_variable(name="LONGITUDE", data=np.asarray(np.nan, dtype=float), dims=[])
        dataset.add_variable(name="NOMINAL_DEPTH", data=np.asarray(np.nan, dtype=float), dims=[])

        if temp_values.size > 0 and np.any(np.isfinite(temp_values)):
            dataset.add_variable(name="TEMP", data=temp_values, dims=[obs_dim])
        if pres_values.size > 0 and np.any(np.isfinite(pres_values)):
            dataset.add_variable(name="PRES", data=pres_values, dims=[obs_dim])

        attrs: dict[str, str | float] = {
            "toolbox_input_file": str(source_file),
            "featureType": mode,
            "instrument_make": "Aquatec",
            "instrument_model": _instrument_model(meta),
            "instrument_firmware": meta.get("VERSION", ""),
            "instrument_serial_no": _instrument_serial(meta),
            "parser": self.parser_name,
            "source_format": source_file.suffix.lower().lstrip("."),
        }

        sample_interval = _sample_interval_seconds(meta)
        if sample_interval is not None and sample_interval > 0:
            attrs["instrument_sample_interval"] = sample_interval
        elif len(time_values) > 1:
            attrs["instrument_sample_interval"] = float(np.median(np.diff(np.asarray(time_values, dtype=float))) * 24.0 * 3600.0)

        dataset.set_attrs(attrs)
        return dataset


def _read_sections(source_file: Path) -> tuple[dict[str, str], list[str], list[str]]:
    meta: dict[str, str] = {}
    heading: list[str] = []
    data_lines: list[str] = []

    for line in source_file.read_text(encoding="utf-8", errors="ignore").splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("DATA"):
            data_lines.append(stripped)
            continue

        key, _, remainder = stripped.partition(",")
        key = key.strip().upper()
        remainder = remainder.strip()
        if key == "HEADING":
            heading = [token.strip() for token in remainder.split(",")]
        else:
            meta[key] = remainder

    return meta, heading, data_lines


def _parse_data_rows(data_lines: list[str], heading: list[str]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    lower_head = [h.lower() for h in heading]
    has_temp = any("ext temperature" in h for h in lower_head)
    has_pres = any(h == "pressure" for h in lower_head)

    time_values: list[float] = []
    temp_values: list[float] = []
    pres_values: list[float] = []

    for line in data_lines:
        parts = [token.strip() for token in line.split(",")]
        if len(parts) < 2:
            continue

        dt_text = parts[1]
        dt = _parse_aquatec_datetime(dt_text)
        if dt is None:
            continue

        values = parts[2:]
        time_values.append(_datetime_to_matlab_datenum(dt))

        temp_val = np.nan
        pres_val = np.nan

        if has_temp and len(values) >= 2:
            try:
                temp_val = float(values[1])
            except ValueError:
                temp_val = np.nan

        if has_pres and len(values) >= 4:
            try:
                pres_bar = float(values[3])
                if np.isfinite(pres_bar):
                    pres_val = pres_bar * 10.0
            except ValueError:
                pres_val = np.nan

        temp_values.append(temp_val)
        pres_values.append(pres_val)

    return np.asarray(time_values, dtype=float), np.asarray(temp_values, dtype=float), np.asarray(pres_values, dtype=float)


def _instrument_model(meta: dict[str, str]) -> str:
    logger_type = meta.get("LOGGER TYPE", "")
    model = logger_type
    for token in ("Pressure & Temperature", "Pressure", "Temperature"):
        model = model.replace(token, "")
    model = model.strip()
    if model:
        return f"Aqualogger {model}"
    return "Aqualogger"


def _instrument_serial(meta: dict[str, str]) -> str:
    logger = meta.get("LOGGER", "")
    return logger.split(",")[0].strip() if logger else ""


def _sample_interval_seconds(meta: dict[str, str]) -> float | None:
    regime = meta.get("REGIME", "")
    if not regime:
        return None

    tokens = [token.strip() for token in regime.split(",") if token.strip()]
    if len(tokens) < 2:
        return None

    amount_match = re.search(r"[-+]?\d*\.?\d+", tokens[1])
    if not amount_match:
        return None

    amount = float(amount_match.group(0))
    unit = tokens[1].lower()
    if "minute" in unit:
        return amount * 60.0
    return amount


def _parse_aquatec_datetime(value: str) -> datetime | None:
    formats = ["%H:%M:%S %d/%m/%Y", "%H:%M:%S %d/%m/%y"]
    for fmt in formats:
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    return None


def _datetime_to_matlab_datenum(value: datetime) -> float:
    ordinal = value.toordinal()
    frac = (value - datetime(value.year, value.month, value.day)).total_seconds() / 86400.0
    return ordinal + 366 + frac
