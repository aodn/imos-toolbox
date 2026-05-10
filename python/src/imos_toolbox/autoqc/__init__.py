"""Automatic QC routines for the IMOS Toolbox Python port."""

from imos_toolbox.autoqc.base import (
    QCResult,
    QCRoutine,
    QCSetRoutine,
    QCVariableRoutine,
)
from imos_toolbox.autoqc.runner import run_qc_chain
from imos_toolbox.autoqc.salinity_from_pt import SalinityFromPTQC
from imos_toolbox.autoqc.rate_of_change import RateOfChangeQC
from imos_toolbox.autoqc.timeseries_spike import TimeSeriesSpikeQC
from imos_toolbox.autoqc.vertical_spike import VerticalSpikeQC
from imos_toolbox.autoqc.density_inversion import DensityInversionSetQC
from imos_toolbox.autoqc.stationarity import StationarityQC
from imos_toolbox.autoqc.ctd_surface_soak import CTDSurfaceSoakQC
from imos_toolbox.autoqc.surface_detection import SurfaceDetectionByDepthSetQC

__all__ = [
    "QCResult",
    "QCRoutine",
    "QCSetRoutine",
    "QCVariableRoutine",
    "run_qc_chain",
    "SalinityFromPTQC",
    "RateOfChangeQC",
    "TimeSeriesSpikeQC",
    "VerticalSpikeQC",
    "DensityInversionSetQC",
    "StationarityQC",
    "CTDSurfaceSoakQC",
    "SurfaceDetectionByDepthSetQC",
]
