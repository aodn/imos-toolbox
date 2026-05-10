"""Base classes for automatic QC routines.

Two types of QC routine mirror the MATLAB architecture:

* **QCVariableRoutine** – operates on one variable at a time.  The runner
  iterates over all eligible variables and calls ``check()`` for each.
* **QCSetRoutine** – receives the whole dataset and can flag multiple
  variables at once.  MATLAB names ending in ``SetQC`` use this pattern.

Both flavours return a :class:`QCResult` that the chain runner folds back
into the dataset.
"""

from __future__ import annotations

import abc
from dataclasses import dataclass, field
from typing import Any, Dict, Optional

import numpy as np
import numpy.typing as npt

from imos_toolbox.model import IMOSDataset


# ---------------------------------------------------------------------------
# QC flag constants (IMOS QC set 1)
# ---------------------------------------------------------------------------

class QCFlags:
    """IMOS standard QC flag values (QC set 1)."""

    RAW = np.int8(0)
    GOOD = np.int8(1)
    PROBABLY_GOOD = np.int8(2)
    PROBABLY_BAD = np.int8(3)
    BAD = np.int8(4)
    MISSING = np.int8(9)


# ---------------------------------------------------------------------------
# Result container
# ---------------------------------------------------------------------------

@dataclass
class QCResult:
    """Outcome produced by a single QC routine for one or more variables.

    Attributes
    ----------
    variable_flags : dict
        Mapping ``{variable_name: numpy int8 flag array}``.
    log : str
        Human-readable summary of parameters / thresholds used.
    """

    variable_flags: Dict[str, npt.NDArray[np.int8]] = field(default_factory=dict)
    log: str = ""


# ---------------------------------------------------------------------------
# Abstract base classes
# ---------------------------------------------------------------------------

class QCRoutine(abc.ABC):
    """Common interface shared by all QC routines."""

    #: A short identifier matching the MATLAB function name.
    name: str = ""

    @abc.abstractmethod
    def run(self, dataset: IMOSDataset, **kwargs: Any) -> QCResult:
        """Execute the QC check and return flags."""
        ...


class QCVariableRoutine(QCRoutine):
    """QC routine executed once per eligible variable.

    Subclasses implement :meth:`check` which receives a single variable's
    data and returns flags for that variable.  The chain runner calls
    ``check`` in a loop over all applicable variables and assembles the
    results.  A convenience :meth:`run` implementation takes care of that
    loop so most callers can simply call ``run()``.
    """

    #: Variable names this routine applies to (empty → all variables).
    applicable_variables: list[str] = []
    #: Variable names this routine should *skip*.
    excluded_variables: list[str] = []

    @abc.abstractmethod
    def check(
        self,
        dataset: IMOSDataset,
        variable_name: str,
    ) -> Optional[QCResult]:
        """Return flags for *variable_name* or ``None`` to skip."""
        ...

    # Convenience: iterate over eligible variables
    def run(self, dataset: IMOSDataset, **kwargs: Any) -> QCResult:
        combined = QCResult()
        # Check both data variables and coordinate variables
        all_names: list[str] = []
        all_names.extend(str(n) for n in dataset.dataset.data_vars)
        all_names.extend(str(n) for n in dataset.dataset.coords)
        seen: set[str] = set()
        for name in all_names:
            if name in seen:
                continue
            seen.add(name)
            if name.endswith("_QC"):
                continue
            if self.applicable_variables and name not in self.applicable_variables:
                continue
            if name in self.excluded_variables:
                continue
            result = self.check(dataset, name)
            if result is not None:
                combined.variable_flags.update(result.variable_flags)
                if result.log:
                    combined.log += ("; " if combined.log else "") + result.log
        return combined


class QCSetRoutine(QCRoutine):
    """QC routine that operates on the whole dataset at once.

    Subclasses implement :meth:`run` directly.
    """

    pass
