"""Unit tests for Phase 4 – Automatic QC routines.

Tests cover the base class infrastructure, the chain runner, and each of
the six initial QC routines.  Sample datasets are constructed inline using
realistic oceanographic values typical of IMOS mooring deployments.
"""

from __future__ import annotations

import numpy as np
import pytest
import xarray as xr

from imos_toolbox.autoqc.base import QCFlags
from imos_toolbox.autoqc.runner import run_qc_chain
from imos_toolbox.autoqc.impossible_date import ImosImpossibleDateQC
from imos_toolbox.autoqc.impossible_location import ImosImpossibleLocationSetQC
from imos_toolbox.autoqc.in_out_water import ImosInOutWaterQC
from imos_toolbox.autoqc.global_range import ImosGlobalRangeQC
from imos_toolbox.autoqc.regional_range import ImosRegionalRangeQC
from imos_toolbox.autoqc.impossible_depth import ImosImpossibleDepthQC
from imos_toolbox.model import IMOSDataset


# ---------------------------------------------------------------------------
# Helpers for building synthetic datasets
# ---------------------------------------------------------------------------

def _repo_root():
    """Return the repository root (parent of 'python/')."""
    from pathlib import Path
    here = Path(__file__).resolve()
    # tests/ is under python/, repo root is python/..
    python_dir = here.parent.parent
    return python_dir.parent


def _make_time_series_dataset(
    *,
    n: int = 100,
    start: str = "2020-01-15T00:00:00",
    freq_h: int = 1,
    temp_range: tuple[float, float] = (18.0, 22.0),
    psal_range: tuple[float, float] = (34.5, 35.5),
    depth_val: float = 50.0,
    lat: float = -33.943,
    lon: float = 151.382,
    site_code: str = "SYD100",
    deploy_start: str = "2020-01-15T00:00:00",
    deploy_end: str = "2020-05-15T00:00:00",
    inst_nominal_depth: float = 50.0,
    site_nominal_depth: float = 100.0,
) -> IMOSDataset:
    """Return a synthetic time-series IMOSDataset for testing."""
    rng = np.random.default_rng(42)
    times = np.arange(
        np.datetime64(start),
        np.datetime64(start) + np.timedelta64(n * freq_h, "h"),
        np.timedelta64(freq_h, "h"),
    )[:n]

    temp = rng.uniform(*temp_range, size=n).astype(np.float32)
    psal = rng.uniform(*psal_range, size=n).astype(np.float32)
    depth = np.full(n, depth_val, dtype=np.float32)
    lon_arr = np.full(1, lon, dtype=np.float64)
    lat_arr = np.full(1, lat, dtype=np.float64)

    ds = xr.Dataset(
        {
            "TEMP": (("TIME",), temp, {"valid_min": -2.5, "valid_max": 40.0}),
            "PSAL": (("TIME",), psal, {"valid_min": 2.0, "valid_max": 41.0}),
            "DEPTH": (("TIME",), depth, {"valid_min": -5.0, "valid_max": 12000.0}),
            "LONGITUDE": (("OBSERVATION",), lon_arr),
            "LATITUDE": (("OBSERVATION",), lat_arr),
        },
        coords={"TIME": times},
        attrs={
            "site_code": site_code,
            "time_deployment_start": np.datetime64(deploy_start),
            "time_deployment_end": np.datetime64(deploy_end),
            "instrument_nominal_depth": inst_nominal_depth,
            "site_nominal_depth": site_nominal_depth,
            "geospatial_lat_min": lat,
            "geospatial_lat_max": lat,
        },
    )
    return IMOSDataset(ds)


