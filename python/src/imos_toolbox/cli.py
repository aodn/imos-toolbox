"""Command-line interface for the IMOS Toolbox port."""

from __future__ import annotations

from pathlib import Path

import click

from imos_toolbox.config import resolve_repo_root
from imos_toolbox.parsers import (
    AquatecParser,
    DR1050Parser,
    ECOBB9Parser,
    ECOTripletParser,
    ParserRegistry,
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
    XRParser,
    YSI6SeriesParser,
)


@click.group()
def main() -> None:
    """IMOS Toolbox CLI."""


@main.command("ui")
@click.option("--host", default="127.0.0.1", show_default=True)
@click.option("--port", default=8050, show_default=True, type=int)
@click.option("--debug/--no-debug", default=False, show_default=True)
def ui_cmd(host: str, port: int, debug: bool) -> None:
    """Run the Dash UI scaffold."""
    try:
        from imos_toolbox.ui import build_app
    except ImportError as exc:
        raise click.ClickException(
            "UI dependencies are not installed. Install with: uv sync --extra ui --extra dev"
        ) from exc

    app = build_app()
    app.run(host=host, port=port, debug=debug)


@main.command("info")
def info_cmd() -> None:
    """Show basic package info."""
    click.echo("IMOS Toolbox (Python port) - scaffold")


@main.command("parser-map")
@click.option("--make", required=True, help="Instrument make")
@click.option("--model", required=True, help="Instrument model")
@click.option("--repo-root", type=click.Path(path_type=Path), default=Path.cwd())
def parser_map_cmd(make: str, model: str, repo_root: Path) -> None:
    """Resolve parser name from instruments mapping."""
    root = resolve_repo_root(repo_root)
    instruments_file = root / "Parser" / "instruments.txt"

    registry = ParserRegistry()
    registry.register_many(
        [
            SBE19Parser,
            SBE26Parser,
            SBE37Parser,
            SBE37SMParser,
            SBE39Parser,
            SBE56Parser,
            SensusUltraParser,
            StarmonMiniParser,
            StarmonDSTParser,
            AquatecParser,
            WetStarParser,
            ECOTripletParser,
            ECOBB9Parser,
            DR1050Parser,
            NIWAParser,
            RCMParser,
            VemcoParser,
            WQMParser,
            XRParser,
            YSI6SeriesParser,
        ]
    )
    registry.load_instruments(instruments_file)

    parser_name = registry.parser_name_for(make, model)
    if parser_name is None:
        raise click.ClickException("No parser mapping found")
    click.echo(parser_name)


@main.command("parse-sbe19")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_sbe19_cmd(file_path: Path, mode: str) -> None:
    """Parse one SBE19 .cnv file and print summary."""
    parser = SBE19Parser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-sbe26")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_sbe26_cmd(file_path: Path, mode: str) -> None:
    """Parse one SBE26 .tid file and print summary."""
    parser = SBE26Parser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-sbe37")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_sbe37_cmd(file_path: Path, mode: str) -> None:
    """Parse one SBE37 .asc/.cnv file and print summary."""
    parser = SBE37Parser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-sbe37sm")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_sbe37sm_cmd(file_path: Path, mode: str) -> None:
    """Parse one SBE37SM .asc/.cnv file and print summary."""
    parser = SBE37SMParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-sbe39")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_sbe39_cmd(file_path: Path, mode: str) -> None:
    """Parse one SBE39 .asc file and print summary."""
    parser = SBE39Parser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-sbe56")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_sbe56_cmd(file_path: Path, mode: str) -> None:
    """Parse one SBE56 .cnv/.csv file and print summary."""
    parser = SBE56Parser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-wqm")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_wqm_cmd(file_path: Path, mode: str) -> None:
    """Parse one WQM .dat/.raw file and print summary."""
    parser = WQMParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-wetstar")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_wetstar_cmd(file_path: Path, mode: str) -> None:
    """Parse one WetStar .raw file (+ matching .dev) and print summary."""
    parser = WetStarParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-ecotriplet")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_ecotriplet_cmd(file_path: Path, mode: str) -> None:
    """Parse one ECOTriplet .raw file (+ matching .dev) and print summary."""
    parser = ECOTripletParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-ecobb9")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_ecobb9_cmd(file_path: Path, mode: str) -> None:
    """Parse one ECOBB9 .raw file (+ matching .dev) and print summary."""
    parser = ECOBB9Parser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-dr1050")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_dr1050_cmd(file_path: Path, mode: str) -> None:
    """Parse one DR1050 export file and print summary."""
    parser = DR1050Parser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-xr")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_xr_cmd(file_path: Path, mode: str) -> None:
    """Parse one XR420/XR620 export file and print summary."""
    parser = XRParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-vemco")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_vemco_cmd(file_path: Path, mode: str) -> None:
    """Parse one Vemco Logger Vue CSV export and print summary."""
    parser = VemcoParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-niwa")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_niwa_cmd(file_path: Path, mode: str) -> None:
    """Parse one NIWA .DAT3 ASCII file and print summary."""
    parser = NIWAParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-sensus-ultra")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_sensus_ultra_cmd(file_path: Path, mode: str) -> None:
    """Parse one ReefNet Sensus Ultra CSV file and print summary."""
    parser = SensusUltraParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-starmon-mini")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_starmon_mini_cmd(file_path: Path, mode: str) -> None:
    """Parse one Star-Oddi Starmon Mini DAT file and print summary."""
    parser = StarmonMiniParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-starmon-dst")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_starmon_dst_cmd(file_path: Path, mode: str) -> None:
    """Parse one Star-Oddi Starmon DST DAT file and print summary."""
    parser = StarmonDSTParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-aquatec")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_aquatec_cmd(file_path: Path, mode: str) -> None:
    """Parse one Aquatec Aqualogger export file and print summary."""
    parser = AquatecParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-rcm")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_rcm_cmd(file_path: Path, mode: str) -> None:
    """Parse one Aanderaa RCM text export and print summary."""
    parser = RCMParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("parse-ysi6")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--mode", default="timeSeries", show_default=True)
