# IMOS Toolbox (Python port)

This directory contains the early-stage Python port of the IMOS Toolbox.

## Status

- Core scaffold plus substantial parser tranche implemented (see `parse-*` commands below).
- Dash UI scaffold is wired to real parser outputs for dataset preview and in-memory QC interactions.
- Preprocessing, full automatic QC chain, NetCDF export pipeline, and production workflow wiring remain in progress.

See [docs/ROADMAP.md](docs/ROADMAP.md) for detailed progress tracking.

## Development

```bash
cd python
python -m pip install uv
uv python install 3.14
uv venv --python 3.14 .venv
uv sync --extra dev
uv run imos-toolbox info

# Verify runtime
uv run python --version

# Tests, lint, type checking
uv run pytest -v
uv run ruff check src tests
uv run mypy src

# Run Dash UI scaffold (install optional UI deps first)
uv sync --extra ui --extra dev
uv run imos-toolbox ui --host 127.0.0.1 --port 8050

# Quick local UI verification example (Vemco parser)
cat > /tmp/vemco_ui_sample.csv << 'EOF'
Source Device: Minilog-12345
Study Start Time: 2024-01-01 00:00:00
Study Stop Time: 2024-01-01 00:04:00
Sample Interval: 00:01:00
Date,Time,Temperature (°C)
2024-01-01,00:00:00,20.0
2024-01-01,00:01:00,20.2
2024-01-01,00:02:00,20.4
2024-01-01,00:03:00,20.1
2024-01-01,00:04:00,20.3
EOF

# In UI Start tab: parser=vemco, input file=/tmp/vemco_ui_sample.csv, then click "Load Dataset"
# In Manual Flagging tab: select points with box/lasso and click "Apply Manual Flag"

# Resolve parser mapping from existing instruments table
uv run imos-toolbox parser-map --make "SEABIRD" --model "SBE19plus V2" --repo-root ..

# Parse one SBE19 .cnv file (initial support)
uv run imos-toolbox parse-sbe19 --file /path/to/file.cnv --mode timeSeries

# Preprocess a parsed NetCDF file (applies default chain: pressure, depth, salinity, oxygen, velocity)
uv run imos-toolbox preprocess --file /path/to/parsed.nc --mode timeSeries

# Export to IMOS-compliant NetCDF
uv run imos-toolbox export --file /path/to/processed.nc --output-dir /path/to/output --mode timeSeries

# Or process everything in one command (parse → preprocess → QC → export)
uv run imos-toolbox process --file /path/to/raw_data.asc --output-dir /path/to/output --mode timeSeries --parser sbe37

# Parse one SBE26 .tid file (initial support)
uv run imos-toolbox parse-sbe26 --file /path/to/file.tid --mode timeSeries

# Parse one SBE37 .asc/.cnv file (initial support)
uv run imos-toolbox parse-sbe37 --file /path/to/file.asc --mode timeSeries

# Parse one SBE37SM .asc/.cnv file (initial support)
uv run imos-toolbox parse-sbe37sm --file /path/to/file.cnv --mode timeSeries

# Parse one SBE39 .asc file (initial support)
uv run imos-toolbox parse-sbe39 --file /path/to/file.asc --mode timeSeries

# Parse one SBE56 .cnv/.csv file (initial support)
uv run imos-toolbox parse-sbe56 --file /path/to/file.csv --mode timeSeries

# Parse one WQM .dat/.raw file (initial support)
uv run imos-toolbox parse-wqm --file /path/to/file.dat --mode timeSeries

# Parse one WetStar .raw file (+ matching .dev)
uv run imos-toolbox parse-wetstar --file /path/to/file.raw --mode timeSeries

# Parse one ECOTriplet .raw file (+ matching .dev)
uv run imos-toolbox parse-ecotriplet --file /path/to/file.raw --mode timeSeries

# Parse one ECOBB9 .raw file (+ matching .dev)
uv run imos-toolbox parse-ecobb9 --file /path/to/file.raw --mode timeSeries

# Parse one DR1050 export file (initial support)
uv run imos-toolbox parse-dr1050 --file /path/to/file.txt --mode timeSeries

# Parse one XR420/XR620 export file (initial support)
uv run imos-toolbox parse-xr --file /path/to/file.dat --mode timeSeries

# Parse one Vemco Logger Vue CSV export (initial support)
uv run imos-toolbox parse-vemco --file /path/to/file.csv --mode timeSeries

# Parse one NIWA DAT3 ASCII export (initial support)
uv run imos-toolbox parse-niwa --file /path/to/file.DAT3 --mode timeSeries

# Parse one Star-Oddi Starmon Mini DAT export (initial support)
uv run imos-toolbox parse-starmon-mini --file /path/to/file.dat --mode timeSeries

# Parse one Star-Oddi Starmon DST DAT export (initial support)
uv run imos-toolbox parse-starmon-dst --file /path/to/file.dat --mode timeSeries

# Parse one Aquatec Aqualogger export (initial support)
uv run imos-toolbox parse-aquatec --file /path/to/file.txt --mode timeSeries

# Parse one Aanderaa RCM text export (initial support)
uv run imos-toolbox parse-rcm --file /path/to/file.txt --mode timeSeries

# Parse one YSI 6-Series binary DAT export (initial support)
uv run imos-toolbox parse-ysi6 --file /path/to/file.dat --mode timeSeries

# Parse one ReefNet Sensus Ultra CSV export (initial support)
uv run imos-toolbox parse-sensus-ultra --file /path/to/file.csv --mode timeSeries
```

Parser format coverage is tracked in [PARSER_FORMAT_MATRIX.md](PARSER_FORMAT_MATRIX.md).

## Command Shortcuts

Use the Makefile shortcuts to run all tooling consistently through `uv run`:

```bash
cd python
make info
make test
make lint
make typecheck
make lock-check
```

## Troubleshooting

- Wrong Python version: run `uv run python --version`; recreate env with `uv venv --python 3.14 .venv`.
- Stale environment: remove and rebuild with `rm -rf .venv && uv venv --python 3.14 .venv && uv sync --extra dev`.
- Lock mismatch after dependency edits: run `uv lock` and commit `uv.lock`.
