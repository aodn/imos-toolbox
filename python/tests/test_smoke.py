from __future__ import annotations

from click.testing import CliRunner

from imos_toolbox.cli import main


def test_cli_info_runs() -> None:
    runner = CliRunner()
    result = runner.invoke(main, ["info"])

    assert result.exit_code == 0
    assert "IMOS Toolbox (Python port)" in result.output
