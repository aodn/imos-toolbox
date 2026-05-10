"""Shared parsing helpers for Star-Oddi DAT exports."""

from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path

import numpy as np

from imos_toolbox.model import IMOSDataset

_VAR_MAP = {
    "temperature": "TEMP",
    "temp": "TEMP",
    "pressure": "PRES",
    "pres": "PRES",
    "depth": "DEPTH",
    "salinity": "PSAL",
    "sal": "PSAL",
    "conductivity": "CNDC",
    "soundvelocity": "SOUND_VEL",
    "soundvel": "SOUND_VEL",
    "roll": "ROLL",
    "pitch": "PITCH",
}


def parse_staroddi_dat(source_file: Path, mode: str, parser_name: str, default_model: str) -> IMOSDataset:
    lines = source_file.read_text(encoding="utf-8", errors="ignore").splitlines()
    header_lines = [line for line in lines if line.startswith("#")]
    data_lines = [line for line in lines if line.strip() and not line.startswith("#")]

    if not data_lines:
        raise ValueError(f"No Star-Oddi samples found in {source_file}")

    header = _parse_header(header_lines)
    time_values, values_by_var = _parse_data_rows(data_lines, header)

    if len(time_values) == 0:
        raise ValueError(f"No valid Star-Oddi rows found in {source_file}")

    instrument_model = str(header.get("instrument_model", default_model))
    if default_model.lower().endswith("dst") and ("PITCH" in values_by_var or "ROLL" in values_by_var):
        instrument_model = "DST Tilt"

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

    attrs: dict[str, str | float] = {
        "toolbox_input_file": str(source_file),
        "featureType": mode,
        "instrument_make": "Star ODDI",
        "instrument_model": instrument_model,
        "instrument_serial_no": str(header.get("serial_no", "")),
        "parser": parser_name,
        "source_format": source_file.suffix.lower().lstrip("."),
    }
    if len(time_values) > 1:
        attrs["instrument_sample_interval"] = float(np.median(np.diff(np.asarray(time_values, dtype=float))) * 24.0 * 3600.0)

    dataset.set_attrs(attrs)
    return dataset


def _parse_header(lines: list[str]) -> dict[str, str | bool | int]:
    header: dict[str, str | bool | int] = {
        "is_date_joined": True,
        "date_format": "dd/mm/yyyy",
        "time_format": "HH:MM:SS",
    }

    recorder_expr = re.compile(r"(?:#\t)?Recorder(?:\s*:\s*|\t)(\S+)(?:\t([^\t]+))?(?:\t([^\t]+))?", re.IGNORECASE)
    date_time_expr = re.compile(r"Date\s*&\s*Time:\s*(\d+)", re.IGNORECASE)
    date_def_expr = re.compile(r"Date def\.:\s*([^\t/]+)", re.IGNORECASE)
    time_def_expr = re.compile(r"Time def\.:\s*(\d+)", re.IGNORECASE)

    for line in lines:
        stripped = line.lstrip("#").strip()

        recorder = recorder_expr.search(line)
        if recorder:
            groups = [g for g in recorder.groups() if g]
            if len(groups) >= 1:
                if groups[0].isdigit():
                    header["serial_no"] = groups[0]
                    if len(groups) >= 2:
                        header["instrument_model"] = groups[1].strip()
                else:
                    header["instrument_model"] = groups[0].strip()
                    if len(groups) >= 2 and groups[1].strip().isdigit():
                        header["serial_no"] = groups[1].strip()
            continue

        match = date_time_expr.search(stripped)
        if match:
            header["is_date_joined"] = match.group(1) != "0"
            continue

        match = date_def_expr.search(stripped)
        if match:
            header["date_format"] = match.group(1).strip()
            continue

        match = time_def_expr.search(stripped)
        if match:
            header["time_format"] = "HH:MM:SS" if match.group(1) == "0" else "HH.MM.SS"

    return header


