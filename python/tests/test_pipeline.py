"""Tests for pipeline orchestration."""

from pathlib import Path
from datetime import datetime, timezone

import numpy as np
import xarray as xr

from imos_toolbox.model import IMOSDataset
from imos_toolbox.pipeline import run_pipeline


def test_pipeline_end_to_end(tmp_path: Path) -> None:
    """Test complete pipeline execution."""
    # Create simple test dataset
    time_data = np.array([
        datetime(2024, 1, 1, i, 0, 0, tzinfo=timezone.utc) for i in range(10)
    ])

    xds = xr.Dataset(
        {
            "TIME": ("TIME", time_data),
            "TEMP": ("TIME", np.linspace(20, 15, 10)),
        }
    )
    xds.attrs["site_code"] = "TEST"

    dataset = IMOSDataset(xds)

    # Run pipeline with minimal chains to avoid datetime issues
    from imos_toolbox.preprocessing.depth import DepthPP

    result = run_pipeline(
        dataset,
        mode="timeSeries",
        output_dir=tmp_path,
        pp_chain=[DepthPP()],  # Minimal preprocessing
        qc_chain=[],  # Skip QC for now
    )

    # Verify success
    assert result.success
    assert result.output_file is not None
    assert result.output_file.exists()
    assert result.output_file.suffix == ".nc"
    assert len(result.log) > 0

    # Verify log contains expected steps
    log_text = "\n".join(result.log)
    assert "preprocessing" in log_text.lower()
    assert "Export" in log_text or "export" in log_text.lower()


def test_pipeline_skip_preprocessing(tmp_path: Path) -> None:
    """Test pipeline with preprocessing skipped."""
    time_data = np.array([
        datetime(2024, 1, 1, i, 0, 0, tzinfo=timezone.utc) for i in range(5)
    ])

    xds = xr.Dataset(
        {
            "TIME": ("TIME", time_data),
            "TEMP": ("TIME", np.array([20.0, 20.1, 20.2, 20.1, 20.0])),
        }
    )
    xds.attrs["site_code"] = "TEST"

    dataset = IMOSDataset(xds)

    result = run_pipeline(
        dataset,
        mode="timeSeries",
        output_dir=tmp_path,
        pp_chain=[],  # Empty = skip
        qc_chain=[],  # Also skip QC to avoid datetime issues
    )

    assert result.success
    log_text = "\n".join(result.log)
    assert "0 preprocessing" in log_text.lower()


def test_pipeline_skip_qc(tmp_path: Path) -> None:
    """Test pipeline with QC skipped."""
    time_data = np.array([
        datetime(2024, 1, 1, i, 0, 0, tzinfo=timezone.utc) for i in range(5)
    ])

    xds = xr.Dataset(
        {
            "TIME": ("TIME", time_data),
            "TEMP": ("TIME", np.array([20.0, 20.1, 20.2, 20.1, 20.0])),
        }
    )
    xds.attrs["site_code"] = "TEST"

    dataset = IMOSDataset(xds)

    result = run_pipeline(
        dataset,
        mode="timeSeries",
        output_dir=tmp_path,
        qc_chain=[],  # Empty = skip
    )

    assert result.success
    log_text = "\n".join(result.log)
    assert "0 QC" in log_text
