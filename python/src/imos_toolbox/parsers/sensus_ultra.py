"""Sensus Ultra parser implementation (initial CSV support)."""

from __future__ import annotations

import csv
from datetime import datetime
from pathlib import Path
from typing import Iterable

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser


class SensusUltraParser(BaseParser):
    """Parser for ReefNet Sensus Ultra exports."""

    parser_name = "sensusUltra"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("sensusUltra parser currently expects exactly one input file")

        source_file = file_list[0]
        if source_file.suffix.lower() != ".csv":
            raise ValueError("sensusUltra parser currently supports .csv files only")

        serials, times, temp_k, pres_mbar = _read_sensus_csv(source_file)
        if len(times) == 0:
            raise ValueError(f"No valid Sensus Ultra samples found in {source_file}")

        temp_c = np.asarray(temp_k, dtype=float) - 273.15
        pres_dbar = np.asarray(pres_mbar, dtype=float) / 100.0
        time_values = np.asarray(times, dtype=float)

        dataset = IMOSDataset.empty()
        obs_dim = "obs"
        dataset.add_dimension(obs_dim, np.arange(len(time_values)))
        dataset.add_variable(name="TIME", data=time_values, dims=[obs_dim])
        dataset.add_variable(name="TIMESERIES", data=np.asarray(1, dtype=np.int32), dims=[])
        dataset.add_variable(name="LATITUDE", data=np.asarray(np.nan, dtype=float), dims=[])
        dataset.add_variable(name="LONGITUDE", data=np.asarray(np.nan, dtype=float), dims=[])
        dataset.add_variable(name="NOMINAL_DEPTH", data=np.asarray(np.nan, dtype=float), dims=[])
        dataset.add_variable(name="TEMP", data=temp_c, dims=[obs_dim])
        dataset.add_variable(name="PRES", data=pres_dbar, dims=[obs_dim])

        attrs: dict[str, str | float] = {
            "toolbox_input_file": str(source_file),
            "featureType": mode,
            "instrument_make": "ReefNet",
            "instrument_model": "SensusUltra",
            "instrument_firmware": "3.02",
            "instrument_serial_no": serials[0] if serials else "",
            "parser": self.parser_name,
            "source_format": "csv",
        }
        if len(time_values) > 1:
            attrs["instrument_sample_interval"] = float(np.median(np.diff(time_values)) * 24.0 * 3600.0)

        dataset.set_attrs(attrs)
        return dataset


def _read_sensus_csv(source_file: Path) -> tuple[list[str], list[float], list[float], list[float]]:
    serials: list[str] = []
    times: list[float] = []
    temp_k: list[float] = []
    pres_mbar: list[float] = []

    with source_file.open("r", encoding="utf-8", errors="ignore") as handle:
        reader = csv.reader(handle)
        for row in reader:
            if len(row) < 12:
                continue
            try:
                year = int(float(row[3]))
                month = int(float(row[4]))
                day = int(float(row[5]))
                hour = int(float(row[6]))
                minute = int(float(row[7]))
                second = float(row[8]) + float(row[9])
                sec_int = int(second)
                micro = int(round((second - sec_int) * 1_000_000))
                dt = datetime(year, month, day, hour, minute, sec_int, micro)
                pressure = float(row[10])
                temperature = float(row[11])
            except ValueError:
                continue

            serials.append(row[1].strip())
            times.append(_datetime_to_matlab_datenum(dt))
            pres_mbar.append(pressure)
            temp_k.append(temperature)

    return serials, times, temp_k, pres_mbar


def _datetime_to_matlab_datenum(value: datetime) -> float:
    ordinal = value.toordinal()
    frac = (value - datetime(value.year, value.month, value.day)).total_seconds() / 86400.0
    return ordinal + 366 + frac