"""Spike classifiers for time series QC."""

import numpy as np


def hampel_filter(
    signal: np.ndarray,
    half_window: int = 3,
    n_sigma: float = 3.0,
    min_mad: float = 0.0,
) -> tuple[np.ndarray, np.ndarray]:
    """Hampel filter for spike detection using median absolute deviation.
    
    Args:
        signal: 1D array of values
        half_window: Half-width of sliding window
        n_sigma: Number of MAD standard deviations for threshold
        min_mad: Minimum MAD value to consider (ignore if below)
    
    Returns:
        spikes: Boolean array marking spike locations
        filtered: Signal with spikes replaced by window median
    """
    n = len(signal)
    spikes = np.zeros(n, dtype=bool)
    filtered = signal.copy()
    
    for i in range(n):
        # Define window bounds
        start = max(0, i - half_window)
        end = min(n, i + half_window + 1)
        window = signal[start:end]
        
        # Compute median and MAD
        median = np.median(window)
        mad = np.median(np.abs(window - median))
        
        # Skip if MAD too small
        if mad < min_mad:
            continue
        
        # Check if point is a spike
        if np.abs(signal[i] - median) > n_sigma * 1.4826 * mad:
            spikes[i] = True
            filtered[i] = median
    
    return spikes, filtered
