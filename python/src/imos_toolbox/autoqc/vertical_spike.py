"""Vertical spike QC for profile data using ARGO spike test."""

from __future__ import annotations

from pathlib import Path

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCVariableRoutine
from imos_toolbox.config import read_properties, resolve_repo_root
from imos_toolbox.model import IMOSDataset


def _load_thresholds(repo_root: Path | None = None) -> dict[str, str]:
    """Load threshold values from config file."""
    if repo_root is None:
        repo_root = resolve_repo_root(__file__)
    cfg = read_properties(repo_root / "AutomaticQC" / "imosVerticalSpikeQC.txt")
    return {k.upper(): v for k, v in cfg.items()}


class VerticalSpikeQC(QCVariableRoutine):
    """Detect spikes in vertical profiles using ARGO test.
    
    Test: |Vn - (Vn+1 + Vn-1)/2| - |(Vn+1 - Vn-1)/2| > threshold
    """

    name = "imosVerticalSpikeQC"

    def __init__(self, repo_root: Path | None = None):
        self.thresholds = _load_thresholds(repo_root)

    def check(self, dataset: IMOSDataset, variable_name: str) -> QCResult | None:
        ds = dataset.dataset
        
        # Only for profile mode (no TIME dimension or profile structure)
        if "TIME" in ds.coords and len(ds.coords["TIME"]) > 1:
            return None
        
        if variable_name not in ds.data_vars:
            return None

        base_name = self._strip_suffix(variable_name).upper()
        if base_name not in self.thresholds:
            return None

        var = ds[variable_name]
        data = var.values
        
        # Get threshold
        threshold_str = self.thresholds[base_name]
        if threshold_str == "PABIM":
            # PABIM not implemented yet, skip
            return None
        
        try:
            threshold = float(threshold_str)
        except ValueError:
            return None

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
            
            if n < 3:
                continue
            
            col_result = np.full(n, qc.RAW, dtype=np.int8)
            
            # Apply ARGO spike test for interior points
            for i in range(1, n - 1):
                if np.isnan(col_data[i]) or np.isnan(col_data[i-1]) or np.isnan(col_data[i+1]):
                    continue
                
                v_n = col_data[i]
                v_prev = col_data[i - 1]
                v_next = col_data[i + 1]
                
                # ARGO test
                test_val = abs(v_n - (v_next + v_prev) / 2) - abs((v_next - v_prev) / 2)
                
                if test_val > threshold:
                    col_result[i] = qc.PROBABLY_BAD
                else:
                    col_result[i] = qc.GOOD
            
            # Endpoints get GOOD if not NaN
            if not np.isnan(col_data[0]):
                col_result[0] = qc.GOOD
            if not np.isnan(col_data[-1]):
                col_result[-1] = qc.GOOD
            
            result_2d[:, col] = col_result

        if squeeze:
            result_flags: np.ndarray = result_2d.ravel()
        else:
            result_flags = result_2d

        return QCResult(
            variable_flags={variable_name: result_flags},
            log=f"ARGO spike test: threshold={threshold}",
        )

    @staticmethod
    def _strip_suffix(name: str) -> str:
        """Strip numeric suffix like '_1', '_2' from variable name."""
        if "_" in name:
            parts = name.rsplit("_", 1)
            if len(parts) == 2 and parts[1].isdigit():
                return parts[0]
        return name
