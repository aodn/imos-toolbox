"""variableOffsetPP – apply a linear offset and scale to named variables.

Transforms variable data as:

    data = offset + scale * data

Parameters are supplied as a mapping ``{variable_name: (offset, scale)}``.
If a listed variable is absent in the dataset it is skipped silently.

Equivalent to the MATLAB ``variableOffsetPP.m`` (batch/auto mode).
"""

from __future__ import annotations

from typing import Mapping, Tuple

import numpy as np

from imos_toolbox.model import IMOSDataset
from imos_toolbox.preprocessing.base import PPResult, PPRoutine


class VariableOffsetPP(PPRoutine):
    """Apply linear offset + scale to specified variables."""

    name = "variableOffsetPP"

    def __init__(self, corrections: Mapping[str, Tuple[float, float]]) -> None:
        """
        Parameters
        ----------
        corrections:
            Mapping of ``{variable_name: (offset, scale)}``.
            ``data = offset + scale * data``
        """
        self._corrections = dict(corrections)

    def run(self, dataset: IMOSDataset) -> PPResult:
        ds = dataset.dataset
        applied: list[str] = []

        for var_name, (offset, scale) in self._corrections.items():
            if var_name not in ds:
                continue
            data = ds[var_name].values.astype(np.float64)
            ds[var_name] = (ds[var_name].dims, (offset + scale * data).astype(ds[var_name].dtype))
            # preserve original attrs, append comment
            comment_str = (
                f"variableOffsetPP: {var_name} = {offset:+g} + {scale:g} * {var_name}."
            )
            existing_comment = ds[var_name].attrs.get("comment", "")
            ds[var_name].attrs["comment"] = (
                f"{existing_comment} {comment_str}".strip()
            )
            applied.append(var_name)

        if not applied:
            return PPResult(modified=False, log="variableOffsetPP: no variables modified")

        comment = "variableOffsetPP: corrections applied to " + ", ".join(applied) + "."
        self._append_history(dataset, comment)
        return PPResult(modified=True, log=comment)