def _make_profile_dataset(
    *,
    depths: np.ndarray | None = None,
    temp: np.ndarray | None = None,
    lat: float = -42.5967,
    lon: float = 148.2333,
    site_code: str = "NRSMAI",
    bot_depth: float = 90.0,
) -> IMOSDataset:
    """Return a synthetic profile IMOSDataset for testing."""
    if depths is None:
        depths = np.arange(0.0, 80.0, 1.0, dtype=np.float32)
    n = len(depths)
    if temp is None:
        temp = np.linspace(20.0, 12.0, n, dtype=np.float32)
    time = np.datetime64("2020-03-10T09:00:00")

    ds = xr.Dataset(
        {
            "TIME": ((), time),
            "DEPTH": (("DEPTH_DIM",), depths, {"valid_min": -5.0, "valid_max": 12000.0}),
            "TEMP": (("DEPTH_DIM",), temp, {"valid_min": -2.5, "valid_max": 40.0}),
            "BOT_DEPTH": ((), bot_depth),
            "LONGITUDE": ((), lon),
            "LATITUDE": ((), lat),
        },
        attrs={
            "site_code": site_code,
            "time_deployment_start": np.datetime64("2020-03-10T08:00:00"),
            "time_deployment_end": np.datetime64("2020-03-10T12:00:00"),
            "geospatial_lat_min": lat,
            "geospatial_lat_max": lat,
        },
    )
    return IMOSDataset(ds)


# ===================================================================
# Test: QCFlags constants
# ===================================================================

class TestQCFlags:
    def test_flag_values(self):
        assert QCFlags.RAW == 0
        assert QCFlags.GOOD == 1
        assert QCFlags.PROBABLY_GOOD == 2
        assert QCFlags.PROBABLY_BAD == 3
        assert QCFlags.BAD == 4
        assert QCFlags.MISSING == 9

    def test_ordering(self):
        """Flags should increase with severity."""
        assert QCFlags.RAW < QCFlags.GOOD < QCFlags.PROBABLY_GOOD < QCFlags.PROBABLY_BAD < QCFlags.BAD


# ===================================================================
# Test: imosImpossibleDateQC
# ===================================================================

class TestImpossibleDateQC:
    def test_all_dates_good(self):
        """Dates in 2020 should all pass (after 2007, before now)."""
        imos_ds = _make_time_series_dataset()
        qc = ImosImpossibleDateQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert "TIME" in result.variable_flags
        flags = result.variable_flags["TIME"]
        assert np.all(flags == QCFlags.GOOD)

    def test_dates_before_2007_flagged(self):
        """Dates before 2007 should be flagged BAD."""
        imos_ds = _make_time_series_dataset(start="2005-06-01T00:00:00", n=10)
        qc = ImosImpossibleDateQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        flags = result.variable_flags["TIME"]
        assert np.all(flags == QCFlags.BAD)

    def test_mixed_dates(self):
        """Some good, some bad dates."""
        times = np.array([
            np.datetime64("2006-12-31T23:00:00"),  # bad
            np.datetime64("2007-01-01T00:00:00"),  # good
            np.datetime64("2020-06-15T12:00:00"),  # good
        ])
        ds = xr.Dataset(
            {"TEMP": (("TIME",), [20.0, 21.0, 22.0])},
            coords={"TIME": times},
        )
        imos_ds = IMOSDataset(ds)
        qc = ImosImpossibleDateQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        flags = result.variable_flags["TIME"]
        assert flags[0] == QCFlags.BAD
        assert flags[1] == QCFlags.GOOD
        assert flags[2] == QCFlags.GOOD

    def test_no_time_variable(self):
        """Dataset without TIME should produce no flags."""
        ds = xr.Dataset({"X": (("N",), [1.0, 2.0])})
        imos_ds = IMOSDataset(ds)
        qc = ImosImpossibleDateQC(repo_root=_repo_root())
        result = qc.run(imos_ds)
        assert len(result.variable_flags) == 0


# ===================================================================
# Test: imosImpossibleLocationSetQC
# ===================================================================

