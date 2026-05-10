# Regression Testing Plan: Python Port vs MATLAB

This document outlines the strategy for regression testing the Python port of IMOS Toolbox against the original MATLAB implementation.

## Objectives

1. **Verify functional equivalence** between Python and MATLAB implementations
2. **Identify and document acceptable differences** (e.g., numeric precision, API differences)
3. **Establish automated regression suite** for continuous validation
4. **Build confidence** in Python port for production use

## Test Architecture

### Directory Structure

```
python/tests/regression/
├── __init__.py
├── run_regression_suite.py          # Main test runner
├── compare_outputs.py                # Comparison utilities
├── test_parser_regression.py         # Parser comparison tests
├── test_preprocessing_regression.py  # Preprocessing comparison tests
├── test_qc_regression.py             # QC comparison tests
├── test_export_regression.py         # Export comparison tests
├── test_pipeline_regression.py       # End-to-end comparison tests
├── fixtures/                         # Test data and expected outputs
│   ├── raw_data/                     # Raw instrument files
│   ├── matlab_outputs/               # MATLAB-generated NetCDF files
│   └── python_outputs/               # Python-generated NetCDF files (gitignored)
└── reports/                          # Test reports (gitignored)

matlab/
├── run_regression_tests.m            # MATLAB test harness
├── generate_regression_baselines.m   # Generate baseline outputs
└── regression_test_config.m          # Test configuration
```

### Test Data Requirements

**Representative instrument files** covering:
- SBE family (SBE19, SBE26, SBE37, SBE37SM, SBE39, SBE56)
- WQM (Wetlabs)
- ECO sensors (WetStar, ECOTriplet, ECOBB9)
- XR/DR loggers (XR420, XR620, DR1050)
- Vemco temperature loggers
- NIWA sensors
- Star-Oddi loggers (Starmon Mini, Starmon DST)
- Aquatec Aqualoggers
- Aanderaa RCM
- YSI 6-Series
- ReefNet Sensus Ultra
- ADCP instruments (Workhorse, AWAC, Aquadopp, Signature) when implemented

**Data characteristics to cover**:
- Time series (mooring deployments)
- Vertical profiles (CTD casts)
- Various sampling rates (1 Hz, 10 Hz, burst mode)
- Missing data / NaN values
- Out-of-range values (for QC testing)
- Edge cases (single sample, very long deployments)

## Comparison Strategy

### 1. Parser Regression Tests

**Goal**: Verify that Python parsers extract identical data from raw files.

**Comparison points**:
- Dimensions (TIME, DEPTH, etc.)
- Variable names and data types
- Variable data arrays (numeric tolerance: 1e-6 relative error)
- Metadata fields (instrument_make, instrument_model, etc.)
- Time values (exact match after conversion to common format)

**Test approach**:
```python
def test_sbe37_parser_regression(raw_file):
    # Run MATLAB parser (via subprocess or pre-generated baseline)
    matlab_output = load_matlab_baseline(raw_file)
    
    # Run Python parser
    python_output = parse_sbe37(raw_file)
    
    # Compare dimensions
    assert_dimensions_match(matlab_output, python_output)
    
    # Compare variables
    for var_name in matlab_output.variables:
        assert_variable_data_close(
            matlab_output[var_name],
            python_output[var_name],
            rtol=1e-6
        )
    
    # Compare metadata
    assert_metadata_match(matlab_output, python_output)
```

### 2. Preprocessing Regression Tests

**Goal**: Verify that preprocessing routines produce identical derived variables.

**Comparison points**:
- PRES_REL values (pressureRelPP)
- DEPTH values (depthPP) - note: gsw Python vs MATLAB may have minor differences
- PSAL values (salinityPP) - note: gsw API differences
- Oxygen variables (oxygenPP)
- CSPD/CDIR values (velocityMagDirPP)
- Time adjustments (timeOffsetPP, timeDriftPP)
- Variable offsets (variableOffsetPP)

**Known differences to document**:
- `gsw.SP_from_C` (Python) vs `gsw.SP_from_R` (MATLAB) - different input parameters
- Numeric precision differences in gsw library implementations

**Test approach**:
```python
def test_depth_pp_regression(parsed_dataset):
    # Run MATLAB preprocessing
    matlab_result = run_matlab_preprocessing(parsed_dataset, 'depthPP')
    
    # Run Python preprocessing
    python_result = run_python_preprocessing(parsed_dataset, 'depthPP')
    
    # Compare DEPTH variable
    assert_arrays_close(
        matlab_result['DEPTH'],
        python_result['DEPTH'],
        rtol=1e-5,  # Slightly relaxed for gsw differences
        atol=0.01   # 1 cm absolute tolerance
    )
```

### 3. Automatic QC Regression Tests

**Goal**: Verify that QC routines flag identical data points.

**Comparison points**:
- QC flag arrays (exact match expected)
- QC test names and parameters
- Flag upgrade logic (never downgrade flags)

