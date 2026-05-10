"""Tests for the preprocessing pipeline (Phase 5)."""

from __future__ import annotations

import numpy as np
import pytest
import xarray as xr

from imos_toolbox.model import IMOSDataset
from imos_toolbox.preprocessing.base import PPResult, PPRoutine
from imos_toolbox.preprocessing.runner import run_pp_chain
from imos_toolbox.preprocessing.pressure_rel import PressureRelPP
from imos_toolbox.preprocessing.depth import DepthPP
from imos_toolbox.preprocessing.salinity import SalinityPP
from imos_toolbox.preprocessing.oxygen import OxygenPP
from imos_toolbox.preprocessing.velocity_mag_dir import VelocityMagDirPP
from imos_toolbox.preprocessing.time_offset import TimeOffsetPP, _parse_timezone
from imos_toolbox.preprocessing.time_drift import TimeDriftPP
from imos_toolbox.preprocessing.variable_offset import VariableOffsetPP


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_ds(**kwargs: xr.DataArray) -> IMOSDataset:
    return IMOSDataset(xr.Dataset(kwargs))


def _time_coord(n: int = 10) -> np.ndarray:
    return np.arange(
        np.datetime64("2024-01-01T00:00:00"),
        np.datetime64("2024-01-01T00:00:00") + np.timedelta64(n, "h"),
        np.timedelta64(1, "h"),
    )


# ---------------------------------------------------------------------------
# Base infrastructure
# ---------------------------------------------------------------------------

class _NopRoutine(PPRoutine):
    name = "nop"

    def run(self, dataset: IMOSDataset) -> PPResult:
        return PPResult(modified=False, log="nop")


def test_pp_result_defaults():
    r = PPResult()
    assert r.modified is False
    assert r.log == ""


def test_run_pp_chain_returns_results():
    ds = IMOSDataset.empty()
    results = run_pp_chain(ds, [_NopRoutine(), _NopRoutine()])
    assert len(results) == 2
    assert all(isinstance(r, PPResult) for r in results)


def test_append_history():
    ds = IMOSDataset.empty()
    _NopRoutine._append_history(ds, "step 1")
    _NopRoutine._append_history(ds, "step 2")
    history = ds.dataset.attrs["history"]
    assert "step 1" in history
    assert "step 2" in history
    assert history.index("step 1") < history.index("step 2")


# ---------------------------------------------------------------------------
# pressureRelPP
# ---------------------------------------------------------------------------

def test_pressure_rel_adds_pres_rel():
    pres = np.array([110.0, 120.0, 130.0], dtype=np.float32)
    ds = _make_ds(PRES=xr.DataArray(pres, dims=("TIME",)))
    result = PressureRelPP().run(ds)
    assert result.modified
    assert "PRES_REL" in ds.dataset
    np.testing.assert_allclose(
        ds.dataset["PRES_REL"].values, pres - 10.1325, rtol=1e-4
    )


def test_pressure_rel_skips_if_already_present():
    pres_rel = np.array([100.0], dtype=np.float32)
    ds = _make_ds(
        PRES=xr.DataArray(np.array([110.0], dtype=np.float32), dims=("TIME",)),
        PRES_REL=xr.DataArray(pres_rel, dims=("TIME",)),
    )
    result = PressureRelPP().run(ds)
    assert not result.modified


def test_pressure_rel_skips_if_no_pres():
    ds = IMOSDataset.empty()
    result = PressureRelPP().run(ds)
    assert not result.modified


def test_pressure_rel_custom_offset():
    pres = np.array([200.0], dtype=np.float32)
    ds = _make_ds(PRES=xr.DataArray(pres, dims=("TIME",)))
    result = PressureRelPP(offset_dbar=-5.0).run(ds)
    assert result.modified
    np.testing.assert_allclose(ds.dataset["PRES_REL"].values, [195.0], rtol=1e-4)


# ---------------------------------------------------------------------------
# depthPP
# ---------------------------------------------------------------------------

