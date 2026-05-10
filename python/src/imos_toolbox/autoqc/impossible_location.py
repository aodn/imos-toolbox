"""imosImpossibleLocationSetQC – flags LATITUDE/LONGITUDE outside site bounds.

Port of ``AutomaticQC/imosImpossibleLocationSetQC.m``.

Uses the site registry (``IMOS/imosSites.txt``) to determine whether
the recorded lat/lon fall within the acceptable area.  Two modes:

* **Rectangular** (if ``distance_km_threshold`` is NaN): checks lon/lat
  independently against ``nominal ± threshold``.
* **Circular** (if ``distance_km_threshold`` is a number): checks
  great-circle distance ≤ threshold km using the Vincenty/haversine
  approximation.

Out-of-bounds points receive ``PROBABLY_BAD`` (3).
"""

from __future__ import annotations

import math
from pathlib import Path
from typing import Any, Dict, List, Optional

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCSetRoutine
from imos_toolbox.config import resolve_repo_root
from imos_toolbox.conventions.sites import load_sites
from imos_toolbox.model import IMOSDataset


def _haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in metres (WGS-84 mean radius)."""
    R = 6_371_000.0  # metres
    rlat1, rlat2 = math.radians(lat1), math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(rlat1) * math.cos(rlat2) * math.sin(dlon / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _haversine_vec(
    lat1: float,
    lon1: float,
    lat2: np.ndarray,
    lon2: np.ndarray,
) -> np.ndarray:
    """Vectorised great-circle distance in metres."""
    R = 6_371_000.0
    rlat1 = math.radians(lat1)
    rlat2 = np.radians(lat2)
    dlat = np.radians(lat2 - lat1)
    dlon = np.radians(lon2 - lon1)
    a = np.sin(dlat / 2) ** 2 + math.cos(rlat1) * np.cos(rlat2) * np.sin(dlon / 2) ** 2
    return R * 2 * np.arctan2(np.sqrt(a), np.sqrt(1 - a))


def _find_site(
    sites: List[Dict[str, object]],
    site_code: str,
) -> Optional[Dict[str, object]]:
    for s in sites:
        if str(s["name"]).strip() == site_code.strip():
            return s
    return None


class ImosImpossibleLocationSetQC(QCSetRoutine):
    """Flag LATITUDE and LONGITUDE outside site boundaries."""

    name = "imosImpossibleLocationSetQC"

    def __init__(self, repo_root: Path | None = None) -> None:
        self._repo_root = repo_root

    def run(self, dataset: IMOSDataset, **kwargs: Any) -> QCResult:
        ds = dataset.dataset
        result = QCResult()

        # Require LATITUDE and LONGITUDE variables
        if "LONGITUDE" not in ds or "LATITUDE" not in ds:
            return result

        lon_data = ds["LONGITUDE"].values
        lat_data = ds["LATITUDE"].values

        # Need site_code in global attrs
        site_code = ds.attrs.get("site_code", "")
        if not site_code:
            result.log = "Warning: no site_code – skipping impossible location QC"
            return result

        # Load sites
        root = self._repo_root or resolve_repo_root(__file__)
        sites = load_sites(root / "IMOS" / "imosSites.txt")
        site = _find_site(sites, site_code)

        if site is None:
            result.log = f"Warning: site '{site_code}' not found in imosSites.txt"
            return result

        flag_lon = np.full(lon_data.shape, QCFlags.PROBABLY_BAD, dtype=np.int8)
        flag_lat = np.full(lat_data.shape, QCFlags.PROBABLY_BAD, dtype=np.int8)

        dist_km = float(str(site["distance_km_threshold"]))
        if math.isnan(dist_km):
            # Rectangular mode
            lon_thresh = float(str(site["longitude_threshold"]))
            lat_thresh = float(str(site["latitude_threshold"]))
            nom_lon = float(str(site["longitude"]))
            nom_lat = float(str(site["latitude"]))

            good_lon = (lon_data >= nom_lon - lon_thresh) & (lon_data <= nom_lon + lon_thresh)
            good_lat = (lat_data >= nom_lat - lat_thresh) & (lat_data <= nom_lat + lat_thresh)

            result.log = (
                f"longitudePlusMinusThreshold={lon_thresh}, "
                f"latitudePlusMinusThreshold={lat_thresh}"
            )
        else:
            # Circular mode
            nom_lon = float(str(site["longitude"]))
            nom_lat = float(str(site["latitude"]))

            if np.isscalar(lat_data) or lat_data.ndim == 0:
                dist_val = _haversine_m(nom_lat, nom_lon, float(lat_data), float(lon_data))
                good_lon = np.array(dist_val / 1000.0 <= dist_km)
            else:
                dist_arr = _haversine_vec(nom_lat, nom_lon, lat_data, lon_data)
                good_lon = dist_arr / 1000.0 <= dist_km
            good_lat = good_lon.copy() if isinstance(good_lon, np.ndarray) else np.array(good_lon)

            result.log = f"distanceKmPlusMinusThreshold={dist_km}"

        flag_lon[good_lon] = QCFlags.GOOD
        flag_lat[good_lat] = QCFlags.GOOD

        result.variable_flags["LONGITUDE"] = flag_lon
        result.variable_flags["LATITUDE"] = flag_lat

        return result
