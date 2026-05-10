"""Dash UI package for the IMOS Toolbox Python port."""

from __future__ import annotations


def build_app():
    from imos_toolbox.ui.app import build_app as _build_app

    return _build_app()

__all__ = ["build_app"]