def test_depth_from_pres_rel_with_latitude():
    pres_rel = np.array([50.0, 100.0, 200.0], dtype=np.float32)
    ds = _make_ds(PRES_REL=xr.DataArray(pres_rel, dims=("TIME",)))
    ds.dataset.attrs["geospatial_lat_min"] = -33.0
    result = DepthPP().run(ds)
    assert result.modified
    depth = ds.dataset["DEPTH"].values
    # depth values should be positive and roughly proportional to pressure
    assert np.all(depth > 0)
    assert depth[0] < depth[1] < depth[2]


def test_depth_fallback_no_latitude():
    pres_rel = np.array([50.0, 100.0], dtype=np.float32)
    ds = _make_ds(PRES_REL=xr.DataArray(pres_rel, dims=("TIME",)))
    result = DepthPP().run(ds)
    assert result.modified
    np.testing.assert_allclose(ds.dataset["DEPTH"].values, pres_rel, rtol=1e-4)


def test_depth_skips_if_already_present():
    ds = _make_ds(
        DEPTH=xr.DataArray(np.array([50.0], dtype=np.float32), dims=("TIME",)),
        PRES_REL=xr.DataArray(np.array([51.0], dtype=np.float32), dims=("TIME",)),
    )
    result = DepthPP().run(ds)
    assert not result.modified


def test_depth_skips_if_no_pressure():
    ds = IMOSDataset.empty()
    result = DepthPP().run(ds)
    assert not result.modified


def test_depth_falls_back_to_pres():
    pres = np.array([110.1325], dtype=np.float32)
    ds = _make_ds(PRES=xr.DataArray(pres, dims=("TIME",)))
    result = DepthPP().run(ds)
    assert result.modified
    # 110.1325 - 10.1325 = 100 dbar ≈ 100 m
    np.testing.assert_allclose(ds.dataset["DEPTH"].values, [100.0], rtol=1e-3)


# ---------------------------------------------------------------------------
# salinityPP
# ---------------------------------------------------------------------------

def test_salinity_derives_psal():
    n = 5
    cndc = np.full(n, 4.2, dtype=np.float32)    # S/m (~35 PSU)
    temp = np.full(n, 15.0, dtype=np.float32)   # °C
    pres_rel = np.full(n, 0.0, dtype=np.float32)
    ds = _make_ds(
        CNDC=xr.DataArray(cndc, dims=("TIME",)),
        TEMP=xr.DataArray(temp, dims=("TIME",)),
        PRES_REL=xr.DataArray(pres_rel, dims=("TIME",)),
    )
    result = SalinityPP().run(ds)
    assert result.modified
    psal = ds.dataset["PSAL"].values
    # gsw.C3515() ≈ 42.914 mS/cm; R=10*4.2/42.914≈0.979 → PSAL≈34.5
    assert np.all(psal > 30.0) and np.all(psal < 40.0)


def test_salinity_skips_if_psal_present():
    ds = _make_ds(
        PSAL=xr.DataArray(np.array([35.0], dtype=np.float32), dims=("TIME",)),
        CNDC=xr.DataArray(np.array([4.2], dtype=np.float32), dims=("TIME",)),
        TEMP=xr.DataArray(np.array([15.0], dtype=np.float32), dims=("TIME",)),
        PRES_REL=xr.DataArray(np.array([0.0], dtype=np.float32), dims=("TIME",)),
    )
    result = SalinityPP().run(ds)
    assert not result.modified


def test_salinity_skips_if_missing_inputs():
    ds = _make_ds(TEMP=xr.DataArray(np.array([15.0], dtype=np.float32), dims=("TIME",)))
    result = SalinityPP().run(ds)
    assert not result.modified


# ---------------------------------------------------------------------------
# oxygenPP
# ---------------------------------------------------------------------------

