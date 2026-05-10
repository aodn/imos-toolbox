# MCR-Based Regression Testing Plan

## Overview

This plan proposes using the MATLAB Compiler Runtime (MCR) to run the MATLAB IMOS Toolbox as part of the regression testing framework, eliminating the need for MATLAB licenses in CI/CD environments.

## Benefits of MCR Approach

1. **No MATLAB license required** - MCR is free to distribute
2. **CI/CD friendly** - Can run in Docker containers and GitHub Actions
3. **Reproducible** - Fixed MATLAB version (R2018b/MCR v95)
4. **Portable** - Same binaries work across test environments
5. **Cost effective** - No per-seat licensing for test infrastructure

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Regression Test Runner                      │
│                     (Python/pytest)                          │
└────────────┬────────────────────────────────────────────────┘
             │
             ├─────────────────┬──────────────────────────────┐
             │                 │                              │
             ▼                 ▼                              ▼
    ┌────────────────┐  ┌──────────────┐         ┌──────────────────┐
    │  Python Port   │  │ MCR Wrapper  │         │  Comparison      │
    │   (Native)     │  │  (Subprocess)│         │   Utilities      │
    └────────────────┘  └──────┬───────┘         └──────────────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ imosToolbox_Linux64  │
                    │   (MCR Binary)       │
                    │   + MCR v95          │
                    └──────────────────────┘
```

## Implementation Strategy

### Phase 1: MCR Wrapper Module

Create a Python wrapper to invoke the MCR-compiled IMOS Toolbox:

**File**: `python/tests/regression/mcr_wrapper.py`

```python
"""Wrapper for invoking MCR-compiled IMOS Toolbox."""

import subprocess
import json
from pathlib import Path
from typing import Dict, List, Optional


class MCRToolbox:
    """Interface to MCR-compiled IMOS Toolbox."""
    
    def __init__(self, mcr_root: str, toolbox_bin: str):
        """
        Initialize MCR wrapper.
        
        Args:
            mcr_root: Path to MCR installation (e.g., /usr/local/MATLAB/MATLAB_Runtime/v95)
            toolbox_bin: Path to imosToolbox binary (e.g., ./imosToolbox_Linux64.bin)
        """
        self.mcr_root = Path(mcr_root)
        self.toolbox_bin = Path(toolbox_bin)
        self.toolbox_sh = self.toolbox_bin.parent / "imosToolbox_Linux64.sh"
        
        if not self.mcr_root.exists():
            raise FileNotFoundError(f"MCR not found: {mcr_root}")
        if not self.toolbox_bin.exists():
            raise FileNotFoundError(f"Toolbox binary not found: {toolbox_bin}")
    
    def run_auto_batch(
        self,
        field_trip: str,
        data_dir: str,
        pp_chain: List[str],
        qc_chain: List[str],
        export_dir: str,
        timeout: int = 300
    ) -> subprocess.CompletedProcess:
        """
        Run toolbox in automatic batch mode.
        
        Args:
            field_trip: Field trip ID
            data_dir: Directory with raw data files
            pp_chain: List of preprocessing routines
            qc_chain: List of QC routines
            export_dir: Output directory for NetCDF files
            timeout: Timeout in seconds
        
        Returns:
            CompletedProcess with stdout/stderr
        """
        # Format chains as MATLAB cell arrays
        pp_str = self._format_cell_array(pp_chain)
        qc_str = self._format_cell_array(qc_chain)
        
        # Build command
        cmd = [
            str(self.toolbox_sh),
            str(self.mcr_root),
            "auto",
            field_trip,
            data_dir,
            pp_str,
            qc_str,
            export_dir
        ]
        
        # Execute
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=self.toolbox_bin.parent
        )
        
        if result.returncode != 0:
            raise RuntimeError(
                f"MCR toolbox failed: {result.stderr}\n{result.stdout}"
            )
        
        return result
    
    @staticmethod
    def _format_cell_array(items: List[str]) -> str:
        """Format Python list as MATLAB cell array string."""
        if not items:
            return "{}"
        quoted = [f"'{item}'" for item in items]
        return "{" + " ".join(quoted) + "}"
