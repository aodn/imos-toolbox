"""salinityPP – derive practical salinity PSAL from CNDC, TEMP, PRES_REL.

Uses the Gibbs-SeaWater (GSW) TEOS-10 toolbox:

    R = 10 * CNDC / gsw.C3515()        # conductivity ratio
    PSAL = gsw.SP_from_R(R, TEMP, PRES_REL)

Skips datasets that already contain ``PSAL``, or that lack any of
``CNDC``, ``TEMP``, and at least one of ``PRES_REL`` / ``PRES`` / ``DEPTH``.

Equivalent to the MATLAB ``salinityPP.m``.
"""

from __future__ import annotations

import logging

import numpy as np

try:
    import gsw
    _GSW_AVAILABLE = True
except ImportError:
    _GSW_AVAILABLE = False

from imos_toolbox.model import IMOSDataset
from imos_toolbox.preprocessing.base import PPResult, PPRoutine

logger = logging.getLogger(__name__)


def _get_pres_rel(ds: object) -> "np.ndarray | None":  # type: ignore[return]
    """Return relative pressure array, or None if unavailable."""
    import xarray as xr
    if not isinstance(ds, xr.Dataset):
        return None
    if "PRES_REL" in ds:
        return ds["PRES_REL"].values.astype(np.float64)
    if "PRES" in ds:
        return ds["PRES"].values.astype(np.float64) - 10.1325
    return None


class SalinityPP(PPRoutine):
    """Derive PSAL from CNDC, TEMP, and PRES_REL using GSW TEOS-10."""

    name = "salinityPP"

    def run(self, dataset: IMOSDataset) -> PPResult:
        ds = dataset.dataset

        if "PSAL" in ds:
            return PPResult(modified=False, log="PSAL already present – skipped")

        if not _GSW_AVAILABLE:
            return PPResult(modified=False, log="gsw not installed – salinityPP skipped")

        if "CNDC" not in ds or "TEMP" not in ds:
            return PPResult(modified=False, log="CNDC or TEMP not found – skipped")

        pres_rel = _get_pres_rel(ds)
        if pres_rel is None:
            return PPResult(modified=False, log="No pressure variable found – skipped")

        cndc = ds["CNDC"].values.astype(np.float64)  # S/m
        temp = ds["TEMP"].values.astype(np.float64)  # °C ITS-90

        # Convert CNDC [S/m] → [mS/cm] (1 S/m = 10 mS/cm)
        cndc_mscm = 10.0 * cndc
        psal = gsw.SP_from_C(cndc_mscm, temp, pres_rel)

        dims = ds["TEMP"].dims
        ds["PSAL"] = (dims, psal.astype(np.float32))
        ds["PSAL"].attrs.update(
            {
                "long_name": "sea_water_practical_salinity",
                "standard_name": "sea_water_practical_salinity",
                "units": "1",
                "valid_min": np.float32(2.0),
                "valid_max": np.float32(41.0),
                "comment": (
                    "salinityPP: derived from CNDC, TEMP and PRES_REL using "
                    "gsw.SP_from_C (TEOS-10)."
                ),
            }
        )

        comment = (
            "salinityPP: PSAL derived from CNDC, TEMP and PRES_REL using "
            "gsw.SP_from_C (TEOS-10)."
        )
        self._append_history(dataset, comment)
        return PPResult(modified=True, log=comment)
