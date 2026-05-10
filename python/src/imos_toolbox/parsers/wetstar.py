"""WetStar parser implementation (initial .raw + .dev support)."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser
from imos_toolbox.parsers.eco_common import parse_wetstar_raw, read_eco_device


class WetStarParser(BaseParser):
    """Parser for WetLabs WetStar raw files."""

    parser_name = "WetStar"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("WetStar parser currently expects exactly one input file")

        source_file = file_list[0]
        if source_file.suffix.lower() != ".raw":
            raise ValueError("WetStar parser currently supports .raw files only")

        dev_file = source_file.with_suffix(".dev")
        if not dev_file.exists():
            raise ValueError("WetStar parser requires matching .dev device file")

        device = read_eco_device(dev_file)
        return parse_wetstar_raw(source_file, device, mode, self.parser_name)