```

### Phase 2: MCR Installation in CI

**File**: `.github/workflows/regression-mcr.yml`

```yaml
name: Regression Tests (MCR)

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday at 2 AM

jobs:
  regression-mcr:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Cache MCR installation
        id: cache-mcr
        uses: actions/cache@v3
        with:
          path: /opt/mcr
          key: mcr-v95-${{ runner.os }}
      
      - name: Install MCR v95
        if: steps.cache-mcr.outputs.cache-hit != 'true'
        run: |
          # Download MCR installer
          wget -q https://ssd.mathworks.com/supportfiles/downloads/R2018b/Release/6/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2018b_Update_6_glnxa64.zip
          
          # Extract and install
          unzip -q MATLAB_Runtime_R2018b_Update_6_glnxa64.zip -d mcr_installer
          cd mcr_installer
          ./install -mode silent -agreeToLicense yes -destinationFolder /opt/mcr
          
          # Cleanup
          cd ..
          rm -rf mcr_installer MATLAB_Runtime_R2018b_Update_6_glnxa64.zip
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.14'
      
      - name: Install Python dependencies
        run: |
          cd python
          pip install uv
          uv sync --extra dev
      
      - name: Download test data
        run: |
          cd python/tests/regression
          ./download_test_data.sh
      
      - name: Run MCR regression tests
        env:
          MCR_ROOT: /opt/mcr/v95
          TOOLBOX_BIN: ${{ github.workspace }}/imosToolbox_Linux64.bin
        run: |
          cd python
          uv run pytest tests/regression/ -v -m mcr --regression-report=reports/mcr_regression.html
      
      - name: Upload regression report
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: mcr-regression-report
          path: python/tests/regression/reports/
```

### Phase 3: Docker Container for Local Testing

**File**: `docker/regression-mcr.Dockerfile`

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    libxt6 \
    libxmu6 \
    libxpm4 \
    libxrender1 \
    libxrandr2 \
    libxinerama1 \
    libxcursor1 \
    libxi6 \
    libgl1-mesa-glx \
    python3.14 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install MCR v95
RUN wget -q https://ssd.mathworks.com/supportfiles/downloads/R2018b/Release/6/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2018b_Update_6_glnxa64.zip \
    && unzip -q MATLAB_Runtime_R2018b_Update_6_glnxa64.zip -d /tmp/mcr_installer \
    && /tmp/mcr_installer/install -mode silent -agreeToLicense yes -destinationFolder /opt/mcr \
    && rm -rf /tmp/mcr_installer MATLAB_Runtime_R2018b_Update_6_glnxa64.zip

# Set MCR environment
ENV MCR_ROOT=/opt/mcr/v95
ENV LD_LIBRARY_PATH=${MCR_ROOT}/runtime/glnxa64:${MCR_ROOT}/bin/glnxa64:${MCR_ROOT}/sys/os/glnxa64

# Copy IMOS Toolbox
COPY imosToolbox_Linux64.bin /opt/imos-toolbox/
COPY imosToolbox_Linux64.sh /opt/imos-toolbox/
RUN chmod +x /opt/imos-toolbox/imosToolbox_Linux64.sh /opt/imos-toolbox/imosToolbox_Linux64.bin

# Install Python dependencies
WORKDIR /workspace
COPY python/pyproject.toml python/uv.lock ./python/
RUN pip install uv && cd python && uv sync --extra dev

# Set environment
ENV TOOLBOX_BIN=/opt/imos-toolbox/imosToolbox_Linux64.bin
ENV PYTHONPATH=/workspace/python/src

CMD ["/bin/bash"]
```

**Usage**:
```bash
# Build container
docker build -f docker/regression-mcr.Dockerfile -t imos-regression-mcr .

# Run regression tests
docker run --rm -v $(pwd):/workspace imos-regression-mcr \
    bash -c "cd python && uv run pytest tests/regression/ -v -m mcr"
```

