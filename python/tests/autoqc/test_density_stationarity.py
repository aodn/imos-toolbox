"""Tests for density inversion and stationarity QC."""

import numpy as np
import pytest
import xarray as xr

from imos_toolbox.autoqc.base import QCFlags
from imos_toolbox.autoqc.density_inversion import DensityInversionSetQC
from imos_toolbox.autoqc.stationarity import StationarityQC
from imos_toolbox.model import IMOSDataset


@pytest.fixture
def qc_flags():
    return QCFlags()


# DensityInversionSetQC tests

def test_density_inversion_detects_inversion(qc_flags):
    """Test that density inversion is detected."""
    depth = np.array([0, 10, 20, 30, 40], dtype=np.float32)
    # Create large inversion: much warmer/fresher water below
    temp = np.array([15.0, 14.0, 13.0, 25.0, 12.0], dtype=np.float32)
    psal = np.array([35.5, 35.6, 35.7, 32.0, 35.9], dtype=np.float32)
    pres = depth.copy()  # Approximate pressure from depth

    ds = xr.Dataset(
        {
            "TEMP": (("DEPTH",), temp),
            "PSAL": (("DEPTH",), psal),
            "PRES_REL": (("DEPTH",), pres),
            "DEPTH": (("DEPTH",), depth),
        },
    )
    dataset = IMOSDataset(ds)

    qc = DensityInversionSetQC()
    result = qc.run(dataset)

    # Should flag the inversion
    assert "TEMP" in result.variable_flags or "PSAL" in result.variable_flags


def test_density_inversion_stable_profile(qc_flags):
    """Test that stable density profile passes."""
    depth = np.linspace(0, 100, 20, dtype=np.float32)
    temp = 20.0 - depth * 0.1  # Decreasing temp
    psal = 35.0 + depth * 0.01  # Increasing salinity

    ds = xr.Dataset(
        {
            "TEMP": (("DEPTH",), temp),
            "PSAL": (("DEPTH",), psal),
            "DEPTH": (("DEPTH",), depth),
        },
    )
    dataset = IMOSDataset(ds)

    qc = DensityInversionSetQC()
    result = qc.run(dataset)

    if "TEMP" in result.variable_flags:
        flags = result.variable_flags["TEMP"]
        # Most should be GOOD
        assert np.sum(flags == qc_flags.GOOD) > 15


def test_density_inversion_skips_timeseries(qc_flags):
    """Test that time series data is skipped."""
    n = 50
    temp = 20.0 + np.random.randn(n) * 0.1
    psal = 35.0 + np.random.randn(n) * 0.1
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"TEMP": (("TIME",), temp), "PSAL": (("TIME",), psal)},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = DensityInversionSetQC()
    result = qc.run(dataset)

    assert len(result.variable_flags) == 0


# StationarityQC tests

def test_stationarity_detects_flatline(qc_flags):
    """Test that flatline is detected."""
    n = 100
    temp = np.full(n, 20.0)  # Constant value
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"TEMP": (("TIME",), temp)},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = StationarityQC()
    result = qc.run(dataset)

    assert "TEMP" in result.variable_flags
    flags = result.variable_flags["TEMP"]
    # Should flag as PROBABLY_BAD
    assert np.sum(flags == qc_flags.PROBABLY_BAD) > 0


def test_stationarity_varying_data(qc_flags):
    """Test that varying data passes."""
    n = 50
    temp = 20.0 + np.random.randn(n) * 0.5
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"TEMP": (("TIME",), temp)},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = StationarityQC()
    result = qc.run(dataset)

    assert "TEMP" in result.variable_flags
    flags = result.variable_flags["TEMP"]
    # Most should be GOOD
    assert np.sum(flags == qc_flags.GOOD) > n * 0.8


def test_stationarity_short_flatline_ok(qc_flags):
    """Test that short flatlines are acceptable."""
    n = 50
    temp = 20.0 + np.random.randn(n) * 0.5
    temp[20:25] = 20.0  # Short flatline (5 points)
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"TEMP": (("TIME",), temp)},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = StationarityQC()
    result = qc.run(dataset)

    assert "TEMP" in result.variable_flags
    flags = result.variable_flags["TEMP"]
    # Short flatline should be GOOD
    assert flags[22] == qc_flags.GOOD


def test_stationarity_skips_excluded(qc_flags):
    """Test that excluded variables are skipped."""
    n = 50
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"LATITUDE": (("TIME",), np.full(n, -33.0))},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = StationarityQC()
    result = qc.run(dataset)

    assert len(result.variable_flags) == 0
