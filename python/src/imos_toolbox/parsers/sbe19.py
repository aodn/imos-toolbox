"""SBE19 parser implementation (initial .cnv support)."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

from imos_toolbox.parsers.base import BaseParser
from imos_toolbox.parsers.seabird_common import parse_cnv_to_dataset


class SBE19Parser(BaseParser):
    """Parser for Sea-Bird SBE19plus V2 .cnv files."""

    parser_name = "SBE19"

    def parse(self, filenames: Iterable[str | Path], mode: str):
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("SBE19 parser currently expects exactly one input file")

        source_file = file_list[0]
        if source_file.suffix.lower() != ".cnv":
            raise ValueError("SBE19 parser currently supports .cnv files only")

        return parse_cnv_to_dataset(
            source_file=source_file,
            mode=mode,
            parser_name=self.parser_name,
            instrument_model="SBE19",
        )