### Phase 4: Regression Test Implementation

**File**: `python/tests/regression/test_mcr_parser_regression.py`

```python
"""Parser regression tests using MCR-compiled MATLAB toolbox."""

import pytest
from pathlib import Path
from .mcr_wrapper import MCRToolbox
from .compare_outputs import compare_netcdf_files, print_comparison_report


pytestmark = pytest.mark.mcr  # Mark all tests in this file


@pytest.fixture(scope="module")
def mcr_toolbox():
    """Initialize MCR toolbox wrapper."""
    import os
    mcr_root = os.environ.get("MCR_ROOT", "/opt/mcr/v95")
    toolbox_bin = os.environ.get("TOOLBOX_BIN", "../imosToolbox_Linux64.bin")
    return MCRToolbox(mcr_root, toolbox_bin)


def test_sbe37_mcr_regression(mcr_toolbox, tmp_path):
    """Compare SBE37 parser output: Python vs MCR-MATLAB."""
    # Setup paths
    raw_file = Path("fixtures/raw_data/sbe37/sbe37_timeseries_01.asc")
    matlab_output_dir = tmp_path / "matlab_output"
    python_output_dir = tmp_path / "python_output"
    matlab_output_dir.mkdir()
    python_output_dir.mkdir()
    
    # Run MCR-MATLAB toolbox
    mcr_toolbox.run_auto_batch(
        field_trip="regression_test",
        data_dir=str(raw_file.parent),
        pp_chain=[],  # No preprocessing for parser test
        qc_chain=[],  # No QC for parser test
        export_dir=str(matlab_output_dir)
    )
    
    # Run Python parser
    from imos_toolbox.parsers import get_parser
    parser = get_parser("sbe37")
    dataset = parser.parse(str(raw_file), mode="timeSeries")
    python_nc = python_output_dir / "sbe37_timeseries_01.nc"
    dataset.to_netcdf(str(python_nc))
    
    # Find MATLAB output
    matlab_nc = list(matlab_output_dir.glob("*.nc"))[0]
    
    # Compare
    results = compare_netcdf_files(str(matlab_nc), str(python_nc))
    print_comparison_report(results)
```

### Phase 5: Batch Processing Script

**File**: `python/tests/regression/generate_mcr_baselines.py`

```python
"""Generate MATLAB baselines using MCR-compiled toolbox."""

import argparse
from pathlib import Path
from mcr_wrapper import MCRToolbox


def generate_baselines(
    mcr_root: str,
    toolbox_bin: str,
    raw_data_dir: str,
    output_dir: str
):
    """Generate MATLAB baseline outputs for all test files."""
    mcr = MCRToolbox(mcr_root, toolbox_bin)
    raw_data = Path(raw_data_dir)
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)
    
    # Process each instrument directory
    for instrument_dir in raw_data.iterdir():
        if not instrument_dir.is_dir():
            continue
        
        print(f"Processing {instrument_dir.name}...")
        
        # Create output subdirectory
        instrument_output = output / instrument_dir.name
        instrument_output.mkdir(exist_ok=True)
        
        # Run MCR toolbox on all files in this directory
        try:
            mcr.run_auto_batch(
                field_trip=f"baseline_{instrument_dir.name}",
                data_dir=str(instrument_dir),
                pp_chain=[],  # Parser only
                qc_chain=[],
                export_dir=str(instrument_output)
            )
            print(f"  ✓ Generated baselines in {instrument_output}")
        except Exception as e:
            print(f"  ✗ Error: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mcr-root", default="/opt/mcr/v95")
    parser.add_argument("--toolbox-bin", default="../imosToolbox_Linux64.bin")
    parser.add_argument("--raw-data", default="fixtures/raw_data")
    parser.add_argument("--output", default="fixtures/matlab_outputs")
    args = parser.parse_args()
    
    generate_baselines(
        args.mcr_root,
        args.toolbox_bin,
        args.raw_data,
        args.output
    )
```

