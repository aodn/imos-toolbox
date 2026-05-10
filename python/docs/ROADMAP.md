# IMOS Toolbox Python Port - Roadmap

This roadmap tracks the Python port plan and progress. Check items off as work is completed.

## Regression Testing Documentation

**MCR-Based Approach** (Recommended - No MATLAB License Required):
- 📘 [MCR_SUMMARY.md](MCR_SUMMARY.md) - Executive summary and recommendation
- 📗 [MCR_REGRESSION_PLAN.md](MCR_REGRESSION_PLAN.md) - Comprehensive technical plan (20KB)
- 📕 [MCR_QUICKSTART.md](MCR_QUICKSTART.md) - 30-minute quick-start guide

**Traditional MATLAB Approach** (Alternative):
- 📙 [REGRESSION_TESTING_SUMMARY.md](REGRESSION_TESTING_SUMMARY.md) - Executive summary
- 📘 [REGRESSION_TESTING_PLAN.md](REGRESSION_TESTING_PLAN.md) - Detailed technical plan (15KB)
- 📗 [REGRESSION_TESTING_QUICKSTART.md](REGRESSION_TESTING_QUICKSTART.md) - Step-by-step guide

**Recommendation**: Use MCR approach for $10,750+ savings and faster implementation (6 weeks vs 10 weeks).

---

## Phase 1 - Scaffold and core model
- [x] Install uv for environment and dependency management
- [x] Bootstrap local Python environment with uv (.venv + sync)
- [x] Pin project interpreter via .python-version (3.14)
- [x] Validate CLI boot using uv run
- [x] Create package layout under python/
- [x] Add core IMOSDataset wrapper and helpers
- [x] Add config loader for toolboxProperties.txt
- [x] Add conventions loaders (parameters, QC flags, QC tests, file versions, sites, naming)
- [x] Add CLI entrypoint skeleton

## Python Development Setup (Detailed)

This section is the canonical setup guide for contributors working on the Python port.

### Environment management standard
- [x] Use `uv` as the single environment and dependency manager for this project
- [x] Keep a project-local virtual environment at `python/.venv`
- [x] Pin interpreter target in `python/.python-version` to `3.14`

### Bootstrap steps (fresh clone)
- [x] Install uv (`python -m pip install uv` or official installer)
- [x] Install Python 3.14 runtime via uv (`uv python install 3.14`)
- [x] Create `.venv` with pinned runtime (`uv venv --python 3.14 .venv`)
- [x] Sync dependencies (`uv sync --extra dev`)

### Day-to-day development workflow
- [x] Add README section with UV-first commands and examples
- [x] Standardize all project commands through `uv run` (tests, lint, type checks, CLI)
- [x] Add contributor command reference for:
	- [x] `uv run imos-toolbox info`
	- [x] `uv run pytest -v`
	- [x] `uv run ruff check src tests`
	- [x] `uv run mypy src`

### Verification and diagnostics
- [x] Verify interpreter (`uv run python --version` reports 3.14.x)
- [x] Verify package entrypoint (`uv run imos-toolbox info`)
- [x] Add a `make`/task alias or script targets (optional) for common uv commands
- [x] Document common setup failures and fixes (broken local Python, stale `.venv`, lock mismatch)

### Dependency/lock hygiene
- [x] Keep `uv.lock` committed and updated when dependencies change
- [ ] Define policy for dependency updates (e.g., scheduled bump window)
- [x] Add CI check to ensure lockfile is in sync with `pyproject.toml`

## Phase 2 - Parser framework and mapping
- [x] Add parser base class and registry
- [x] Load parser mapping from Parser/instruments.txt
- [x] Implement SBE19 parser
- [x] Implement SBE26 parser
- [x] Implement SBE37 parser
- [x] Implement SBE37SM parser
- [x] Implement SBE39 parser
- [x] Implement SBE56 parser
- [x] Implement SBE3x shared logic
- [ ] Implement Workhorse ADCP parser
- [ ] Implement AWAC parser
- [ ] Implement Continental parser
- [ ] Implement Aquadopp Profiler parser
- [ ] Implement Aquadopp Velocity parser
- [ ] Implement Signature/AD2CP parser
- [ ] Implement OceanContour parser
- [x] Implement WQM parser
- [x] Implement WetStar parser
- [x] Implement ECOBB9 parser
- [x] Implement ECO Triplet parser
- [x] Implement XR parser
- [x] Implement DR1050 parser
- [x] Implement Vemco parser
- [x] Implement NIWA parser
- [ ] Implement NXIC binary parser
- [x] Implement Starmon Mini parser
- [x] Implement Starmon DST parser
- [x] Implement Aquatec parser
- [x] Implement Sensus Ultra parser
- [ ] Implement Echoview parser
- [ ] Implement Infinity SD Logger parser
- [x] Implement RCM parser
- [x] Implement YSI 6-Series parser
- [ ] Implement NetCDF re-import parser
- [ ] Port GenericParser framework

