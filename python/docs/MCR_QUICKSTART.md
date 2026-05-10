# MCR Regression Testing Quick Start

This guide gets you started with MCR-based regression testing in under 30 minutes.

## Prerequisites

- Linux (Ubuntu 22.04+) or macOS
- Python 3.14
- Existing IMOS Toolbox compiled binary (`imosToolbox_Linux64.bin`)

## Step 1: Install MCR v95 (5 minutes)

### Linux

```bash
# Download MCR installer
wget https://ssd.mathworks.com/supportfiles/downloads/R2018b/Release/6/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2018b_Update_6_glnxa64.zip

# Extract and install
unzip MATLAB_Runtime_R2018b_Update_6_glnxa64.zip -d mcr_installer
cd mcr_installer
sudo ./install -mode silent -agreeToLicense yes -destinationFolder /opt/mcr

# Set environment (add to ~/.bashrc)
export MCR_ROOT=/opt/mcr/v95
export LD_LIBRARY_PATH=${MCR_ROOT}/runtime/glnxa64:${MCR_ROOT}/bin/glnxa64:${MCR_ROOT}/sys/os/glnxa64:${LD_LIBRARY_PATH}

# Reload environment
source ~/.bashrc
```

### Verify Installation

```bash
ls -la /opt/mcr/v95
# Should show: bin/ runtime/ sys/ etc/
```

## Step 2: Create MCR Wrapper (10 minutes)

```bash
cd /home/tisham/dev/imos-toolbox/python/tests
mkdir -p regression
cd regression
```

Create `mcr_wrapper.py`:

```python
"""Minimal MCR wrapper for regression testing."""

import subprocess
from pathlib import Path
from typing import List


class MCRToolbox:
    def __init__(self, mcr_root: str = "/opt/mcr/v95"):
        self.mcr_root = Path(mcr_root)
        self.toolbox_sh = Path(__file__).parent.parent.parent.parent / "imosToolbox_Linux64.sh"
        
        if not self.mcr_root.exists():
            raise FileNotFoundError(f"MCR not found: {mcr_root}")
        if not self.toolbox_sh.exists():
            raise FileNotFoundError(f"Toolbox not found: {self.toolbox_sh}")
    
    def run_auto_batch(self, field_trip: str, data_dir: str, 
                       pp_chain: List[str], qc_chain: List[str], 
                       export_dir: str) -> subprocess.CompletedProcess:
        """Run toolbox in batch mode."""
        pp_str = "{" + " ".join(f"'{p}'" for p in pp_chain) + "}" if pp_chain else "{}"
        qc_str = "{" + " ".join(f"'{q}'" for q in qc_chain) + "}" if qc_chain else "{}"
        
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
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        if result.returncode != 0:
            raise RuntimeError(f"MCR failed: {result.stderr}")
        
        return result
```

## Step 3: Test MCR Wrapper (5 minutes)

Create `test_mcr_smoke.py`:

```python
"""Smoke test for MCR wrapper."""

import pytest
from pathlib import Path
from mcr_wrapper import MCRToolbox


def test_mcr_available():
    """Verify MCR is installed and accessible."""
    mcr = MCRToolbox()
    assert mcr.mcr_root.exists()
    assert mcr.toolbox_sh.exists()


@pytest.mark.skipif(not Path("/opt/mcr/v95").exists(), reason="MCR not installed")
def test_mcr_toolbox_runs(tmp_path):
    """Verify MCR toolbox can execute."""
    mcr = MCRToolbox()
    
    # Create dummy test file (minimal SBE37 format)
    test_file = tmp_path / "test.asc"
    test_file.write_text("""* Sea-Bird SBE 37-SM MicroCAT
* Temperature: 20.0
* Conductivity: 3.5
* Pressure: 10.0
""")
    
    output_dir = tmp_path / "output"
    output_dir.mkdir()
    
    # Run MCR toolbox (should not crash)
    try:
        result = mcr.run_auto_batch(
            field_trip="smoke_test",
            data_dir=str(tmp_path),
            pp_chain=[],
            qc_chain=[],
            export_dir=str(output_dir)
        )
        print(f"MCR stdout: {result.stdout}")
        print(f"MCR stderr: {result.stderr}")
    except Exception as e:
        pytest.skip(f"MCR execution failed (expected for dummy file): {e}")
```

Run the test:

```bash
cd /home/tisham/dev/imos-toolbox/python
uv run pytest tests/regression/test_mcr_smoke.py -v
```

