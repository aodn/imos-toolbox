"""Tests for spike detection routines."""

import numpy as np
import pytest
import xarray as xr

from imos_toolbox.autoqc.base import QCFlags
from imos_toolbox.autoqc.timeseries_spike import TimeSeriesSpikeQC
from imos_toolbox.autoqc.vertical_spike import VerticalSpikeQC
from imos_toolbox.model import IMOSDataset


@pytest.fixture
def qc_flags():
    return QCFlags()


# TimeSeriesSpikeQC tests

def test_timeseries_spike_detects_spike(qc_flags):
    """Test that a spike is detected in time series."""
    n = 50
    temp = 20.0 + np.random.randn(n) * 0.1
    temp[25] = 30.0  # Large spike
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"TEMP": (("TIME",), temp)},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = TimeSeriesSpikeQC(half_window=3, n_sigma=3.0)
    result = qc.run(dataset)

    assert "TEMP" in result.variable_flags
    flags = result.variable_flags["TEMP"]
    assert flags[25] == qc_flags.PROBABLY_BAD


def test_timeseries_spike_stable_data(qc_flags):
    """Test that stable data passes spike detection."""
    n = 50
    temp = 20.0 + np.random.randn(n) * 0.1
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"TEMP": (("TIME",), temp)},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = TimeSeriesSpikeQC(half_window=3, n_sigma=3.0)
    result = qc.run(dataset)

    assert "TEMP" in result.variable_flags
    flags = result.variable_flags["TEMP"]
    assert np.sum(flags == qc_flags.GOOD) > n * 0.8


def test_timeseries_spike_skips_excluded(qc_flags):
    """Test that excluded variables are skipped."""
    n = 50
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"LATITUDE": (("TIME",), np.full(n, -33.0))},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = TimeSeriesSpikeQC()
    result = qc.run(dataset)

    assert len(result.variable_flags) == 0


# VerticalSpikeQC tests

def test_vertical_spike_detects_spike(qc_flags):
    """Test ARGO spike test detects spike in profile."""
    depth = np.array([0, 10, 20, 30, 40, 50], dtype=np.float32)
    temp = np.array([20.0, 19.5, 19.0, 30.0, 18.0, 17.5], dtype=np.float32)  # Large spike at index 3

    ds = xr.Dataset(
        {"TEMP": (("DEPTH",), temp), "DEPTH": (("DEPTH",), depth)},
    )
    dataset = IMOSDataset(ds)

    qc = VerticalSpikeQC()
    result = qc.run(dataset)

    assert "TEMP" in result.variable_flags
    flags = result.variable_flags["TEMP"]
    assert flags[3] == qc_flags.PROBABLY_BAD


def test_vertical_spike_smooth_profile(qc_flags):
    """Test that smooth profile passes."""
    depth = np.linspace(0, 100, 20, dtype=np.float32)
    temp = 20.0 - depth * 0.1  # Linear decrease

    ds = xr.Dataset(
        {"TEMP": (("DEPTH",), temp), "DEPTH": (("DEPTH",), depth)},
    )
    dataset = IMOSDataset(ds)

    qc = VerticalSpikeQC()
    result = qc.run(dataset)

    assert "TEMP" in result.variable_flags
    flags = result.variable_flags["TEMP"]
    assert np.sum(flags == qc_flags.GOOD) > 15


def test_vertical_spike_skips_timeseries(qc_flags):
    """Test that time series data is skipped."""
    n = 50
    temp = 20.0 + np.random.randn(n) * 0.1
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"TEMP": (("TIME",), temp)},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = VerticalSpikeQC()
    result = qc.run(dataset)

    # Should skip because it has TIME dimension
    assert len(result.variable_flags) == 0


def test_vertical_spike_unknown_param(qc_flags):
    """Test that unknown parameters are skipped."""
    depth = np.linspace(0, 100, 20, dtype=np.float32)
    data = np.random.randn(20)

    ds = xr.Dataset(
        {"UNKNOWN": (("DEPTH",), data), "DEPTH": (("DEPTH",), depth)},
    )
    dataset = IMOSDataset(ds)

    qc = VerticalSpikeQC()
    result = qc.run(dataset)

    assert len(result.variable_flags) == 0