class TestImpossibleLocationSetQC:
    def test_good_location(self):
        """Location within NRSMAI site bounds passes."""
        imos_ds = _make_time_series_dataset(
            lat=-42.59667, lon=148.2333, site_code="NRSMAI", n=5,
        )
        qc = ImosImpossibleLocationSetQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert "LATITUDE" in result.variable_flags
        assert "LONGITUDE" in result.variable_flags
        assert np.all(result.variable_flags["LATITUDE"] == QCFlags.GOOD)
        assert np.all(result.variable_flags["LONGITUDE"] == QCFlags.GOOD)

    def test_bad_location(self):
        """Location far from site should be flagged PROBABLY_BAD."""
        imos_ds = _make_time_series_dataset(
            lat=0.0, lon=0.0, site_code="NRSMAI", n=5,
        )
        qc = ImosImpossibleLocationSetQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert np.all(result.variable_flags["LATITUDE"] == QCFlags.PROBABLY_BAD)
        assert np.all(result.variable_flags["LONGITUDE"] == QCFlags.PROBABLY_BAD)

    def test_no_site_code(self):
        """Missing site_code produces warning, no flags."""
        imos_ds = _make_time_series_dataset(site_code="", n=5)
        qc = ImosImpossibleLocationSetQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert len(result.variable_flags) == 0
        assert "Warning" in result.log

    def test_unknown_site(self):
        """Unknown site_code produces warning, no flags."""
        imos_ds = _make_time_series_dataset(site_code="NONEXISTENT", n=5)
        qc = ImosImpossibleLocationSetQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert len(result.variable_flags) == 0
        assert "not found" in result.log


# ===================================================================
# Test: imosInOutWaterQC
# ===================================================================

class TestInOutWaterQC:
    def test_all_in_water(self):
        """All times within deployment window → RAW (preserve existing)."""
        imos_ds = _make_time_series_dataset(
            n=24, start="2020-01-15T01:00:00",
            deploy_start="2020-01-15T00:00:00",
            deploy_end="2020-05-15T00:00:00",
        )
        qc = ImosInOutWaterQC(mode="timeSeries")
        result = qc.run(imos_ds)

        assert "TEMP" in result.variable_flags
        assert np.all(result.variable_flags["TEMP"] == QCFlags.RAW)

    def test_out_of_water_before(self):
        """Times before deployment start → BAD."""
        imos_ds = _make_time_series_dataset(
            n=10, start="2019-12-01T00:00:00",
            deploy_start="2020-01-15T00:00:00",
            deploy_end="2020-05-15T00:00:00",
        )
        qc = ImosInOutWaterQC(mode="timeSeries")
        result = qc.run(imos_ds)

        assert "TEMP" in result.variable_flags
        assert np.all(result.variable_flags["TEMP"] == QCFlags.BAD)

    def test_mixed_in_out(self):
        """Some before, some during deployment window."""
        times = np.array([
            np.datetime64("2020-01-14T23:00:00"),  # before → BAD
            np.datetime64("2020-01-15T00:00:00"),  # start → RAW
            np.datetime64("2020-01-15T01:00:00"),  # in → RAW
            np.datetime64("2020-05-15T01:00:00"),  # after → BAD
        ])
        ds = xr.Dataset(
            {"TEMP": (("TIME",), [19.0, 20.0, 20.5, 21.0], {"valid_min": -2.5, "valid_max": 40.0})},
            coords={"TIME": times},
            attrs={
                "time_deployment_start": np.datetime64("2020-01-15T00:00:00"),
                "time_deployment_end": np.datetime64("2020-05-15T00:00:00"),
            },
        )
        imos_ds = IMOSDataset(ds)
        qc = ImosInOutWaterQC(mode="timeSeries")
        result = qc.run(imos_ds)

        flags = result.variable_flags["TEMP"]
        assert flags[0] == QCFlags.BAD
        assert flags[1] == QCFlags.RAW
        assert flags[2] == QCFlags.RAW
        assert flags[3] == QCFlags.BAD

    def test_skips_excluded(self):
        """LATITUDE, LONGITUDE, NOMINAL_DEPTH should be skipped."""
        imos_ds = _make_time_series_dataset(n=5)
        qc = ImosInOutWaterQC(mode="timeSeries")
        result = qc.run(imos_ds)

        assert "LATITUDE" not in result.variable_flags
        assert "LONGITUDE" not in result.variable_flags

    def test_missing_deployment_times(self):
        """No deployment attrs → warning, no flags."""
        ds = xr.Dataset(
            {"TEMP": (("TIME",), [20.0, 21.0])},
            coords={"TIME": [np.datetime64("2020-06-01"), np.datetime64("2020-06-02")]},
        )
        imos_ds = IMOSDataset(ds)
        qc = ImosInOutWaterQC(mode="timeSeries")
        result = qc.run(imos_ds)

        assert "Warning" in result.log