## Phase 3 - Preprocessing
- [x] Add preprocessing base class (`PPRoutine`, `PPResult`) and chain runner (`run_pp_chain`)
- [x] Implement pressureRelPP (PRES_REL = PRES + offset, default -10.1325 dbar)
- [x] Implement depthPP using gsw (DEPTH = -gsw.z_from_p(PRES_REL, lat); fallback 1 dbar ≈ 1 m)
- [x] Implement salinityPP using gsw (PSAL from CNDC, TEMP, PRES_REL via gsw.SP_from_C)
- [x] Implement oxygenPP using gsw (OXSOL_SURFACE, DOX1, DOX2, DOXS conversions)
- [x] Implement velocityMagDirPP (CSPD/CDIR from UCUR/VCUR)
- [x] Implement timeOffsetPP (UTC timezone correction; parses numeric, UTC±HH[:MM])
- [x] Implement timeDriftPP (linear time-drift correction between start/end offsets)
- [x] Implement variableOffsetPP (data = offset + scale * data for named variables)
- [x] Wire `preprocess` CLI command for default timeSeries/profile chains
- [x] Add 31 unit tests (all passing), ruff clean, mypy clean
- [ ] Implement magneticDeclinationPP using pyIGRF or equivalent
- [ ] Implement adcpBinMappingPP
- [ ] Implement adcpNortekVelocityBeam2EnuPP
- [ ] Implement adcpNortekVelocityEnu2BeamPP
- [ ] Implement adcpWorkhorseVelocityBeam2EnuPP
- [ ] Implement transformPP
- [ ] Implement absiDecibelBasicPP
- [ ] Implement aquatrackaPP
- [ ] Implement rinkoDoPP
- [ ] Implement CTDDepthBinPP
- [ ] Implement timeMetaOffsetPP
- [ ] Implement timeStartPP
- [ ] Implement soakStatusPP

## Phase 4 - Automatic QC
- [x] Add QC base classes and chain runner
- [x] Implement imosImpossibleDateQC
- [x] Implement imosImpossibleLocationSetQC
- [x] Implement imosInOutWaterQC
- [x] Implement imosGlobalRangeQC
- [x] Implement imosRegionalRangeQC
- [x] Implement imosImpossibleDepthQC
- [x] Implement imosSalinityFromPTQC
- [x] Implement imosRateOfChangeQC
- [x] Implement imosTimeSeriesSpikeQC
- [x] Implement imosVerticalSpikeQC
- [x] Implement imosDensityInversionSetQC
- [x] Implement imosStationarityQC
- [x] Implement CTDSurfaceSoakQC
- [x] Implement imosSurfaceDetectionByDepthSetQC
- [ ] Implement imosSideLobeVelocitySetQC (ADCP-specific, lower priority)
- [ ] Implement imosTiltVelocitySetQC (ADCP-specific, lower priority)
- [ ] Implement imosHorizontalVelocitySetQC (ADCP-specific, lower priority)
- [ ] Implement imosVerticalVelocityQC (ADCP-specific, lower priority)
- [ ] Implement imosCorrMagVelocitySetQC (ADCP-specific, lower priority)
- [ ] Implement imosEchoIntensitySetQC (ADCP-specific, lower priority)
- [ ] Implement imosEchoIntensityVelocitySetQC (ADCP-specific, lower priority)
- [ ] Implement imosEchoRangeSetQC (ADCP-specific, lower priority)
- [ ] Implement imosErrorVelocitySetQC (ADCP-specific, lower priority)
- [ ] Implement imosPercentGoodVelocitySetQC (ADCP-specific, lower priority)
- [ ] Implement imosTier2ProfileVelocitySetQC (ADCP-specific, lower priority)
- [ ] Implement teledyneSetQC (ADCP-specific, lower priority)
- [ ] Implement imosHistoricalManualSetQC (lower priority)
- [x] Port spike classifiers (Hampel implemented)
- [ ] Add `ioos_qc` adapter layer for overlapping automatic QC routines while preserving IMOS Set 1 flags and upgrade-only merge semantics
- [ ] Reuse overlapping `ioos_qc` automations where semantics align (`qartod.gross_range_test`, `qartod.rate_of_change_test`, `qartod.spike_test`, `qartod.flat_line_test`, `qartod.density_inversion_test`, `qartod.climatology_test`, `qartod.location_test`, `axds.valid_range_test`)
- [ ] Keep IMOS-native implementations for routines with no `ioos_qc` equivalent or materially different behaviour (`imosSalinityFromPTQC`, `CTDSurfaceSoakQC`, `imosSurfaceDetectionByDepthSetQC`, ADCP set QC)
- [ ] Use `IOOS_QC_IMOS_QC_OVERLAP.md` as the decision log for `ioos_qc` reuse vs IMOS-specific QC implementations

