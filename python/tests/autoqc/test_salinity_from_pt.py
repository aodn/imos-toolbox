"""Tests for SalinityFromPTQC routine."""

import numpy as np
import pytest
import xarray as xr

from imos_toolbox.autoqc.base import QCFlags
from imos_toolbox.autoqc.salinity_from_pt import SalinityFromPTQC
from imos_toolbox.model import IMOSDataset


@pytest.fixture
def qc_flags():
    """QC flags fixture."""
    return QCFlags()


def test_salinity_from_pt_propagates_flags(qc_flags):
    """Test that flags are propagated from TEMP, CNDC, PRES to PSAL."""
    time = np.arange(10, dtype=np.float64)
    temp = 20.0 + np.random.randn(10) * 0.5
    cndc = 4.0 + np.random.randn(10) * 0.1
    pres = 10.0 + np.random.randn(10) * 0.5
    psal = 35.0 + np.random.randn(10) * 0.2

    # Create flags with some bad values
    temp_flags = np.full(10, qc_flags.GOOD, dtype=np.int8)
    temp_flags[3] = qc_flags.PROBABLY_BAD  # Flag one temp value

    cndc_flags = np.full(10, qc_flags.GOOD, dtype=np.int8)
    cndc_flags[5] = qc_flags.BAD  # Flag one conductivity value

    pres_flags = np.full(10, qc_flags.GOOD, dtype=np.int8)
    pres_flags[7] = qc_flags.PROBABLY_BAD  # Flag one pressure value

    ds = xr.Dataset(
        {
            "TEMP": (("TIME",), temp),
            "TEMP_QC": (("TIME",), temp_flags),
            "CNDC": (("TIME",), cndc),
            "CNDC_QC": (("TIME",), cndc_flags),
            "PRES_REL": (("TIME",), pres),
            "PRES_REL_QC": (("TIME",), pres_flags),
            "PSAL": (("TIME",), psal),
            "PSAL_QC": (("TIME",), np.full(10, qc_flags.RAW, dtype=np.int8)),
        },
        coords={"TIME": time},
    )
    dataset = IMOSDataset(ds)

    qc = SalinityFromPTQC()
    result = qc.run(dataset)

    assert "PSAL" in result.variable_flags
    flags = result.variable_flags["PSAL"]

    # Check that flags were propagated
    # Index 3: TEMP is PROBABLY_BAD
    assert flags[3] == qc_flags.PROBABLY_BAD
    # Index 5: CNDC is BAD
    assert flags[5] == qc_flags.BAD
    # Index 7: PRES is PROBABLY_BAD
    assert flags[7] == qc_flags.PROBABLY_BAD
    # Other indices should be GOOD (max of all GOOD flags)
    assert flags[0] == qc_flags.GOOD


def test_salinity_from_pt_prefers_depth_over_pressure(qc_flags):
    """Test that DEPTH flags are used when available instead of PRES."""
    time = np.arange(10, dtype=np.float64)
    temp = 20.0 + np.random.randn(10) * 0.5
    pres = 10.0 + np.random.randn(10) * 0.5
    depth = 10.0 + np.random.randn(10) * 0.5
    psal = 35.0 + np.random.randn(10) * 0.2

    # Flag pressure at index 3
    pres_flags = np.full(10, qc_flags.GOOD, dtype=np.int8)
    pres_flags[3] = qc_flags.BAD

    # Flag depth at index 5
    depth_flags = np.full(10, qc_flags.GOOD, dtype=np.int8)
    depth_flags[5] = qc_flags.BAD

    ds = xr.Dataset(
        {
            "TEMP": (("TIME",), temp),
            "TEMP_QC": (("TIME",), np.full(10, qc_flags.GOOD, dtype=np.int8)),
            "PRES_REL": (("TIME",), pres),
            "PRES_REL_QC": (("TIME",), pres_flags),
            "DEPTH": (("TIME",), depth),
            "DEPTH_QC": (("TIME",), depth_flags),
            "PSAL": (("TIME",), psal),
            "PSAL_QC": (("TIME",), np.full(10, qc_flags.RAW, dtype=np.int8)),
        },
        coords={"TIME": time},
    )
    dataset = IMOSDataset(ds)

    qc = SalinityFromPTQC()
    result = qc.run(dataset)

    assert "PSAL" in result.variable_flags
    flags = result.variable_flags["PSAL"]

    # DEPTH flag at index 5 should be propagated
    assert flags[5] == qc_flags.BAD
    # PRES flag at index 3 should NOT be propagated (DEPTH takes precedence)
    assert flags[3] == qc_flags.GOOD