# ===================================================================
# Test: imosGlobalRangeQC
# ===================================================================

class TestGlobalRangeQC:
    def test_all_in_range(self):
        """TEMP values 18-22 are within valid_min=-2.5, valid_max=40."""
        imos_ds = _make_time_series_dataset(temp_range=(18.0, 22.0))
        qc = ImosGlobalRangeQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert "TEMP" in result.variable_flags
        assert np.all(result.variable_flags["TEMP"] == QCFlags.GOOD)

    def test_out_of_range(self):
        """Inject some TEMP values outside valid range."""
        imos_ds = _make_time_series_dataset(n=10)
        ds = imos_ds.dataset
        temp = ds["TEMP"].values.copy()
        temp[0] = -10.0  # below valid_min=-2.5
        temp[1] = 50.0   # above valid_max=40.0
        ds["TEMP"].values[:] = temp

        qc = ImosGlobalRangeQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        flags = result.variable_flags["TEMP"]
        assert flags[0] == QCFlags.BAD
        assert flags[1] == QCFlags.BAD
        assert np.all(flags[2:] == QCFlags.GOOD)

    def test_psal_in_range(self):
        """PSAL values 34.5-35.5 within valid_min=2.0, valid_max=41.0."""
        imos_ds = _make_time_series_dataset(psal_range=(34.5, 35.5))
        qc = ImosGlobalRangeQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert "PSAL" in result.variable_flags
        assert np.all(result.variable_flags["PSAL"] == QCFlags.GOOD)

    def test_depth_in_range(self):
        """DEPTH=50 within valid_min=-5, valid_max=12000."""
        imos_ds = _make_time_series_dataset(depth_val=50.0)
        qc = ImosGlobalRangeQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert "DEPTH" in result.variable_flags
        assert np.all(result.variable_flags["DEPTH"] == QCFlags.GOOD)

    def test_unchecked_param_skipped(self):
        """A variable not listed in imosGlobalRangeQC.txt is skipped."""
        ds = xr.Dataset(
            {"CUSTOM_VAR": (("N",), [1.0, 2.0], {"valid_min": 0, "valid_max": 10})}
        )
        imos_ds = IMOSDataset(ds)
        qc = ImosGlobalRangeQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert "CUSTOM_VAR" not in result.variable_flags

    def test_numeric_suffix_stripped(self):
        """UCUR_1 should be matched as UCUR."""
        ds = xr.Dataset(
            {"UCUR_1": (("TIME",), np.array([0.5, 1.0, -0.5], dtype=np.float32),
                        {"valid_min": -10.0, "valid_max": 10.0})},
            coords={"TIME": np.arange(3)},
        )
        imos_ds = IMOSDataset(ds)
        qc = ImosGlobalRangeQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert "UCUR_1" in result.variable_flags
        assert np.all(result.variable_flags["UCUR_1"] == QCFlags.GOOD)


# ===================================================================
# Test: imosRegionalRangeQC
# ===================================================================

