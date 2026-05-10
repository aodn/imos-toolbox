"""Base parser interfaces."""

from __future__ import annotations

from abc import ABC, abstractmethod
from pathlib import Path
from typing import Iterable

from imos_toolbox.model import IMOSDataset


class BaseParser(ABC):
    """Abstract parser contract for instrument file readers."""

    parser_name: str = "base"

    @abstractmethod
    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        """Parse one or more input files into an IMOSDataset."""