**Test approach**:
```python
def test_global_range_qc_regression(dataset):
    # Run MATLAB QC
    matlab_flags = run_matlab_qc(dataset, 'imosGlobalRangeQC')
    
    # Run Python QC
    python_flags = run_python_qc(dataset, 'GlobalRangeQC')
    
    # Compare flags (exact match)
    for var_name in matlab_flags:
        assert_flags_exact_match(
            matlab_flags[var_name],
            python_flags[var_name]
        )
```

**Special cases**:
- Spike detection (Hampel filter) - may have minor differences due to implementation details
- Density inversion - may have minor differences due to gsw precision

### 4. NetCDF Export Regression Tests

**Goal**: Verify that exported NetCDF files are structurally and semantically identical.

**Comparison points**:
- Global attributes (exact match for strings, tolerance for numeric)
- Dimensions (exact match)
- Variables (names, types, shapes)
- Variable attributes (units, long_name, valid_min/max, etc.)
- Variable data (numeric tolerance)
- QC flag variables (exact match)
- Compression settings (optional - may differ)

**Test approach**:
```python
def test_netcdf_export_regression(processed_dataset):
    # Export with MATLAB
    matlab_nc = export_matlab_netcdf(processed_dataset)
    
    # Export with Python
    python_nc = export_python_netcdf(processed_dataset)
    
    # Compare structure
    assert_netcdf_structure_match(matlab_nc, python_nc)
    
    # Compare data
    assert_netcdf_data_close(matlab_nc, python_nc, rtol=1e-6)
    
    # Compare attributes
    assert_netcdf_attributes_match(matlab_nc, python_nc)
```

### 5. End-to-End Pipeline Regression Tests

**Goal**: Verify that complete processing workflows produce equivalent outputs.

**Test approach**:
```python
def test_timeseries_pipeline_regression(raw_file):
    # Run MATLAB pipeline
    matlab_output = run_matlab_pipeline(
        raw_file,
        mode='timeSeries',
        pp_chain=['pressureRelPP', 'depthPP', 'salinityPP'],
        qc_chain=['imosGlobalRangeQC', 'imosTimeSeriesSpikeQC']
    )
    
    # Run Python pipeline
    python_output = run_python_pipeline(
        raw_file,
        mode='timeSeries',
        pp_chain=['pressureRelPP', 'depthPP', 'salinityPP'],
        qc_chain=['GlobalRangeQC', 'TimeSeriesSpikeQC']
    )
    
    # Compare final NetCDF outputs
    assert_netcdf_equivalent(matlab_output, python_output, rtol=1e-5)
```

## Comparison Utilities

### Numeric Comparison

```python
def assert_arrays_close(matlab_array, python_array, rtol=1e-6, atol=1e-8):
    """Compare numeric arrays with relative and absolute tolerance."""
    # Handle NaN values
    matlab_valid = ~np.isnan(matlab_array)
    python_valid = ~np.isnan(python_array)
    
    # Check NaN positions match
    assert np.array_equal(matlab_valid, python_valid), "NaN positions differ"
    
    # Compare valid values
    np.testing.assert_allclose(
        matlab_array[matlab_valid],
        python_array[python_valid],
        rtol=rtol,
        atol=atol
    )
```

### Flag Comparison

```python
def assert_flags_exact_match(matlab_flags, python_flags):
    """Compare QC flag arrays (exact match required)."""
    assert matlab_flags.shape == python_flags.shape, "Flag array shapes differ"
    assert np.array_equal(matlab_flags, python_flags), "QC flags differ"
```

### NetCDF Comparison

```python
def assert_netcdf_equivalent(matlab_nc_path, python_nc_path, rtol=1e-6):
    """Compare two NetCDF files for equivalence."""
    with nc.Dataset(matlab_nc_path) as matlab_ds, \
         nc.Dataset(python_nc_path) as python_ds:
        
        # Compare dimensions
        assert set(matlab_ds.dimensions.keys()) == set(python_ds.dimensions.keys())
        
        # Compare variables
        for var_name in matlab_ds.variables:
            assert var_name in python_ds.variables, f"Variable {var_name} missing"
            
            matlab_var = matlab_ds.variables[var_name]
            python_var = python_ds.variables[var_name]
            
            # Compare data
            if np.issubdtype(matlab_var.dtype, np.number):
                assert_arrays_close(matlab_var[:], python_var[:], rtol=rtol)
            else:
                assert np.array_equal(matlab_var[:], python_var[:])
```

## Test Execution Workflow

### 1. Generate MATLAB Baselines

```bash
# In MATLAB
cd matlab
run_regression_tests  # Generates baseline outputs in python/tests/regression/fixtures/matlab_outputs/
```

### 2. Run Python Regression Suite

```bash
cd python
uv run pytest tests/regression/ -v --regression-report=reports/regression_report.html
```

### 3. Review Differences

```bash
# View HTML report
open tests/regression/reports/regression_report.html

# Or view text summary
uv run python tests/regression/run_regression_suite.py --summary
```

## Tolerance Thresholds

