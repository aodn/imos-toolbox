"""Shared UI state helpers."""

from __future__ import annotations

from dataclasses import asdict, dataclass


@dataclass
class UIConfig:
    mode: str = "timeSeries"
    data_dir: str = ""
    field_trip: str = ""
    ddb_connection: str = ""

    def to_dict(self) -> dict[str, str]:
        return asdict(self)