## Phase 5 - NetCDF/Parquet/Zarr export
- [x] Implement NetCDF template parser
- [ ] Implement makeNetCDFCompliant logic
- [x] Implement NetCDF export writer
- [ ] Implement Parquet export writer (parallel to NetCDF outputs)
- [ ] Capture and persist dataset/variable metadata in Parquet outputs
- [ ] Implement Zarr export target for suitable multidimensional data types
- [ ] Capture and persist dataset/variable metadata in Zarr outputs
- [ ] Implement finaliseData equivalent
- [ ] Port global_attributes_timeSeries template
- [ ] Port global_attributes_profile template
- [ ] Port time_attributes template
- [ ] Port depth_attributes template
- [ ] Port latitude_attributes template
- [ ] Port longitude_attributes template
- [ ] Port nominal_depth_attributes template
- [ ] Port instrument_index_attributes template
- [ ] Port instrument_attributes template
- [ ] Port variable_attributes template
- [ ] Port qc_attributes template
- [ ] Port traj_quality_control_attributes template
- [ ] Port dist_along_beams_attributes template
- [ ] Port dist_along_beams_qc_attributes template
- [ ] Port height_above_sensor_attributes template
- [ ] Port spct_attributes template
- [ ] Port sswv_attributes template
- [ ] Port sswv_qc_attributes template
- [ ] Port triaxys_attributes template
- [ ] Port triaxys_qc_attributes template
- [ ] Port platform-specific templates (Aurora, Rehua, Saxon_onward, default)
- [ ] Evaluate `ioos_qc.stores.PandasStore` and `ioos_qc.stores.CFNetCDFStore` for QC-result I/O, ancillary-variable wiring, and intermediate QC exports where they do not conflict with IMOS NetCDF requirements

## Phase 6 - Pipeline and CLI
- [x] Implement import manager
- [x] Implement preprocess manager wiring
- [x] Implement auto QC manager wiring
- [x] Implement export manager wiring
- [x] Add CLI commands for batch processing
- [ ] Wire parser selection by instrument metadata
- [ ] Wire DDB metadata lookup and caching
- [ ] Implement batch entrypoint equivalent to autoIMOSToolbox
- [ ] Implement interactive workflow hooks for UI callbacks
- [ ] Add CLI options for QC/PP chain overrides
- [ ] Add CLI options for DDB connection settings
- [ ] Add CLI options for template and export settings
- [ ] Add CLI options to select export targets (NetCDF, Parquet, Zarr where applicable)
- [ ] Implement JSON deployment input file parser (SFR §2)
- [ ] Implement JSON schema validation for input file packages (SFR §4.1)
- [ ] Implement input file package ingestion (zip → parse → validate) (SFR §5.1)
- [ ] Implement save/resume processing state (SFR §8)
- [ ] Implement reprocessing from archived inputs (SFR §7)
- [x] Add CLI options for log/diagnostic output
- [ ] Add `IMOSDataset` / xarray adapters over `ioos_qc.streams.XarrayStream` and `ioos_qc.streams.NetcdfStream` for automated QC input handling where stream semantics overlap
- [ ] Add `ioos_qc.config.Config`-driven QC pipeline entrypoints for overlap cases so shared thresholds/configuration can be reused instead of duplicated

