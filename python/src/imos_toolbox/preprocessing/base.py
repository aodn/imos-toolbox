"""Base class for preprocessing routines."""

from __future__ import annotations

import abc
from dataclasses import dataclass

from imos_toolbox.model import IMOSDataset


@dataclass
class PPResult:
    """Outcome produced by a single preprocessing routine.

    Attributes
    ----------
    modified : bool
        Whether the dataset was changed.
    log : str
        Human-readable description of what was done (appended to history).
    """

    modified: bool = False
    log: str = ""


class PPRoutine(abc.ABC):
    """Abstract base class for all preprocessing routines.

    Subclasses implement :meth:`run` which receives an
    :class:`~imos_toolbox.model.IMOSDataset`, modifies it **in-place**, and
    returns a :class:`PPResult`.

    The routine should silently skip (return ``PPResult(modified=False)``) when
    the required input variables are absent, mirroring the MATLAB behaviour.
    """

    #: Short name matching the MATLAB function name.
    name: str = ""

    @abc.abstractmethod
    def run(self, dataset: IMOSDataset) -> PPResult:
        """Apply this preprocessing step to *dataset* in-place."""
        ...

    @staticmethod
    def _append_history(dataset: IMOSDataset, comment: str) -> None:
        import datetime
        now = datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
        entry = f"{now} - {comment}"
        existing = dataset.dataset.attrs.get("history", "")
        if existing:
            dataset.dataset.attrs["history"] = f"{existing}\n{entry}"
        else:
            dataset.dataset.attrs["history"] = entry