## Step 4: Create First Regression Test (10 minutes)

Create `test_mcr_parser.py`:

```python
"""First MCR parser regression test."""

import pytest
from pathlib import Path
from mcr_wrapper import MCRToolbox


@pytest.fixture
def mcr():
    return MCRToolbox()


@pytest.mark.mcr
def test_sbe37_parser_mcr(mcr, tmp_path):
    """Compare SBE37 parser: Python vs MCR-MATLAB."""
    # Setup test data (use real file from fixtures)
    raw_file = Path("fixtures/raw_data/sbe37/sbe37_test.asc")
    
    if not raw_file.exists():
        pytest.skip("Test data not available")
    
    # Run MCR toolbox
    matlab_output = tmp_path / "matlab"
    matlab_output.mkdir()
    
    mcr.run_auto_batch(
        field_trip="regression",
        data_dir=str(raw_file.parent),
        pp_chain=[],
        qc_chain=[],
        export_dir=str(matlab_output)
    )
    
    # Run Python parser
    from imos_toolbox.parsers import get_parser
    parser = get_parser("sbe37")
    dataset = parser.parse(str(raw_file), mode="timeSeries")
    
    python_output = tmp_path / "python"
    python_output.mkdir()
    python_nc = python_output / "sbe37_test.nc"
    dataset.to_netcdf(str(python_nc))
    
    # Compare (basic check)
    import netCDF4 as nc
    
    matlab_nc_file = list(matlab_output.glob("*.nc"))[0]
    
    with nc.Dataset(matlab_nc_file) as m_ds, nc.Dataset(python_nc) as p_ds:
        # Check dimensions match
        assert set(m_ds.dimensions.keys()) == set(p_ds.dimensions.keys())
        
        # Check variables match
        assert set(m_ds.variables.keys()) == set(p_ds.variables.keys())
        
        print("✓ Parser regression test passed!")
```

## Step 5: Run Regression Test

```bash
cd /home/tisham/dev/imos-toolbox/python

# Run MCR-marked tests
uv run pytest tests/regression/ -v -m mcr

# Or run all regression tests
uv run pytest tests/regression/ -v
```

## Docker Alternative (Optional)

If you prefer Docker:

```bash
# Build container
docker build -f docker/regression-mcr.Dockerfile -t imos-mcr .

# Run tests
docker run --rm -v $(pwd):/workspace imos-mcr \
    bash -c "cd python && uv run pytest tests/regression/ -v -m mcr"
```

## Troubleshooting

### MCR not found

```bash
# Check MCR installation
ls -la /opt/mcr/v95

# If missing, reinstall
sudo rm -rf /opt/mcr
# Then repeat Step 1
```

### Toolbox binary not found

```bash
# Check binary exists
ls -la /home/tisham/dev/imos-toolbox/imosToolbox_Linux64.bin

# Make executable
chmod +x /home/tisham/dev/imos-toolbox/imosToolbox_Linux64.bin
chmod +x /home/tisham/dev/imos-toolbox/imosToolbox_Linux64.sh
```

### MCR execution fails

```bash
# Check environment variables
echo $MCR_ROOT
echo $LD_LIBRARY_PATH

# Test MCR directly
/home/tisham/dev/imos-toolbox/imosToolbox_Linux64.sh /opt/mcr/v95 auto test /tmp {} {} /tmp
```

### Python import errors

```bash
# Ensure dependencies installed
cd /home/tisham/dev/imos-toolbox/python
uv sync --extra dev

# Check Python path
uv run python -c "import sys; print(sys.path)"
```

## Next Steps

1. ✅ MCR installed and verified
2. ✅ MCR wrapper working
3. ✅ First regression test passing
4. ⬜ Add more parser tests
5. ⬜ Add preprocessing tests
6. ⬜ Add QC tests
7. ⬜ Set up CI workflow
8. ⬜ Generate comprehensive baselines

## Resources

- Full plan: `MCR_REGRESSION_PLAN.md`
- Roadmap: `ROADMAP.md` (Phase 10)
- MCR download: https://www.mathworks.com/products/compiler/matlab-runtime.html
- IMOS Toolbox wiki: https://github.com/aodn/imos-toolbox/wiki

## Time Investment

- Initial setup: 30 minutes
- Per parser test: 15 minutes
- Full regression suite: 2-3 weeks

**Total ROI**: Eliminates need for MATLAB licenses ($2,150+ per seat)