## Phase 7 - Dash web UI
- [x] Scaffold Dash app and layout
- [x] Implement data exploration views
- [x] Implement QC interaction views (spike selection, manual flagging)
- [x] Implement export flow
- [x] Add plot exports
- [x] Implement start page (mode, data dir, field trip, DDB)
- [x] Implement dataset preview page
- [x] Implement metadata editor page
- [x] Implement QC summary/stats page
- [x] Implement spike selection page
- [x] Implement manual flagging page
- [x] Implement graph export page
- [x] Implement log/diagnostics page
- [x] Wire Start page to real parser/file loading into in-memory dataset state
- [x] Drive preview table/plots from parsed dataset state
- [x] Drive spike/manual QC actions from in-memory dataset state

## Phase 8 - Tests and validation
- [ ] Add pytest scaffolding and fixtures
- [x] Add parser format test matrix
- [x] Add UI state mutation tests (spike/manual/manual file parsing)
- [x] Add UI callback wiring regression check for manual flag path
- [ ] Port representative parser tests
- [ ] Port preprocessing/QC tests
- [ ] Add NetCDF regression tests
- [ ] Add Parquet regression tests (including metadata round-trip checks)
- [ ] Add Zarr regression tests for eligible multidimensional datasets (including metadata round-trip checks)
- [ ] Add CI checks (lint, typecheck, tests)
- [ ] Add parity tests for `ioos_qc`-backed QC adapters to confirm IMOS flag mapping and upgrade-only merge behaviour on overlapping checks

## Phase 9 - Documentation and release
- [ ] Add user and developer docs
- [ ] Add migration notes from MATLAB
- [ ] Add migration notes describing `ioos_qc` reuse boundaries, QARTOD-to-IMOS flag mapping, and the IMOS-only QC paths that remain custom
- [ ] Publish first alpha release to PyPI
- [ ] Publish JSON deployment input file schema for Facility operators (SFR §8)
- [ ] Document known differences from MATLAB outputs (SFR §1)

## Phase 10 - Regression testing against MATLAB
**Note**: See `MCR_REGRESSION_PLAN.md` for detailed MCR-based testing strategy (recommended approach - no MATLAB license required).

- [ ] **Test infrastructure setup**
  - [ ] Install MCR v95 (MATLAB Runtime R2018b) in CI environment
  - [ ] Create MCR wrapper module (`python/tests/regression/mcr_wrapper.py`)
  - [ ] Create MCR baseline generator (`python/tests/regression/generate_mcr_baselines.py`)
  - [ ] Add Docker container for MCR-based testing (`docker/regression-mcr.Dockerfile`)
  - [ ] Add GitHub Actions workflow for MCR regression tests (`.github/workflows/regression-mcr.yml`)
  - [ ] Create `python/tests/regression/` directory structure
  - [ ] Add Python regression test runner (`python/tests/regression/run_regression_suite.py`)
  - [ ] Define comparison tolerance thresholds (numeric: 1e-6 relative, flags: exact match)
  - [ ] Create test data repository or download script for representative instrument files
- [ ] **Parser regression tests**
  - [ ] SBE19 parser: compare parsed variables, dimensions, metadata
  - [ ] SBE26 parser: compare parsed variables, dimensions, metadata
  - [ ] SBE37/SBE37SM parser: compare parsed variables, dimensions, metadata
  - [ ] SBE39 parser: compare parsed variables, dimensions, metadata
  - [ ] SBE56 parser: compare parsed variables, dimensions, metadata
  - [ ] WQM parser: compare parsed variables, dimensions, metadata
  - [ ] WetStar/ECO parsers: compare parsed variables, dimensions, metadata
  - [ ] XR/DR1050 parsers: compare parsed variables, dimensions, metadata
  - [ ] Vemco parser: compare parsed variables, dimensions, metadata
  - [ ] NIWA parser: compare parsed variables, dimensions, metadata
  - [ ] Starmon parsers: compare parsed variables, dimensions, metadata
  - [ ] Aquatec parser: compare parsed variables, dimensions, metadata
  - [ ] RCM parser: compare parsed variables, dimensions, metadata
  - [ ] YSI 6-Series parser: compare parsed variables, dimensions, metadata
  - [ ] Sensus Ultra parser: compare parsed variables, dimensions, metadata
  - [ ] ADCP parsers (Workhorse, AWAC, Aquadopp, Signature): compare when implemented
