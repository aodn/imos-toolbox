"""SBE39 parser implementation (initial .asc support)."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

from imos_toolbox.parsers.base import BaseParser
from imos_toolbox.parsers.seabird_common import parse_sbe3x_asc_to_dataset


class SBE39Parser(BaseParser):
    """Parser for Sea-Bird SBE39 .asc output.

    Initial implementation supports rows in one of these formats:
    - TEMP, DATE, TIME
    - TEMP, PRES_REL, DATE, TIME
    where DATE is like '01 Jan 2008' and TIME is '15:45:03'.
    """

    parser_name = "SBE39"

    def parse(self, filenames: Iterable[str | Path], mode: str):
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("SBE39 parser currently expects exactly one input file")

        source_file = file_list[0]
        if source_file.suffix.lower() != ".asc":
            raise ValueError("SBE39 parser currently supports .asc files only")

        return parse_sbe3x_asc_to_dataset(
            source_file=source_file,
            mode=mode,
            parser_name=self.parser_name,
            instrument_model="SBE39",
            variable_layout=("TEMP", "PRES_REL", "PSAL"),
        )