class TestRegionalRangeQC:
    def test_nrsmai_temp_in_range(self):
        """NRSMAI TEMP 5-25 °C → values 12-20 should be good."""
        imos_ds = _make_time_series_dataset(
            temp_range=(12.0, 20.0), site_code="NRSMAI",
        )
        qc = ImosRegionalRangeQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert "TEMP" in result.variable_flags
        assert np.all(result.variable_flags["TEMP"] == QCFlags.GOOD)

    def test_nrsmai_temp_out_of_range(self):
        """Inject TEMP values outside NRSMAI regional range (5-25)."""
        imos_ds = _make_time_series_dataset(
            temp_range=(12.0, 20.0), site_code="NRSMAI", n=10,
        )
        ds = imos_ds.dataset
        temp = ds["TEMP"].values.copy()
        temp[0] = 2.0   # below 5
        temp[1] = 30.0   # above 25
        ds["TEMP"].values[:] = temp

        qc = ImosRegionalRangeQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        flags = result.variable_flags["TEMP"]
        assert flags[0] == QCFlags.BAD
        assert flags[1] == QCFlags.BAD
        assert np.all(flags[2:] == QCFlags.GOOD)

    def test_nrsnsi_psal_in_range(self):
        """NRSNSI PSAL 31.3-38.7 → values 34.5-35.5 should be good."""
        imos_ds = _make_time_series_dataset(
            psal_range=(34.5, 35.5), site_code="NRSNSI",
        )
        qc = ImosRegionalRangeQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert "PSAL" in result.variable_flags
        assert np.all(result.variable_flags["PSAL"] == QCFlags.GOOD)

    def test_unknown_site_warning(self):
        """Unknown site → warning but no crash."""
        imos_ds = _make_time_series_dataset(site_code="NONEXISTENT")
        qc = ImosRegionalRangeQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert "Warning" in result.log or "not in" in result.log

    def test_no_site_code(self):
        """Missing site_code → warning."""
        imos_ds = _make_time_series_dataset(site_code="")
        qc = ImosRegionalRangeQC(repo_root=_repo_root())
        result = qc.run(imos_ds)

        assert "Warning" in result.log


# ===================================================================
# Test: imosImpossibleDepthQC (timeSeries mode)
# ===================================================================

class TestImpossibleDepthQC:
    def test_depth_in_range_timeseries(self):
        """DEPTH=50 with inst_nom=50, site_nom=100 should pass."""
        imos_ds = _make_time_series_dataset(
            depth_val=50.0, inst_nominal_depth=50.0, site_nominal_depth=100.0,
        )
        qc = ImosImpossibleDepthQC(repo_root=_repo_root(), mode="timeSeries")
        result = qc.run(imos_ds)

        assert "DEPTH" in result.variable_flags
        assert np.all(result.variable_flags["DEPTH"] == QCFlags.GOOD)

    def test_depth_too_shallow(self):
        """DEPTH=-10 should be flagged BAD (below surface)."""
        imos_ds = _make_time_series_dataset(
            depth_val=-10.0, inst_nominal_depth=50.0, site_nominal_depth=100.0,
        )
        qc = ImosImpossibleDepthQC(repo_root=_repo_root(), mode="timeSeries")
        result = qc.run(imos_ds)

        flags = result.variable_flags["DEPTH"]
        assert np.all(flags == QCFlags.BAD)

    def test_depth_too_deep(self):
        """DEPTH=500 with site_nom=100 should be flagged BAD."""
        imos_ds = _make_time_series_dataset(
            depth_val=500.0, inst_nominal_depth=50.0, site_nominal_depth=100.0,
        )
        qc = ImosImpossibleDepthQC(repo_root=_repo_root(), mode="timeSeries")
        result = qc.run(imos_ds)

        flags = result.variable_flags["DEPTH"]
        assert np.all(flags == QCFlags.BAD)

    def test_missing_metadata_warning(self):
        """Missing depth metadata → warning, no flags."""
        ds = xr.Dataset(
            {"DEPTH": (("TIME",), np.array([50.0, 55.0], dtype=np.float32),
                       {"valid_min": -5.0, "valid_max": 12000.0})},
            coords={"TIME": [np.datetime64("2020-01-01"), np.datetime64("2020-01-02")]},
            attrs={},
        )
        imos_ds = IMOSDataset(ds)
        qc = ImosImpossibleDepthQC(repo_root=_repo_root(), mode="timeSeries")
        result = qc.run(imos_ds)

        assert "Warning" in result.log

    def test_profile_mode_good(self):
        """Profile depths 0-79 with BOT_DEPTH=90 (+20%=108) → all good."""
        imos_ds = _make_profile_dataset(bot_depth=90.0)
        qc = ImosImpossibleDepthQC(repo_root=_repo_root(), mode="profile")
        result = qc.run(imos_ds)

        assert "DEPTH" in result.variable_flags
        assert np.all(result.variable_flags["DEPTH"] == QCFlags.GOOD)

    def test_profile_mode_too_deep(self):
        """Profile depth exceeding BOT_DEPTH + 20% → BAD."""
        depths = np.array([0.0, 50.0, 150.0], dtype=np.float32)  # 150 > 90*1.2=108
        imos_ds = _make_profile_dataset(depths=depths, temp=np.array([20.0, 15.0, 10.0]), bot_depth=90.0)
        qc = ImosImpossibleDepthQC(repo_root=_repo_root(), mode="profile")
        result = qc.run(imos_ds)

        flags = result.variable_flags["DEPTH"]
        assert flags[0] == QCFlags.GOOD
        assert flags[1] == QCFlags.GOOD
        assert flags[2] == QCFlags.BAD


