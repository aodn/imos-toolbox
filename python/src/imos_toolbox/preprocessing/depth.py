"""depthPP – derive DEPTH from PRES_REL (or PRES) using GSW TEOS-10.

Adds ``DEPTH`` (positive downward, in metres) to datasets that have
``PRES_REL`` (preferred) or ``PRES`` but no existing ``DEPTH`` variable.

The latitude used for the conversion is taken from the dataset attributes
(``geospatial_lat_min``, ``geospatial_lat_max``, or ``LATITUDE`` variable).
When no latitude is available the approximation ``1 dbar ≈ 1 m`` is used.

Equivalent to the MATLAB ``depthPP.m`` (single-dataset, batch mode only).
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


def _get_latitude(dataset: IMOSDataset) -> float | None:
    """Return a representative latitude for depth calculation, or None."""
    ds = dataset.dataset
    # 1. scalar/mean from geospatial attributes
    for attr in ("geospatial_lat_min", "geospatial_lat_max"):
        val = ds.attrs.get(attr)
        if val is not None:
            try:
                return float(val)
            except (TypeError, ValueError):
                pass
    # 2. LATITUDE variable
    for name in ("LATITUDE", "latitude", "lat"):
        if name in ds:
            arr = ds[name].values
            finite = arr[np.isfinite(arr)]
            if finite.size:
                return float(np.mean(finite))
    return None


class DepthPP(PPRoutine):
    """Derive DEPTH from PRES_REL (or PRES) using GSW TEOS-10."""

    name = "depthPP"

    def run(self, dataset: IMOSDataset) -> PPResult:
        ds = dataset.dataset

        if "DEPTH" in ds:
            return PPResult(modified=False, log="DEPTH already present – skipped")

        # prefer PRES_REL, fall back to PRES
        if "PRES_REL" in ds:
            pres_rel = ds["PRES_REL"].values.astype(np.float64)
            pres_dims = ds["PRES_REL"].dims
            source = "PRES_REL"
        elif "PRES" in ds:
            pres_rel = ds["PRES"].values.astype(np.float64) - 10.1325
            pres_dims = ds["PRES"].dims
            source = "PRES (offset -10.1325 dbar applied)"
        else:
            return PPResult(modified=False, log="Neither PRES_REL nor PRES found – skipped")

        lat = _get_latitude(dataset)

        if _GSW_AVAILABLE and lat is not None:
            # depth = -gsw.z_from_p(p, lat)   (z_from_p returns negative height)
            depth = -gsw.z_from_p(pres_rel, lat)
            comment = (
                f"depthPP: DEPTH derived from {source} and latitude {lat:.4f}° "
                "using gsw.z_from_p (TEOS-10)."
            )
        else:
            # fallback: 1 dbar ≈ 1 m
            depth = pres_rel.copy()
            if lat is None:
                reason = "no latitude available"
            else:
                reason = "gsw not installed"
            comment = (
                f"depthPP: DEPTH approximated from {source} as 1 dbar ≈ 1 m "
                f"({reason})."
            )
            logger.warning("depthPP fallback: %s", reason)

        ds["DEPTH"] = (pres_dims, depth.astype(np.float32))
        ds["DEPTH"].attrs.update(
            {
                "long_name": "sea_floor_depth_below_sea_surface",
                "standard_name": "depth",
                "units": "m",
                "positive": "down",
                "valid_min": np.float32(-5.0),
                "valid_max": np.float32(12000.0),
                "comment": comment,
            }
        )

        self._append_history(dataset, comment)
        return PPResult(modified=True, log=comment)
