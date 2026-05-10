"""imosImpossibleDateQC – flags TIME values outside an acceptable range.

Port of ``AutomaticQC/imosImpossibleDateQC.m``.

The default date range is read from ``AutomaticQC/imosImpossibleDateQC.txt``:
  dateMin = 01/01/2007
  dateMax = (empty → current UTC time)

Any TIME value outside [dateMin, dateMax] receives ``BAD`` (4); values
inside the range receive ``GOOD`` (1).
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCVariableRoutine
from imos_toolbox.config import read_properties, resolve_repo_root
from imos_toolbox.model import IMOSDataset


def _load_date_bounds(repo_root: Path | None = None) -> tuple[datetime, datetime]:
    """Read dateMin/dateMax from the config txt file."""
    if repo_root is None:
        repo_root = resolve_repo_root(__file__)
    cfg_path = repo_root / "AutomaticQC" / "imosImpossibleDateQC.txt"
    props = read_properties(cfg_path)

    date_min_str = props.get("dateMin", "01/01/2007")
    date_min = datetime.strptime(date_min_str, "%d/%m/%Y").replace(tzinfo=timezone.utc)

    date_max_str = props.get("dateMax", "")
    if date_max_str:
        date_max = datetime.strptime(date_max_str, "%d/%m/%Y").replace(tzinfo=timezone.utc)
    else:
        date_max = datetime.now(timezone.utc)

    return date_min, date_max


class ImosImpossibleDateQC(QCVariableRoutine):
    """Flag TIME values outside the acceptable date range."""

    name = "imosImpossibleDateQC"
    applicable_variables = ["TIME"]

    def __init__(self, repo_root: Path | None = None) -> None:
        self._repo_root = repo_root

    def check(
        self,
        dataset: IMOSDataset,
        variable_name: str,
    ) -> Optional[QCResult]:
        if variable_name != "TIME":
            return None

        ds = dataset.dataset
        if "TIME" not in ds and "TIME" not in ds.coords:
            return None

        time_data = ds["TIME"].values  # numpy datetime64 array
        date_min, date_max = _load_date_bounds(self._repo_root)

        # Convert bounds to numpy datetime64
        np_min = np.datetime64(date_min.strftime("%Y-%m-%dT%H:%M:%S"), "ns")
        np_max = np.datetime64(date_max.strftime("%Y-%m-%dT%H:%M:%S"), "ns")

        flags = np.full(time_data.shape, QCFlags.BAD, dtype=np.int8)
        good_mask = (time_data >= np_min) & (time_data <= np_max)
        flags[good_mask] = QCFlags.GOOD

        log = f"dateMin={date_min:%d/%m/%Y}, dateMax={date_max:%d/%m/%Y}"
        n_bad = int(np.sum(~good_mask))
        if n_bad > 0:
            log += f" ({n_bad} points failed)"

        return QCResult(variable_flags={"TIME": flags}, log=log)
