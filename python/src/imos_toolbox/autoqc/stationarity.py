"""Stationarity QC - flags flatline (constant value) regions.

Flags consecutive equal values when the number of consecutive points exceeds
a threshold based on sampling interval: T = 24 * (60 / delta_t_minutes)
"""

from __future__ import annotations

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCVariableRoutine
from imos_toolbox.model import IMOSDataset


class StationarityQC(QCVariableRoutine):
    """Flag flatline regions in time series data."""

    name = "imosStationarityQC"
    excluded_variables = ["TIME", "LATITUDE", "LONGITUDE", "NOMINAL_DEPTH"]

    def check(self, dataset: IMOSDataset, variable_name: str) -> QCResult | None:
        ds = dataset.dataset
        
        # Only for time series
        if "TIME" not in ds.coords:
            return None
        
        if variable_name not in ds.data_vars:
            return None

        var = ds[variable_name]
        data = var.values
        time = ds.coords["TIME"].values
        
        # Compute sampling interval in minutes
        if len(time) < 2:
            return None
        
        time_diff = np.diff(time.astype("datetime64[s]").astype(np.float64))
        median_interval = np.median(time_diff) / 60  # Convert to minutes
        
        if median_interval == 0:
            return None
        
        # Threshold: 24 hours worth of samples
        threshold = int(24 * (60 / median_interval))
        
        qc = QCFlags()

        # Handle 1D or 2D data
        if data.ndim == 1:
            data_2d = data.reshape(-1, 1)
            result_2d = np.full(data_2d.shape, qc.RAW, dtype=np.int8)
            squeeze = True
        else:
            data_2d = data
            result_2d = np.full(data.shape, qc.RAW, dtype=np.int8)
            squeeze = False

        for col in range(data_2d.shape[1]):
            col_data = data_2d[:, col]
            n = len(col_data)
            
            col_result = np.full(n, qc.RAW, dtype=np.int8)
            
            # Find consecutive equal values
            i = 0
            while i < n:
                if np.isnan(col_data[i]):
                    i += 1
                    continue
                
                # Count consecutive equal values
                j = i + 1
                while j < n and not np.isnan(col_data[j]) and col_data[j] == col_data[i]:
                    j += 1
                
                run_length = j - i
                
                # Flag if run exceeds threshold
                if run_length > threshold:
                    col_result[i:j] = qc.PROBABLY_BAD
                else:
                    col_result[i:j] = qc.GOOD
                
                i = j
            
            result_2d[:, col] = col_result

        if squeeze:
            final_flags: np.ndarray = result_2d.ravel()
        else:
            final_flags = result_2d

        return QCResult(
            variable_flags={variable_name: final_flags},
            log=f"Flatline threshold={threshold} consecutive points",
        )
