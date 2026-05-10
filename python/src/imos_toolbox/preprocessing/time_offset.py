"""timeOffsetPP – shift TIME by a fixed UTC offset.

Applies a UTC timezone offset (in hours) to the ``TIME`` coordinate,
converting local instrument time to UTC.  The offset is taken from (in
priority order):

1. ``offset_hours`` constructor argument.
2. ``timezone`` dataset attribute (numeric string or IANA-style ``UTC+10``).

If the timezone string is not parseable the offset defaults to 0 (no-op).

Equivalent to the MATLAB ``timeOffsetPP.m`` (batch/auto mode).
"""

from __future__ import annotations

import logging
import re

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.preprocessing.base import PPResult, PPRoutine

logger = logging.getLogger(__name__)


def _parse_timezone(tz: str) -> float | None:
    """Return offset in hours from a timezone string, or None."""
    tz = tz.strip()
    try:
        return float(tz)
    except ValueError:
        pass
    # UTC±HH or UTC±HH:MM
    m = re.match(r"^UTC([+-]\d+(?::\d+)?)$", tz, re.IGNORECASE)
    if m:
        parts = m.group(1).replace("+", "").split(":")
        sign = -1 if m.group(1).startswith("-") else 1
        hours = int(parts[0].lstrip("+-"))
        minutes = int(parts[1]) if len(parts) > 1 else 0
        return sign * (hours + minutes / 60.0)
    return None


class TimeOffsetPP(PPRoutine):
    """Shift the TIME coordinate by a fixed UTC offset (in hours)."""

    name = "timeOffsetPP"

    def __init__(self, offset_hours: float | None = None) -> None:
        self._offset_hours = offset_hours

    def run(self, dataset: IMOSDataset) -> PPResult:
        ds = dataset.dataset

        offset = self._offset_hours
        if offset is None:
            tz = ds.attrs.get("timezone", "0")
            offset = _parse_timezone(str(tz))
            if offset is None:
                logger.warning("timeOffsetPP: cannot parse timezone '%s', defaulting to 0", tz)
                offset = 0.0

        if offset == 0.0:
            return PPResult(modified=False, log="timeOffsetPP: offset is 0 – skipped")

        if "TIME" not in ds.coords:
            return PPResult(modified=False, log="timeOffsetPP: TIME coordinate not found – skipped")

        delta = np.timedelta64(int(offset * 3600 * 1e9), "ns")
        ds.coords["TIME"] = ds.coords["TIME"] + delta

        comment = f"timeOffsetPP: TIME shifted by {offset:+.4f} hours to convert to UTC."
        self._append_history(dataset, comment)
        return PPResult(modified=True, log=comment)
