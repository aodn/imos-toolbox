"""Tests for RateOfChangeQC routine."""

import numpy as np
import pytest
import xarray as xr

from imos_toolbox.autoqc.base import QCFlags
from imos_toolbox.autoqc.rate_of_change import RateOfChangeQC
from imos_toolbox.model import IMOSDataset


@pytest.fixture
def qc_flags():
    """QC flags fixture."""
    return QCFlags()


def test_rate_of_change_stable_data(qc_flags):
    """Test that stable data passes the rate of change check."""
    n = 100
    temp = 20.0 + np.random.randn(n) * 0.1  # small variations
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"TEMP": (("TIME",), temp), "TEMP_QC": (("TIME",), np.full(n, qc_flags.RAW, dtype=np.int8))},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = RateOfChangeQC()
    result = qc.run(dataset)

    assert "TEMP" in result.variable_flags
    flags = result.variable_flags["TEMP"]
    # Most points should be GOOD (small variations)
    assert np.sum(flags == qc_flags.GOOD) > n * 0.8


def test_rate_of_change_spike_detected(qc_flags):
    """Test that a spike is detected and flagged."""
    n = 100
    temp = 20.0 + np.random.randn(n) * 0.1
    temp[50] = 30.0  # Large spike
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"TEMP": (("TIME",), temp), "TEMP_QC": (("TIME",), np.full(n, qc_flags.RAW, dtype=np.int8))},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = RateOfChangeQC()
    result = qc.run(dataset)

    assert "TEMP" in result.variable_flags
    flags = result.variable_flags["TEMP"]
    # Spike should be flagged as PROBABLY_BAD
    assert flags[50] == qc_flags.PROBABLY_BAD


def test_rate_of_change_large_time_gap_ignored(qc_flags):
    """Test that large time gaps (>1h) don't trigger false positives."""
    n = 50
    # Create data with a gap > 1 hour
    time1 = np.datetime64("2020-01-01") + np.arange(25) * np.timedelta64(1, "h")
    time2 = np.datetime64("2020-01-01") + np.arange(25, 50) * np.timedelta64(1, "h") + np.timedelta64(2, "h")
    time_coord = np.concatenate([time1, time2])
    
    temp = 20.0 + np.random.randn(n) * 0.1
    # Large jump at the gap
    temp[25:] += 5.0

    ds = xr.Dataset(
        {"TEMP": (("TIME",), temp), "TEMP_QC": (("TIME",), np.full(n, qc_flags.RAW, dtype=np.int8))},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = RateOfChangeQC()
    result = qc.run(dataset)

    assert "TEMP" in result.variable_flags
    flags = result.variable_flags["TEMP"]
    # Point at gap should remain RAW (not flagged bad)
    assert flags[25] == qc_flags.RAW


def test_rate_of_change_skips_bad_data(qc_flags):
    """Test that already BAD data is skipped."""
    n = 100
    temp = 20.0 + np.random.randn(n) * 0.1
    temp[30] = 999.0  # Bad value
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    flags_in = np.full(n, qc_flags.RAW, dtype=np.int8)
    flags_in[30] = qc_flags.BAD  # Already flagged

    ds = xr.Dataset(
        {"TEMP": (("TIME",), temp), "TEMP_QC": (("TIME",), flags_in)},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = RateOfChangeQC()
    result = qc.run(dataset)

    assert "TEMP" in result.variable_flags
    # Should not crash and should process remaining data
    assert len(result.variable_flags["TEMP"]) == n


def test_rate_of_change_no_applicable_variable(qc_flags):
    """Test that non-applicable variables are skipped."""
    n = 100
    data = np.random.randn(n)
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"UNKNOWN_VAR": (("TIME",), data), "UNKNOWN_VAR_QC": (("TIME",), np.full(n, qc_flags.RAW, dtype=np.int8))},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = RateOfChangeQC()
    result = qc.run(dataset)

    # Should return empty result for unknown variable
    assert len(result.variable_flags) == 0


def test_rate_of_change_numbered_variable(qc_flags):
    """Test that numbered variables like TEMP_1 are handled."""
    n = 100
    temp = 20.0 + np.random.randn(n) * 0.1
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"TEMP_1": (("TIME",), temp), "TEMP_1_QC": (("TIME",), np.full(n, qc_flags.RAW, dtype=np.int8))},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = RateOfChangeQC()
    result = qc.run(dataset)

    assert "TEMP_1" in result.variable_flags
