"""Time series spike QC using Hampel filter."""

from __future__ import annotations

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCVariableRoutine
from imos_toolbox.autoqc.spike_classifiers import hampel_filter
from imos_toolbox.model import IMOSDataset


class TimeSeriesSpikeQC(QCVariableRoutine):
    """Detect spikes in time series data using Hampel filter."""

    name = "imosTimeSeriesSpikeQC"
    excluded_variables = ["TIME", "LATITUDE", "LONGITUDE", "NOMINAL_DEPTH"]

    def __init__(
        self,
        half_window: int = 3,
        n_sigma: float = 3.0,
        min_mad: float = 0.0,
    ):
        self.half_window = half_window
        self.n_sigma = n_sigma
        self.min_mad = min_mad

    def check(self, dataset: IMOSDataset, variable_name: str) -> QCResult | None:
        ds = dataset.dataset
        
        # Skip if not time series mode
        if "TIME" not in ds.coords:
            return None
        
        if variable_name not in ds.data_vars:
            return None

        var = ds[variable_name]
        data = var.values
        
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
            
            # Skip if all NaN or too few points
            valid = ~np.isnan(col_data)
            if np.sum(valid) < 2 * self.half_window + 1:
                continue
            
            # Run Hampel filter
            spikes, _ = hampel_filter(
                col_data[valid],
                self.half_window,
                self.n_sigma,
                self.min_mad,
            )
            
            # Map spikes back to original indices
            col_result = np.full(len(col_data), qc.RAW, dtype=np.int8)
            valid_indices = np.where(valid)[0]
            col_result[valid_indices[~spikes]] = qc.GOOD
            col_result[valid_indices[spikes]] = qc.PROBABLY_BAD
            
            result_2d[:, col] = col_result

        if squeeze:
            result_flags: np.ndarray = result_2d.ravel()
        else:
            result_flags = result_2d

        return QCResult(
            variable_flags={variable_name: result_flags},
            log=f"Hampel filter: window={self.half_window}, n_sigma={self.n_sigma}",
        )
