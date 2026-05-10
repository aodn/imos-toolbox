"""Tests for CTD surface soak and ADCP surface detection QC."""

import numpy as np
import pytest
import xarray as xr

from imos_toolbox.autoqc.base import QCFlags
from imos_toolbox.autoqc.ctd_surface_soak import CTDSurfaceSoakQC
from imos_toolbox.autoqc.surface_detection import SurfaceDetectionByDepthSetQC
from imos_toolbox.model import IMOSDataset


@pytest.fixture
def qc_flags():
    return QCFlags()


# CTDSurfaceSoakQC tests

def test_ctd_soak_depth_based(qc_flags):
    """Test surface soak detection using depth."""
    depth = np.array([0.5, 1.0, 2.5, 5.0, 10.0], dtype=np.float32)
    temp = np.array([20.0, 19.5, 19.0, 18.5, 18.0], dtype=np.float32)

    ds = xr.Dataset(
        {"TEMP": (("DEPTH",), temp), "DEPTH": (("DEPTH",), depth)},
    )
    dataset = IMOSDataset(ds)

    qc = CTDSurfaceSoakQC()
    result = qc.run(dataset)

    if "TEMP" in result.variable_flags:
        flags = result.variable_flags["TEMP"]
        # Shallow samples should be flagged
        assert flags[0] == qc_flags.PROBABLY_BAD
        assert flags[1] == qc_flags.PROBABLY_BAD
        # Deep samples should be good
        assert flags[3] == qc_flags.GOOD


def test_ctd_soak_skips_timeseries(qc_flags):
    """Test that time series data is skipped."""
    n = 50
    temp = 20.0 + np.random.randn(n) * 0.1
    time_coord = np.datetime64("2020-01-01") + np.arange(n) * np.timedelta64(1, "h")

    ds = xr.Dataset(
        {"TEMP": (("TIME",), temp)},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = CTDSurfaceSoakQC()
    result = qc.run(dataset)

    assert len(result.variable_flags) == 0


# SurfaceDetectionByDepthSetQC tests

def test_surface_detection_flags_above_surface(qc_flags):
    """Test that bins above surface are flagged."""
    n_time = 10
    n_bins = 20
    time_coord = np.datetime64("2020-01-01") + np.arange(n_time) * np.timedelta64(1, "h")
    bin_heights = np.linspace(1, 60, n_bins, dtype=np.float32)  # Bins up to 60m
    
    # Instrument at 50m depth, bathymetry at 100m -> 50m water column
    depth = np.full(n_time, 50.0, dtype=np.float32)
    
    # Create velocity data
    vel = np.random.randn(n_time, n_bins).astype(np.float32)

    ds = xr.Dataset(
        {
            "DEPTH": (("TIME",), depth),
            "UCUR": (("TIME", "HEIGHT_ABOVE_SENSOR"), vel),
        },
        coords={
            "TIME": time_coord,
            "HEIGHT_ABOVE_SENSOR": bin_heights,
        },
        attrs={"site_nominal_depth": 100.0},
    )
    dataset = IMOSDataset(ds)

    qc = SurfaceDetectionByDepthSetQC()
    result = qc.run(dataset)

    if "UCUR" in result.variable_flags:
        flags = result.variable_flags["UCUR"]
        # Lower bins should be GOOD
        assert flags[0, 0] == qc_flags.GOOD
        # Upper bins (>50m) should be BAD (above surface)
        assert flags[0, -1] == qc_flags.BAD


def test_surface_detection_no_depth(qc_flags):
    """Test that routine skips when DEPTH is missing."""
    n_time = 10
    n_bins = 20
    time_coord = np.datetime64("2020-01-01") + np.arange(n_time) * np.timedelta64(1, "h")
    bin_heights = np.linspace(1, 40, n_bins, dtype=np.float32)
    vel = np.random.randn(n_time, n_bins).astype(np.float32)

    ds = xr.Dataset(
        {"UCUR": (("TIME", "HEIGHT_ABOVE_SENSOR"), vel)},
        coords={
            "TIME": time_coord,
            "HEIGHT_ABOVE_SENSOR": bin_heights,
        },
    )
    dataset = IMOSDataset(ds)

    qc = SurfaceDetectionByDepthSetQC()
    result = qc.run(dataset)

    assert len(result.variable_flags) == 0


def test_surface_detection_no_bin_dimension(qc_flags):
    """Test that routine skips when bin dimension is missing."""
    n_time = 10
    time_coord = np.datetime64("2020-01-01") + np.arange(n_time) * np.timedelta64(1, "h")
    depth = np.full(n_time, 50.0, dtype=np.float32)

    ds = xr.Dataset(
        {"DEPTH": (("TIME",), depth)},
        coords={"TIME": time_coord},
    )
    dataset = IMOSDataset(ds)

    qc = SurfaceDetectionByDepthSetQC()
    result = qc.run(dataset)

    assert len(result.variable_flags) == 0