- [ ] **Preprocessing regression tests**
  - [ ] pressureRelPP: compare PRES_REL output values
  - [ ] depthPP: compare DEPTH output values (gsw Python vs MATLAB)
  - [ ] salinityPP: compare PSAL output values (gsw Python vs MATLAB)
  - [ ] oxygenPP: compare OXSOL_SURFACE, DOX1, DOX2, DOXS output values
  - [ ] velocityMagDirPP: compare CSPD/CDIR output values
  - [ ] timeOffsetPP: compare adjusted TIME values
  - [ ] timeDriftPP: compare drift-corrected TIME values
  - [ ] variableOffsetPP: compare offset-adjusted variable values
  - [ ] Full preprocessing chain: compare end-to-end timeSeries and profile outputs
- [ ] **Automatic QC regression tests**
  - [ ] imosImpossibleDateQC: compare QC flags
  - [ ] imosImpossibleLocationSetQC: compare QC flags
  - [ ] imosInOutWaterQC: compare QC flags
  - [ ] imosGlobalRangeQC: compare QC flags
  - [ ] imosRegionalRangeQC: compare QC flags
  - [ ] imosImpossibleDepthQC: compare QC flags
  - [ ] imosSalinityFromPTQC: compare QC flags
  - [ ] imosRateOfChangeQC: compare QC flags
  - [ ] imosTimeSeriesSpikeQC: compare QC flags (Hampel filter)
  - [ ] imosVerticalSpikeQC: compare QC flags (ARGO spike test)
  - [ ] imosDensityInversionSetQC: compare QC flags
  - [ ] imosStationarityQC: compare QC flags
  - [ ] CTDSurfaceSoakQC: compare QC flags
  - [ ] imosSurfaceDetectionByDepthSetQC: compare QC flags
  - [ ] Full QC chain: compare end-to-end timeSeries and profile QC flag arrays
- [ ] **NetCDF export regression tests**
  - [ ] Template parsing: compare attribute resolution for timeSeries/profile templates
  - [ ] NetCDF structure: compare dimensions, variables, global attributes
  - [ ] NetCDF data values: compare variable data arrays (numeric tolerance)
  - [ ] NetCDF QC flags: compare QC flag arrays (exact match)
  - [ ] NetCDF metadata: compare variable attributes (units, long_name, etc.)
  - [ ] Full export: compare byte-level NetCDF outputs (ncdump -h and -v)
- [ ] **End-to-end pipeline regression tests**
  - [ ] timeSeries workflow: raw file → MATLAB NetCDF vs Python NetCDF
  - [ ] profile workflow: raw file → MATLAB NetCDF vs Python NetCDF
  - [ ] Compare processing logs and diagnostic outputs
  - [ ] Compare performance metrics (processing time, memory usage)
- [ ] **Regression test automation**
  - [ ] Add CI job to run regression suite on representative test files
  - [ ] Create regression test report generator (HTML/Markdown summary)
  - [ ] Add regression test status badge to README
  - [ ] Document regression test execution in developer guide
  - [ ] Create script to update regression baselines when MATLAB code changes
- [ ] **Known differences documentation**
  - [ ] Document intentional differences (e.g., Python gsw API vs MATLAB)
  - [ ] Document acceptable numeric precision differences
  - [ ] Document any behavioral improvements in Python port
  - [ ] Create migration guide for users transitioning from MATLAB

## Phase 11 - SFR Integration Requirements
*Items derived from the IMOS Toolbox Software Functional Requirements document.*

### Input File Package Handling
- [ ] Define and publish JSON deployment metadata schema (SFR §2, §8)
- [ ] Build input file package validator (file count, extensions, naming conventions) (SFR §4.1)
- [ ] CSV schema checker for ancillary data (SFR §4.1 — work in progress upstream)
- [ ] Support SBE19plus zip input packages (xmlcon + json + hex + XML) (SFR §4.3)
- [ ] Support NRS multi-instrument zip packages (SBE56 + SBE39 + SBE37 + Signature) (SFR §4.3)

