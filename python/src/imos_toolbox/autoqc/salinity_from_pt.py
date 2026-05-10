"""Salinity QC from pressure/temperature/conductivity flags.

Propagates the highest QC flags from pressure/depth, conductivity, and temperature
to salinity variables, since salinity is derived from these measurements.
"""

import numpy as np

from imos_toolbox.autoqc.base import QCFlags, QCResult, QCSetRoutine
from imos_toolbox.model import IMOSDataset


class SalinityFromPTQC(QCSetRoutine):
    """Propagate pressure/temperature/conductivity flags to salinity."""

    name = "imosSalinityFromPTQC"

    def run(self, dataset: IMOSDataset, **kwargs) -> QCResult:
        result = QCResult()
        qc_flags = QCFlags()
        ds = dataset.dataset

        # Find all salinity variables
        for var_name in ds.data_vars:
            base_name = self._strip_suffix(str(var_name))
            if base_name != "PSAL":
                continue

            var = ds[var_name]
            
            # Initialize flags to RAW
            flags = np.full(var.shape, qc_flags.RAW, dtype=np.int8)
            depth_flags = np.full(var.shape, qc_flags.RAW, dtype=np.int8)
            pressure_flags = np.full(var.shape, qc_flags.RAW, dtype=np.int8)

            # Collect flags from TEMP and CNDC
            param_names = {"TEMP", "CNDC"}
            for other_name in ds.data_vars:
                other_base = self._strip_suffix(str(other_name))
                if other_base in param_names:
                    qc_var_name = f"{other_name}_QC"
                    if qc_var_name in ds:
                        other_flags = ds[qc_var_name].values.ravel()
                        flags = np.maximum(flags, other_flags[: flags.size])

            # Collect flags from pressure variables
            pressure_names = {"PRES_REL", "PRES"}
            for other_name in ds.data_vars:
                other_base = self._strip_suffix(str(other_name))
                if other_base in pressure_names:
                    qc_var_name = f"{other_name}_QC"
                    if qc_var_name in ds:
                        other_flags = ds[qc_var_name].values.ravel()
                        pressure_flags = np.maximum(
                            pressure_flags, other_flags[: pressure_flags.size]
                        )

            # Collect flags from DEPTH
            has_depth = False
            for other_name in ds.data_vars:
                other_base = self._strip_suffix(str(other_name))
                if other_base == "DEPTH":
                    qc_var_name = f"{other_name}_QC"
                    if qc_var_name in ds:
                        has_depth = True
                        other_flags = ds[qc_var_name].values.ravel()
                        depth_flags = np.maximum(
                            depth_flags, other_flags[: depth_flags.size]
                        )

            # Use DEPTH flags if available, otherwise use pressure flags
            if has_depth:
                flags = np.maximum(flags, depth_flags)
            else:
                flags = np.maximum(flags, pressure_flags)

            # Reshape flags to match variable shape
            flags = flags.reshape(var.shape)

            result.variable_flags[str(var_name)] = flags
            if not result.log:
                result.log = "Flags propagated from TEMP, CNDC, PRES/DEPTH"

        return result

    @staticmethod
    def _strip_suffix(name: str) -> str:
        """Strip numeric suffix like '_1', '_2' from variable name."""
        if "_" in name:
            parts = name.rsplit("_", 1)
            if len(parts) == 2 and parts[1].isdigit():
                return parts[0]
        return name
