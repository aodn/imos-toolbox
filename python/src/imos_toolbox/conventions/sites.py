"""IMOS site registry loader."""

from __future__ import annotations

from pathlib import Path
from typing import Dict, List

from imos_toolbox.conventions._parser import parse_csv

FIELDS = [
    "name",
    "longitude",
    "latitude",
    "longitude_threshold",
    "latitude_threshold",
    "distance_km_threshold",
]


def load_sites(path: str | Path) -> List[Dict[str, object]]:
    sites: List[Dict[str, object]] = []
    for row in parse_csv(path):
        if len(row) < 6:
            continue
        values = [field.strip() for field in row[:6]]
        entry = {
            "name": values[0],
            "longitude": float(values[1]),
            "latitude": float(values[2]),
            "longitude_threshold": float(values[3]),
            "latitude_threshold": float(values[4]),
            "distance_km_threshold": float(values[5]),
        }
        sites.append(entry)
    return sites
