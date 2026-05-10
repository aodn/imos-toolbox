"""Dataset loading, serialization, and QC mutation helpers for the Dash UI."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np

from imos_toolbox.parsers import (
    AquatecParser,
    DR1050Parser,
    ECOBB9Parser,
    ECOTripletParser,
    NIWAParser,
    RCMParser,
    SBE19Parser,
    SBE26Parser,
    SBE37Parser,
    SBE37SMParser,
    SBE39Parser,
    SBE56Parser,
    SensusUltraParser,
    StarmonDSTParser,
    StarmonMiniParser,
    VemcoParser,
    WetStarParser,
    WQMParser,
    XRParser,
    YSI6SeriesParser,
)
from imos_toolbox.parsers.base import BaseParser


PARSER_CLASSES: dict[str, type[BaseParser]] = {
    "sbe19": SBE19Parser,
    "sbe26": SBE26Parser,
    "sbe37": SBE37Parser,
    "sbe37sm": SBE37SMParser,
    "sbe39": SBE39Parser,
    "sbe56": SBE56Parser,
    "wqm": WQMParser,
    "wetstar": WetStarParser,
    "ecotriplet": ECOTripletParser,
    "ecobb9": ECOBB9Parser,
    "dr1050": DR1050Parser,
    "xr": XRParser,
    "vemco": VemcoParser,
    "niwa": NIWAParser,
    "sensus-ultra": SensusUltraParser,
    "starmon-mini": StarmonMiniParser,
    "starmon-dst": StarmonDSTParser,
    "aquatec": AquatecParser,
    "rcm": RCMParser,
    "ysi6series": YSI6SeriesParser,
}


def parser_options() -> list[dict[str, str]]:
    return [{"label": name, "value": name} for name in sorted(PARSER_CLASSES)]


def parse_file_list(raw_value: str) -> list[str]:
    entries = [item.strip() for item in raw_value.replace("\n", ",").split(",")]
    return [item for item in entries if item]


def _coerce_scalar(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, np.generic):
        return value.item()
    if isinstance(value, (np.datetime64,)):
        return np.datetime_as_string(value, unit="s")
    if isinstance(value, (np.timedelta64,)):
        return str(value)
    if isinstance(value, (str, int, float, bool)):
        return value
    return str(value)


def _to_json_series(values: np.ndarray) -> list[Any]:
    output: list[Any] = []
    for value in values:
        scalar = _coerce_scalar(value)
        if isinstance(scalar, float) and not np.isfinite(scalar):
            output.append(None)
        else:
            output.append(scalar)
    return output


def _pick_primary_dim(xds: Any) -> str:
    if "TIME" in xds.coords and xds["TIME"].dims:
        return str(xds["TIME"].dims[0])
    for coord in xds.coords:
        cvar = xds[coord]
        if cvar.dims and np.issubdtype(cvar.dtype, np.datetime64):
            return str(cvar.dims[0])
    if xds.dims:
        return str(next(iter(xds.dims)))
    raise ValueError("Parsed dataset has no dimensions")


def load_dataset_state(parser_name: str, filenames: list[str], mode: str) -> dict[str, Any]:
    parser_class = PARSER_CLASSES.get(parser_name)
    if parser_class is None:
        raise ValueError(f"Unknown parser: {parser_name}")

    paths = [str(Path(name).expanduser()) for name in filenames]
    parser = parser_class()
    imos_dataset = parser.parse(paths, mode)
    xds = imos_dataset.to_xarray()

    primary_dim = _pick_primary_dim(xds)
    n_rows = int(xds.sizes[primary_dim])
    x_name = "TIME" if "TIME" in xds.coords and primary_dim in xds["TIME"].dims else primary_dim

    if x_name in xds:
        x_values = _to_json_series(np.asarray(xds[x_name].values))
    else:
        x_values = list(range(n_rows))

    variables: dict[str, list[Any]] = {}
    qc_flags: dict[str, list[int]] = {}
    for var_name, data_array in xds.data_vars.items():
        var_name_str = str(var_name)
        if data_array.ndim != 1 or primary_dim not in data_array.dims:
            continue
        values = _to_json_series(np.asarray(data_array.values))
        variables[var_name_str] = values
        numeric_arr = np.asarray(data_array.values)
        if np.issubdtype(numeric_arr.dtype, np.number):
            qc_flags[var_name_str] = [1] * len(values)

    if not variables:
        raise ValueError("Parsed dataset has no 1D variables that can be previewed")

    attrs = {str(key): str(value) for key, value in xds.attrs.items()}
    selected_var = next(iter(qc_flags or variables))

    return {
        "parser": parser_name,
        "files": paths,
        "mode": mode,
        "primary_dim": primary_dim,
        "x_name": x_name,
        "x": x_values,
        "variables": variables,
        "qc_flags": qc_flags,
        "selected_var": selected_var,
        "attrs": attrs,
    }


def dataset_variables(dataset_state: dict[str, Any] | None) -> list[str]:
    if not dataset_state:
        return []
    variables = dataset_state.get("variables", {})
    if not isinstance(variables, dict):
        return []
    return [str(name) for name in variables.keys()]


def mark_spikes(
    dataset_state: dict[str, Any],
    variable: str,
    threshold: float,
    flag_code: int = 4,
) -> tuple[dict[str, Any], int]:
    values = dataset_state.get("variables", {}).get(variable, [])
    numeric = np.asarray([np.nan if value is None else value for value in values], dtype=float)
    finite = np.isfinite(numeric)
    if finite.sum() < 2:
        return dataset_state, 0

    mean = float(np.nanmean(numeric))
    stdev = float(np.nanstd(numeric))
    if stdev == 0.0:
        return dataset_state, 0

    z_scores = np.abs((numeric - mean) / stdev)
    spike_mask = np.isfinite(z_scores) & (z_scores >= threshold)
    idx = np.where(spike_mask)[0]

    updated = dict(dataset_state)
    qc_flags = dict(dataset_state.get("qc_flags", {}))
    existing = list(qc_flags.get(variable, [1] * len(values)))
    for i in idx:
        existing[int(i)] = int(flag_code)
    qc_flags[variable] = existing
    updated["qc_flags"] = qc_flags
    updated["selected_var"] = variable
    return updated, int(len(idx))


def apply_manual_flags(
    dataset_state: dict[str, Any],
    variable: str,
    indices: list[int],
    flag_code: int,
) -> tuple[dict[str, Any], int]:
    values = dataset_state.get("variables", {}).get(variable, [])
    if not values:
        return dataset_state, 0

    updated = dict(dataset_state)
    qc_flags = dict(dataset_state.get("qc_flags", {}))
    existing = list(qc_flags.get(variable, [1] * len(values)))

    applied = 0
    for index in indices:
        if 0 <= index < len(existing):
            existing[index] = int(flag_code)
            applied += 1

    qc_flags[variable] = existing
    updated["qc_flags"] = qc_flags
    updated["selected_var"] = variable
    return updated, applied