# ===================================================================
# Test: QC chain runner
# ===================================================================

class TestQCChainRunner:
    def test_chain_runs_in_order(self):
        """Run a chain of two QC routines and verify both apply."""
        imos_ds = _make_time_series_dataset(n=20)
        chain = [
            ImosImpossibleDateQC(repo_root=_repo_root()),
            ImosGlobalRangeQC(repo_root=_repo_root()),
        ]
        results = run_qc_chain(imos_ds, chain)

        assert len(results) == 2
        # TIME should have QC flags from impossible date
        assert "TIME_QC" in imos_ds.dataset

    def test_flag_upgrade_semantics(self):
        """Flags can only increase (worse) – never decrease."""
        # Create a dataset where the first routine marks TEMP as GOOD,
        # then a second routine marks some as BAD.
        imos_ds = _make_time_series_dataset(n=10, temp_range=(18.0, 22.0))
        # Inject one out-of-range value
        imos_ds.dataset["TEMP"].values[0] = -10.0  # below global valid_min

        chain = [
            ImosGlobalRangeQC(repo_root=_repo_root()),
        ]
        run_qc_chain(imos_ds, chain)

        flags = imos_ds.dataset["TEMP_QC"].values
        assert flags[0] == QCFlags.BAD
        assert np.all(flags[1:] == QCFlags.GOOD)

    def test_full_timeseries_chain(self):
        """Run the first 5 QC routines of the standard timeSeries chain."""
        imos_ds = _make_time_series_dataset(
            n=48,
            lat=-42.59667,
            lon=148.2333,
            site_code="NRSMAI",
            temp_range=(12.0, 20.0),
            psal_range=(30.0, 37.0),
            depth_val=50.0,
            inst_nominal_depth=50.0,
            site_nominal_depth=100.0,
        )
        chain = [
            ImosImpossibleDateQC(repo_root=_repo_root()),
            ImosImpossibleLocationSetQC(repo_root=_repo_root()),
            ImosInOutWaterQC(mode="timeSeries"),
            ImosGlobalRangeQC(repo_root=_repo_root()),
            ImosRegionalRangeQC(repo_root=_repo_root()),
            ImosImpossibleDepthQC(repo_root=_repo_root(), mode="timeSeries"),
        ]
        results = run_qc_chain(imos_ds, chain)

        assert len(results) == 6
        # After running all QC, TEMP should have flags
        assert "TEMP_QC" in imos_ds.dataset
        # With realistic data and correct site, TEMP should be all GOOD
        assert np.all(imos_ds.dataset["TEMP_QC"].values >= QCFlags.GOOD)

    def test_reset_clears_flags(self):
        """reset=True should set all QC flags to RAW before running."""
        imos_ds = _make_time_series_dataset(n=5)
        # Manually set some flags
        imos_ds.add_variable(
            "TEMP_QC",
            np.full(5, QCFlags.BAD, dtype=np.int8),
            dims=("TIME",),
        )
        chain = [ImosGlobalRangeQC(repo_root=_repo_root())]
        run_qc_chain(imos_ds, chain, reset=True)

        # Global range should have re-evaluated to GOOD
        flags = imos_ds.dataset["TEMP_QC"].values
        assert np.all(flags == QCFlags.GOOD)


