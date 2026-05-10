"""pressureRelPP – derive PRES_REL from PRES.

Adds ``PRES_REL`` (sea water pressure relative to sea surface, in dbar) by
subtracting one standard atmosphere (10.1325 dbar) from absolute pressure
``PRES``.  Skips datasets that already have ``PRES_REL`` or lack ``PRES``.

Equivalent to the MATLAB ``pressureRelPP.m``.
"""

from __future__ import annotations

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.preprocessing.base import PPResult, PPRoutine

# 1 standard atmosphere expressed in dbar
_ONE_ATM_DBAR = 10.1325


class PressureRelPP(PPRoutine):
    """Convert absolute pressure PRES to relative pressure PRES_REL."""

    name = "pressureRelPP"

    def __init__(self, offset_dbar: float = -_ONE_ATM_DBAR) -> None:
        self._offset = offset_dbar

    def run(self, dataset: IMOSDataset) -> PPResult:
        ds = dataset.dataset

        if "PRES_REL" in ds:
            return PPResult(modified=False, log="PRES_REL already present – skipped")

        if "PRES" not in ds:
            return PPResult(modified=False, log="PRES not found – skipped")

        pres_rel = ds["PRES"].values + self._offset
        ds["PRES_REL"] = (ds["PRES"].dims, pres_rel.astype(ds["PRES"].dtype))
        ds["PRES_REL"].attrs.update(
            {
                "long_name": "sea_water_pressure_due_to_sea_water",
                "standard_name": "sea_water_pressure_due_to_sea_water",
                "units": "dbar",
                "valid_min": np.float32(-15.0),
                "valid_max": np.float32(12000.0),
                "applied_offset": self._offset,
                "comment": (
                    f"pressureRelPP: PRES_REL computed from PRES applying "
                    f"offset {self._offset:+.4f} dbar."
                ),
            }
        )

        comment = (
            f"pressureRelPP: PRES_REL computed from PRES applying "
            f"offset {self._offset:+.4f} dbar."
        )
        self._append_history(dataset, comment)
        return PPResult(modified=True, log=comment)
