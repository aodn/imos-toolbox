"""Parameter registry loader."""

from __future__ import annotations

from pathlib import Path
from typing import Dict, List

from imos_toolbox.conventions._parser import coerce_value, parse_csv

FIELDS = [
    "name",
    "is_cf",
    "standard_name",
    "units",
    "direction_positive",
    "reference_datum",
    "data_code",
    "fill_value",
    "valid_min",
    "valid_max",
    "netcdf_type",
]


def load_parameters(path: str | Path) -> List[Dict[str, object]]:
    rows = parse_csv(path)
    parameters: List[Dict[str, object]] = []
    for row in rows:
        if not row:
            continue
        normalized = [field.replace("percent", "%") for field in row]
        values = [coerce_value(field) for field in normalized]
        entry = {key: values[idx] if idx < len(values) else "" for idx, key in enumerate(FIELDS)}
        parameters.append(entry)
    return parameters


_PARAM_CACHE: Dict[str, Dict[str, object]] | None = None


def get_parameter_info(param_name: str) -> Dict[str, object]:
    """Get parameter metadata by name.

    Args:
        param_name: IMOS parameter name (e.g., 'TEMP', 'PSAL')

    Returns:
        Dictionary with parameter metadata (standard_name, units, etc.)
    """
    global _PARAM_CACHE

    if _PARAM_CACHE is None:
        # Load parameters on first access
        from imos_toolbox.config import resolve_repo_root

        try:
            repo_root = resolve_repo_root(Path.cwd())
            param_file = repo_root / "IMOS" / "imosParameters.txt"
            params = load_parameters(param_file)
            _PARAM_CACHE = {str(p["name"]): p for p in params if p.get("name")}
        except Exception:
            _PARAM_CACHE = {}

    return _PARAM_CACHE.get(param_name, {})