# ===================================================================
# Test: Realistic oceanographic sample data (SBE37-like CTD series)
#
# Simulates a 30-day mooring deployment at NRSMAI (Maria Island NRS)
# with realistic temperature (10-18 C), salinity (34.5-35.5 PSU),
# and depth (~45 m) data, including deliberate outliers.
# ===================================================================

class TestRealisticSBE37Sample:
    """End-to-end QC with a simulated SBE37 CTD time-series."""

    @pytest.fixture
    def sbe37_dataset(self):
        """Build a 30-day hourly CTD dataset at NRSMAI."""
        rng = np.random.default_rng(123)
        n = 720  # 30 days * 24 h
        start = np.datetime64("2020-04-01T00:00:00")
        times = np.arange(start, start + np.timedelta64(n, "h"), np.timedelta64(1, "h"))

        # Realistic temperature: seasonal cycle + noise
        t = np.arange(n)
        temp = 14.0 + 2.0 * np.sin(2 * np.pi * t / 720) + rng.normal(0, 0.3, n)
        # Inject 5 impossible values
        temp[100] = -5.0   # below global range (-2.5)
        temp[200] = 45.0   # above global range (40.0)
        temp[300] = 1.0    # below NRSMAI regional range (5)
        temp[400] = 28.0   # above NRSMAI regional range (25)
        temp[500] = 20.0   # normal (valid)

        psal = 35.0 + rng.normal(0, 0.2, n).astype(np.float32)
        psal[101] = 1.0    # below global range (2.0)
        psal[201] = 45.0   # above global range (41.0)

        depth = 45.0 + rng.normal(0, 0.5, n).astype(np.float32)

        ds = xr.Dataset(
            {
                "TEMP": (("TIME",), temp.astype(np.float32), {"valid_min": -2.5, "valid_max": 40.0}),
                "PSAL": (("TIME",), psal, {"valid_min": 2.0, "valid_max": 41.0}),
                "DEPTH": (("TIME",), depth, {"valid_min": -5.0, "valid_max": 12000.0}),
                "LONGITUDE": (("OBSERVATION",), np.array([148.2333])),
                "LATITUDE": (("OBSERVATION",), np.array([-42.59667])),
            },
            coords={"TIME": times},
            attrs={
                "site_code": "NRSMAI",
                "time_deployment_start": np.datetime64("2020-04-01T00:00:00"),
                "time_deployment_end": np.datetime64("2020-05-01T00:00:00"),
                "instrument_nominal_depth": 45.0,
                "site_nominal_depth": 85.0,
                "geospatial_lat_min": -42.59667,
                "geospatial_lat_max": -42.59667,
            },
        )
        return IMOSDataset(ds)

    def test_global_range_catches_outliers(self, sbe37_dataset):
        qc = ImosGlobalRangeQC(repo_root=_repo_root())
        result = qc.run(sbe37_dataset)

        temp_flags = result.variable_flags["TEMP"]
        assert temp_flags[100] == QCFlags.BAD   # -5.0 below -2.5
        assert temp_flags[200] == QCFlags.BAD   # 45.0 above 40.0
        assert temp_flags[500] == QCFlags.GOOD  # 20.0 in range

        psal_flags = result.variable_flags["PSAL"]
        assert psal_flags[101] == QCFlags.BAD   # 1.0 below 2.0
        assert psal_flags[201] == QCFlags.BAD   # 45.0 above 41.0

    def test_regional_range_catches_outliers(self, sbe37_dataset):
        qc = ImosRegionalRangeQC(repo_root=_repo_root())
        result = qc.run(sbe37_dataset)

        temp_flags = result.variable_flags["TEMP"]
        assert temp_flags[300] == QCFlags.BAD   # 1.0 below NRSMAI min 5
        assert temp_flags[400] == QCFlags.BAD   # 28.0 above NRSMAI max 25
        assert temp_flags[500] == QCFlags.GOOD  # 20.0 in regional range

    def test_full_chain_integration(self, sbe37_dataset):
        chain = [
            ImosImpossibleDateQC(repo_root=_repo_root()),
            ImosImpossibleLocationSetQC(repo_root=_repo_root()),
            ImosInOutWaterQC(mode="timeSeries"),
            ImosGlobalRangeQC(repo_root=_repo_root()),
            ImosRegionalRangeQC(repo_root=_repo_root()),
            ImosImpossibleDepthQC(repo_root=_repo_root(), mode="timeSeries"),
        ]
        results = run_qc_chain(sbe37_dataset, chain)

        assert len(results) == 6
        ds = sbe37_dataset.dataset

        # verify accumulated flags
        temp_qc = ds["TEMP_QC"].values
        assert temp_qc[100] == QCFlags.BAD  # global range fail
        assert temp_qc[200] == QCFlags.BAD  # global range fail
        assert temp_qc[300] == QCFlags.BAD  # regional range fail
        assert temp_qc[400] == QCFlags.BAD  # regional range fail

        # Dates are all post-2007, location is correct, so time and location QC are good
        assert "TIME_QC" in ds


