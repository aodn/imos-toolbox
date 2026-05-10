"""QC flag definitions loader."""

from __future__ import annotations

from pathlib import Path
from typing import Dict, List

from imos_toolbox.conventions._parser import parse_csv


def _parse_color(value: str) -> List[float]:
    stripped = value.strip().lstrip("[").rstrip("]")
    if not stripped:
        return []
    parts = stripped.split()
    return [float(part) for part in parts]


def load_qc_flags(path: str | Path) -> List[Dict[str, object]]:
    flags: List[Dict[str, object]] = []
    for row in parse_csv(path):
        if len(row) < 5:
            continue
        qc_id = int(row[0].strip())
        raw_flag_value = row[1].strip()
        flag_value: object = raw_flag_value
        try:
            flag_value = int(raw_flag_value)
        except ValueError:
            pass
        description = row[2].strip()
        color = _parse_color(row[3])
        classes = row[4].split()
        flags.append(
            {
                "qc_id": qc_id,
                "flag_value": flag_value,
                "description": description,
                "color": color,
                "classes": classes,
            }
        )
    return flags
