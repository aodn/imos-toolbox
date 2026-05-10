"""imosRegionalRangeQC – flags data outside site-specific thresholds.

Port of ``AutomaticQC/imosRegionalRangeQC.m``.

Regional ranges are read from ``AutomaticQC/imosRegionalRangeQC.txt``,
keyed by ``(site_code, parameter_name)``.  Data outside the range
receives ``BAD`` (4); data inside receives ``GOOD`` (1).
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Dict, Optional, Tuple

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCVariableRoutine
from imos_toolbox.config import resolve_repo_root
from imos_toolbox.model import IMOSDataset

_SUFFIX_RE = re.compile(r"^(.+)_\d+$")


def _strip_numeric_suffix(name: str) -> str:
    m = _SUFFIX_RE.match(name)
    return m.group(1) if m else name


def _load_regional_ranges(
    repo_root: Path | None = None,
) -> Dict[Tuple[str, str], Tuple[float, float]]:
    """Parse imosRegionalRangeQC.txt → {(site, param): (min, max)}."""
    if repo_root is None:
        repo_root = resolve_repo_root(__file__)
    txt_path = repo_root / "AutomaticQC" / "imosRegionalRangeQC.txt"
    ranges: Dict[Tuple[str, str], Tuple[float, float]] = {}
    for line in txt_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("%"):
            continue
        parts = [p.strip() for p in line.split(",")]
        if len(parts) < 4:
            continue
        site, param = parts[0], parts[1]
        try:
            rmin, rmax = float(parts[2]), float(parts[3])
        except ValueError:
            continue
        ranges[(site, param)] = (rmin, rmax)
    return ranges


class ImosRegionalRangeQC(QCVariableRoutine):
    """Flag data outside site-specific regional ranges."""

    name = "imosRegionalRangeQC"

    def __init__(self, repo_root: Path | None = None) -> None:
        self._repo_root = repo_root
        self._ranges: Optional[Dict[Tuple[str, str], Tuple[float, float]]] = None

    def _get_ranges(self) -> Dict[Tuple[str, str], Tuple[float, float]]:
        if self._ranges is None:
            self._ranges = _load_regional_ranges(self._repo_root)
        return self._ranges

    def check(
        self,
        dataset: IMOSDataset,
        variable_name: str,
    ) -> Optional[QCResult]:
        ds = dataset.dataset
        site_code = ds.attrs.get("site_code", "")
        if not site_code:
            return QCResult(
                log="Warning: no site_code – skipping regional range QC"
            )

        base_name = _strip_numeric_suffix(variable_name)
        ranges = self._get_ranges()

        # Check if site exists at all
        site_exists = any(k[0] == site_code for k in ranges)
        if not site_exists:
            return QCResult(
                log=f"Warning: site '{site_code}' not in imosRegionalRangeQC.txt"
            )

        key = (site_code, base_name)
        if key not in ranges:
            return None

        rmin, rmax = ranges[key]
        if rmin == rmax:
            return None

        data = ds[variable_name].values
        flat = data.ravel()
        flags_flat = np.full(flat.shape, QCFlags.BAD, dtype=np.int8)
        passed = (flat >= rmin) & (flat <= rmax)
        flags_flat[passed] = QCFlags.GOOD
        flags = flags_flat.reshape(data.shape)

        log = f"{variable_name}: regional min={rmin}, max={rmax} (site={site_code})"
        return QCResult(variable_flags={variable_name: flags}, log=log)