def test_oxygen_derives_oxsol_surface():
    n = 5
    temp = np.full(n, 15.0, dtype=np.float32)
    psal = np.full(n, 35.0, dtype=np.float32)
    pres_rel = np.full(n, 0.0, dtype=np.float32)
    dox = np.full(n, 5.0, dtype=np.float32)  # ml/L
    ds = _make_ds(
        TEMP=xr.DataArray(temp, dims=("TIME",)),
        PSAL=xr.DataArray(psal, dims=("TIME",)),
        PRES_REL=xr.DataArray(pres_rel, dims=("TIME",)),
        DOX=xr.DataArray(dox, dims=("TIME",)),
    )
    ds.dataset.attrs.update({"geospatial_lat_min": -33.0, "geospatial_lon_min": 151.0})
    result = OxygenPP().run(ds)
    assert result.modified
    assert "OXSOL_SURFACE" in ds.dataset
    assert "DOX1" in ds.dataset
    assert "DOX2" in ds.dataset
    assert "DOXS" in ds.dataset
    # sanity: OXSOL_SURFACE ~220-260 µmol/kg at 15°C, S=35
    oxsol = ds.dataset["OXSOL_SURFACE"].values
    assert np.all(oxsol > 180.0) and np.all(oxsol < 300.0)


def test_oxygen_skips_missing_temp_psal():
    ds = _make_ds(DOX=xr.DataArray(np.array([5.0], dtype=np.float32), dims=("TIME",)))
    result = OxygenPP().run(ds)
    assert not result.modified


def test_oxygen_skips_no_do_variable():
    n = 3
    ds = _make_ds(
        TEMP=xr.DataArray(np.full(n, 15.0, dtype=np.float32), dims=("TIME",)),
        PSAL=xr.DataArray(np.full(n, 35.0, dtype=np.float32), dims=("TIME",)),
        PRES_REL=xr.DataArray(np.full(n, 0.0, dtype=np.float32), dims=("TIME",)),
    )
    result = OxygenPP().run(ds)
    assert not result.modified


# ---------------------------------------------------------------------------
# velocityMagDirPP
# ---------------------------------------------------------------------------

def test_velocity_mag_dir_derives_cspd_cdir():
    ucur = np.array([1.0, 0.0, -1.0], dtype=np.float32)
    vcur = np.array([0.0, 1.0, 0.0], dtype=np.float32)
    ds = _make_ds(
        UCUR=xr.DataArray(ucur, dims=("TIME",)),
        VCUR=xr.DataArray(vcur, dims=("TIME",)),
    )
    result = VelocityMagDirPP().run(ds)
    assert result.modified
    cspd = ds.dataset["CSPD"].values
    cdir = ds.dataset["CDIR"].values
    np.testing.assert_allclose(cspd, [1.0, 1.0, 1.0], rtol=1e-5)
    # east-only (UCUR=1, VCUR=0) → 90°
    np.testing.assert_allclose(cdir[0], 90.0, atol=0.1)
    # north-only (UCUR=0, VCUR=1) → 0° (or 360°)
    assert cdir[1] % 360.0 == pytest.approx(0.0, abs=0.1)


def test_velocity_skips_if_cspd_present():
    ds = _make_ds(
        UCUR=xr.DataArray(np.array([1.0], dtype=np.float32), dims=("TIME",)),
        VCUR=xr.DataArray(np.array([0.0], dtype=np.float32), dims=("TIME",)),
        CSPD=xr.DataArray(np.array([1.0], dtype=np.float32), dims=("TIME",)),
    )
    result = VelocityMagDirPP().run(ds)
    assert not result.modified


def test_velocity_skips_missing_ucur_vcur():
    ds = IMOSDataset.empty()
    result = VelocityMagDirPP().run(ds)
    assert not result.modified


# ---------------------------------------------------------------------------
# timeOffsetPP
# ---------------------------------------------------------------------------

def test_parse_timezone_numeric():
    assert _parse_timezone("10") == pytest.approx(10.0)
    assert _parse_timezone("-5") == pytest.approx(-5.0)
    assert _parse_timezone("0") == pytest.approx(0.0)


def test_parse_timezone_utc_string():
    assert _parse_timezone("UTC+10") == pytest.approx(10.0)
    assert _parse_timezone("UTC-5") == pytest.approx(-5.0)
    assert _parse_timezone("UTC+5:30") == pytest.approx(5.5)


def test_time_offset_shifts_time():
    times = _time_coord(5)
    ds = IMOSDataset(xr.Dataset(coords={"TIME": times}))
    result = TimeOffsetPP(offset_hours=-10.0).run(ds)
    assert result.modified
    shifted = ds.dataset.coords["TIME"].values
    delta = (shifted[0] - times[0]) / np.timedelta64(1, "h")
    assert delta == pytest.approx(-10.0, abs=0.001)


