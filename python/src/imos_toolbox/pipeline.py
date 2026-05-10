"""Pipeline orchestration for end-to-end processing."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from imos_toolbox.autoqc.runner import run_qc_chain
from imos_toolbox.export import export_netcdf
from imos_toolbox.model import IMOSDataset
from imos_toolbox.preprocessing.runner import run_pp_chain


@dataclass
class PipelineResult:
    """Result of pipeline execution."""

    success: bool
    input_file: Path
    output_file: Path | None
    log: list[str]
    error: str | None = None


def run_pipeline(
    dataset: IMOSDataset,
    mode: str,
    output_dir: Path,
    pp_chain: list | None = None,
    qc_chain: list | None = None,
    log_callback: Callable[[str], None] | None = None,
) -> PipelineResult:
    """Run complete processing pipeline on a dataset.

    Args:
        dataset: Parsed dataset to process
        mode: Processing mode ('timeSeries' or 'profile')
        output_dir: Directory for output files
        pp_chain: Preprocessing routines (uses defaults if None)
        qc_chain: QC routines (uses defaults if None)
        log_callback: Optional callback for progress logging

    Returns:
        PipelineResult with success status and output path
    """
    log: list[str] = []

    def _log(msg: str) -> None:
        log.append(msg)
        if log_callback:
            log_callback(msg)

    try:
        # Step 1: Preprocessing
        if pp_chain is None:
            pp_chain = _get_default_pp_chain(mode)

        if pp_chain:
            _log(f"Running {len(pp_chain)} preprocessing routines...")
            pp_results = run_pp_chain(dataset, pp_chain)
            for routine, result in zip(pp_chain, pp_results):
                status = "✓" if result.modified else "○"
                _log(f"  {status} {routine.name}")
        else:
            _log("Running 0 preprocessing routines...")

        # Step 2: Automatic QC
        if qc_chain is None:
            qc_chain = _get_default_qc_chain(mode)

        if qc_chain:
            _log(f"Running {len(qc_chain)} QC routines...")
            qc_results = run_qc_chain(dataset, qc_chain)
            for routine, qc_result in zip(qc_chain, qc_results):
                flagged = len(qc_result.flags) if hasattr(qc_result, "flags") and qc_result.flags is not None else 0
                _log(f"  ✓ {routine.name}: {flagged} flags set")
        else:
            _log("Running 0 QC routines...")

        # Step 3: Export
        _log("Exporting to NetCDF...")
        output_path = export_netcdf(dataset, output_dir, mode)
        _log(f"✓ Exported: {output_path.name}")

        return PipelineResult(
            success=True,
            input_file=Path(""),  # Set by caller
            output_file=output_path,
            log=log,
        )

    except Exception as e:
        _log(f"✗ Error: {e}")
        return PipelineResult(
            success=False,
            input_file=Path(""),
            output_file=None,
            log=log,
            error=str(e),
        )


def _get_default_pp_chain(mode: str) -> list:
    """Get default preprocessing chain for mode."""
    from imos_toolbox.preprocessing.depth import DepthPP
    from imos_toolbox.preprocessing.oxygen import OxygenPP
    from imos_toolbox.preprocessing.pressure_rel import PressureRelPP
    from imos_toolbox.preprocessing.salinity import SalinityPP
    from imos_toolbox.preprocessing.velocity_mag_dir import VelocityMagDirPP

    chain = [
        PressureRelPP(),
        DepthPP(),
        SalinityPP(),
        OxygenPP(),
    ]

    if mode == "timeSeries":
        chain.append(VelocityMagDirPP())

    return chain


def _get_default_qc_chain(mode: str) -> list:
    """Get default QC chain for mode."""
    from imos_toolbox.autoqc.global_range import ImosGlobalRangeQC
    from imos_toolbox.autoqc.impossible_date import ImosImpossibleDateQC
    from imos_toolbox.autoqc.impossible_depth import ImosImpossibleDepthQC
    from imos_toolbox.autoqc.impossible_location import ImosImpossibleLocationSetQC
    from imos_toolbox.autoqc.rate_of_change import RateOfChangeQC
    from imos_toolbox.autoqc.regional_range import ImosRegionalRangeQC
    from imos_toolbox.autoqc.timeseries_spike import TimeSeriesSpikeQC

    chain = [
        ImosImpossibleDateQC(),
        ImosImpossibleLocationSetQC(),
        ImosImpossibleDepthQC(),
        ImosGlobalRangeQC(),
        ImosRegionalRangeQC(),
        RateOfChangeQC(),
    ]

    if mode == "timeSeries":
        chain.append(TimeSeriesSpikeQC())

    return chain
