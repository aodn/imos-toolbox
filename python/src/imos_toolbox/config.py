"""Configuration helpers for IMOS Toolbox settings files."""

from __future__ import annotations

from pathlib import Path
from typing import Dict

COMMENT_PREFIX = "%"
KEY_VALUE_SEPARATOR = "="
DEFAULT_PROPERTIES_FILE = "toolboxProperties.txt"


def resolve_repo_root(start_path: str | Path) -> Path:
    current = Path(start_path).resolve()
    if current.is_file():
        current = current.parent
    for parent in [current, *current.parents]:
        candidate = parent / DEFAULT_PROPERTIES_FILE
        if candidate.exists():
            return parent
    raise FileNotFoundError(f"Unable to find {DEFAULT_PROPERTIES_FILE} from {start_path}")


def read_properties(path: str | Path) -> Dict[str, str]:
    """Read a MATLAB-style key=value properties file."""

    properties: Dict[str, str] = {}
    for raw_line in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(COMMENT_PREFIX):
            continue
        if KEY_VALUE_SEPARATOR not in line:
            continue
        key, value = line.split(KEY_VALUE_SEPARATOR, 1)
        properties[key.strip()] = value.strip()
    return properties


def load_properties(root_path: str | Path) -> Dict[str, str]:
    root = resolve_repo_root(root_path)
    return read_properties(root / DEFAULT_PROPERTIES_FILE)
