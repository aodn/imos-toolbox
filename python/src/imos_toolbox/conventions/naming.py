"""IMOS NetCDF naming rules loader."""

from __future__ import annotations

from pathlib import Path
from typing import Dict

from imos_toolbox.config import read_properties


def load_naming_rules(path: str | Path) -> Dict[str, str]:
    return read_properties(path)