def parse_ysi6_cmd(file_path: Path, mode: str) -> None:
    """Parse one YSI 6-Series binary DAT file and print summary."""
    parser = YSI6SeriesParser()
    dataset = parser.parse([file_path], mode)
    xds = dataset.to_xarray()

    click.echo(f"file={file_path}")
    click.echo(f"variables={len(xds.data_vars)}")
    click.echo(f"dimensions={dict(xds.dims)}")


@main.command("preprocess")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option(
    "--mode",
    default="timeSeries",
    show_default=True,
    type=click.Choice(["timeSeries", "profile"]),
)
@click.option("--pressure-offset", default=-10.1325, show_default=True, type=float,
              help="Offset applied to PRES to derive PRES_REL (dbar).")
def preprocess_cmd(file_path: Path, mode: str, pressure_offset: float) -> None:
    """Run the default preprocessing chain on a parsed NetCDF file.

    The input file must be a NetCDF file previously produced by a parse-*
    command.  The routine applies the default preprocessing chain for the
    given mode and prints a summary of which steps ran.
    """
    import xarray as xr
    from imos_toolbox.model import IMOSDataset
    from imos_toolbox.preprocessing.runner import run_pp_chain
    from imos_toolbox.preprocessing.pressure_rel import PressureRelPP
    from imos_toolbox.preprocessing.depth import DepthPP
    from imos_toolbox.preprocessing.salinity import SalinityPP
    from imos_toolbox.preprocessing.oxygen import OxygenPP
    from imos_toolbox.preprocessing.velocity_mag_dir import VelocityMagDirPP

    ds = IMOSDataset(xr.open_dataset(str(file_path)))

    routines = [
        PressureRelPP(offset_dbar=pressure_offset),
        DepthPP(),
        SalinityPP(),
        OxygenPP(),
    ]
    if mode == "timeSeries":
        routines.append(VelocityMagDirPP())

    results = run_pp_chain(ds, routines)

    click.echo(f"file={file_path}  mode={mode}")
    for routine, result in zip(routines, results):
        status = "MODIFIED" if result.modified else "skipped"
        click.echo(f"  [{status:8s}] {routine.name}: {result.log[:80]}")


@main.command("export")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--output-dir", required=True, type=click.Path(path_type=Path))
@click.option(
    "--mode",
    default="timeSeries",
    show_default=True,
    type=click.Choice(["timeSeries", "profile"]),
)
def export_cmd(file_path: Path, output_dir: Path, mode: str) -> None:
    """Export a dataset to IMOS-compliant NetCDF.

    The input file should be a NetCDF file (from parse-* or preprocess commands).
    """
    import xarray as xr
    from imos_toolbox.model import IMOSDataset
    from imos_toolbox.export import export_netcdf

    ds = IMOSDataset(xr.open_dataset(str(file_path)))
    output_path = export_netcdf(ds, output_dir, mode)
    click.echo(f"Exported: {output_path}")


@main.command("process")
@click.option("--file", "file_path", required=True, type=click.Path(path_type=Path, exists=True))
@click.option("--output-dir", required=True, type=click.Path(path_type=Path))
@click.option(
    "--mode",
    default="timeSeries",
    show_default=True,
    type=click.Choice(["timeSeries", "profile"]),
)
@click.option("--parser", help="Parser name (auto-detected if omitted)")
@click.option("--skip-pp", is_flag=True, help="Skip preprocessing")
@click.option("--skip-qc", is_flag=True, help="Skip quality control")
def process_cmd(
    file_path: Path,
    output_dir: Path,
    mode: str,
    parser: str | None,
    skip_pp: bool,
    skip_qc: bool,
) -> None:
    """Process a raw instrument file through the complete pipeline.

    This command runs: parse → preprocess → QC → export in one step.
    """
    from imos_toolbox.model import IMOSDataset
    from imos_toolbox.pipeline import run_pipeline

    # Step 1: Parse
    click.echo(f"Parsing {file_path.name}...")
    if parser:
        # Use specified parser
        registry = ParserRegistry()
        registry.register_many([
            SBE19Parser, SBE26Parser, SBE37Parser, SBE37SMParser,
            SBE39Parser, SBE56Parser, WQMParser, WetStarParser,
            ECOTripletParser, ECOBB9Parser, XRParser, DR1050Parser,
            VemcoParser, NIWAParser, StarmonMiniParser, StarmonDSTParser,
            AquatecParser, RCMParser, YSI6SeriesParser, SensusUltraParser,
        ])
        parser_cls = registry.get(parser)
        if not parser_cls:
            raise click.ClickException(f"Unknown parser: {parser}")
        dataset = parser_cls().parse([file_path], mode)
    else:
        # Auto-detect parser (simplified - just try common ones)
        raise click.ClickException("Auto-detection not yet implemented. Use --parser option.")

    # Step 2-4: Run pipeline
    pp_chain = None if skip_pp else []  # None = use defaults, [] = skip
    qc_chain = None if skip_qc else []

    result = run_pipeline(
        dataset,
        mode,
        output_dir,
        pp_chain=pp_chain if not skip_pp else [],
        qc_chain=qc_chain if not skip_qc else [],
        log_callback=click.echo,
    )

    if result.success:
        click.echo(f"\n✓ Success: {result.output_file}")
    else:
        raise click.ClickException(f"Processing failed: {result.error}")


if __name__ == "__main__":
    main()
