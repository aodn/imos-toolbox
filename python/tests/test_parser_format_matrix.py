from __future__ import annotations

from pathlib import Path

import pytest

from imos_toolbox.parsers import (
    AquatecParser,
    ECOBB9Parser,
    ECOTripletParser,
    NIWAParser,
    RCMParser,
    SBE19Parser,
    SBE26Parser,
    SBE37Parser,
    SBE37SMParser,
    SBE39Parser,
    SBE56Parser,
    SensusUltraParser,
    StarmonDSTParser,
    StarmonMiniParser,
    VemcoParser,
    WetStarParser,
    WQMParser,
    YSI6SeriesParser,
)


@pytest.mark.parametrize(
    ("parser_cls", "supported_suffixes"),
    [
        (SBE19Parser, [".cnv"]),
        (AquatecParser, [".txt", ".dat", ".csv"]),
        (SBE26Parser, [".tid"]),
        (SBE37Parser, [".asc", ".cnv"]),
        (SBE37SMParser, [".asc", ".cnv"]),
        (SBE39Parser, [".asc"]),
        (SBE56Parser, [".cnv", ".csv"]),
        (WQMParser, [".dat", ".raw"]),
        (WetStarParser, [".raw"]),
        (ECOTripletParser, [".raw"]),
        (ECOBB9Parser, [".raw"]),
        (VemcoParser, [".csv"]),
        (NIWAParser, [".dat3", ".dat"]),
        (RCMParser, [".txt"]),
        (SensusUltraParser, [".csv"]),
        (StarmonMiniParser, [".dat"]),
        (StarmonDSTParser, [".dat"]),
        (YSI6SeriesParser, [".dat"]),
    ],
)
def test_parser_rejects_unsupported_extensions(
    tmp_path: Path, parser_cls: type, supported_suffixes: list[str]
) -> None:
    parser = parser_cls()

    unsupported = tmp_path / "sample.unsupported"
    unsupported.write_text("dummy", encoding="utf-8")

    if ".raw" in supported_suffixes:
        dev_file = unsupported.with_suffix(".dev")
        dev_file.write_text("dummy", encoding="utf-8")

    with pytest.raises(ValueError):
        parser.parse([unsupported], "timeSeries")


@pytest.mark.parametrize(
    ("command_name",),
    [
        ("parse-sbe19",),
        ("parse-aquatec",),
        ("parse-sbe26",),
        ("parse-sbe37",),
        ("parse-sbe37sm",),
        ("parse-sbe39",),
        ("parse-sbe56",),
        ("parse-wqm",),
        ("parse-wetstar",),
        ("parse-ecotriplet",),
        ("parse-ecobb9",),
        ("parse-dr1050",),
        ("parse-xr",),
        ("parse-vemco",),
        ("parse-niwa",),
        ("parse-rcm",),
        ("parse-sensus-ultra",),
        ("parse-starmon-mini",),
        ("parse-starmon-dst",),
        ("parse-ysi6",),
    ],
)
def test_parser_commands_exist(command_name: str) -> None:
    from imos_toolbox.cli import main

    assert command_name in main.commands
