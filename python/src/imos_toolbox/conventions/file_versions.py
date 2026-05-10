"""IMOS file version definitions loader."""

from __future__ import annotations

from pathlib import Path
from typing import Dict, List

from imos_toolbox.conventions._parser import parse_csv


def load_file_versions(path: str | Path) -> List[Dict[str, object]]:
    versions: List[Dict[str, object]] = []
    for row in parse_csv(path):
        if len(row) < 4:
            continue
        versions.append(
            {
                "index": int(row[0].strip()),
                "file_id": row[1].strip(),
                "name": row[2].strip(),
                "description": row[3].strip(),
            }
        )
    return versions
