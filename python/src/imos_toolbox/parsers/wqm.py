"""WQM parser implementation (initial .dat and .raw support)."""

from __future__ import annotations

import csv
from datetime import datetime
from pathlib import Path
from typing import Iterable

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser

_FIELD_MAP = {
    "COND(MMHO)": "CNDC",
    "COND(S/M)": "CNDC",
    "TEMP(C)": "TEMP",
    "PRES(DBAR)": "PRES_REL",
    "SAL(PSU)": "PSAL",
    "DO(MG/L)": "DOXY",
    "DO(MMOL/M^3)": "DOX1",
    "DO(ML/L)": "DOX",
    "CHL(UG/L)": "CPHL",
    "CHLA(UG/L)": "CPHL",
    "F-CAL-CHL(UG/L)": "CPHL",
    "FACT-CHL(UG/L)": "CPHL",
    "U-CAL-CHL(UG/L)": "CPHL",
    "RAWCHL(COUNTS)": "FLU2",
    "CHLA(COUNTS)": "FLU2",
    "NTU": "TURB",
    "NTU(NTU)": "TURB",
    "TURBIDITY(NTU)": "TURB",
    "RHO": "DENS",
    "PAR(UMOL_PHTN/M2/S)": "PAR",
}


class WQMParser(BaseParser):
    """Parser for Wetlabs WQM files."""

    parser_name = "WQM"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("WQM parser currently expects exactly one input file")

        source_file = file_list[0]
        suffix = source_file.suffix.lower()

        if suffix == ".dat":
            return _parse_dat(source_file, mode, self.parser_name)
        if suffix == ".raw":
            return _parse_raw(source_file, mode, self.parser_name)

        raise ValueError("WQM parser currently supports .dat and .raw files")


def _parse_dat(source_file: Path, mode: str, parser_name: str) -> IMOSDataset:
    lines = source_file.read_text(encoding="utf-8", errors="ignore").splitlines()
    header_fields = _find_dat_header(lines)
    if not header_fields:
        raise ValueError(f"No valid WQM DAT header found in {source_file}")

    header_idx = next(idx for idx, line in enumerate(lines) if _looks_like_dat_header(line))

    field_index = {name.upper(): idx for idx, name in enumerate(header_fields)}
    date_idx = _first_existing_index(field_index, ["MMDDYY", "MM/DD/YY"])
    time_idx = _first_existing_index(field_index, ["HHMMSS", "HH:MM:SS"])
    serial_idx = _first_existing_index(field_index, ["WQM-SN", "SN"])
    if date_idx is None or time_idx is None:
        raise ValueError(f"WQM DAT missing date/time columns in {source_file}")

    by_var: dict[str, list[float]] = {}
    times: list[float] = []
    serial: str | None = None

    delimiter = "\t" if "\t" in lines[header_idx] else ","
    reader = csv.reader(lines[header_idx + 1 :], delimiter=delimiter)
    for row in reader:
        if len(row) < len(header_fields):
            continue

        try:
            dt = _parse_wqm_datetime(row[date_idx].strip(), row[time_idx].strip())
        except ValueError:
            continue

        times.append(_datetime_to_matlab_datenum(dt))

        if serial is None and serial_idx is not None:
            serial = row[serial_idx].strip()

        for idx, field in enumerate(header_fields):
            mapped = _map_field(field)
            if mapped is None:
                continue
            try:
                value = float(row[idx])
            except ValueError:
                value = np.nan
            by_var.setdefault(mapped, []).append(value)

    if not times:
        raise ValueError(f"No valid WQM DAT samples found in {source_file}")

    return _build_wqm_dataset(
        source_file=source_file,
        mode=mode,
        parser_name=parser_name,
        source_format="dat",
        times=times,
        values_by_var=by_var,
        serial=serial,
    )


