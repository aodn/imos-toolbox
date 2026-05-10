"""imosImpossibleDepthQC – flags DEPTH / PRES / PRES_REL outside acceptable bounds.

Port of ``AutomaticQC/imosImpossibleDepthQC.m``.

**timeSeries mode**:
  acceptable range derived from instrument & site nominal depths plus
  margin and knock-down angle::

    upperRange = instrumentNominalDepth - zNominalMargin
    lowerRange = instrumentNominalDepth + zNominalMargin
                 + (siteNominalDepth - (instrumentNominalDepth - zNominalMargin))
                   * (1 - cos(maxAngle * pi/180))

  Default parameters from ``AutomaticQC/imosImpossibleDepthQC.txt``:
    zNominalMargin = 15
    maxAngle = 70

**profile mode**:
  checks values lie between 0 and BOT_DEPTH + 20 %.

Pressure variables (PRES, PRES_REL) are converted from depth using
``gsw.p_from_z`` when latitude metadata is available.
"""

from __future__ import annotations

import math
from pathlib import Path
from typing import Any, Optional

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCVariableRoutine
from imos_toolbox.config import read_properties, resolve_repo_root
from imos_toolbox.model import IMOSDataset

DEPTH_PARAMS = {"DEPTH", "PRES_REL", "PRES"}

# Standard atmospheric pressure in dbar (gsw_P0 / 1e4)
P0_DBAR = 10.1325


def _strip_numeric_suffix(name: str) -> str:
    import re
    m = re.match(r"^(.+)_\d+$", name)
    return m.group(1) if m else name


class ImosImpossibleDepthQC(QCVariableRoutine):
    """Flag DEPTH/PRES/PRES_REL values outside acceptable bounds."""

    name = "imosImpossibleDepthQC"

    def __init__(
        self,
        repo_root: Path | None = None,
        mode: str = "timeSeries",
    ) -> None:
        self._repo_root = repo_root
        self._mode = mode

    def _load_params(self) -> tuple[float, float]:
        root = self._repo_root or resolve_repo_root(__file__)
        cfg = read_properties(root / "AutomaticQC" / "imosImpossibleDepthQC.txt")
        z_margin = float(cfg.get("zNominalMargin", "15"))
        max_angle = float(cfg.get("maxAngle", "70"))
        return z_margin, max_angle

    def check(
        self,
        dataset: IMOSDataset,
        variable_name: str,
    ) -> Optional[QCResult]:
        base_name = _strip_numeric_suffix(variable_name)
        if base_name not in DEPTH_PARAMS:
            return None

        ds = dataset.dataset
        data = ds[variable_name].values

        if self._mode == "profile":
            return self._check_profile(ds, variable_name, base_name, data)
        else:
            return self._check_timeseries(ds, variable_name, base_name, data)

    # ----- Profile mode -----
    def _check_profile(
        self, ds: Any, variable_name: str, base_name: str, data: np.ndarray
    ) -> Optional[QCResult]:
        if "BOT_DEPTH" not in ds:
            return QCResult(
                log="Warning: BOT_DEPTH not found – skipping impossible depth QC"
            )

        bot_depth = float(np.nanmax(ds["BOT_DEPTH"].values))
        if np.isnan(bot_depth):
            return QCResult(
                log="Warning: BOT_DEPTH is NaN – skipping impossible depth QC"
            )

        margin = 0.20
        upper_bound = bot_depth * (1 + margin)

        # Convert to pressure if needed
        if base_name in ("PRES", "PRES_REL"):
            lat = self._get_latitude(ds)
            if lat is not None:
                try:
                    import gsw
                    upper_bound = gsw.p_from_z(-upper_bound, lat)
                except ImportError:
                    pass  # Assume 1 dbar ≈ 1 m
            if base_name == "PRES":
                upper_bound += P0_DBAR

        flat = data.ravel()
        flags_flat = np.full(flat.shape, QCFlags.BAD, dtype=np.int8)
        passed = (flat >= 0) & (flat <= upper_bound)
        flags_flat[passed] = QCFlags.GOOD
        flags = flags_flat.reshape(data.shape)

        log = f"{variable_name}: profile bot_depth={bot_depth}, upper_bound={upper_bound:.2f}"
        return QCResult(variable_flags={variable_name: flags}, log=log)

    # ----- TimeSeries mode -----
    def _check_timeseries(
        self, ds: Any, variable_name: str, base_name: str, data: np.ndarray
    ) -> Optional[QCResult]:
        z_margin, max_angle = self._load_params()

        # Determine instrument and site nominal depths
        inst_depth = ds.attrs.get("instrument_nominal_depth")
        site_depth = ds.attrs.get("site_nominal_depth") or ds.attrs.get("site_depth_at_deployment")

        # Fallback: use instrument_nominal_height
        if inst_depth is None:
            inst_height = ds.attrs.get("instrument_nominal_height")
            if inst_height is not None and site_depth is not None:
                inst_depth = float(site_depth) - float(inst_height)

        if inst_depth is None or site_depth is None:
            return QCResult(
                log="Warning: insufficient depth metadata – skipping impossible depth QC"
            )

        inst_depth = float(inst_depth)
        site_depth = float(site_depth)

        # Compute acceptable range
        possible_min = inst_depth - z_margin
        possible_max = inst_depth + z_margin

        # Knock-down correction
        delta_z_max = (site_depth - possible_min) * (1 - math.cos(math.radians(max_angle)))
        possible_max += delta_z_max

        # Cannot be out of water
        possible_min = max(0.0, possible_min)

        # Clamp to global range (DEPTH valid_min) and site depth
        depth_valid_min = -5.0  # Default from imosParameters DEPTH valid_min
        possible_min = max(possible_min, depth_valid_min)
        possible_max = min(possible_max, site_depth + z_margin)

        # Pressure conversion
        if base_name in ("PRES", "PRES_REL"):
            lat = self._get_latitude(ds)
            if lat is not None:
                try:
                    import gsw
                    possible_min = gsw.p_from_z(-possible_min, lat)
                    possible_max = gsw.p_from_z(-possible_max, lat)
                    # Ensure min < max after conversion
                    if possible_min > possible_max:
                        possible_min, possible_max = possible_max, possible_min
                except ImportError:
                    pass  # 1 dbar ≈ 1 m assumed

            if base_name == "PRES":
                possible_min += P0_DBAR
                possible_max += P0_DBAR

        flat = data.ravel()
        flags_flat = np.full(flat.shape, QCFlags.BAD, dtype=np.int8)
        passed = (flat >= possible_min) & (flat <= possible_max)
        flags_flat[passed] = QCFlags.GOOD
        flags = flags_flat.reshape(data.shape)

        log = (
            f"{variable_name}: zNominalMargin={z_margin}, maxAngle={max_angle} "
            f"=> min={possible_min:.2f}, max={possible_max:.2f}"
        )
        return QCResult(variable_flags={variable_name: flags}, log=log)

    @staticmethod
    def _get_latitude(ds: Any) -> Optional[float]:
        lat_min = ds.attrs.get("geospatial_lat_min")
        lat_max = ds.attrs.get("geospatial_lat_max")
        if lat_min is not None and lat_max is not None:
            lat_min, lat_max = float(lat_min), float(lat_max)
            if lat_min == lat_max:
                return lat_min
            return lat_min + (lat_max - lat_min) / 2.0
        return None
