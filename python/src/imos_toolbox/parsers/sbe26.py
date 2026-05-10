"""SBE26 parser implementation (initial .tid support)."""

from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser


class SBE26Parser(BaseParser):
    """Parser for Sea-Bird SBE26 .tid files."""

    parser_name = "SBE26"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("SBE26 parser currently expects exactly one input file")

        source_file = file_list[0]
        if source_file.suffix.lower() != ".tid":
            raise ValueError("SBE26 parser currently supports .tid files only")

        time_values: list[float] = []
        pressures_dbar: list[float] = []
        temps: list[float] = []

        for raw_line in source_file.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = raw_line.strip()
            if not line:
                continue

            tokens = line.split()
            if len(tokens) < 4:
                continue

            # Expected: measurement_no, mm/dd/yyyy, HH:MM:SS, pressure_psia, temperature
            if len(tokens) < 5:
                continue

            try:
                date_text = tokens[1]
                time_text = tokens[2]
                pressure_psia = float(tokens[3])
                temp_c = float(tokens[4])
                dt = datetime.strptime(f"{date_text} {time_text}", "%m/%d/%Y %H:%M:%S")
            except ValueError:
                continue

            # MATLAB parser applies +2 minutes to represent center of 4-min average.
            dt_center = dt + timedelta(minutes=2)

            time_values.append(_datetime_to_matlab_datenum(dt_center))
            pressures_dbar.append(pressure_psia * 0.6894757)
            temps.append(temp_c)

        if not temps:
            raise ValueError(f"No valid SBE26 samples found in {source_file}")

        obs_dim = "obs"
        dataset = IMOSDataset.empty()
        dataset.add_dimension(obs_dim, np.arange(len(temps)))
        dataset.add_variable(name="TIME", data=np.asarray(time_values, dtype=float), dims=[obs_dim])
        dataset.add_variable(name="PRES_REL", data=np.asarray(pressures_dbar, dtype=float), dims=[obs_dim])
        dataset.add_variable(name="TEMP", data=np.asarray(temps, dtype=float), dims=[obs_dim])

        dataset.set_attrs(
            {
                "toolbox_input_file": str(source_file),
                "featureType": mode,
                "instrument_make": "Seabird",
                "instrument_model": "SBE26",
                "parser": self.parser_name,
                "source_format": "tid",
                "time_comment": "Time stamp corresponds to center of 4-minute measurement window",
            }
        )

        return dataset


def _datetime_to_matlab_datenum(value: datetime) -> float:
    ordinal = value.toordinal()
    frac = (value - datetime(value.year, value.month, value.day)).total_seconds() / 86400.0
    return ordinal + 366 + frac