def test_salinity_from_pt_handles_numbered_variables(qc_flags):
    """Test that numbered variables like TEMP_1, PSAL_1 are handled correctly."""
    time = np.arange(10, dtype=np.float64)
    temp = 20.0 + np.random.randn(10) * 0.5
    psal = 35.0 + np.random.randn(10) * 0.2

    temp_flags = np.full(10, qc_flags.GOOD, dtype=np.int8)
    temp_flags[2] = qc_flags.BAD

    ds = xr.Dataset(
        {
            "TEMP_1": (("TIME",), temp),
            "TEMP_1_QC": (("TIME",), temp_flags),
            "PSAL_1": (("TIME",), psal),
            "PSAL_1_QC": (("TIME",), np.full(10, qc_flags.RAW, dtype=np.int8)),
        },
        coords={"TIME": time},
    )
    dataset = IMOSDataset(ds)

    qc = SalinityFromPTQC()
    result = qc.run(dataset)

    assert "PSAL_1" in result.variable_flags
    flags = result.variable_flags["PSAL_1"]
    assert flags[2] == qc_flags.BAD


def test_salinity_from_pt_no_salinity_variable(qc_flags):
    """Test that no results are returned when there's no salinity variable."""
    time = np.arange(10, dtype=np.float64)
    temp = 20.0 + np.random.randn(10) * 0.5

    ds = xr.Dataset(
        {
            "TEMP": (("TIME",), temp),
            "TEMP_QC": (("TIME",), np.full(10, qc_flags.GOOD, dtype=np.int8)),
        },
        coords={"TIME": time},
    )
    dataset = IMOSDataset(ds)

    qc = SalinityFromPTQC()
    result = qc.run(dataset)

    assert len(result.variable_flags) == 0


def test_salinity_from_pt_takes_maximum_flag(qc_flags):
    """Test that the maximum (worst) flag is propagated."""
    time = np.arange(10, dtype=np.float64)
    temp = 20.0 + np.random.randn(10) * 0.5
    cndc = 4.0 + np.random.randn(10) * 0.1
    psal = 35.0 + np.random.randn(10) * 0.2

    # At index 4, TEMP is PROBABLY_BAD and CNDC is BAD
    temp_flags = np.full(10, qc_flags.GOOD, dtype=np.int8)
    temp_flags[4] = qc_flags.PROBABLY_BAD

    cndc_flags = np.full(10, qc_flags.GOOD, dtype=np.int8)
    cndc_flags[4] = qc_flags.BAD

    ds = xr.Dataset(
        {
            "TEMP": (("TIME",), temp),
            "TEMP_QC": (("TIME",), temp_flags),
            "CNDC": (("TIME",), cndc),
            "CNDC_QC": (("TIME",), cndc_flags),
            "PSAL": (("TIME",), psal),
            "PSAL_QC": (("TIME",), np.full(10, qc_flags.RAW, dtype=np.int8)),
        },
        coords={"TIME": time},
    )
    dataset = IMOSDataset(ds)

    qc = SalinityFromPTQC()
    result = qc.run(dataset)

    assert "PSAL" in result.variable_flags
    flags = result.variable_flags["PSAL"]

    # Should take the maximum (worst) flag, which is BAD
    assert flags[4] == qc_flags.BAD
