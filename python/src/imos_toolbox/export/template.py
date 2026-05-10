"""NetCDF template parser.

Parses IMOS NetCDF attribute template files (.txt) that define
global and variable attributes for IMOS-compliant NetCDF outputs.
"""

import re
from pathlib import Path
from typing import Any

from imos_toolbox.model import IMOSDataset


def parse_template(
    template_path: Path, dataset: IMOSDataset, var_idx: int | None = None
) -> dict[str, Any]:
    """Parse a NetCDF attribute template file.

    Template syntax:
        type, attribute_name = attribute_value

    Types:
        S - String
        N - Numeric
        D - Date
        Q - QC flag

    Tokens in attribute_value:
        [ddb field] - deployment database field (not yet implemented)
        [mat statement] - Python expression evaluated with dataset context

    Args:
        template_path: Path to template .txt file
        dataset: IMOSDataset containing data and metadata
        var_idx: Optional variable index for variable attribute templates

    Returns:
        Dictionary of attribute name -> value pairs
    """
    attributes = {}

    with template_path.open("r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("%"):
                continue

            match = re.match(r"^\s*([SNDQ])\s*,\s*(\S+)\s*=\s*(.*)$", line)
            if not match:
                continue

            attr_type, attr_name, attr_value = match.groups()
            attr_value = attr_value.strip()

            if not attr_value:
                continue

            # Process tokens
            processed_value = _process_tokens(attr_value, dataset, var_idx)

            # Type conversion
            if attr_type == "N":
                try:
                    processed_value = float(processed_value)
                except (ValueError, TypeError):
                    continue
            elif attr_type == "D":
                # Date handling - for now keep as string, will enhance later
                pass

            if processed_value:
                attributes[attr_name] = processed_value

    return attributes


def _process_tokens(value: str, dataset: IMOSDataset, var_idx: int | None) -> Any:
    """Process [mat ...] and [ddb ...] tokens in attribute values."""

    def replace_mat_token(match: re.Match) -> str:
        expr = match.group(1).strip()
        try:
            # Build evaluation context
            ctx = {
                "sample_data": dataset,
                "dataset": dataset,
                "k": var_idx,
            }
            result = eval(expr, {"__builtins__": {}}, ctx)
            return str(result) if result is not None else ""
        except Exception:
            return ""

    # Replace [mat ...] tokens
    value = re.sub(r"\[mat\s+([^\]]+)\]", replace_mat_token, value)

    # [ddb ...] tokens not yet implemented - strip them
    value = re.sub(r"\[ddb[^\]]*\]", "", value)

    return value.strip()
