"""QC test map loader."""

from __future__ import annotations

from pathlib import Path
from typing import Dict

from imos_toolbox.conventions._parser import parse_csv


def load_qc_tests(path: str | Path) -> Dict[str, int]:
    tests: Dict[str, int] = {}
    for row in parse_csv(path):
        if len(row) < 2:
            continue
        name = row[0].strip()
        value = int(row[1].strip())
        tests[name] = value
    return tests
