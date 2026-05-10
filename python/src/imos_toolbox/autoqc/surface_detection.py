"""Surface detection QC for ADCP using depth information.

Flags ADCP bins that are above the water surface based on depth and
bin distance information.
"""

from __future__ import annotations

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCSetRoutine
from imos_toolbox.model import IMOSDataset


class SurfaceDetectionByDepthSetQC(QCSetRoutine):
    """Flag ADCP bins above water surface."""

    name = "imosSurfaceDetectionByDepthSetQC"

    def run(self, dataset: IMOSDataset, **kwargs) -> QCResult:
        ds = dataset.dataset
        result = QCResult()
        
        # Need TIME, DEPTH, and bin distance dimension
        if "TIME" not in ds.coords or "DEPTH" not in ds.data_vars:
            return result
        
        # Check for bin distance dimension
        bin_dim = None
        for dim_name in ["HEIGHT_ABOVE_SENSOR", "DIST_ALONG_BEAMS"]:
            if dim_name in ds.dims:
                bin_dim = dim_name
                break
        
        if bin_dim is None:
            return result
        
        depth = ds["DEPTH"].values
        
        # Get bin distances
        if bin_dim in ds.coords:
            bin_dist = ds.coords[bin_dim].values
        else:
            return result
        
        # Get site bathymetry (nominal depth)
        bathy = ds.attrs.get("site_nominal_depth", None)
        if bathy is None:
            bathy = ds.attrs.get("instrument_nominal_depth", 100.0)
        
        qc = QCFlags()
        
        # For each time step, determine which bins are in water
        n_time = len(depth)
        n_bins = len(bin_dist)
        flags = np.full((n_time, n_bins), qc.RAW, dtype=np.int8)
        
        for t in range(n_time):
            if np.isnan(depth[t]):
                continue
            
            # Water column height from sensor
            water_height = bathy - depth[t]
            
            # Flag bins above surface
            for b in range(n_bins):
                if bin_dist[b] <= water_height:
                    flags[t, b] = qc.GOOD
                else:
                    flags[t, b] = qc.BAD
        
        # Apply flags to all variables with TIME and bin dimension
        for var_name_raw in ds.data_vars:
            var_name = str(var_name_raw)
            var = ds[var_name]
            if "TIME" in var.dims and bin_dim in var.dims:
                result.variable_flags[var_name] = flags
        
        result.log = f"Surface detection using {bin_dim} and DEPTH"
        return result
