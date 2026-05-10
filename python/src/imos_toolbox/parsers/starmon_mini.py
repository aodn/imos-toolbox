"""Starmon Mini parser implementation (initial DAT support)."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser
from imos_toolbox.parsers.staroddi_common import parse_staroddi_dat


class StarmonMiniParser(BaseParser):
    """Parser for Star-Oddi Starmon Mini DAT exports."""

    parser_name = "StarmonMini"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("StarmonMini parser currently expects exactly one input file")

        source_file = file_list[0]
        if source_file.suffix.lower() != ".dat":
            raise ValueError("StarmonMini parser currently supports .dat files only")

        return parse_staroddi_dat(source_file, mode, self.parser_name, default_model="Starmon Mini")
