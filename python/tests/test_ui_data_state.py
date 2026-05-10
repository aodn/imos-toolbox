from __future__ import annotations

from imos_toolbox.ui.data import apply_manual_flags, mark_spikes, parse_file_list


def test_parse_file_list_handles_newlines_and_commas() -> None:
    result = parse_file_list(" /tmp/a.cnv,\n/tmp/b.cnv \n,  ")
    assert result == ["/tmp/a.cnv", "/tmp/b.cnv"]


def test_mark_spikes_updates_qc_flags() -> None:
    state = {
        "variables": {"TEMP": [1.0, 1.1, 12.0, 1.2, 1.1]},
        "qc_flags": {"TEMP": [1, 1, 1, 1, 1]},
    }
    updated, count = mark_spikes(state, variable="TEMP", threshold=1.5, flag_code=4)
    assert count == 1
    assert updated["qc_flags"]["TEMP"][2] == 4


def test_apply_manual_flags_updates_selected_indices() -> None:
    state = {
        "variables": {"TEMP": [1.0, 1.1, 1.2]},
        "qc_flags": {"TEMP": [1, 1, 1]},
    }
    updated, count = apply_manual_flags(state, variable="TEMP", indices=[0, 2], flag_code=3)
    assert count == 2
    assert updated["qc_flags"]["TEMP"] == [3, 1, 3]
