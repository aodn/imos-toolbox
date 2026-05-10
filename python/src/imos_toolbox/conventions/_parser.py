"""Shared parsing utilities for IMOS convention files."""

from __future__ import annotations

import csv
from pathlib import Path
from typing import Iterable, List

COMMENT_PREFIX = "%"


def iter_data_lines(path: str | Path) -> Iterable[str]:
    for raw_line in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(COMMENT_PREFIX):
            continue
        yield raw_line


def parse_csv(path: str | Path) -> List[List[str]]:
    lines = list(iter_data_lines(path))
    if not lines:
        return []
    reader = csv.reader(lines, skipinitialspace=True)
    return [list(row) for row in reader]


def coerce_value(value: str) -> object:
    text = value.strip()
    if text == "":
        return ""
    try:
        return int(text)
    except ValueError:
        pass
    try:
        return float(text)
    except ValueError:
        return text
