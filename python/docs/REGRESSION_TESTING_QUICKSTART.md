# Regression Testing Quick Start Guide

This guide provides step-by-step instructions to begin implementing regression tests for the Python port.

## Prerequisites

- MATLAB R2018b or newer installed and accessible
- Python 3.14 environment set up (see `python/README.md`)
- Access to representative instrument data files
- Both MATLAB and Python IMOS Toolbox codebases

## Step 1: Set Up Directory Structure

```bash
cd /home/tisham/dev/imos-toolbox

# Create Python regression test directories
mkdir -p python/tests/regression/{fixtures/{raw_data,matlab_outputs,python_outputs},reports}

# Create MATLAB regression test directory
mkdir -p matlab/regression

# Create gitignore for generated outputs
cat > python/tests/regression/.gitignore << 'EOF'
fixtures/python_outputs/
reports/
__pycache__/
*.pyc
EOF
```

## Step 2: Collect Test Data

Gather representative instrument files covering different scenarios:

```bash
cd python/tests/regression/fixtures/raw_data

# Example structure:
# sbe37/
#   ├── sbe37_timeseries_01.asc
#   ├── sbe37_timeseries_02.asc
#   └── sbe37_profile_01.cnv
# sbe19/
#   ├── sbe19_profile_01.cnv
#   └── sbe19_profile_02.cnv
# wqm/
#   ├── wqm_timeseries_01.dat
#   └── wqm_timeseries_02.raw
# ... etc
```

**Recommended test files** (minimum viable set):
- 1-2 files per implemented parser
- Mix of timeSeries and profile modes
- Include edge cases (single sample, missing data, out-of-range values)

## Step 3: Create MATLAB Test Harness

Create `matlab/regression/run_regression_tests.m`:

```matlab
function run_regression_tests()
    % MATLAB test harness to generate baseline outputs for regression testing
    
    % Configuration
    raw_data_dir = '../python/tests/regression/fixtures/raw_data';
    output_dir = '../python/tests/regression/fixtures/matlab_outputs';
    
    % Ensure output directory exists
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Add IMOS Toolbox to path
    addpath(genpath('..'));
    
    % Test SBE37 parser
    fprintf('Testing SBE37 parser...\n');
    test_parser('sbe37', 'SBE37Parse', 'timeSeries');
    
    % Test SBE19 parser
    fprintf('Testing SBE19 parser...\n');
    test_parser('sbe19', 'SBE19Parse', 'profile');
    
    % Test WQM parser
    fprintf('Testing WQM parser...\n');
    test_parser('wqm', 'WQMParse', 'timeSeries');
    
    % Add more parsers as needed...
    
    fprintf('Baseline generation complete!\n');
end

function test_parser(instrument_dir, parser_name, mode)
    raw_data_dir = '../python/tests/regression/fixtures/raw_data';
    output_dir = '../python/tests/regression/fixtures/matlab_outputs';
    
    % Find all files for this instrument
    files = dir(fullfile(raw_data_dir, instrument_dir, '*'));
    files = files(~[files.isdir]);
    
    for i = 1:length(files)
        file_path = fullfile(files(i).folder, files(i).name);
        fprintf('  Processing: %s\n', files(i).name);
        
        try
            % Parse file
            sample_data = feval(parser_name, file_path, mode);
            
            % Save as intermediate NetCDF (parsed only, no PP/QC)
            [~, base_name, ~] = fileparts(files(i).name);
            output_file = fullfile(output_dir, instrument_dir, ...
                sprintf('%s_parsed.nc', base_name));
            
            % Ensure output subdirectory exists
            output_subdir = fullfile(output_dir, instrument_dir);
            if ~exist(output_subdir, 'dir')
                mkdir(output_subdir);
            end
            
            % Export to NetCDF (simplified - just save raw parsed data)
            save_sample_data_to_netcdf(sample_data, output_file);
            
            fprintf('    ✓ Saved: %s\n', output_file);
        catch ME
            fprintf('    ✗ Error: %s\n', ME.message);
        end
    end
end

function save_sample_data_to_netcdf(sample_data, output_file)
    % Simplified NetCDF export for regression testing
    % (Use existing exportNetCDF or create minimal version)
    
    % Create NetCDF file
    ncid = netcdf.create(output_file, 'NETCDF4');
    
    % Add dimensions
    for i = 1:length(sample_data.dimensions)
        dim = sample_data.dimensions{i};
        netcdf.defDim(ncid, dim.name, length(dim.data));
    end
    
    % Add variables
    for i = 1:length(sample_data.variables)
        var = sample_data.variables{i};
        % Define variable (simplified - assumes 1D)
        varid = netcdf.defVar(ncid, var.name, 'double', 0);
        netcdf.endDef(ncid);
        netcdf.putVar(ncid, varid, var.data);
        netcdf.reDef(ncid);
    end
    
    netcdf.close(ncid);
end
```

