"""Tests for NetCDF export functionality."""

from pathlib import Path
from datetime import datetime, timezone

import netCDF4 as nc
import numpy as np
import xarray as xr

from imos_toolbox.export import export_netcdf
from imos_toolbox.model import IMOSDataset


def test_export_basic_timeseries(tmp_path: Path) -> None:
    """Test basic NetCDF export for timeSeries mode."""
    # Create minimal xarray dataset
    time_data = np.array([datetime(2024, 1, 1, i, 0, 0, tzinfo=timezone.utc) for i in range(5)])
    temp_data = np.array([20.0, 20.1, 20.2, 20.1, 20.0])
    qc_flags = np.array([1, 1, 1, 1, 1], dtype=np.int8)

    xds = xr.Dataset(
        {
            "TIME": ("TIME", time_data),
            "TEMP": ("TIME", temp_data),
            "TEMP_QC": ("TIME", qc_flags),
        }
    )

    dataset = IMOSDataset(xds)
    dataset.site_code = "TEST"

    # Export
    output_path = export_netcdf(dataset, tmp_path, mode="timeSeries")

    # Verify file exists
    assert output_path.exists()
    assert output_path.suffix == ".nc"

    # Verify contents
    with nc.Dataset(output_path, "r") as ncfile:
        assert "TIME" in ncfile.dimensions
        assert "TEMP" in ncfile.variables
        assert "TEMP_quality_control" in ncfile.variables

        # Check global attributes
        assert hasattr(ncfile, "Conventions")
        assert "IMOS" in ncfile.Conventions

        # Check data
        assert len(ncfile.variables["TEMP"]) == 5
        np.testing.assert_array_almost_equal(
            ncfile.variables["TEMP"][:], [20.0, 20.1, 20.2, 20.1, 20.0]
        )

        # Check QC flags
        np.testing.assert_array_equal(
            ncfile.variables["TEMP_quality_control"][:], [1, 1, 1, 1, 1]
        )


def test_export_with_multiple_variables(tmp_path: Path) -> None:
    """Test export with multiple variables."""
    time_data = np.array([datetime(2024, 1, 1, i, 0, 0, tzinfo=timezone.utc) for i in range(3)])

    xds = xr.Dataset(
        {
            "TIME": ("TIME", time_data),
            "TEMP": ("TIME", np.array([20.0, 20.1, 20.2])),
            "PSAL": ("TIME", np.array([35.0, 35.1, 35.2])),
        }
    )

    dataset = IMOSDataset(xds)
    dataset.site_code = "TEST"

    output_path = export_netcdf(dataset, tmp_path, mode="timeSeries")

    with nc.Dataset(output_path, "r") as ncfile:
        assert "TEMP" in ncfile.variables
        assert "PSAL" in ncfile.variables
        assert len(ncfile.variables["TEMP"]) == 3
        assert len(ncfile.variables["PSAL"]) == 3
