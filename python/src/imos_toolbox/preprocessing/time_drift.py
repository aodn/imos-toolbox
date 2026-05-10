"""timeDriftPP – apply a linear time-drift correction.

Instruments sometimes have clocks that drift between deployment and
recovery.  This routine applies a linear correction by interpolating between
a start offset and an end offset (both in seconds) over the full data extent.

Parameters come from (in priority order):

1. Constructor arguments ``start_offset_s`` / ``end_offset_s``.
2. Dataset attributes ``time_drift_start_offset_s`` /
   ``time_drift_end_offset_s``.

If both offsets are 0 the routine is a no-op.

Equivalent to the MATLAB ``timeDriftPP.m`` (batch/auto mode).
"""

from __future__ import annotations

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.preprocessing.base import PPResult, PPRoutine


class TimeDriftPP(PPRoutine):
    """Apply a linear time-drift correction to the TIME coordinate."""

    name = "timeDriftPP"

    def __init__(
        self,
        start_offset_s: float | None = None,
        end_offset_s: float | None = None,
    ) -> None:
        self._start_s = start_offset_s
        self._end_s = end_offset_s

    def run(self, dataset: IMOSDataset) -> PPResult:
        ds = dataset.dataset

        start_s = self._start_s
        end_s = self._end_s

        if start_s is None:
            start_s = float(ds.attrs.get("time_drift_start_offset_s", 0.0))
        if end_s is None:
            end_s = float(ds.attrs.get("time_drift_end_offset_s", 0.0))

        if start_s == 0.0 and end_s == 0.0:
            return PPResult(modified=False, log="timeDriftPP: both offsets are 0 – skipped")

        if "TIME" not in ds.coords:
            return PPResult(modified=False, log="timeDriftPP: TIME coordinate not found – skipped")

        times = ds.coords["TIME"].values.astype("datetime64[ns]").astype(np.int64)
        t_min, t_max = times.min(), times.max()
        t_range = t_max - t_min

        if t_range == 0:
            return PPResult(modified=False, log="timeDriftPP: single-point dataset – skipped")

        # linear interpolation of offset (in nanoseconds)
        alpha = (times - t_min) / t_range
        offset_ns = (start_s + alpha * (end_s - start_s)) * 1e9
        ds.coords["TIME"] = (
            ds.coords["TIME"].dims,
            (times - offset_ns.astype(np.int64)).astype("datetime64[ns]"),
        )

        comment = (
            f"timeDriftPP: linear time-drift correction applied "
            f"(start {start_s:+.2f} s, end {end_s:+.2f} s)."
        )
        self._append_history(dataset, comment)
        return PPResult(modified=True, log=comment)
