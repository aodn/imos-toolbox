"""NetCDF file writer for IMOS-compliant outputs."""

from datetime import datetime, timezone
from pathlib import Path

import netCDF4 as nc
import numpy as np
import xarray as xr

from imos_toolbox.conventions import get_parameter_info
from imos_toolbox.model import IMOSDataset

from .template import parse_template


def export_netcdf(dataset: IMOSDataset, output_dir: Path, mode: str = "timeSeries") -> Path:
    """Export IMOSDataset to IMOS-compliant NetCDF file.

    Args:
        dataset: Dataset to export
        output_dir: Directory to write NetCDF file
        mode: Data type mode ('timeSeries' or 'profile')

    Returns:
        Path to created NetCDF file
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    # Generate filename
    filename = _generate_filename(dataset, mode)
    output_path = output_dir / filename

    # Create NetCDF4 file with compression
    with nc.Dataset(output_path, "w", format="NETCDF4") as ncfile:
        ncfile.set_fill_off()

        # Write global attributes
        _write_global_attributes(ncfile, dataset, mode)

        # Define dimensions
        _define_dimensions(ncfile, dataset)

        # Define and write variables
        _write_variables(ncfile, dataset, mode)

    return output_path


def _generate_filename(dataset: IMOSDataset, mode: str) -> str:
    """Generate IMOS-compliant filename."""
    # Simplified filename generation - enhance later
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    site = getattr(dataset, "site_code", "UNKNOWN")
    return f"IMOS_{mode}_{site}_{timestamp}_FV01.nc"


def _write_global_attributes(ncfile: nc.Dataset, dataset: IMOSDataset, mode: str) -> None:
    """Write global attributes from template."""
    # Try to find template directory
    template_dir = Path(__file__).parents[4] / "NetCDF" / "template"
    template_path = template_dir / f"global_attributes_{mode}.txt"

    if template_path.exists():
        attrs = parse_template(template_path, dataset)
        for name, value in attrs.items():
            if value:
                ncfile.setncattr(name, value)

    # Mandatory attributes
    ncfile.setncattr("date_created", datetime.now(timezone.utc).isoformat())
    ncfile.setncattr("Conventions", "CF-1.6,IMOS-1.4")
    ncfile.setncattr("file_version", "Level 1 - Quality Controlled Data")


def _define_dimensions(ncfile: nc.Dataset, dataset: IMOSDataset) -> None:
    """Define NetCDF dimensions."""
    xds = dataset.dataset
    for dim_name, dim_size in xds.sizes.items():
        ncfile.createDimension(str(dim_name), dim_size)


def _write_variables(ncfile: nc.Dataset, dataset: IMOSDataset, mode: str) -> None:
    """Define and write variables with attributes."""
    template_dir = Path(__file__).parents[4] / "NetCDF" / "template"
    xds = dataset.dataset

    # Write all variables (coordinates and data variables)
    for var_name in xds.variables:
        var_name_str = str(var_name)
        if var_name_str.endswith("_QC"):
            continue  # Skip QC variables, handled separately

        var = xds[var_name]
        _write_variable(ncfile, var_name_str, var, dataset, template_dir)


def _write_variable(
    ncfile: nc.Dataset,
    var_name: str,
    var: xr.DataArray,
    dataset: IMOSDataset,
    template_dir: Path,
) -> None:
    """Write a single variable with attributes and QC flags."""
    data = var.values

    # Determine datatype and fill value
    dtype_str: str
    fill_value: float | int | str

    if data.dtype.kind in ("U", "S", "O", "M"):  # M for datetime64
        if data.dtype.kind == "M":
            # Convert datetime64 to float (days since epoch)
            data = (data - np.datetime64("1950-01-01T00:00:00")) / np.timedelta64(1, "D")
            dtype_str = "f8"
            fill_value = 999999.0
        else:
            dtype_str = "S1"
            fill_value = ""
    elif data.dtype.kind == "f":
        dtype_str = "f8"
        fill_value = 999999.0
    else:
        dtype_str = "i4"
        fill_value = -999

    # Get dimensions for this variable
    dims = tuple(str(d) for d in var.dims)

    # Create variable
    ncvar = ncfile.createVariable(  # type: ignore[call-overload]
        var_name,
        dtype_str,
        dims,
        fill_value=fill_value,
        zlib=True,
        complevel=1,
    )

    # Write data
    if dtype_str == "S1":
        ncvar[:] = data.astype(str)
    else:
        ncvar[:] = data

    # Write attributes from xarray variable
    for attr_name, attr_value in var.attrs.items():
        ncvar.setncattr(attr_name, attr_value)

    # Write attributes from template
    template_name = f"{var_name.lower()}_attributes.txt"
    template_path = template_dir / template_name

    if not template_path.exists():
        template_path = template_dir / "variable_attributes.txt"

    if template_path.exists():
        attrs = parse_template(template_path, dataset, var_idx=None)
        for name, value in attrs.items():
            if value and not ncvar.getncattr(name) if name in ncvar.ncattrs() else True:
                ncvar.setncattr(name, value)

    # Add parameter info if available
    param_info = get_parameter_info(var_name)
    if param_info:
        if "standard_name" in param_info and param_info["standard_name"]:
            ncvar.setncattr("standard_name", param_info["standard_name"])
        if "long_name" in param_info and param_info["long_name"]:
            ncvar.setncattr("long_name", param_info["long_name"])
        if "units" in param_info and param_info["units"]:
            ncvar.setncattr("units", param_info["units"])

    # Write QC flags if present
    qc_name = f"{var_name}_QC"
    if qc_name in dataset.dataset:
        qc_data = dataset.dataset[qc_name].values
        qc_var_name = f"{var_name}_quality_control"
        qc_var = ncfile.createVariable(  # type: ignore[call-overload]
            qc_var_name,
            "i1",
            dims,
            fill_value=0,
            zlib=True,
            complevel=1,
        )
        qc_var[:] = qc_data
        qc_var.setncattr("long_name", f"quality flag for {var_name}")
        qc_var.setncattr("standard_name", "status_flag")
        qc_var.setncattr(
            "flag_values",
            np.array([0, 1, 2, 3, 4, 6, 7, 9], dtype="i1"),
        )
        qc_var.setncattr(
            "flag_meanings",
            "unknown good_data probably_good_data probably_bad_data bad_data not_deployed interpolated missing_value",
        )
