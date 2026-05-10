# IMOS Toolbox - Copilot Instructions

## Project Overview
IMOS Toolbox converts oceanographic instrument files into quality-controlled IMOS-compliant NetCDF. It supports time-series (moorings) and profile (casts) workflows with batch and GUI usage. MATLAB is the primary language, with Java utilities and a Python build script for standalone compilation.

## Key Paths
- MATLAB source: `IMOS/`, `Preprocessing/`, `AutomaticQC/`, `Parser/`, `Util/`, `NetCDF/`
- Java utilities: `Java/`
- Build tooling: `build.py`
- Configuration defaults: `toolboxProperties.txt`
- Tests/scripts: `runalltests.sh`, `runalltests.bat`, `batchTesting.m`

## Conventions and Constraints
- Prefer MATLAB `.m` edits for core logic; keep functions vectorized where possible.
- Do not modify or regenerate binaries (`*.exe`, `*.bin`, `imosToolbox_*`) unless explicitly requested.
- Keep toolbox mode options aligned with existing conventions: `timeSeries` or `profile`.
- Maintain QC pipeline ordering when editing QC chains; avoid reordering without justification.
- Use ASCII-only text unless the file already contains Unicode.

## Configuration Patterns
- Use `toolboxProperties.txt` as the canonical defaults for:
  - `toolbox.mode`
  - template directory and date formats
  - preprocessing and auto-QC chains
  - visual QC settings
- If adding a new default setting, document it in `toolboxProperties.txt` and keep names consistent with existing keys.

## Build and Runtime
- Standalone builds are managed via `build.py` (uses `docopt`, `GitPython`, and `ant` for Java deps).
- MATLAB version baseline for standalone is R2018b; keep compatibility with that runtime.
- For Java updates, ensure `Java/` builds via `ant install`.

## Testing
- Use `runalltests.sh` (Linux) or `runalltests.bat` (Windows) for full test runs.
- For batch regression, use `batchTesting.m` when appropriate.

## Documentation
- Prefer linking to the wiki for usage; update `README.md` only for repo-level changes.

## Python Port Roadmap
- Maintain the Python port plan and progress checklist in `python/ROADMAP.md`.
- When completing a Python port task, check it off in that roadmap.

## Python Parser Delivery Cycle
- For parser roadmap work, implement one parser at a time and keep changes scoped to that parser + shared utilities only.
- After wiring parser code/CLI/docs, always run the local quality gate from `python/`:
  - `uv run ruff check src tests`
  - `uv run mypy src`
  - `uv run pytest -v`
  - `uv run imos-toolbox --help`
- Only push when all checks pass locally.
- After push, monitor GitHub Actions `Python Port CI` and address failures before moving to the next parser.
