"""Core data model for the IMOS Toolbox port."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable, Mapping

import numpy as np
import xarray as xr

QC_SUFFIX = "_QC"


@dataclass
class IMOSDataset:
    """Wrapper around xarray.Dataset with IMOS-specific helpers."""

    dataset: xr.Dataset

    @classmethod
    def empty(cls) -> "IMOSDataset":
        return cls(xr.Dataset())

    @classmethod
    def from_xarray(cls, dataset: xr.Dataset) -> "IMOSDataset":
        return cls(dataset)

    def to_xarray(self) -> xr.Dataset:
        return self.dataset

    def add_dimension(
        self,
        name: str,
        data: Iterable[Any],
        attrs: Mapping[str, Any] | None = None,
    ) -> None:
        coord = xr.DataArray(np.asarray(list(data)), dims=(name,), attrs=dict(attrs or {}))
        self.dataset = self.dataset.assign_coords({name: coord})

    def add_variable(
        self,
        name: str,
        data: Any,
        dims: Iterable[str],
        attrs: Mapping[str, Any] | None = None,
        flags: Any | None = None,
        flag_attrs: Mapping[str, Any] | None = None,
    ) -> None:
        self.dataset[name] = (tuple(dims), data, dict(attrs or {}))
        if flags is not None:
            flag_name = f"{name}{QC_SUFFIX}"
            self.dataset[flag_name] = (tuple(dims), flags, dict(flag_attrs or {}))

    def get_variable(self, name: str) -> xr.DataArray:
        return self.dataset[name]

    def get_flags(self, name: str) -> xr.DataArray | None:
        flag_name = f"{name}{QC_SUFFIX}"
        return self.dataset.get(flag_name)

    def set_attrs(self, attrs: Mapping[str, Any]) -> None:
        self.dataset.attrs.update(dict(attrs))

    def copy(self) -> "IMOSDataset":
        return IMOSDataset(self.dataset.copy())
