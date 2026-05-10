"""CTD surface soak QC - flags data during surface soak period.

Flags samples taken during CTD surface soak (before proper deployment) based on
soak status flags or depth/pressure criteria.
"""

from __future__ import annotations

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCSetRoutine
from imos_toolbox.model import IMOSDataset


class CTDSurfaceSoakQC(QCSetRoutine):
    """Flag CTD data during surface soak period."""

    name = "CTDSurfaceSoakQC"

    def run(self, dataset: IMOSDataset, **kwargs) -> QCResult:
        ds = dataset.dataset
        result = QCResult()
        
        # Only for profile mode
        if "TIME" in ds.coords and len(ds.coords["TIME"]) > 1:
            return result
        
        # Check for soak status variables
        soak_vars = []
        for var_name in ["tempSoakStatus", "cndSoakStatus", "oxSoakStatus"]:
            if var_name in ds.data_vars:
                soak_vars.append(var_name)
        
        if not soak_vars:
            # No soak status, try depth-based detection
            return self._depth_based_soak(ds, result)
        
        # Use soak status flags
        qc = QCFlags()
        
        # Get dimension size
        dim_size = 0
        for dim_name, dim_val in ds.dims.items():
            if dim_name == "DEPTH":
                dim_size = dim_val
                break
        
        if dim_size == 0:
            return result
        
        # Combine all soak statuses (any non-zero means soaking)
        soak_mask = np.zeros(dim_size, dtype=bool)
        for var_name in soak_vars:
            soak_data = ds[var_name].values
            soak_mask = soak_mask | (soak_data != 0)
        
        # Flag all variables during soak period
        for var_name_raw in ds.data_vars:
            var_name = str(var_name_raw)
            if var_name.endswith("SoakStatus"):
                continue
            
            var = ds[var_name]
            flags = np.full(var.shape, qc.RAW, dtype=np.int8)
            flags[soak_mask] = qc.BAD
            flags[~soak_mask] = qc.GOOD
            
            result.variable_flags[var_name] = flags
        
        result.log = "Surface soak flagged using soak status variables"
        return result
    
    def _depth_based_soak(self, ds, result: QCResult) -> QCResult:
        """Flag surface soak based on shallow depth."""
        qc = QCFlags()
        
        # Look for depth or pressure
        depth_var = None
        for dname in ["DEPTH", "PRES_REL", "PRES"]:
            if dname in ds.data_vars:
                depth_var = dname
                break
        
        if depth_var is None:
            return result
        
        depth = ds[depth_var].values
        
        # Flag samples shallower than 2m as potential soak
        soak_mask = depth < 2.0
        
        for var_name in ds.data_vars:
            if var_name in ["DEPTH", "PRES_REL", "PRES"]:
                continue
            
            var = ds[var_name]
            flags = np.full(var.shape, qc.RAW, dtype=np.int8)
            flags[soak_mask] = qc.PROBABLY_BAD
            flags[~soak_mask] = qc.GOOD
            
            result.variable_flags[var_name] = flags
        
        result.log = "Surface soak flagged using depth < 2m criterion"
        return result