**Usage**:
```bash
cd python/tests/regression
python generate_mcr_baselines.py --mcr-root /opt/mcr/v95
```

## MCR Installation Guide

### Linux (Ubuntu/Debian)

```bash
# Download MCR installer
wget https://ssd.mathworks.com/supportfiles/downloads/R2018b/Release/6/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2018b_Update_6_glnxa64.zip

# Extract
unzip MATLAB_Runtime_R2018b_Update_6_glnxa64.zip -d mcr_installer

# Install (requires sudo)
cd mcr_installer
sudo ./install -mode silent -agreeToLicense yes -destinationFolder /opt/mcr

# Set environment variables (add to ~/.bashrc)
export MCR_ROOT=/opt/mcr/v95
export LD_LIBRARY_PATH=${MCR_ROOT}/runtime/glnxa64:${MCR_ROOT}/bin/glnxa64:${MCR_ROOT}/sys/os/glnxa64:${LD_LIBRARY_PATH}

# Verify installation
ls -la /opt/mcr/v95
```

### macOS

```bash
# Download MCR installer for macOS
wget https://ssd.mathworks.com/supportfiles/downloads/R2018b/Release/6/deployment_files/installer/complete/maci64/MATLAB_Runtime_R2018b_Update_6_maci64.dmg.zip

# Extract and mount
unzip MATLAB_Runtime_R2018b_Update_6_maci64.dmg.zip
hdiutil attach MATLAB_Runtime_R2018b_Update_6_maci64.dmg

# Install
sudo /Volumes/MATLAB_Runtime/InstallForMacOSX.app/Contents/MacOS/InstallForMacOSX -mode silent -agreeToLicense yes

# Set environment
export MCR_ROOT=/Applications/MATLAB/MATLAB_Runtime/v95
export DYLD_LIBRARY_PATH=${MCR_ROOT}/runtime/maci64:${MCR_ROOT}/bin/maci64:${MCR_ROOT}/sys/os/maci64:${DYLD_LIBRARY_PATH}
```

## Testing Strategy

### 1. Parser Tests (MCR)

```python
@pytest.mark.mcr
def test_parser_mcr(mcr_toolbox, parser_name, test_file):
    """Generic parser regression test using MCR."""
    # Run MCR toolbox (parser only, no PP/QC)
    matlab_output = run_mcr_parser(mcr_toolbox, test_file)
    
    # Run Python parser
    python_output = run_python_parser(parser_name, test_file)
    
    # Compare
    assert_netcdf_equivalent(matlab_output, python_output)
```

### 2. Preprocessing Tests (MCR)

```python
@pytest.mark.mcr
def test_preprocessing_mcr(mcr_toolbox, pp_chain, test_file):
    """Preprocessing regression test using MCR."""
    # Run MCR toolbox with PP chain
    matlab_output = mcr_toolbox.run_auto_batch(
        field_trip="pp_test",
        data_dir=test_file.parent,
        pp_chain=pp_chain,
        qc_chain=[],
        export_dir=output_dir
    )
    
    # Run Python preprocessing
    python_output = run_python_preprocessing(test_file, pp_chain)
    
    # Compare
    assert_netcdf_equivalent(matlab_output, python_output, rtol=1e-5)
```

### 3. QC Tests (MCR)

```python
@pytest.mark.mcr
def test_qc_mcr(mcr_toolbox, qc_chain, test_file):
    """QC regression test using MCR."""
    # Run MCR toolbox with QC chain
    matlab_output = mcr_toolbox.run_auto_batch(
        field_trip="qc_test",
        data_dir=test_file.parent,
        pp_chain=[],
        qc_chain=qc_chain,
        export_dir=output_dir
    )
    
    # Run Python QC
    python_output = run_python_qc(test_file, qc_chain)
    
    # Compare QC flags (exact match)
    assert_qc_flags_match(matlab_output, python_output)
```

