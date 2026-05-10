"""Preprocessing pipeline for the IMOS Toolbox Python port.

Each routine is a :class:`PPRoutine` subclass that modifies an
:class:`~imos_toolbox.model.IMOSDataset` in-place.  The chain runner
(:func:`~imos_toolbox.preprocessing.runner.run_pp_chain`) applies a sequence
of routines in order, mirroring the MATLAB ``preprocessManager`` behaviour.

Default chains (from ``toolboxProperties.txt``):

* **timeSeries**: ``pressureRelPP`` → ``depthPP`` → ``salinityPP`` →
  ``oxygenPP`` → ``velocityMagDirPP``
* **profile**: ``pressureRelPP`` → ``depthPP`` → ``salinityPP`` →
  ``oxygenPP``

Only *batch/auto* mode is implemented; GUI dialogs are not ported.
"""

from imos_toolbox.preprocessing.base import PPResult, PPRoutine
from imos_toolbox.preprocessing.runner import DEFAULT_CHAINS, run_pp_chain

__all__ = [
    "PPRoutine",
    "PPResult",
    "run_pp_chain",
    "DEFAULT_CHAINS",
]