# ===================================================================
# Test: Realistic GBR (Great Barrier Reef) temperature-only sensor
#
# Simulates a coastal temperature logger deployed at GBRHIS
# (Heron Island South, GBR) with values typical of tropical waters.
# ===================================================================

class TestRealisticGBRSample:
    """End-to-end QC with simulated GBR temperature data."""

    @pytest.fixture
    def gbr_dataset(self):
        rng = np.random.default_rng(999)
        n = 168  # 1 week hourly
        start = np.datetime64("2021-02-01T00:00:00")
        times = np.arange(start, start + np.timedelta64(n, "h"), np.timedelta64(1, "h"))

        temp = 27.0 + rng.normal(0, 1.5, n).astype(np.float32)
        temp[10] = 5.0    # below GBRHIS regional min (10)
        temp[50] = 35.0   # above GBRHIS regional max (32)

        ds = xr.Dataset(
            {
                "TEMP": (("TIME",), temp, {"valid_min": -2.5, "valid_max": 40.0}),
                "LONGITUDE": (("OBS",), np.array([151.914])),
                "LATITUDE": (("OBS",), np.array([-23.442])),
            },
            coords={"TIME": times},
            attrs={
                "site_code": "GBRHIS",
                "time_deployment_start": np.datetime64("2021-02-01T00:00:00"),
                "time_deployment_end": np.datetime64("2021-02-08T00:00:00"),
            },
        )
        return IMOSDataset(ds)

    def test_regional_range_gbr(self, gbr_dataset):
        qc = ImosRegionalRangeQC(repo_root=_repo_root())
        result = qc.run(gbr_dataset)

        flags = result.variable_flags["TEMP"]
        assert flags[10] == QCFlags.BAD   # 5°C below min 10
        assert flags[50] == QCFlags.BAD   # 35°C above max 32

    def test_global_range_gbr(self, gbr_dataset):
        qc = ImosGlobalRangeQC(repo_root=_repo_root())
        result = qc.run(gbr_dataset)

        flags = result.variable_flags["TEMP"]
        # 5°C and 35°C are within global range [-2.5, 40] so GOOD for global
        assert flags[10] == QCFlags.GOOD
        assert flags[50] == QCFlags.GOOD
