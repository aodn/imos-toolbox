"""YSI 6-Series parser implementation (initial binary .DAT support)."""

from __future__ import annotations

import struct
from pathlib import Path
from typing import Iterable

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.parsers.base import BaseParser

_RECORD_CODE_MAP = {
    1: "temperature",
    4: "cond",
    6: "spcond",
    10: "tds",
    12: "salinity",
    18: "ph",
    19: "orp",
    22: "depth",
    24: "bp",
    28: "battery",
    193: "chlorophyll",
    196: "latitude",
    197: "longitude",
    203: "turbidity",
    211: "odo",
    212: "odo2",
}

_VARIABLE_MAP = {
    "temperature": ("TEMP", 1.0),
    "cond": ("CNDC", 0.1),
    "spcond": ("SPEC_CNDC", 0.1),
    "tds": ("TDS", 1.0),
    "salinity": ("PSAL", 1.0),
    "ph": ("ACID", 1.0),
    "orp": ("ORP", 1.0),
    "depth": ("DEPTH", 1.0),
    "bp": ("PRES", 1.0 / 1.45037738),
    "battery": ("BAT_VOLT", 1.0),
    "chlorophyll": ("CPHL", 1.0),
    "turbidity": ("TURB", 1.0),
    "odo": ("DOXS", 1.0),
    "odo2": ("DOXY", 1.0),
}


class YSI6SeriesParser(BaseParser):
    """Parser for YSI 6-series binary DAT files."""

    parser_name = "YSI6Series"

    def parse(self, filenames: Iterable[str | Path], mode: str) -> IMOSDataset:
        file_list = [Path(name) for name in filenames]
        if len(file_list) != 1:
            raise ValueError("YSI6Series parser currently expects exactly one input file")

        source_file = file_list[0]
        if source_file.suffix.lower() != ".dat":
            raise ValueError("YSI6Series parser currently supports .dat files only")

        raw = source_file.read_bytes()
        if not raw:
            raise ValueError(f"Empty YSI file: {source_file}")

        record_fmt, record_start, record_len = _read_header(raw)
        records = _read_records(raw, record_fmt, record_start, record_len)

        times_seconds = records.pop("time", np.array([], dtype=float))
        if times_seconds.size == 0:
            raise ValueError(f"No valid YSI records found in {source_file}")

        # MATLAB: seconds since 1-Mar-1984 converted to MATLAB datenum.
        ysi_epoch = 723913.0  # datenum('1-Mar-1984')
        time_values = (times_seconds / 86400.0) + ysi_epoch

        dataset = IMOSDataset.empty()
        obs_dim = "obs"
        dataset.add_dimension(obs_dim, np.arange(len(time_values)))
        dataset.add_variable(name="TIME", data=np.asarray(time_values, dtype=float), dims=[obs_dim])
        dataset.add_variable(name="TIMESERIES", data=np.asarray(1, dtype=np.int32), dims=[])
        dataset.add_variable(name="LATITUDE", data=np.asarray(np.nan, dtype=float), dims=[])
        dataset.add_variable(name="LONGITUDE", data=np.asarray(np.nan, dtype=float), dims=[])
        dataset.add_variable(name="NOMINAL_DEPTH", data=np.asarray(np.nan, dtype=float), dims=[])

        for key, values in records.items():
            mapped = _VARIABLE_MAP.get(key)
            if not mapped:
                continue
            var_name, scale = mapped
            scaled = np.asarray(values, dtype=float) * float(scale)
            if var_name == "LATITUDE":
                if np.isfinite(scaled).any():
                    dataset.add_variable(name="LATITUDE", data=np.asarray(np.nanmean(scaled), dtype=float), dims=[])
                continue
            if var_name == "LONGITUDE":
                if np.isfinite(scaled).any():
                    dataset.add_variable(name="LONGITUDE", data=np.asarray(np.nanmean(scaled), dtype=float), dims=[])
                continue
            dataset.add_variable(name=var_name, data=scaled, dims=[obs_dim])

        attrs: dict[str, str | float] = {
            "toolbox_input_file": str(source_file),
            "featureType": mode,
            "instrument_make": "YSI",
            "instrument_model": "6 Series",
            "instrument_serial_no": "",
            "parser": self.parser_name,
            "source_format": "dat",
        }
        if len(time_values) > 1:
            attrs["instrument_sample_interval"] = float(np.median(np.diff(np.asarray(time_values, dtype=float))) * 24.0 * 3600.0)

        dataset.set_attrs(attrs)
        return dataset


def _read_header(data: bytes) -> tuple[list[int], int, int]:
    idx = data.find(bytes([66]))
    if idx < 0:
        raise ValueError("YSI sync byte 0x42 not found")

    record_fmt: list[int] = []
    cursor = idx
    while cursor + 14 < len(data):
        entry = data[cursor : cursor + 15]
        if entry[0] != 66:
            break
        record_fmt.append(entry[3])
        cursor += 15

    if not record_fmt:
        raise ValueError("YSI record format table is empty")

    record_start = cursor
    record_len = 1 + (len(record_fmt) + 1) * 4
    return record_fmt, record_start, record_len


def _read_records(data: bytes, record_fmt: list[int], record_start: int, record_len: int) -> dict[str, np.ndarray]:
    samples: dict[str, list[float]] = {"time": []}
    for code in record_fmt:
        key = _RECORD_CODE_MAP.get(code)
        if key:
            samples.setdefault(key, [])

    cursor = record_start
    while cursor + record_len <= len(data):
        record = data[cursor : cursor + record_len]
        cursor += record_len

        if record[0] != 68:
            next_sync = data.find(bytes([68]), cursor)
            if next_sync < 0:
                break
            cursor = next_sync
            continue

        time_val = struct.unpack("<I", record[1:5])[0]
        samples["time"].append(float(time_val))

        value_bytes = record[5:]
        n_floats = len(value_bytes) // 4
        vals = struct.unpack(f"<{n_floats}f", value_bytes[: n_floats * 4])

        for idx, code in enumerate(record_fmt):
            key = _RECORD_CODE_MAP.get(code)
            if not key or idx >= len(vals):
                continue
            samples[key].append(float(vals[idx]))

    n = len(samples["time"])
    out: dict[str, np.ndarray] = {}
    for key, values in samples.items():
        if len(values) < n:
            values = [*values, *([np.nan] * (n - len(values)))]
        out[key] = np.asarray(values[:n], dtype=float)
    return out
