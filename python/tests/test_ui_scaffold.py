from __future__ import annotations


def test_ui_command_registered() -> None:
    from imos_toolbox.cli import main

    assert "ui" in main.commands


def test_manual_flagging_callback_wired_when_ui_deps_available() -> None:
    try:
        from imos_toolbox.ui import build_app
        app = build_app()
    except ModuleNotFoundError:
        return

    keys = list(app.callback_map.keys())
    assert any("manual-status.children" in key and "dataset-store.data" in key for key in keys)
