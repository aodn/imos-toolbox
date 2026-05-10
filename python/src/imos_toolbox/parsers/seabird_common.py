"""Shared utilities for Sea-Bird parser implementations."""

from __future__ import annotations

import csv
from datetime import datetime
from pathlib import Path
from typing import Any, Sequence

import numpy as np

from imos_toolbox.model import IMOSDataset


def parse_cnv_to_dataset(
    source_file: Path,
    mode: str,
    parser_name: str,
    instrument_model: str,
) -> IMOSDataset:
    """Parse a Sea-Bird CNV file into an IMOSDataset.

    Requires the optional `seabird` dependency.
    """

    try:
        from seabird.cnv import fCNV
    except ImportError as exc:
        raise ImportError(
            "Sea-Bird CNV parsing requires the 'seabird' package. Install with: pip install seabird"
        ) from exc

    profile = fCNV(str(source_file))
    variable_names = list(profile.keys())
    if not variable_names:
        raise ValueError(f"No data variables found in {source_file}")

    first_var = np.ma.filled(np.asarray(profile[variable_names[0]]), np.nan)
    obs_dim = "obs"

    dataset = IMOSDataset.empty()
    dataset.add_dimension(obs_dim, np.arange(first_var.shape[0]))

    for name in variable_names:
        values = np.ma.filled(np.asarray(profile[name]), np.nan)
        dataset.add_variable(name=name, data=values, dims=[obs_dim])

    dataset.set_attrs(
        {
            "toolbox_input_file": str(source_file),
            "featureType": mode,
            "instrument_make": "Seabird",
            "instrument_model": instrument_model,
            "parser": parser_name,
            "source_format": "cnv",
        }
    )

    for key, value in getattr(profile, "attrs", {}).items():
        dataset.dataset.attrs[f"seabird_{key}"] = _safe_attr(value)

    return dataset


def _safe_attr(value: Any) -> Any:
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return str(value)


def parse_sbe3x_asc_to_dataset(
    source_file: Path,
    mode: str,
    parser_name: str,
    instrument_model: str,
    variable_layout: Sequence[str] = ("TEMP", "CNDC", "PRES_REL", "PSAL"),
) -> IMOSDataset:
    """Parse Sea-Bird SBE3x-style ASCII data rows.

    Supports rows with trailing date/time fields and configurable variable
    layouts for the numeric columns preceding date/time.
    """

    if not variable_layout:
        raise ValueError("variable_layout must contain at least one variable")

    values_by_var: dict[str, list[float]] = {name: [] for name in variable_layout}
    time_values: list[float] = []

    column_count: int | None = None

    for raw_line in source_file.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("*") or line.startswith("s"):
            continue

        parts = [part.strip() for part in line.split(",")]
        if len(parts) < 3:
            continue

        candidate_count = len(parts) - 2
        if candidate_count < 1 or candidate_count > len(variable_layout):
            continue

        try:
            numeric = [float(token) for token in parts[:candidate_count]]
            dt = datetime.strptime(f"{parts[-2]}, {parts[-1]}", "%d %b %Y, %H:%M:%S")
        except ValueError:
            continue

        if column_count is None:
            column_count = candidate_count

        for index, var_name in enumerate(variable_layout):
            if index < candidate_count:
                values_by_var[var_name].append(numeric[index])
            elif column_count is not None and index < column_count:
                values_by_var[var_name].append(np.nan)

        time_values.append(_datetime_to_matlab_datenum(dt))

    first_var = variable_layout[0]
    if not values_by_var[first_var]:
        raise ValueError(f"No supported SBE3x ASCII samples found in {source_file}")

    obs_dim = "obs"
    dataset = IMOSDataset.empty()
    dataset.add_dimension(obs_dim, np.arange(len(values_by_var[first_var])))
    dataset.add_variable(name="TIME", data=np.asarray(time_values, dtype=float), dims=[obs_dim])

    max_columns = column_count if column_count is not None else len(variable_layout)
    for index, var_name in enumerate(variable_layout):
        if index >= max_columns:
            continue
        values = values_by_var[var_name]
        if len(values) < len(values_by_var[first_var]):
            values.extend([np.nan] * (len(values_by_var[first_var]) - len(values)))
        dataset.add_variable(name=var_name, data=np.asarray(values, dtype=float), dims=[obs_dim])

    dataset.set_attrs(
        {
            "toolbox_input_file": str(source_file),
            "featureType": mode,
            "instrument_make": "Seabird",
            "instrument_model": instrument_model,
            "parser": parser_name,
            "source_format": "asc",
        }
    )

    return dataset


