"""oxygenPP – derive oxygen-related variables using GSW TEOS-10.

Derived variables (where inputs permit):

* ``OXSOL_SURFACE`` – oxygen solubility at sea surface atmospheric pressure
  (µmol/kg), from ``gsw.O2sol_SP_pt(PSAL, potential_temperature)``.
* ``DOX1`` – dissolved oxygen in µmol/L (converted from DOX [ml/L] or DOXY
  [µmol/kg] or DOX2 [µmol/kg]).
* ``DOX2`` – dissolved oxygen in µmol/kg (converted from DOX [ml/L] or
  DOX1 [µmol/L] or DOXS [% saturation]).
* ``DOXS`` – oxygen saturation (%) = DOX2 / OXSOL_SURFACE * 100.

Unit conversion constants follow the SCOR WG-142 recommendations and the
SeaBird data processing manual, matching the MATLAB ``oxygenPP.m``.

Equivalent to the MATLAB ``oxygenPP.m`` (batch mode, single dataset).
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

# O2 [µmol/L] = 44.6596 * O2 [ml/L]
_ML_L_TO_UMOL_L = 44.6596


def _get_pres_rel(ds: object) -> "np.ndarray | None":  # type: ignore[return]
    import xarray as xr  # local import
    if not isinstance(ds, xr.Dataset):
        return None
    if "PRES_REL" in ds:
        return ds["PRES_REL"].values.astype(np.float64)
    if "PRES" in ds:
        return ds["PRES"].values.astype(np.float64) - 10.1325
    return None


def _get_lat_lon(dataset: IMOSDataset) -> tuple[float | None, float | None]:
    ds = dataset.dataset
    lat, lon = None, None
    for attr, target in [
        ("geospatial_lat_min", "lat"),
        ("geospatial_lat_max", "lat"),
        ("geospatial_lon_min", "lon"),
        ("geospatial_lon_max", "lon"),
    ]:
        val = ds.attrs.get(attr)
        if val is not None:
            try:
                fval = float(val)
                if target == "lat" and lat is None:
                    lat = fval
                elif target == "lon" and lon is None:
                    lon = fval
            except (TypeError, ValueError):
                pass
    for name in ("LATITUDE", "latitude", "lat"):
        if name in ds and lat is None:
            arr = ds[name].values
            finite = arr[np.isfinite(arr)]
            if finite.size:
                lat = float(np.mean(finite))
    for name in ("LONGITUDE", "longitude", "lon"):
        if name in ds and lon is None:
            arr = ds[name].values
            finite = arr[np.isfinite(arr)]
            if finite.size:
                lon = float(np.mean(finite))
    return lat, lon


class OxygenPP(PPRoutine):
    """Derive OXSOL_SURFACE, DOX1, DOX2, DOXS using GSW TEOS-10."""

    name = "oxygenPP"

    def run(self, dataset: IMOSDataset) -> PPResult:
        if not _GSW_AVAILABLE:
            return PPResult(modified=False, log="gsw not installed – oxygenPP skipped")

        ds = dataset.dataset

        # require TEMP, PSAL, and pressure
        if "TEMP" not in ds or "PSAL" not in ds:
            return PPResult(modified=False, log="TEMP or PSAL not found – skipped")

        pres_rel = _get_pres_rel(ds)
        if pres_rel is None:
            return PPResult(modified=False, log="No pressure variable found – skipped")

        # detect available DO inputs
        has_dox   = "DOX"  in ds
        has_doxy  = "DOXY" in ds
        has_dox1  = "DOX1" in ds
        has_dox2  = "DOX2" in ds
        has_doxs  = "DOXS" in ds

        if not any([has_dox, has_doxy, has_dox1, has_dox2, has_doxs]):
            return PPResult(modified=False, log="No dissolved oxygen variable found – skipped")

        # skip if all outputs already present
        if has_dox1 and has_dox2 and has_doxs:
            return PPResult(modified=False, log="DOX1/DOX2/DOXS already present – skipped")

        temp = ds["TEMP"].values.astype(np.float64)
        psal = ds["PSAL"].values.astype(np.float64)
        dims = ds["TEMP"].dims

        lat, lon = _get_lat_lon(dataset)
        if lat is None or lon is None:
            return PPResult(modified=False, log="Latitude/longitude not available – oxygenPP skipped")

        # potential temperature at p_ref=0
        SA = gsw.SA_from_SP(psal, pres_rel, lon, lat)
        pot_temp = gsw.pt0_from_t(SA, temp, pres_rel)

        # potential density at 0 dbar [kg/m³]
        CT = gsw.CT_from_pt(SA, pot_temp)
        pot_dens = gsw.rho(SA, CT, 0.0)  # kg/m³

        # oxygen solubility at surface atmospheric pressure [µmol/kg]
        oxsol = gsw.O2sol_SP_pt(psal, pot_temp)

        comments: list[str] = []

        if "OXSOL_SURFACE" not in ds:
            ds["OXSOL_SURFACE"] = (dims, oxsol.astype(np.float32))
            ds["OXSOL_SURFACE"].attrs.update(
                {
                    "long_name": "moles_of_oxygen_per_unit_mass_in_sea_water_at_saturation",
                    "units": "umol kg-1",
                    "comment": (
                        "oxygenPP: OXSOL_SURFACE derived from PSAL and potential "
                        "temperature using gsw.O2sol_SP_pt (TEOS-10)."
                    ),
                }
            )
            comments.append("OXSOL_SURFACE added")

        # --- DOX1 (µmol/L) ---
        if not has_dox1:
            dox1: np.ndarray | None = None
            if has_dox:
                # DOX [ml/L] → DOX1 [µmol/L]
                dox1 = ds["DOX"].values.astype(np.float64) * _ML_L_TO_UMOL_L
                src = "DOX [ml/L]"
            elif has_doxy:
                # DOXY [µmol/kg] → DOX1 [µmol/L]  (pot_dens in kg/m³ = kg/L * 1000)
                dox1 = ds["DOXY"].values.astype(np.float64) * (pot_dens / 1000.0)
                src = "DOXY [µmol/kg]"
            elif has_dox2:
                # DOX2 [µmol/kg] → DOX1 [µmol/L]
                dox1 = ds["DOX2"].values.astype(np.float64) * (pot_dens / 1000.0)
                src = "DOX2 [µmol/kg]"
            elif has_doxs:
                # DOXS [%] → DOX1 [µmol/L]
                doxs = ds["DOXS"].values.astype(np.float64)
                dox2_from_doxs = doxs / 100.0 * oxsol
                dox1 = dox2_from_doxs * (pot_dens / 1000.0)
                src = "DOXS [%]"
            if dox1 is not None:
                ds["DOX1"] = (dims, dox1.astype(np.float32))
                ds["DOX1"].attrs.update(
                    {
                        "long_name": "moles_of_oxygen_per_unit_volume_in_sea_water",
                        "units": "umol l-1",
                        "comment": f"oxygenPP: DOX1 derived from {src}.",
                    }
                )
                comments.append(f"DOX1 from {src}")

        # --- DOX2 (µmol/kg) ---
        if not has_dox2:
            dox2: np.ndarray | None = None
            if "DOX1" in ds:
                dox2 = ds["DOX1"].values.astype(np.float64) / (pot_dens / 1000.0)
                src = "DOX1 [µmol/L]"
            elif has_dox:
                dox2 = ds["DOX"].values.astype(np.float64) * _ML_L_TO_UMOL_L / (pot_dens / 1000.0)
                src = "DOX [ml/L]"
            elif has_doxy:
                dox2 = ds["DOXY"].values.astype(np.float64)
                src = "DOXY [µmol/kg]"
            elif has_doxs:
                dox2 = ds["DOXS"].values.astype(np.float64) / 100.0 * oxsol
                src = "DOXS [%]"
            if dox2 is not None:
                ds["DOX2"] = (dims, dox2.astype(np.float32))
                ds["DOX2"].attrs.update(
                    {
                        "long_name": "moles_of_oxygen_per_unit_mass_in_sea_water",
                        "units": "umol kg-1",
                        "comment": f"oxygenPP: DOX2 derived from {src}.",
                    }
                )
                comments.append(f"DOX2 from {src}")

        # --- DOXS (%) ---
        if not has_doxs:
            if "DOX2" in ds:
                doxs = ds["DOX2"].values.astype(np.float64) / oxsol * 100.0
                ds["DOXS"] = (dims, doxs.astype(np.float32))
                ds["DOXS"].attrs.update(
                    {
                        "long_name": "fractional_saturation_of_oxygen_in_sea_water",
                        "units": "%",
                        "comment": "oxygenPP: DOXS = DOX2 / OXSOL_SURFACE * 100.",
                    }
                )
                comments.append("DOXS from DOX2/OXSOL_SURFACE")

        if not comments:
            return PPResult(modified=False, log="oxygenPP: nothing to add")

        comment = "oxygenPP: " + "; ".join(comments) + "."
        self._append_history(dataset, comment)
        return PPResult(modified=True, log=comment)
