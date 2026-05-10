"""Rate of change QC - flags rapid changes in parameter values.

Flags consecutive values where the gradient exceeds a threshold based on
standard deviation. The test checks: |Vi - Vi-1| + |Vi - Vi+1| > 2*threshold
"""

from __future__ import annotations

from pathlib import Path

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCVariableRoutine
from imos_toolbox.config import read_properties, resolve_repo_root
from imos_toolbox.model import IMOSDataset


def _load_thresholds(repo_root: Path | None = None) -> dict[str, str]:
    """Load threshold expressions from config file."""
    if repo_root is None:
        repo_root = resolve_repo_root(__file__)
    cfg = read_properties(repo_root / "AutomaticQC" / "imosRateOfChangeQC.txt")
    return {k.upper(): v for k, v in cfg.items()}


def _compute_stddev(data: np.ndarray, time: np.ndarray, flags: np.ndarray) -> float:
    """Compute standard deviation from first month of good data."""
    qc = QCFlags()
    good_mask = (flags == qc.RAW) | (flags == qc.GOOD) | (flags == qc.PROBABLY_GOOD)
    
    if not np.any(good_mask):
        return np.nan
    
    first_good = np.argmax(good_mask)
    time_limit = time[first_good] + 30 * 24 * 3600  # 30 days in seconds
    month_mask = good_mask & (time >= time[first_good]) & (time <= time_limit)
    
    if not np.any(month_mask):
        return np.nan
    
    return float(np.std(data[month_mask]))


class RateOfChangeQC(QCVariableRoutine):
    """Flag values with excessive rate of change."""

    name = "imosRateOfChangeQC"

    def __init__(self, repo_root: Path | None = None):
        self.thresholds = _load_thresholds(repo_root)

    def check(self, dataset: IMOSDataset, variable_name: str) -> QCResult | None:
        ds = dataset.dataset
        if variable_name not in ds.data_vars:
            return None

        base_name = self._strip_suffix(variable_name).upper()
        if base_name not in self.thresholds:
            return None

        var = ds[variable_name]
        data = var.values
        qc_var = f"{variable_name}_QC"
        flags = ds[qc_var].values if qc_var in ds else np.full(data.shape, QCFlags.RAW, dtype=np.int8)

        # Get time in seconds
        if "TIME" not in ds.coords:
            return None
        time = ds.coords["TIME"].values.astype("datetime64[s]").astype(np.float64)

        qc = QCFlags()

        # Handle 1D or 2D data
        if data.ndim == 1:
            data_2d = data.reshape(-1, 1)
            flags_2d = flags.reshape(-1, 1)
            result_flags_2d = np.full(data_2d.shape, qc.RAW, dtype=np.int8)
            squeeze_output = True
        else:
            data_2d = data
            flags_2d = flags
            result_flags_2d = np.full(data.shape, qc.RAW, dtype=np.int8)
            squeeze_output = False

        for col in range(data_2d.shape[1]):
            col_data = data_2d[:, col]
            col_flags = flags_2d[:, col]
            
            # Skip already bad data
            bad_mask = col_flags == qc.BAD
            if np.all(bad_mask):
                continue
                
            good_data = col_data[~bad_mask]
            good_time = time[~bad_mask]
            
            if len(good_data) < 2:
                continue

            # Compute stddev from first month
            stddev = _compute_stddev(col_data, time, col_flags)
            if np.isnan(stddev) or stddev == 0:
                continue

            # Evaluate threshold expression
            threshold_expr = self.thresholds[base_name]
            try:
                threshold = eval(threshold_expr, {"stdDev": stddev})
            except Exception:
                continue

            # Compute gradients
            prev_grad = np.concatenate([[0], np.abs(np.diff(good_data))])
            next_grad = np.concatenate([np.abs(np.diff(good_data)), [0]])
            double_grad = prev_grad + next_grad

            # Adjust threshold for interior points (2x) vs endpoints (1x)
            thresh_arr = np.full(len(good_data), threshold)
            thresh_arr[1:-1] *= 2

            # Check time gaps > 1 hour
            time_diff_prev = np.concatenate([[0], np.diff(good_time)])
            time_diff_next = np.concatenate([np.diff(good_time), [0]])
            large_gap = (time_diff_prev > 3600) | (time_diff_next > 3600)

            # Flag points
            good_grad = (double_grad <= thresh_arr) & ~large_gap
            bad_grad = (double_grad > thresh_arr) & ~large_gap

            # Build result flags for this column
            col_result = np.full(len(col_data), qc.RAW, dtype=np.int8)
            good_indices = np.where(~bad_mask)[0]
            col_result[good_indices[good_grad]] = qc.GOOD
            col_result[good_indices[bad_grad]] = qc.PROBABLY_BAD

            result_flags_2d[:, col] = col_result

        if squeeze_output:
            result_flags: np.ndarray = result_flags_2d.ravel()
        else:
            result_flags = result_flags_2d

        return QCResult(
            variable_flags={variable_name: result_flags},
            log=f"threshold={self.thresholds[base_name]}",
        )

    @staticmethod
    def _strip_suffix(name: str) -> str:
        """Strip numeric suffix like '_1', '_2' from variable name."""
        if "_" in name:
            parts = name.rsplit("_", 1)
            if len(parts) == 2 and parts[1].isdigit():
                return parts[0]
        return name