## Advantages Over MATLAB-Based Testing

| Aspect | MATLAB | MCR |
|--------|--------|-----|
| License cost | $$$$ per seat | Free |
| CI/CD integration | Complex | Simple |
| Docker support | Difficult | Easy |
| Reproducibility | Version drift | Fixed (v95) |
| Parallel testing | License limits | No limits |
| Setup time | Hours | Minutes |
| Portability | Poor | Excellent |

## Limitations and Workarounds

### Limitation 1: No Interactive Mode

**Issue**: MCR cannot run GUI components.

**Workaround**: Use batch mode (`autoIMOSToolbox`) exclusively for regression tests.

### Limitation 2: Limited Debugging

**Issue**: MCR errors are less informative than MATLAB.

**Workaround**: 
- Capture stdout/stderr in detail
- Add verbose logging to MCR wrapper
- Keep MATLAB source available for debugging

### Limitation 3: Fixed MATLAB Version

**Issue**: MCR v95 = MATLAB R2018b only.

**Workaround**: 
- This is actually a feature (reproducibility)
- Matches minimum supported MATLAB version
- Recompile binary if MATLAB code changes

## Integration with Existing Plan

This MCR approach **replaces** the MATLAB-based testing in Phase 10 of the roadmap:

**Before** (ROADMAP.md Phase 10):
```
- [ ] Add MATLAB test harness script (matlab/run_regression_tests.m)
```

**After** (with MCR):
```
- [ ] Add MCR wrapper module (python/tests/regression/mcr_wrapper.py)
- [ ] Add MCR baseline generator (python/tests/regression/generate_mcr_baselines.py)
- [ ] Add MCR CI workflow (.github/workflows/regression-mcr.yml)
- [ ] Add MCR Docker container (docker/regression-mcr.Dockerfile)
```

## Timeline

- **Week 1**: MCR installation and wrapper development
- **Week 2**: Docker container and CI setup
- **Week 3**: Parser regression tests (15 parsers)
- **Week 4**: Preprocessing regression tests
- **Week 5**: QC regression tests
- **Week 6**: Documentation and refinement

**Total: 6 weeks** (vs 10 weeks for MATLAB-based approach)

## Success Criteria

1. ✅ MCR v95 installed and verified in CI
2. ✅ MCR wrapper can invoke toolbox in batch mode
3. ✅ All parser tests pass with MCR baseline
4. ✅ All preprocessing tests pass with MCR baseline
5. ✅ All QC tests pass with MCR baseline
6. ✅ Docker container runs regression suite successfully
7. ✅ CI runs regression tests on every commit
8. ✅ Regression reports generated automatically

## Cost-Benefit Analysis

**Traditional MATLAB Approach**:
- Cost: $2,150 per license (Standard) × N developers/CI runners
- Setup: Complex, requires license server
- Maintenance: License renewals, version management

**MCR Approach**:
- Cost: $0 (MCR is free)
- Setup: Simple, download and install
- Maintenance: Minimal, fixed version

**Savings**: $2,150+ per developer/CI runner + reduced complexity

## Recommendation

**Use MCR for all regression testing** because:

1. ✅ Zero licensing cost
2. ✅ CI/CD friendly (Docker, GitHub Actions)
3. ✅ Reproducible (fixed MATLAB version)
4. ✅ Faster setup (6 weeks vs 10 weeks)
5. ✅ No license management overhead
6. ✅ Unlimited parallel testing

**Keep MATLAB source code** for:
- Development and debugging
- Updating the compiled binary when code changes
- Reference implementation

## Next Steps

1. Install MCR v95 on development machine
2. Verify existing `imosToolbox_Linux64.bin` works with MCR
3. Implement `mcr_wrapper.py` module
4. Create Docker container for local testing
5. Set up GitHub Actions workflow
6. Generate first set of MCR baselines
7. Implement parser regression tests
8. Expand to preprocessing and QC tests
9. Document known differences
10. Update ROADMAP.md with MCR approach
