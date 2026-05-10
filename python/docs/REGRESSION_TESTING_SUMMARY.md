# Regression Testing Plan Summary

## Overview

A comprehensive regression testing plan has been created to validate the Python port of IMOS Toolbox against the original MATLAB implementation. This ensures functional equivalence and builds confidence for production use.

## What Was Added

### 1. Phase 10 in ROADMAP.md

Added a new phase covering:
- **Test infrastructure setup** (5 tasks)
- **Parser regression tests** (16 parsers)
- **Preprocessing regression tests** (9 tasks)
- **Automatic QC regression tests** (15 tasks)
- **NetCDF export regression tests** (6 tasks)
- **End-to-end pipeline regression tests** (4 tasks)
- **Regression test automation** (5 tasks)
- **Known differences documentation** (4 tasks)

**Total: 64 regression testing tasks**

### 2. REGRESSION_TESTING_PLAN.md

Created a detailed 15KB plan document covering:

#### Test Architecture
- Directory structure for regression tests
- Test data requirements (representative instrument files)
- Comparison strategy for each component

#### Comparison Strategy
1. **Parser tests**: Compare parsed variables, dimensions, metadata
2. **Preprocessing tests**: Compare derived variables (DEPTH, PSAL, etc.)
3. **QC tests**: Compare QC flag arrays (exact match)
4. **Export tests**: Compare NetCDF structure and data
5. **Pipeline tests**: End-to-end workflow comparison

#### Tolerance Thresholds
| Component | Relative Tolerance | Absolute Tolerance |
|-----------|-------------------|-------------------|
| Parser data | 1e-6 | 1e-8 |
| Preprocessing (general) | 1e-6 | 1e-8 |
| Preprocessing (gsw) | 1e-5 | 0.01 |
| QC flags | N/A | 0 (exact) |
| NetCDF data | 1e-6 | 1e-8 |

#### Test Execution Workflow
1. Generate MATLAB baselines using test harness
2. Run Python regression suite with pytest
3. Review differences in HTML report
4. Document known differences

#### CI Integration
- GitHub Actions workflow for automated regression testing
- Regression report generation and archiving
- Test data download and caching

#### Known Differences
- gsw library API differences (MATLAB vs Python)
- Numeric precision differences (acceptable at 1e-6 level)
- Time representation differences (datenum vs datetime64)
- Spike detection boundary handling

## Key Features

### Automated Comparison Utilities
```python
# Numeric comparison with tolerance
assert_arrays_close(matlab_array, python_array, rtol=1e-6, atol=1e-8)

# Exact flag comparison
assert_flags_exact_match(matlab_flags, python_flags)

# NetCDF equivalence check
assert_netcdf_equivalent(matlab_nc, python_nc, rtol=1e-6)
```

### Comprehensive Test Coverage
- 15 parser implementations
- 8 preprocessing routines
- 14 QC routines
- NetCDF export pipeline
- End-to-end workflows (timeSeries + profile)

### Regression Reporting
- HTML report with pass/fail summary
- Detailed failure analysis with max errors
- Warnings for minor differences
- Maintenance instructions for updating baselines

## Success Criteria

The Python port is regression-validated when:
1. ✅ All parser tests pass with < 1e-6 relative error
2. ✅ All preprocessing tests pass with documented tolerances
3. ✅ All QC tests produce identical flags (or documented exceptions)
4. ✅ All export tests produce structurally equivalent NetCDF files
5. ✅ End-to-end pipeline tests produce equivalent outputs
6. ✅ Known differences are documented and justified
7. ✅ Regression suite runs in CI on every commit
8. ✅ Regression report is automatically generated

## Timeline

- **Week 1-2**: Test infrastructure and MATLAB harness
- **Week 3-4**: Parser regression tests (15 parsers)
- **Week 5**: Preprocessing regression tests (8 routines)
- **Week 6**: QC regression tests (14 routines)
- **Week 7**: Export and pipeline regression tests
- **Week 8**: CI integration and documentation
- **Week 9-10**: Review, refinement, baseline updates

**Total estimated effort: 10 weeks**

## Next Steps

1. **Create test infrastructure**:
   ```bash
   mkdir -p python/tests/regression/{fixtures/{raw_data,matlab_outputs},reports}
   ```

2. **Implement MATLAB test harness**:
   ```matlab
   % matlab/run_regression_tests.m
   % Generate baseline outputs for all test files
   ```

3. **Implement Python comparison utilities**:
   ```bash
   cd python/tests/regression
   touch compare_outputs.py
   ```

4. **Start with parser regression tests** (highest priority):
   - SBE family parsers (most common)
   - WQM parser
   - ECO parsers

5. **Set up CI workflow**:
   ```bash
   mkdir -p .github/workflows
   touch .github/workflows/regression.yml
   ```

## Files Modified/Created

1. ✅ `python/docs/ROADMAP.md` - Added Phase 10 (64 tasks)
2. ✅ `python/docs/REGRESSION_TESTING_PLAN.md` - Created detailed plan (15KB)
3. ✅ This summary document

## References

- Roadmap: `/home/tisham/dev/imos-toolbox/python/docs/ROADMAP.md`
- Detailed plan: `/home/tisham/dev/imos-toolbox/python/docs/REGRESSION_TESTING_PLAN.md`
- Python tests: `/home/tisham/dev/imos-toolbox/python/tests/`
- MATLAB tests: `/home/tisham/dev/imos-toolbox/test/`