def _datetime_to_matlab_datenum(value: datetime) -> float:
    ordinal = value.toordinal()
    frac = (value - datetime(value.year, value.month, value.day)).total_seconds() / 86400.0
    return ordinal + 366 + frac


def parse_sbe56_csv_to_dataset(
    source_file: Path,
    mode: str,
    parser_name: str,
    instrument_model: str,
) -> IMOSDataset:
    """Parse Sea-Bird SBE56 CSV export data.

    Expected columns include DATE, TIME, and TEMPERATURE (case-insensitive).
    """

    rows = source_file.read_text(encoding="utf-8", errors="ignore").splitlines()
    header_lines = [line for line in rows if line.strip().startswith("%")]
    data_lines = [line for line in rows if line.strip() and not line.strip().startswith("%")]

    if not data_lines:
        raise ValueError(f"No CSV data rows found in {source_file}")

    reader = csv.DictReader(data_lines)
    if reader.fieldnames is None:
        raise ValueError(f"Unable to detect CSV header row in {source_file}")

    normalized_fields = {_normalize_csv_field(name): name for name in reader.fieldnames}
    required = ["DATE", "TIME", "TEMPERATURE"]
    missing = [field for field in required if field not in normalized_fields]
    if missing:
        raise ValueError(f"SBE56 CSV missing required columns: {', '.join(missing)}")

    date_key = normalized_fields["DATE"]
    time_key = normalized_fields["TIME"]
    temp_key = normalized_fields["TEMPERATURE"]

    times: list[float] = []
    temps: list[float] = []
    for row in reader:
        try:
            temp = float((row.get(temp_key) or "").strip().strip('"'))
            dt = _parse_sbe56_datetime(
                date_text=(row.get(date_key) or "").strip().strip('"'),
                time_text=(row.get(time_key) or "").strip().strip('"'),
            )
        except ValueError:
            continue

        temps.append(temp)
        times.append(_datetime_to_matlab_datenum(dt))

    if not temps:
        raise ValueError(f"No valid SBE56 CSV samples found in {source_file}")

    obs_dim = "obs"
    dataset = IMOSDataset.empty()
    dataset.add_dimension(obs_dim, np.arange(len(temps)))
    dataset.add_variable(name="TIME", data=np.asarray(times, dtype=float), dims=[obs_dim])
    dataset.add_variable(name="TEMP", data=np.asarray(temps, dtype=float), dims=[obs_dim])

    dataset.set_attrs(
        {
            "toolbox_input_file": str(source_file),
            "featureType": mode,
            "instrument_make": "Seabird",
            "instrument_model": instrument_model,
            "parser": parser_name,
            "source_format": "csv",
        }
    )

    for line in header_lines:
        if "=" not in line:
            continue
        key, value = line.lstrip("%").split("=", 1)
        norm_key = "sbe56_" + "_".join(key.strip().lower().split())
        dataset.dataset.attrs[norm_key] = value.strip()

    return dataset


def _normalize_csv_field(field: str) -> str:
    return "".join(char for char in field.upper() if char.isalnum())


def _parse_sbe56_datetime(date_text: str, time_text: str) -> datetime:
    date_formats = ["%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y"]
    time_formats = ["%H:%M:%S.%f", "%H:%M:%S"]
    for date_fmt in date_formats:
        for time_fmt in time_formats:
            try:
                return datetime.strptime(f"{date_text} {time_text}", f"{date_fmt} {time_fmt}")
            except ValueError:
                continue
    raise ValueError("Unsupported SBE56 date/time format")