## Step 4: Generate MATLAB Baselines

```bash
cd /home/tisham/dev/imos-toolbox/matlab/regression

# Run MATLAB test harness
matlab -batch "run_regression_tests"

# Verify outputs were created
ls -lh ../python/tests/regression/fixtures/matlab_outputs/
```

## Step 5: Create Python Comparison Utilities

Create `python/tests/regression/compare_outputs.py`:

```python
"""Utilities for comparing MATLAB and Python outputs."""

import numpy as np
import netCDF4 as nc
from typing import Dict, List, Tuple


def assert_arrays_close(
    matlab_array: np.ndarray,
    python_array: np.ndarray,
    rtol: float = 1e-6,
    atol: float = 1e-8,
    var_name: str = "variable"
) -> None:
    """Compare numeric arrays with tolerance."""
    # Check shapes match
    assert matlab_array.shape == python_array.shape, \
        f"{var_name}: shape mismatch {matlab_array.shape} vs {python_array.shape}"
    
    # Handle NaN values
    matlab_valid = ~np.isnan(matlab_array)
    python_valid = ~np.isnan(python_array)
    
    # Check NaN positions match
    assert np.array_equal(matlab_valid, python_valid), \
        f"{var_name}: NaN positions differ"
    
    # Compare valid values
    if np.any(matlab_valid):
        np.testing.assert_allclose(
            matlab_array[matlab_valid],
            python_array[python_valid],
            rtol=rtol,
            atol=atol,
            err_msg=f"{var_name}: values differ beyond tolerance"
        )


def compare_netcdf_files(
    matlab_nc_path: str,
    python_nc_path: str,
    rtol: float = 1e-6,
    atol: float = 1e-8
) -> Dict[str, List[str]]:
    """
    Compare two NetCDF files.
    
    Returns dict with 'passed', 'failed', 'warnings' lists.
    """
    results = {'passed': [], 'failed': [], 'warnings': []}
    
    with nc.Dataset(matlab_nc_path) as matlab_ds, \
         nc.Dataset(python_nc_path) as python_ds:
        
        # Compare dimensions
        matlab_dims = set(matlab_ds.dimensions.keys())
        python_dims = set(python_ds.dimensions.keys())
        
        if matlab_dims != python_dims:
            results['failed'].append(
                f"Dimension mismatch: {matlab_dims} vs {python_dims}"
            )
            return results
        
        results['passed'].append("Dimensions match")
        
        # Compare variables
        matlab_vars = set(matlab_ds.variables.keys())
        python_vars = set(python_ds.variables.keys())
        
        if matlab_vars != python_vars:
            missing = matlab_vars - python_vars
            extra = python_vars - matlab_vars
            if missing:
                results['failed'].append(f"Missing variables: {missing}")
            if extra:
                results['warnings'].append(f"Extra variables: {extra}")
        
        # Compare variable data
        for var_name in matlab_vars & python_vars:
            try:
                matlab_var = matlab_ds.variables[var_name][:]
                python_var = python_ds.variables[var_name][:]
                
                if np.issubdtype(matlab_var.dtype, np.number):
                    assert_arrays_close(
                        matlab_var, python_var,
                        rtol=rtol, atol=atol,
                        var_name=var_name
                    )
                else:
                    assert np.array_equal(matlab_var, python_var), \
                        f"{var_name}: non-numeric data differs"
                
                results['passed'].append(f"Variable {var_name} matches")
            
            except AssertionError as e:
                results['failed'].append(f"Variable {var_name}: {str(e)}")
    
    return results


def print_comparison_report(results: Dict[str, List[str]]) -> None:
    """Print formatted comparison report."""
    print("\n" + "="*60)
    print("REGRESSION TEST REPORT")
    print("="*60)
    
    print(f"\n✓ Passed: {len(results['passed'])}")
    for msg in results['passed']:
        print(f"  • {msg}")
    
    if results['warnings']:
        print(f"\n⚠ Warnings: {len(results['warnings'])}")
        for msg in results['warnings']:
            print(f"  • {msg}")
    
    if results['failed']:
        print(f"\n✗ Failed: {len(results['failed'])}")
        for msg in results['failed']:
            print(f"  • {msg}")
    
    print("\n" + "="*60)
    
    if results['failed']:
        raise AssertionError(f"{len(results['failed'])} comparison(s) failed")
```

