"""velocityMagDirPP – derive CSPD and CDIR from UCUR and VCUR.

Adds ``CSPD`` (sea water speed in m/s) and ``CDIR`` (direction in degrees
clockwise from true North) to datasets containing ``UCUR`` (eastward) and
``VCUR`` (northward) velocity components.  Skips datasets that already
contain ``CSPD`` or ``CDIR``, or that lack either ``UCUR`` or ``VCUR``.

Direction convention (matching MATLAB ``velocityMagDirPP.m``):

    cdir = -atan2(VCUR, UCUR) * 180/π + 90   (range 0–360°)

Equivalent to the MATLAB ``velocityMagDirPP.m``.
"""

from __future__ import annotations

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.preprocessing.base import PPResult, PPRoutine


class VelocityMagDirPP(PPRoutine):
    """Derive CSPD and CDIR from UCUR and VCUR."""

    name = "velocityMagDirPP"

    def run(self, dataset: IMOSDataset) -> PPResult:
        ds = dataset.dataset

        if "CSPD" in ds or "CDIR" in ds:
            return PPResult(modified=False, log="CSPD/CDIR already present – skipped")

        if "UCUR" not in ds or "VCUR" not in ds:
            return PPResult(modified=False, log="UCUR or VCUR not found – skipped")

        ucur = ds["UCUR"].values.astype(np.float64)
        vcur = ds["VCUR"].values.astype(np.float64)
        dims = ds["UCUR"].dims

        cspd = np.sqrt(ucur ** 2 + vcur ** 2)

        # atan2 positive anti-clockwise with 0 on the east; convert to
        # oceanographic convention: positive clockwise with 0 at north.
        cdir = -np.arctan2(vcur, ucur) * 180.0 / np.pi + 90.0
        cdir = cdir % 360.0  # wrap to [0, 360)

        comment = "velocityMagDirPP: CSPD and CDIR derived from UCUR and VCUR."

        ds["CSPD"] = (dims, cspd.astype(np.float32))
        ds["CSPD"].attrs.update(
            {
                "long_name": "sea_water_speed",
                "standard_name": "sea_water_speed",
                "units": "m s-1",
                "valid_min": np.float32(0.0),
                "valid_max": np.float32(10.0),
                "comment": comment,
            }
        )

        ds["CDIR"] = (dims, cdir.astype(np.float32))
        ds["CDIR"].attrs.update(
            {
                "long_name": "direction_of_sea_water_velocity",
                "standard_name": "direction_of_sea_water_velocity",
                "units": "degrees_true",
                "valid_min": np.float32(0.0),
                "valid_max": np.float32(360.0),
                "comment": comment,
            }
        )

        self._append_history(dataset, comment)
        return PPResult(modified=True, log=comment)
