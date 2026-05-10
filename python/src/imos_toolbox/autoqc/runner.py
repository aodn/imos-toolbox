"""QC chain runner – applies a sequence of QC routines to a dataset.

The runner:
1. Resets all ``*_QC`` variables to ``RAW`` (0).
2. Iterates through the chain in order.
3. For each routine, applies the returned flags using *upgrade-only*
   semantics: a flag value can only increase (raw → good → probGood →
   probBad → bad), never decrease.  ``imosHistoricalManualSetQC`` is
   exempt from this restriction but is not yet implemented.
"""

from __future__ import annotations

import logging
from typing import Any, Dict, List, Sequence

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCRoutine
from imos_toolbox.model import IMOSDataset, QC_SUFFIX

logger = logging.getLogger(__name__)


def _reset_flags(dataset: IMOSDataset) -> None:
    """Set every ``*_QC`` variable in *dataset* to ``RAW`` (0)."""
    ds = dataset.dataset
    for name in list(ds.data_vars):
        if str(name).endswith(QC_SUFFIX):
            ds[name].values[:] = QCFlags.RAW


def _apply_flags_upgrade(
    dataset: IMOSDataset,
    new_flags: Dict[str, np.ndarray],
) -> None:
    """Merge *new_flags* into the dataset using upgrade-only semantics."""
    ds = dataset.dataset
    for var_name, flags in new_flags.items():
        qc_name = f"{var_name}{QC_SUFFIX}"
        if qc_name not in ds:
            # Create the QC companion variable
            var = ds[var_name]
            ds[qc_name] = var.dims, np.full(var.shape, QCFlags.RAW, dtype=np.int8)
        existing = ds[qc_name].values
        # Upgrade only: keep the higher (worse) flag
        ds[qc_name].values = np.maximum(existing, flags.astype(np.int8))


def run_qc_chain(
    dataset: IMOSDataset,
    chain: Sequence[QCRoutine],
    *,
    reset: bool = True,
    **kwargs: Any,
) -> List[QCResult]:
    """Execute *chain* against *dataset* in order.

    Parameters
    ----------
    dataset : IMOSDataset
        The dataset to QC **in-place**.
    chain : sequence of QCRoutine
        Ordered QC routines.
    reset : bool
        If True (default), reset all existing QC flags to RAW before
        running the chain.

    Returns
    -------
    list of QCResult
        One result per routine.
    """
    if reset:
        _reset_flags(dataset)

    results: List[QCResult] = []
    for routine in chain:
        logger.info("Running QC routine: %s", routine.name)
        try:
            result = routine.run(dataset, **kwargs)
        except Exception:
            logger.exception("QC routine %s raised an exception", routine.name)
            result = QCResult(log=f"{routine.name}: ERROR")
        else:
            _apply_flags_upgrade(dataset, result.variable_flags)
        results.append(result)
    return results
