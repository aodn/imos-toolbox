"""Preprocessing chain runner."""

from __future__ import annotations

import logging
from typing import List, Sequence

from imos_toolbox.model import IMOSDataset
from imos_toolbox.preprocessing.base import PPResult, PPRoutine

logger = logging.getLogger(__name__)

# Default chains (from toolboxProperties.txt preprocessManager.preprocessDefaultChain)
# Populated lazily to avoid circular imports.
DEFAULT_CHAINS: dict[str, list[str]] = {
    "timeSeries": [
        "pressureRelPP",
        "depthPP",
        "salinityPP",
        "oxygenPP",
        "velocityMagDirPP",
    ],
    "profile": [
        "pressureRelPP",
        "depthPP",
        "salinityPP",
        "oxygenPP",
    ],
}


def run_pp_chain(
    dataset: IMOSDataset,
    chain: Sequence[PPRoutine],
) -> List[PPResult]:
    """Execute preprocessing *chain* against *dataset* in order.

    Each routine modifies *dataset* in-place; the results are returned for
    logging / inspection.

    Parameters
    ----------
    dataset:
        The dataset to preprocess **in-place**.
    chain:
        Ordered sequence of :class:`~imos_toolbox.preprocessing.base.PPRoutine`
        instances.

    Returns
    -------
    list of PPResult
        One result per routine.
    """
    results: List[PPResult] = []
    for routine in chain:
        logger.info("Running preprocessing routine: %s", routine.name)
        try:
            result = routine.run(dataset)
        except Exception:
            logger.exception("Preprocessing routine %s raised an exception", routine.name)
            result = PPResult(log=f"{routine.name}: ERROR")
        results.append(result)
    return results