### Data Lineage & Provenance
- [ ] Archive all input files alongside NetCDF outputs (SFR §5.1)
- [ ] Generate processing manifest (inputs, versions, parameters, timestamps) (SFR §1)
- [ ] Implement automatic versioning (hash-based or semantic) for outputs (SFR Appendix Table 1)
- [ ] Record full processing chain: raw → processed → QC'd with version refs (SFR Appendix Table 1)

### Reprocessing & Reproducibility
- [ ] Support reprocessing from versioned Processing Input Files (SFR §1)
- [ ] Apply existing QC flags on reprocessing (e.g. compass error → reprocess, keep expert flags) (SFR UC13)
- [ ] Support dropping timeseries: process ADCP now, CTD later, merge (SFR UC8)
- [ ] Handle metadata divergence on reprocessing (station rename scenarios) (SFR UC11)

### User Cases Validation
- [ ] UC1: Single CTD cast processing
- [ ] UC2: Forgotten aqualogger from prior mooring
- [ ] UC3: Updated calibration file → reprocess CTDs
- [ ] UC4: ADCP with new magnetic declination
- [ ] UC5: Entire CTD cast trip (batch + transect visualisation)
- [ ] UC6: Full NRS mooring package (CTD + ADCP + loggers)
- [ ] UC7: Single mooring instrument (e.g. ADCP)
- [ ] UC8: Dropping timeseries (ADCP now, CTD later)
- [ ] UC9: Reprocess with time history
- [ ] UC10: Multi-operator, multi-instrument mooring
- [ ] UC12: QC changes start/end dates
- [ ] UC13: Compass error reprocess keeping expert QC
- [ ] UC14: NRS mooring vs CTD profile comparison

### Output & Archival
- [ ] Generate static plots per instrument (depth comparison, T-S diagrams) (SFR §5.1)
- [ ] Output one NetCDF per instrument deployed (FV00/FV01) (SFR §5.1)
- [ ] Support AODN file naming conventions and validation (SFR §4.1)
- [ ] Implement calibration plugin architecture (SFR Appendix Table 1)

### Suggested Architecture Alignment (SFR Supplementary Text 1)
- [x] `imos_toolbox.parsers` ↔ imos.io (Parsers for raw files)
- [x] `imos_toolbox.preprocessing` ↔ imos.processing (unit conversion, TEOS-10, transforms)
- [x] `imos_toolbox.autoqc` ↔ imos.qc (Automatic QC checks)
- [x] `imos_toolbox.export` ↔ imos.export (NetCDF outputs)
- [x] `imos_toolbox.model` ↔ imos.models (Schemas for metadata, variables, QC flags)
- [x] `imos_toolbox.cli` ↔ imos.cli (Unified CLI)
- [ ] `imos_toolbox.visualisation` ↔ imos.visualisation (pre-submission visual check)

## Bookend update (2026-02-17)
- [x] Verified local Dash UI launch with optional `ui` dependencies.
- [x] Verified parser-to-UI dataset load path with a Vemco sample file.
- [x] Verified end-to-end manual flagging state mutation path (`dataset-store` updates QC flags).
- [x] Added regression coverage for manual-flag callback wiring.
- [ ] Next session: wire export flow from in-memory QC state to file outputs.

## Bookend update (2026-03-02)
- [x] Phase 4 foundation: added QC base classes (`QCFlags`, `QCResult`, `QCVariableRoutine`, `QCSetRoutine`) and chain runner with flag-upgrade-only semantics.
- [x] Implemented 6 automatic QC routines: `ImpossibleDateQC`, `ImpossibleLocationSetQC`, `InOutWaterQC`, `GlobalRangeQC`, `RegionalRangeQC`, `ImpossibleDepthQC`.
- [x] Created 41 unit tests with synthetic oceanographic data (SBE37 at NRSMAI, GBR temperature logger at GBRHIS).
- [x] All quality gates passing: 85 tests green, ruff clean, mypy clean.

