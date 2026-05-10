"""SBE37SM parser implementation (initial .asc and .cnv support)."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser
from imos_toolbox.parsers.seabird_common import parse_cnv_to_dataset, parse_sbe3x_asc_to_dataset


class SBE37SMParser(BaseParser):
    """Parser for Sea-Bird SBE37SM output files."""

    parser_name = "SBE37SM"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("SBE37SM parser currently expects exactly one input file")

        source_file = file_list[0]
        suffix = source_file.suffix.lower()

        if suffix == ".cnv":
            return parse_cnv_to_dataset(
                source_file=source_file,
                mode=mode,
                parser_name=self.parser_name,
                instrument_model="SBE37SM",
            )
        if suffix == ".asc":
            return parse_sbe3x_asc_to_dataset(
                source_file=source_file,
                mode=mode,
                parser_name=self.parser_name,
                instrument_model="SBE37SM",
            )

        raise ValueError("SBE37SM parser currently supports .asc and .cnv files")