| Comparison Type | Relative Tolerance | Absolute Tolerance | Notes |
|-----------------|-------------------|-------------------|-------|
| Parser numeric data | 1e-6 | 1e-8 | Should be near-exact |
| Preprocessing (general) | 1e-6 | 1e-8 | Most routines exact |
| Preprocessing (gsw) | 1e-5 | 0.01 | gsw library differences |
| QC flags | N/A | 0 (exact) | Flags must match exactly |
| NetCDF data | 1e-6 | 1e-8 | After full pipeline |
| Time values | N/A | 1e-6 days | ~0.1 second precision |

## Continuous Integration

### CI Pipeline

```yaml
# .github/workflows/regression.yml
name: Regression Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  regression:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.14'
      
      - name: Install dependencies
        run: |
          cd python
          pip install uv
          uv sync --extra dev
      
      - name: Download test data
        run: |
          cd python/tests/regression
          ./download_test_data.sh
      
      - name: Run regression tests
        run: |
          cd python
          uv run pytest tests/regression/ -v --regression-report=reports/regression_report.html
      
      - name: Upload regression report
        uses: actions/upload-artifact@v3
        with:
          name: regression-report
          path: python/tests/regression/reports/
```

## Known Differences Documentation

### Intentional Differences

1. **gsw library API**:
   - MATLAB: `gsw.SP_from_R(R, T, P)` (conductivity ratio)
   - Python: `gsw.SP_from_C(C, T, P)` (conductivity in mS/cm)
   - Impact: Minor numeric differences in PSAL (< 0.001 PSU)

2. **Numeric precision**:
   - MATLAB uses double precision throughout
   - Python may use float32 for memory efficiency in large datasets
   - Impact: Differences at 1e-6 level acceptable

3. **Time representation**:
   - MATLAB: datenum (days since 0000-01-01)
   - Python: numpy.datetime64 or float64 (days since 1950-01-01)
   - Impact: Conversion required for comparison

### Acceptable Differences

1. **Spike detection**: Hampel filter implementation may differ slightly at boundaries
2. **Density calculations**: gsw library version differences
3. **NetCDF compression**: Different compression levels acceptable (data identical)
4. **Attribute ordering**: NetCDF attribute order may differ (semantically equivalent)

## Reporting

### Regression Report Format

```
IMOS Toolbox Regression Test Report
====================================
Date: 2026-03-04
Python version: 3.14.0
MATLAB version: R2018b

Summary:
--------
Total tests: 127
Passed: 124
Failed: 3
Warnings: 5

Parser Tests: 15/15 passed
Preprocessing Tests: 8/9 passed (1 warning)
QC Tests: 14/14 passed
Export Tests: 2/2 passed
Pipeline Tests: 2/2 passed

Failures:
---------
1. test_salinity_pp_regression: PSAL difference exceeds tolerance
   - Max relative error: 2.3e-5 (threshold: 1e-5)
   - Likely cause: gsw library version difference
   - Action: Review tolerance or update baseline

Warnings:
---------
1. test_spike_qc_regression: 3 flags differ at time series boundaries
   - Likely cause: Hampel filter boundary handling
   - Impact: Minimal (< 0.1% of data points)
```

## Maintenance

### Updating Baselines

When MATLAB code is updated:

```bash
# Regenerate MATLAB baselines
cd matlab
run_regression_tests

# Verify Python tests still pass
cd ../python
uv run pytest tests/regression/ -v

# If intentional changes, update documentation
vim tests/regression/KNOWN_DIFFERENCES.md
```

### Adding New Tests

1. Add representative raw data file to `fixtures/raw_data/`
2. Generate MATLAB baseline: `matlab -batch "generate_baseline('new_file.dat')"`
3. Add Python test case to appropriate test file
4. Run and verify: `uv run pytest tests/regression/test_new_case.py -v`
5. Update this document with any new known differences

## Success Criteria

The Python port is considered regression-validated when:

1. ✅ All parser tests pass with < 1e-6 relative error
2. ✅ All preprocessing tests pass with documented tolerances
3. ✅ All QC tests produce identical flags (or documented exceptions)
4. ✅ All export tests produce structurally equivalent NetCDF files
5. ✅ End-to-end pipeline tests produce equivalent outputs
6. ✅ Known differences are documented and justified
7. ✅ Regression suite runs in CI on every commit
8. ✅ Regression report is automatically generated and archived

## Timeline

- **Week 1-2**: Set up test infrastructure and MATLAB harness
- **Week 3-4**: Implement parser regression tests (15 parsers)
- **Week 5**: Implement preprocessing regression tests (8 routines)
- **Week 6**: Implement QC regression tests (14 routines)
- **Week 7**: Implement export and pipeline regression tests
- **Week 8**: CI integration and documentation
- **Week 9-10**: Review, refinement, and baseline updates

## References

- IMOS Toolbox MATLAB source: `/home/tisham/dev/imos-toolbox/`
- Python port source: `/home/tisham/dev/imos-toolbox/python/src/`
- Test data repository: TBD (IMOS data portal or internal repository)
- gsw-python documentation: https://teos-10.github.io/GSW-Python/
- NetCDF comparison tools: `ncdump`, `nccmp`, `xarray`