def _parse_raw(source_file: Path, mode: str, parser_name: str) -> IMOSDataset:
    lines = source_file.read_text(encoding="utf-8", errors="ignore").splitlines()

    header_lines = []
    payload_lines = []
    in_data = False
    for line in lines:
        stripped = line.strip()
        if stripped == "<EOH>":
            in_data = True
            continue
        if not in_data:
            header_lines.append(stripped)
        elif stripped:
            payload_lines.append(stripped)

    format_line = next((line for line in header_lines if line.upper().startswith("FILE FORMAT:")), "")
    payload_fields = _parse_raw_payload_fields(format_line)

    times: list[float] = []
    by_var: dict[str, list[float]] = {}
    serial: str | None = None

    for line in payload_lines:
        parts = [part.strip() for part in line.split(",", 4)]
        if len(parts) != 5:
            continue
        if parts[1] != "6":
            continue

        serial = serial or parts[0]
        try:
            dt = _parse_wqm_raw_datetime(parts[2], parts[3])
        except ValueError:
            continue

        payload_values = [token.strip() for token in parts[4].split(",")]
        if not payload_values:
            continue

        times.append(_datetime_to_matlab_datenum(dt))
        for idx, field in enumerate(payload_fields):
            if idx >= len(payload_values):
                continue
            mapped = _map_field(field)
            if mapped is None:
                continue
            try:
                value = float(payload_values[idx])
            except ValueError:
                value = np.nan
            by_var.setdefault(mapped, []).append(value)

    if not times:
        raise ValueError(f"No valid WQM RAW samples found in {source_file}")

    return _build_wqm_dataset(
        source_file=source_file,
        mode=mode,
        parser_name=parser_name,
        source_format="raw",
        times=times,
        values_by_var=by_var,
        serial=serial,
    )


def _build_wqm_dataset(
    source_file: Path,
    mode: str,
    parser_name: str,
    source_format: str,
    times: list[float],
    values_by_var: dict[str, list[float]],
    serial: str | None,
) -> IMOSDataset:
    dataset = IMOSDataset.empty()
    obs_dim = "obs"
    dataset.add_dimension(obs_dim, np.arange(len(times)))
    dataset.add_variable(name="TIME", data=np.asarray(times, dtype=float), dims=[obs_dim])

    for var_name, values in values_by_var.items():
        if len(values) < len(times):
            values = [*values, *([np.nan] * (len(times) - len(values)))]
        dataset.add_variable(name=var_name, data=np.asarray(values[: len(times)], dtype=float), dims=[obs_dim])

    attrs = {
        "toolbox_input_file": str(source_file),
        "featureType": mode,
        "instrument_make": "WET Labs",
        "instrument_model": "WQM",
        "parser": parser_name,
        "source_format": source_format,
    }
    if serial:
        attrs["instrument_serial_no"] = serial
    dataset.set_attrs(attrs)
    return dataset


def _find_dat_header(lines: list[str]) -> list[str]:
    for line in lines:
        if _looks_like_dat_header(line):
            return [token.strip() for token in line.split("\t")]
    return []


def _looks_like_dat_header(line: str) -> bool:
    upper = line.upper()
    return ("MMDDYY" in upper or "MM/DD/YY" in upper) and ("HHMMSS" in upper or "HH:MM:SS" in upper)


def _first_existing_index(index_map: dict[str, int], names: list[str]) -> int | None:
    for name in names:
        if name in index_map:
            return index_map[name]
    return None


def _map_field(field_name: str) -> str | None:
    normalized = field_name.strip().upper()
    return _FIELD_MAP.get(normalized)


def _parse_raw_payload_fields(format_line: str) -> list[str]:
    if not format_line:
        return []
    _, _, right = format_line.partition(":")
    fields = [token.strip() for token in right.split(",")]
    # File format includes SN,State,Date,Time before payload; remove if present.
    payload_start = 0
    for idx, token in enumerate(fields):
        if token.upper().startswith("COND") or token.upper().startswith("TEMP"):
            payload_start = idx
            break
    return fields[payload_start:]


def _parse_wqm_datetime(date_text: str, time_text: str) -> datetime:
    for fmt in ("%m%d%y %H%M%S", "%m/%d/%y %H:%M:%S"):
        try:
            return datetime.strptime(f"{date_text} {time_text}", fmt)
        except ValueError:
            continue
    raise ValueError("Unsupported WQM DAT date/time format")


def _parse_wqm_raw_datetime(date_text: str, time_text: str) -> datetime:
    # RAW uses numeric date/time (MMDDYY, HHMMSS)
    return _parse_wqm_datetime(date_text, time_text)


def _datetime_to_matlab_datenum(value: datetime) -> float:
    ordinal = value.toordinal()
    frac = (value - datetime(value.year, value.month, value.day)).total_seconds() / 86400.0
    return ordinal + 366 + frac
