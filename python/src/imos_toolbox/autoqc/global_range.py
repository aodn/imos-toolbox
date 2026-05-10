"""imosGlobalRangeQC – flags data outside the parameter's valid_min / valid_max.

Port of ``AutomaticQC/imosGlobalRangeQC.m``.

The list of parameters to check is read from
``AutomaticQC/imosGlobalRangeQC.txt`` (one IMOS parameter name per line).

For each matching variable the routine reads ``valid_min`` and
``valid_max`` from the variable's own attributes (as set by the parser
from ``IMOS/imosParameters.txt``).  Data outside the range receives
``BAD`` (4); data inside receives ``GOOD`` (1).
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Optional, Set

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCVariableRoutine
from imos_toolbox.config import resolve_repo_root
from imos_toolbox.model import IMOSDataset

# Regex to strip trailing _N suffixes (e.g. UCUR_1 → UCUR)
_SUFFIX_RE = re.compile(r"^(.+)_\d+$")


def _strip_numeric_suffix(name: str) -> str:
    m = _SUFFIX_RE.match(name)
    return m.group(1) if m else name


def _load_checked_params(repo_root: Path | None = None) -> Set[str]:
    """Read parameter names from imosGlobalRangeQC.txt."""
    if repo_root is None:
        repo_root = resolve_repo_root(__file__)
    txt = (repo_root / "AutomaticQC" / "imosGlobalRangeQC.txt").read_text(encoding="utf-8")
    params: set[str] = set()
    for line in txt.splitlines():
        line = line.strip()
        if not line or line.startswith("%"):
            continue
        params.add(line.strip())
    return params


class ImosGlobalRangeQC(QCVariableRoutine):
    """Flag data outside the global valid_min / valid_max range."""

    name = "imosGlobalRangeQC"

    def __init__(self, repo_root: Path | None = None) -> None:
        self._repo_root = repo_root
        self._checked_params: Set[str] | None = None

    def _get_checked_params(self) -> Set[str]:
        if self._checked_params is None:
            self._checked_params = _load_checked_params(self._repo_root)
        return self._checked_params

    def check(
        self,
        dataset: IMOSDataset,
        variable_name: str,
    ) -> Optional[QCResult]:
        base_name = _strip_numeric_suffix(variable_name)
        if base_name not in self._get_checked_params():
            return None

        ds = dataset.dataset
        var = ds[variable_name]
        data = var.values

        valid_min = var.attrs.get("valid_min")
        valid_max = var.attrs.get("valid_max")

        if valid_min is None or valid_max is None:
            return None
        if valid_min == valid_max:
            # Cannot test when min == max
            return None

        valid_min = float(valid_min)
        valid_max = float(valid_max)

        flat = data.ravel()
        flags_flat = np.full(flat.shape, QCFlags.BAD, dtype=np.int8)
        passed = (flat >= valid_min) & (flat <= valid_max)
        flags_flat[passed] = QCFlags.GOOD
        flags = flags_flat.reshape(data.shape)

        log = f"{variable_name}: min={valid_min}, max={valid_max}"
        return QCResult(variable_flags={variable_name: flags}, log=log)
