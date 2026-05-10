"""Finalization hooks for IMOS datasets."""

from __future__ import annotations

from imos_toolbox.model import IMOSDataset


def finalise_dataset(dataset: IMOSDataset) -> IMOSDataset:
    """Placeholder for post-processing before NetCDF export."""
    return dataset
