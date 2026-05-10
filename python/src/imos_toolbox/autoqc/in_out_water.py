"""imosInOutWaterQC – flags samples outside the deployment time window.

Port of ``AutomaticQC/imosInOutWaterQC.m``.

In **timeSeries** mode every data point whose TIME timestamp falls
outside ``[time_deployment_start, time_deployment_end]`` is flagged
``BAD`` (4).  Points inside the window are left as ``RAW`` (0) to
preserve existing flags (matching MATLAB behaviour).

The test skips dimensions and the special variables ``TIMESERIES``,
``PROFILE``, ``TRAJECTORY``, ``LATITUDE``, ``LONGITUDE``,
``NOMINAL_DEPTH``.
"""

from __future__ import annotations

from typing import Optional

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCVariableRoutine
from imos_toolbox.model import IMOSDataset

EXCLUDED = frozenset(
    ["TIMESERIES", "PROFILE", "TRAJECTORY", "LATITUDE", "LONGITUDE", "NOMINAL_DEPTH"]
)


class ImosInOutWaterQC(QCVariableRoutine):
    """Flag data recorded outside the deployment time window."""

    name = "imosInOutWaterQC"
    excluded_variables = list(EXCLUDED)

    def __init__(self, mode: str = "timeSeries") -> None:
        self._mode = mode

    def check(
        self,
        dataset: IMOSDataset,
        variable_name: str,
    ) -> Optional[QCResult]:
        if variable_name in EXCLUDED:
            return None

        ds = dataset.dataset

        # Need deployment timestamps in attrs
        time_start = ds.attrs.get("time_deployment_start")
        time_end = ds.attrs.get("time_deployment_end")

        if time_start is None or time_end is None:
            return QCResult(
                log="Warning: time_deployment_start/end not set – skipping in/out water QC"
            )

        # Get TIME coordinate
        if "TIME" not in ds.dims and "TIME" not in ds:
            return None

        time_data = ds["TIME"].values

        # Convert deployment bounds to numpy datetime64
        np_start = np.datetime64(time_start, "ns") if not isinstance(time_start, np.datetime64) else time_start
        np_end = np.datetime64(time_end, "ns") if not isinstance(time_end, np.datetime64) else time_end

        if self._mode == "timeSeries":
            # Flag array shaped to the variable
            var = ds[variable_name]
            flags = np.full(var.shape, QCFlags.BAD, dtype=np.int8)

            # Find in-water mask along TIME dimension
            in_water = (time_data >= np_start) & (time_data <= np_end)

            # Broadcast along TIME axis (assumed first dim)
            if var.ndim == 1:
                flags[in_water] = QCFlags.RAW
            else:
                # For multi-dim variables, expand mask to match shape
                expand = (slice(None),) + (np.newaxis,) * (var.ndim - 1)
                flags[in_water[expand[0]]] = QCFlags.RAW
                # Simpler: use broadcast
                mask_nd = np.broadcast_to(in_water.reshape((-1,) + (1,) * (var.ndim - 1)), var.shape)
                flags = np.where(mask_nd, QCFlags.RAW, QCFlags.BAD).astype(np.int8)

            log_msg = (
                f"in={np.datetime_as_string(np_start, unit='s')}, "
                f"out={np.datetime_as_string(np_end, unit='s')}"
            )
            return QCResult(variable_flags={variable_name: flags}, log=log_msg)

        elif self._mode == "profile":
            # Profile mode: only check TIME variable itself
            if variable_name != "TIME":
                return None

            if np.any(time_data < np_start) or np.any(time_data > np_end):
                return QCResult(
                    log="ERROR: TIME outside deployment window in profile mode"
                )
            return None

        return None