def test_time_offset_zero_is_noop():
    times = _time_coord(3)
    ds = IMOSDataset(xr.Dataset(coords={"TIME": times}))
    result = TimeOffsetPP(offset_hours=0.0).run(ds)
    assert not result.modified


# ---------------------------------------------------------------------------
# timeDriftPP
# ---------------------------------------------------------------------------

def test_time_drift_applies_correction():
    times = _time_coord(11)
    ds = IMOSDataset(xr.Dataset(coords={"TIME": times}))
    original_first = times[0]
    original_last = times[-1]
    result = TimeDriftPP(start_offset_s=0.0, end_offset_s=3600.0).run(ds)
    assert result.modified
    corrected = ds.dataset.coords["TIME"].values
    # first sample: offset=0 → unchanged
    assert corrected[0] == original_first
    # last sample: offset=3600s → 1 hour earlier
    delta_last = (original_last - corrected[-1]) / np.timedelta64(1, "s")
    assert delta_last == pytest.approx(3600.0, abs=1.0)


def test_time_drift_zero_offsets_is_noop():
    times = _time_coord(3)
    ds = IMOSDataset(xr.Dataset(coords={"TIME": times}))
    result = TimeDriftPP(start_offset_s=0.0, end_offset_s=0.0).run(ds)
    assert not result.modified


# ---------------------------------------------------------------------------
# variableOffsetPP
# ---------------------------------------------------------------------------

def test_variable_offset_applies_correction():
    temp = np.array([20.0, 21.0, 22.0], dtype=np.float32)
    ds = _make_ds(TEMP=xr.DataArray(temp, dims=("TIME",)))
    result = VariableOffsetPP({"TEMP": (0.5, 1.0)}).run(ds)
    assert result.modified
    np.testing.assert_allclose(ds.dataset["TEMP"].values, temp + 0.5, rtol=1e-5)


def test_variable_offset_scale():
    temp = np.array([10.0], dtype=np.float32)
    ds = _make_ds(TEMP=xr.DataArray(temp, dims=("TIME",)))
    result = VariableOffsetPP({"TEMP": (0.0, 2.0)}).run(ds)
    assert result.modified
    np.testing.assert_allclose(ds.dataset["TEMP"].values, [20.0], rtol=1e-5)


def test_variable_offset_skips_missing_variable():
    ds = IMOSDataset.empty()
    result = VariableOffsetPP({"NONEXISTENT": (1.0, 1.0)}).run(ds)
    assert not result.modified


# ---------------------------------------------------------------------------
# Integration: default timeSeries chain
# ---------------------------------------------------------------------------

def test_default_timeseries_chain():
    """Run the full default timeSeries chain on a synthetic dataset."""
    n = 10
    pres = np.full(n, 110.1325, dtype=np.float32)  # → PRES_REL ≈ 100 dbar
    cndc = np.full(n, 4.2, dtype=np.float32)
    temp = np.full(n, 15.0, dtype=np.float32)
    ucur = np.full(n, 1.0, dtype=np.float32)
    vcur = np.full(n, 0.0, dtype=np.float32)

    ds = IMOSDataset(
        xr.Dataset(
            {
                "PRES":  (("TIME",), pres),
                "CNDC":  (("TIME",), cndc),
                "TEMP":  (("TIME",), temp),
                "UCUR":  (("TIME",), ucur),
                "VCUR":  (("TIME",), vcur),
            },
            attrs={"geospatial_lat_min": -33.0, "geospatial_lon_min": 151.0},
        )
    )

    chain = [
        PressureRelPP(),
        DepthPP(),
        SalinityPP(),
        OxygenPP(),
        VelocityMagDirPP(),
    ]
    results = run_pp_chain(ds, chain)

    assert all(isinstance(r, PPResult) for r in results)
    assert "PRES_REL" in ds.dataset
    assert "DEPTH" in ds.dataset
    assert "PSAL" in ds.dataset
    assert "CSPD" in ds.dataset
    assert "CDIR" in ds.dataset
    # DEPTH should be ~100 m
    np.testing.assert_allclose(ds.dataset["DEPTH"].values, 100.0, rtol=0.02)
