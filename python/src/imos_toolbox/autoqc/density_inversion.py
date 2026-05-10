"""Density inversion QC for profile data.

Flags salinity/temperature/conductivity/density values showing density inversions
or excessive density changes in vertical profiles.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCSetRoutine
from imos_toolbox.config import read_properties, resolve_repo_root
from imos_toolbox.model import IMOSDataset


def _load_threshold(repo_root: Path | None = None) -> float:
    """Load density threshold from config file."""
    if repo_root is None:
        repo_root = resolve_repo_root(__file__)
    cfg = read_properties(repo_root / "AutomaticQC" / "imosDensityInversionSetQC.txt")
    return float(cfg.get("threshold", "0.03"))


def _compute_density(temp: np.ndarray, psal: np.ndarray, pres: np.ndarray) -> np.ndarray:
    """Simplified density calculation (UNESCO 1983 EOS80).
    
    For full accuracy, should use gsw library. This is a simplified approximation.
    """
    # Simplified density formula (rough approximation)
    # Real implementation should use gsw.rho(SA, CT, p)
    rho = 1000 + 0.8 * psal - 0.2 * temp + 0.004 * pres
    return rho


class DensityInversionSetQC(QCSetRoutine):
    """Flag density inversions in vertical profiles."""

    name = "imosDensityInversionSetQC"

    def __init__(self, repo_root: Path | None = None):
        self.threshold = _load_threshold(repo_root)

    def run(self, dataset: IMOSDataset, **kwargs) -> QCResult:
        ds = dataset.dataset
        result = QCResult()
        
        # Only for profile mode
        if "TIME" in ds.coords and len(ds.coords["TIME"]) > 1:
            return result
        
        # Need TEMP, PSAL, and pressure
        if "TEMP" not in ds.data_vars or "PSAL" not in ds.data_vars:
            return result
        
        # Get pressure (try PRES_REL, PRES, or DEPTH)
        pres_var = None
        for pname in ["PRES_REL", "PRES", "DEPTH"]:
            if pname in ds.data_vars:
                pres_var = pname
                break
        
        if pres_var is None:
            return result
        
        temp = ds["TEMP"].values
        psal = ds["PSAL"].values
        pres = ds[pres_var].values
        
        # Compute density
        density = _compute_density(temp, psal, pres)
        
        qc = QCFlags()
        
        # Check for inversions (density should increase with depth)
        temp_flags = np.full(temp.shape, qc.RAW, dtype=np.int8)
        psal_flags = np.full(psal.shape, qc.RAW, dtype=np.int8)
        
        for i in range(1, len(density)):
            if np.isnan(density[i]) or np.isnan(density[i-1]):
                continue
            
            dens_diff = density[i] - density[i-1]
            
            # Density should increase going down (positive diff)
            # Flag if decrease > threshold or increase > threshold
            if dens_diff < -self.threshold or dens_diff > self.threshold:
                temp_flags[i] = qc.PROBABLY_BAD
                psal_flags[i] = qc.PROBABLY_BAD
                temp_flags[i-1] = qc.PROBABLY_BAD
                psal_flags[i-1] = qc.PROBABLY_BAD
            else:
                if temp_flags[i] == qc.RAW:
                    temp_flags[i] = qc.GOOD
                if psal_flags[i] == qc.RAW:
                    psal_flags[i] = qc.GOOD
        
        result.variable_flags["TEMP"] = temp_flags
        result.variable_flags["PSAL"] = psal_flags
        result.log = f"Density inversion threshold={self.threshold} kg/m³"
        
        return result