def _parse_data_rows(lines: list[str], header: dict[str, str | bool | int]) -> tuple[np.ndarray, dict[str, np.ndarray]]:
    is_date_joined = bool(header.get("is_date_joined", True))

    times: list[float] = []
    by_var: dict[str, list[float]] = {}

    for line in lines:
        parts = [token for token in re.split(r"\s+", line.strip()) if token]
        if len(parts) < 3:
            continue

        idx = 1  # first token is sample number

        if is_date_joined:
            if len(parts) < 3:
                continue
            date_text = parts[idx]
            time_text = parts[idx + 1]
            value_start = idx + 2
        else:
            if len(parts) < 4:
                continue
            date_text = parts[idx]
            time_text = parts[idx + 1]
            value_start = idx + 2

        dt = _parse_datetime(date_text, time_text)
        if dt is None:
            continue

        numeric_tokens = parts[value_start:]
        parsed_values = []
        for token in numeric_tokens:
            cleaned = token.replace(",", ".")
            try:
                parsed_values.append(float(cleaned))
            except ValueError:
                parsed_values.append(np.nan)

        times.append(_datetime_to_matlab_datenum(dt))

        if not by_var:
            for col_idx in range(len(parsed_values)):
                by_var[f"col_{col_idx+1}"] = []

        for key in by_var:
            by_var[key].append(np.nan)

        for col_idx, value in enumerate(parsed_values):
            raw_name = f"col_{col_idx+1}"
            by_var[raw_name][-1] = value

    mapped_by_var: dict[str, np.ndarray] = {}
    ordered_keys = sorted(by_var.keys(), key=lambda k: int(k.split("_")[1]))
    for index, key in enumerate(ordered_keys, start=1):
        name_guess = _guess_var_name(lines, index)
        var_name = _normalize_var(name_guess) if name_guess else ""
        if not var_name:
            continue

        values = np.asarray(by_var[key], dtype=float)

        if var_name == "TEMP" and _is_probably_fahrenheit(values):
            values = (values - 32.0) * 5.0 / 9.0

        if var_name in mapped_by_var:
            suffix = 1
            while f"{var_name}_{suffix}" in mapped_by_var:
                suffix += 1
            var_name = f"{var_name}_{suffix}"

        mapped_by_var[var_name] = values

    return np.asarray(times, dtype=float), mapped_by_var


def _guess_var_name(lines: list[str], column_index: int) -> str:
    channel_pattern = re.compile(rf"Channel\s+{column_index}:\s*([^\(\t]+)", re.IGNORECASE)
    axis_pattern = re.compile(rf"Axis\s*\t?\s*{column_index}\s*\t\s*([^\(\t]+)", re.IGNORECASE)

    for line in lines:
        raw = line.lstrip("#")
        match = channel_pattern.search(raw)
        if match:
            return match.group(1).strip()
        match = axis_pattern.search(raw)
        if match:
            return match.group(1).strip()
    return ""


def _normalize_var(value: str) -> str:
    key = re.sub(r"[^a-zA-Z]", "", value).lower()
    return _VAR_MAP.get(key, "")


def _is_probably_fahrenheit(values: np.ndarray) -> bool:
    finite = values[np.isfinite(values)]
    if finite.size == 0:
        return False
    return float(np.nanmedian(finite)) > 60.0


def _parse_datetime(date_text: str, time_text: str) -> datetime | None:
    combos = [
        "%d.%m.%y %H:%M:%S",
        "%m.%d.%y %H:%M:%S",
        "%d/%m/%y %H:%M:%S",
        "%m/%d/%y %H:%M:%S",
        "%d-%m-%y %H:%M:%S",
        "%m-%d-%y %H:%M:%S",
        "%d/%m/%Y %H:%M:%S",
        "%Y-%m-%d %H:%M:%S",
        "%Y/%m/%d %H:%M:%S",
    ]

    normalized_time = time_text.replace(".", ":")
    text = f"{date_text} {normalized_time}"
    for fmt in combos:
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            continue
    return None


def _datetime_to_matlab_datenum(value: datetime) -> float:
    ordinal = value.toordinal()
    frac = (value - datetime(value.year, value.month, value.day)).total_seconds() / 86400.0
    return ordinal + 366 + frac