## Step 6: Create First Parser Regression Test

Create `python/tests/regression/test_parser_regression.py`:

```python
"""Parser regression tests comparing Python vs MATLAB outputs."""

import pytest
from pathlib import Path
from imos_toolbox.parsers import get_parser
from .compare_outputs import compare_netcdf_files, print_comparison_report


FIXTURES_DIR = Path(__file__).parent / "fixtures"
RAW_DATA_DIR = FIXTURES_DIR / "raw_data"
MATLAB_OUTPUTS_DIR = FIXTURES_DIR / "matlab_outputs"
PYTHON_OUTPUTS_DIR = FIXTURES_DIR / "python_outputs"


@pytest.fixture(autouse=True)
def setup_output_dir():
    """Ensure Python output directory exists."""
    PYTHON_OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)


def test_sbe37_parser_regression():
    """Compare SBE37 parser output with MATLAB baseline."""
    # Find test file
    raw_file = RAW_DATA_DIR / "sbe37" / "sbe37_timeseries_01.asc"
    matlab_baseline = MATLAB_OUTPUTS_DIR / "sbe37" / "sbe37_timeseries_01_parsed.nc"
    
    if not raw_file.exists():
        pytest.skip(f"Test file not found: {raw_file}")
    if not matlab_baseline.exists():
        pytest.skip(f"MATLAB baseline not found: {matlab_baseline}")
    
    # Parse with Python
    parser = get_parser("sbe37")
    dataset = parser.parse(str(raw_file), mode="timeSeries")
    
    # Export to NetCDF
    python_output = PYTHON_OUTPUTS_DIR / "sbe37" / "sbe37_timeseries_01_parsed.nc"
    python_output.parent.mkdir(parents=True, exist_ok=True)
    dataset.to_netcdf(str(python_output))
    
    # Compare outputs
    results = compare_netcdf_files(
        str(matlab_baseline),
        str(python_output),
        rtol=1e-6,
        atol=1e-8
    )
    
    print_comparison_report(results)


# Add more parser tests following the same pattern...
```

## Step 7: Run First Regression Test

```bash
cd /home/tisham/dev/imos-toolbox/python

# Run single test
uv run pytest tests/regression/test_parser_regression.py::test_sbe37_parser_regression -v

# Run all regression tests
uv run pytest tests/regression/ -v
```

## Step 8: Iterate and Expand

1. **Add more parser tests** - Follow the pattern in Step 6
2. **Add preprocessing tests** - Compare outputs after PP chain
3. **Add QC tests** - Compare QC flag arrays
4. **Add export tests** - Compare final NetCDF outputs
5. **Add pipeline tests** - End-to-end comparison

## Common Issues and Solutions

### Issue: MATLAB baseline generation fails

**Solution**: Check MATLAB path includes IMOS Toolbox:
```matlab
addpath(genpath('/home/tisham/dev/imos-toolbox'));
savepath;
```

### Issue: Python parser not found

**Solution**: Ensure parser is registered:
```python
from imos_toolbox.parsers import list_parsers
print(list_parsers())
```

### Issue: NetCDF comparison fails with "dimension mismatch"

**Solution**: Check if MATLAB and Python use different dimension names. Update comparison to handle aliases.

### Issue: Numeric differences exceed tolerance

**Solution**: 
1. Check if gsw library versions differ
2. Verify input data is identical
3. Consider relaxing tolerance for known differences (document in KNOWN_DIFFERENCES.md)

## Next Steps

1. ✅ Complete Step 1-7 for first parser (SBE37)
2. ⬜ Expand to all implemented parsers (15 total)
3. ⬜ Add preprocessing regression tests
4. ⬜ Add QC regression tests
5. ⬜ Add export regression tests
6. ⬜ Set up CI automation
7. ⬜ Document known differences

## Resources

- Detailed plan: `python/docs/REGRESSION_TESTING_PLAN.md`
- Roadmap Phase 10: `python/docs/ROADMAP.md`
- MATLAB tests: `/home/tisham/dev/imos-toolbox/test/`
- Python tests: `/home/tisham/dev/imos-toolbox/python/tests/`

## Questions?

Refer to the detailed regression testing plan or consult the development team.