## Bookend update (2026-03-03)
- [x] Ported the preprocessing pipeline (Phase 3) — default timeSeries and profile chains fully operational.
- [x] Added `preprocessing/` subpackage with `PPRoutine` / `PPResult` base class and `run_pp_chain` runner (mirrors autoqc architecture).
- [x] Implemented 9 preprocessing routines: `pressureRelPP`, `depthPP`, `salinityPP`, `oxygenPP`, `velocityMagDirPP`, `timeOffsetPP`, `timeDriftPP`, `variableOffsetPP`.
- [x] Fixed gsw Python API difference (`gsw.SP_from_C` instead of MATLAB `gsw.SP_from_R(R, T, P)`).
- [x] Wired `preprocess` CLI command for default timeSeries/profile chains on existing NetCDF files.
- [x] Added 31 unit tests (all passing, including full chain integration test).
- [x] All quality gates passing: 146 tests green, ruff clean, mypy clean.
- [x] **Phase 3 core preprocessing complete** (ADCP-specific and minor routines remain).
- [x] Implemented `RateOfChangeQC` routine to detect rapid changes in parameter values using gradient thresholds.
- [x] Implemented `TimeSeriesSpikeQC` routine using Hampel filter for spike detection in time series.
- [x] Implemented `VerticalSpikeQC` routine using ARGO spike test for vertical profiles.
- [x] Implemented `DensityInversionSetQC` routine to detect density inversions in profiles.
- [x] Implemented `StationarityQC` routine to flag flatline (constant value) regions.
- [x] Implemented `CTDSurfaceSoakQC` routine to flag CTD data during surface soak period.
- [x] Implemented `SurfaceDetectionByDepthSetQC` routine to flag ADCP bins above water surface.
- [x] Created spike classifier infrastructure with Hampel filter implementation.
- [x] Added 30 comprehensive unit tests across all new routines.
- [x] All quality gates passing: 115 tests green, ruff clean, mypy clean.
- [x] **14 out of 28 QC routines complete (50% of Phase 4)**
- [x] Core QC routines complete; remaining are ADCP-specific (lower priority for general use)

## Bookend update (2026-03-04) – session 1
- [x] **Phase 5 NetCDF export foundation complete** — template parser and basic writer operational.
- [x] Implemented `parse_template` to process IMOS NetCDF attribute templates with [mat ...] token evaluation.
- [x] Implemented `export_netcdf` writer with NetCDF4 compression, dimension/variable creation, and QC flag handling.
- [x] Added `get_parameter_info` helper to conventions module for parameter metadata lookup.
- [x] Wired `export` CLI command for timeSeries/profile modes.
- [x] Created 2 unit tests for basic and multi-variable export scenarios.
- [x] All quality gates passing: 148 tests green, ruff clean, mypy clean.
- [x] **Core export pipeline now functional** — can parse → preprocess → QC → export to NetCDF.

## Bookend update (2026-03-04) – session 2
- [x] **Phase 6 pipeline integration complete** — end-to-end batch processing operational.
- [x] Implemented `run_pipeline` orchestrator that chains parse → preprocess → QC → export.
- [x] Added `process` CLI command for one-step batch processing with configurable chains.
- [x] Created default preprocessing and QC chains for timeSeries/profile modes.
- [x] Added 3 pipeline integration tests (end-to-end, skip-pp, skip-qc).
- [x] All quality gates passing: 151 tests green, ruff clean, mypy clean.
- [x] **Complete end-to-end workflow now functional** — users can process raw files to IMOS NetCDF in one command.

## Bookend update (2026-04-27)
- [x] Captured the inferred deployment database schema from `docs/SCHEMA.md` in a canonical `imos_toolbox.ddb.schema` module.
- [x] Added one-source-of-truth schema derivations for SQLAlchemy/Alembic-compatible `MetaData`, JSON serialization, database-agnostic DDL, and JSON Schema validation.
- [x] Added `imos_toolbox.ddb` public exports plus coverage for metadata structure, serialization, DDL rendering, and row/database payload validation.
- [x] Added `SQLAlchemy` and `jsonschema` dependencies and updated `docs/SCHEMA.md` to point to the runtime schema module.
- [x] Verified the new schema tests and full pytest suite (`156` passing) after the schema integration.
- [ ] Next session: wire `[ddb ...]` template token resolution and DDB access flows against the canonical schema model.
- [ ] Repository-wide `ruff` and `mypy` are still blocked by pre-existing `src/imos_toolbox/cli.py` issues unrelated to this schema checkpoint.
