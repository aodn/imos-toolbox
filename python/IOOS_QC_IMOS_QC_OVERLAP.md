# ioos_qc ↔ IMOS Toolbox Python Port QC Overlap Analysis

## Flag Scheme Comparison

### IMOS Toolbox (Set 1 — IMOS Standard Flags)

| Flag | Value | Description |
|------|-------|-------------|
| RAW | `0` | No QC performed (unevaluated) |
| GOOD | `1` | Good data |
| PROBABLY_GOOD | `2` | Probably good data |
| PROBABLY_BAD | `3` | Probably bad data (correctable) |
| BAD | `4` | Bad data |
| MISSING | `9` | Missing value |

### ioos_qc (QARTOD Flags)

| Flag | Value | Description |
|------|-------|-------------|
| GOOD | `1` | Passed all tests |
| UNKNOWN | `2` | Not evaluated / insufficient data |
| SUSPECT | `3` | Passed gross checks, failed detailed checks |
| FAIL | `4` | Failed critical tests |
| MISSING | `9` | Missing data |

### Key Flag-Level Differences

| Aspect | IMOS Toolbox | ioos_qc (QARTOD) |
|--------|-------------|------------------|
| "Not evaluated" | `0` (RAW) — used before any QC | `2` (UNKNOWN) — used when test cannot run |
| "Probably good" | `2` (PROBABLY_GOOD) — positive intermediate | No equivalent (2 = UNKNOWN) |
| "Borderline bad" | `3` (PROBABLY_BAD) — potentially correctable | `3` (SUSPECT) — equivalent concept |
| "Bad" | `4` (BAD) — do not use | `4` (FAIL) — equivalent concept |
| Flag upgrade rule | Flags can only increase (runner enforces `max`) | `aggregate()` uses QARTOD precedence: FAIL > SUSPECT > UNKNOWN > GOOD |
| Missing | `9` (MISSING) | `9` (MISSING) |

---

## QC Test Comparison

### Global/Gross Range Check

| Attribute | IMOS `ImosGlobalRangeQC` | ioos_qc `qartod.gross_range_test` |
|-----------|--------------------------|-----------------------------------|
| **Purpose** | Flag values outside the global valid range | Flag values outside sensor or climatological range bounds |
| **Algorithm** | `value < valid_min OR value > valid_max` (from config file) | Same; additionally supports an inner `suspect_span` band |
| **Inputs** | `valid_min`, `valid_max` from `imosGlobalRangeQC.txt` | `fail_span (min, max)`; optional `suspect_span (min, max)` |
| **Flags assigned** | GOOD (1), BAD (4) | GOOD (1), SUSPECT (3), FAIL (4), UNKNOWN (2) |
| **Suspect zone** | Not supported — only binary good/bad | Supported via `suspect_span` |
| **Missing handling** | NaN → RAW (0) by default | NaN/masked → UNKNOWN (2) |
| **Config-driven** | Yes (`imosGlobalRangeQC.txt`, keyed by parameter name) | No — thresholds passed as arguments |

**Overlap**: Strong. Both implement sensor-range gross range checking. `gross_range_test` is richer: it adds an optional suspect band and flags missing as UNKNOWN rather than preserving RAW.

---

### Regional / Site-Specific Range Check

| Attribute | IMOS `ImosRegionalRangeQC` | ioos_qc `qartod.climatology_test` |
|-----------|---------------------------|-----------------------------------|
| **Purpose** | Flag values outside site-specific (regional) min/max | Flag values outside seasonal + depth-stratified climatological bounds |
| **Algorithm** | Simple min/max per `(site_code, parameter)` from config | Seasonal window + optional depth band from `ClimatologyConfig` |
| **Inputs** | `(site_code, parameter) → (min, max)` from `imosRegionalRangeQC.txt` | `ClimatologyConfig` with time/depth windows and suspect/fail spans |
| **Flags assigned** | GOOD (1), BAD (4) | GOOD (1), SUSPECT (3), FAIL (4), UNKNOWN (2) |
| **Seasonality** | No | Yes — per-season or per-month windows |
| **Depth stratification** | No | Yes — optional `zspan` in ClimatologyConfig |

**Overlap**: Partial. Both encode expected ranges per context (site vs. season/depth). IMOS uses static site lookup; ioos_qc uses a richer climatology model with time and depth windows.

---

### Spike Detection (Time Series)

| Attribute | IMOS `TimeSeriesSpikeQC` | ioos_qc `qartod.spike_test` |
|-----------|-------------------------|-----------------------------|
| **Purpose** | Detect spikes in time series data | Detect spikes in time series data |
| **Algorithm** | **Hampel filter** — `\|value − median(window)\| > n_sigma × 1.4826 × MAD(window)` | **Average method** (default): `\|Vn − (Vn+1 + Vn-2)/2\| > threshold`; or **differential method**: `\|Vn − Vn-1\| > threshold` |
| **Inputs** | `half_window` (int), `n_sigma` (float), `min_mad` (float) | `suspect_threshold` (obs units), `fail_threshold` (obs units), `method` ('average' or 'differential') |
| **Flags assigned** | RAW (0), GOOD (1), PROBABLY_BAD (3) | GOOD (1), SUSPECT (3), FAIL (4), UNKNOWN (2) |
| **Suspect zone** | Not supported — only spike/non-spike | Supported: separate suspect and fail thresholds |
| **Threshold derivation** | Adaptive (sigma × MAD, data-driven) | Fixed (user-supplied, units of obs) |
| **Missing handling** | NaN → RAW (0) | NaN/masked → UNKNOWN (2) |

**Overlap**: Moderate. Both detect point spikes in time series, but use different algorithms. IMOS uses a data-adaptive Hampel/MAD approach; ioos_qc uses fixed absolute thresholds with the three-point average or differential method. ioos_qc supports graduated severity (SUSPECT vs FAIL); IMOS treats all spikes equally as PROBABLY_BAD.

---

### Spike Detection (Vertical Profile)

| Attribute | IMOS `VerticalSpikeQC` | ioos_qc — no direct equivalent |
|-----------|------------------------|--------------------------------|
| **Purpose** | Detect spikes in vertical CTD/profile data | — |
| **Algorithm** | ARGO spike test: `\|Vn − (Vn+1 + Vn-1)/2\| − \|(Vn+1 − Vn-1)/2\| > threshold` | `qartod.spike_test` can be applied to profile data but uses a simpler algorithm |
| **Inputs** | Thresholds from `imosVerticalSpikeQC.txt` per parameter | `suspect_threshold`, `fail_threshold` (obs units) |
| **Flags assigned** | RAW (0), GOOD (1), PROBABLY_BAD (3) | GOOD (1), SUSPECT (3), FAIL (4), UNKNOWN (2) |
| **Profile-specific** | Yes — profile mode only, endpoints always GOOD | Not explicitly — works on any 1D array |

**Overlap**: Partial. The IMOS ARGO spike formula is the same as the ARGO QC manual and is more appropriate for profiles (it normalises for vertical gradient). ioos_qc's `spike_test` can be applied to profiles but lacks the ARGO normalisation term.

---

### Rate of Change

| Attribute | IMOS `RateOfChangeQC` | ioos_qc `qartod.rate_of_change_test` |
|-----------|----------------------|--------------------------------------|
| **Purpose** | Detect excessive rate of change between successive observations | Detect excessive rate of change per unit time |
| **Algorithm** | `\|Vi − Vi-1\| + \|Vi − Vi+1\| > 2×threshold` (interior); threshold derived from `stdDev × factor` using first-month data | First-order difference normalised by time: `\|Vi − Vi-1\| / dt > threshold (units/sec)` |
| **Inputs** | Threshold expression from `imosRateOfChangeQC.txt` (e.g. `stdDev * 1.5`); skips gaps >1 hr | `threshold` (obs units/sec); optional `fail_threshold` |
| **Flags assigned** | RAW (0), GOOD (1), PROBABLY_BAD (3) | GOOD (1), SUSPECT (3), FAIL (4), UNKNOWN (2) |
| **Time-normalised** | No — absolute difference compared to data-derived threshold | Yes — divided by elapsed seconds |
| **Threshold derivation** | Adaptive (stdDev from clean data) | Fixed (user-supplied) |

**Overlap**: Moderate. Both detect large changes between successive values. IMOS uses a symmetric interior-point check with an adaptive threshold; ioos_qc uses a time-normalised first-order difference with fixed thresholds.

---

### Flatline / Stuck Value Detection

| Attribute | IMOS `StationarityQC` | ioos_qc `qartod.flat_line_test` |
|-----------|----------------------|----------------------------------|
| **Purpose** | Detect consecutive constant (flatline) values | Detect consecutively repeated values within a tolerance |
| **Algorithm** | Detects runs of exactly equal values where run length > `24 × (60 / delta_t_minutes)` | Rolling window: range of values in window < `tolerance` for ≥ `suspect_threshold` or `fail_threshold` seconds |
| **Inputs** | None (auto-detects from TIME dimension) | `suspect_threshold` (sec), `fail_threshold` (sec), `tolerance` (obs units) |
| **Flags assigned** | RAW (0), GOOD (1), PROBABLY_BAD (3) | GOOD (1), SUSPECT (3), FAIL (4), UNKNOWN (2) |
| **Tolerance** | Zero tolerance only (exact equality) | Configurable tolerance — handles sensor noise |
| **Severity levels** | Single level (PROBABLY_BAD) | Two levels (SUSPECT / FAIL) |

**Overlap**: Strong conceptual match. Both detect stuck-sensor behaviour. ioos_qc is more flexible: it supports a non-zero tolerance (important for noisy sensors), time-based thresholds, and graduated severity. IMOS's threshold is fixed at approximately one day's worth of samples at the observed sampling rate.

---

### Attenuated Signal / Low Variance

| Attribute | IMOS — no direct equivalent | ioos_qc `qartod.attenuated_signal_test` |
|-----------|-----------------------------|------------------------------------------|
| **Purpose** | — | Detect near-flat-line conditions using range or standard deviation over a rolling window |
| **Algorithm** | — | Rolling window std dev or range < threshold |
| **Inputs** | — | `suspect_threshold`, `fail_threshold`, `test_period` (sec), `check_type` ('std' or 'range') |
| **Flags assigned** | — | GOOD (1), SUSPECT (3), FAIL (4), UNKNOWN (2) |

**Overlap**: None. IMOS has no equivalent. This is related to `StationarityQC` but is more general — it flags low variance rather than exact repeats.

---

### Density Inversion

| Attribute | IMOS `DensityInversionSetQC` | ioos_qc `qartod.density_inversion_test` |
|-----------|------------------------------|------------------------------------------|
| **Purpose** | Flag density inversions in vertical profiles | Flag density inversions in vertical profiles |
| **Algorithm** | Simplified density: `ρ = 1000 + 0.8×PSAL − 0.2×TEMP + 0.004×PRES`; flags if `\|ρ[i] − ρ[i-1]\| > 0.03 kg/m³` | Takes pre-computed potential density (`inp`) and depth (`zinp`); flags where density decreases with depth beyond threshold |
| **Inputs** | Reads TEMP, PSAL, PRES from dataset; threshold from config (default 0.03 kg/m³) | `inp` (potential density array), `zinp` (depth/pressure array); `suspect_threshold`, `fail_threshold` |
| **Flags assigned** | RAW (0), GOOD (1), PROBABLY_BAD (3) | GOOD (1), SUSPECT (3), FAIL (4), UNKNOWN (2) |
| **Density formula** | Simplified linear approximation (built-in) | Caller must supply pre-computed potential density (no formula built-in) |
| **Severity** | Single level (PROBABLY_BAD) | Two levels (SUSPECT / FAIL) |
| **Mode** | Profile only (single TIME point) | Any 1D array |

**Overlap**: Strong conceptual match. Both detect where density unexpectedly decreases with depth. IMOS computes density internally using a simplified formula; ioos_qc expects the caller to supply it (allowing use of full seawater equations like GSW). ioos_qc supports graduated severity.

---

### Location / Position Check

| Attribute | IMOS `ImosImpossibleLocationSetQC` | ioos_qc `qartod.location_test` |
|-----------|-------------------------------------|--------------------------------|
| **Purpose** | Flag LATITUDE/LONGITUDE outside site-specific bounds | Flag lat/lon outside a global or user-defined bounding box |
| **Algorithm** | Rectangular: `\|lon − nominal\| ≤ threshold` AND `\|lat − nominal\| ≤ threshold`; or circular: Haversine distance ≤ threshold_km | Rectangular bounding box; optionally maximum great-circle range from a centroid |
| **Inputs** | Site lookup from `IMOS/imosSites.txt`; circular threshold if `distance_km_threshold` defined | `bbox` (minx, miny, maxx, maxy); optional `range_max` in metres |
| **Flags assigned** | GOOD (1), PROBABLY_BAD (3) | GOOD (1), FAIL (4), UNKNOWN (2) |
| **Config-driven** | Yes (site database) | No — thresholds passed as arguments |
| **Severity** | Single level (PROBABLY_BAD) | Single level (FAIL) |

**Overlap**: Moderate. Both check that position is geographically reasonable. IMOS uses site-keyed bounds (mooring-specific); ioos_qc uses global or user-supplied bounds. IMOS flags out-of-bounds as PROBABLY_BAD (3); ioos_qc flags as FAIL (4).

---

### Speed Test (Platform Velocity)

| Attribute | IMOS — no direct equivalent | ioos_qc `argo.speed_test` |
|-----------|-----------------------------|---------------------------|
| **Purpose** | — | Detect implausible platform movement speed between successive positions |
| **Algorithm** | — | `distance(lon[i], lat[i], lon[i-1], lat[i-1]) / time_diff > threshold` |
| **Inputs** | — | `lon`, `lat`, `tinp`, `suspect_threshold` (m/s), `fail_threshold` (m/s) |
| **Flags assigned** | — | GOOD (1), SUSPECT (3), FAIL (4), UNKNOWN (2), MISSING (9) |

**Overlap**: None. IMOS has no platform-speed check. Relevant for drifting platforms and gliders.

---

### Pressure Increasing Test

| Attribute | IMOS — no direct equivalent | ioos_qc `argo.pressure_increasing_test` |
|-----------|-----------------------------|------------------------------------------|
| **Purpose** | — | Check that pressure monotonically increases (downcast QC) |
| **Algorithm** | — | Flags points where `P[i] ≤ P[i-1]` as SUSPECT; corrects for upcasts by sign flip |
| **Inputs** | — | `inp` (pressure array) |
| **Flags assigned** | — | GOOD (1), SUSPECT (3) |

**Overlap**: None. IMOS has no monotonic pressure check. Related to IMOS's `ImosImpossibleDepthQC` (depth bounds) but distinct.

---

### Impossible Date Check

| Attribute | IMOS `ImosImpossibleDateQC` | ioos_qc — no direct equivalent |
|-----------|----------------------------|--------------------------------|
| **Purpose** | Flag TIME values outside acceptable date range | — |
| **Algorithm** | `TIME < dateMin OR TIME > dateMax` (default dateMax = current UTC) | `axds.valid_range_test` can check datetime values with `dtype=datetime64` |
| **Inputs** | `dateMin`, `dateMax` from `imosImpossibleDateQC.txt` | `valid_span` (start, end) as datetime-like objects |
| **Flags assigned** | GOOD (1), BAD (4) | GOOD (1), FAIL (4), MISSING (9) |

**Overlap**: Partial. ioos_qc's `axds.valid_range_test` supports datetime objects and can be used as an equivalent, but it is a general-purpose range check rather than a dedicated date QC test.

---

### Impossible Depth Check

| Attribute | IMOS `ImosImpossibleDepthQC` | ioos_qc — no direct equivalent |
|-----------|------------------------------|--------------------------------|
| **Purpose** | Flag depth/pressure values inconsistent with mooring geometry or site bathymetry | — |
| **Algorithm** | timeSeries: `[inst_depth − margin, inst_depth + margin + knockdown]`; profile: `[0, bot_depth × 1.2]` | `qartod.gross_range_test` can serve as a depth range check |
| **Inputs** | `zNominalMargin`, `maxAngle` from config; instrument metadata | `fail_span (min, max)` |
| **Flags assigned** | GOOD (1), BAD (4) | GOOD (1), FAIL (4), UNKNOWN (2) |

**Overlap**: Partial. ioos_qc has no instrument-geometry-aware depth check. `gross_range_test` with user-supplied bounds can approximate it.

---

### Deployment Window / In-Out Water

| Attribute | IMOS `ImosInOutWaterQC` | ioos_qc `axds.valid_range_test` (partial) |
|-----------|------------------------|-------------------------------------------|
| **Purpose** | Flag data recorded outside the deployment time window | — |
| **Algorithm** | Points before `time_deployment_start` or after `time_deployment_end` → BAD; inside → preserve existing flags | `valid_range_test` with a datetime `valid_span` can reject out-of-window data |
| **Inputs** | `time_deployment_start`, `time_deployment_end` from dataset attributes | `valid_span`, `dtype=datetime64` |
| **Flags assigned** | RAW (0) (inside — preserve), BAD (4) (outside) | GOOD (1), FAIL (4), MISSING (9) |

**Overlap**: Partial. IMOS's implementation is deployment-metadata-driven and uses a flag-preserve semantic (inside window keeps existing flags). ioos_qc has no concept of a deployment window; `valid_range_test` on time is the closest proxy but always sets GOOD inside the window rather than preserving.

---

### Salinity Flag Propagation

| Attribute | IMOS `SalinityFromPTQC` | ioos_qc — no direct equivalent |
|-----------|------------------------|--------------------------------|
| **Purpose** | Propagate worst QC flag from T, C, P inputs to derived PSAL | — |
| **Algorithm** | `PSAL_QC = max(TEMP_QC, CNDC_QC, PRES_QC)` for matching variable | No flag propagation utilities; caller must aggregate manually |
| **Flags assigned** | Inherited (max of sources) | — |

**Overlap**: None. ioos_qc has no built-in mechanism for propagating input-variable QC flags to derived variables. The `aggregate` / `qartod_compare` functions aggregate across tests for the *same* variable, not across different variables.

---

### CTD Surface Soak

| Attribute | IMOS `CTDSurfaceSoakQC` | ioos_qc — no direct equivalent |
|-----------|------------------------|--------------------------------|
| **Purpose** | Flag CTD data during surface equilibration soak | — |
| **Algorithm** | Status-based (soak status variables) or depth-based (depth < 2 m) | — |
| **Flags assigned** | GOOD (1), PROBABLY_BAD (3), BAD (4) | — |

**Overlap**: None. ioos_qc has no soak-period detection.

---

### ADCP Surface Detection

| Attribute | IMOS `SurfaceDetectionByDepthSetQC` | ioos_qc — no direct equivalent |
|-----------|-------------------------------------|--------------------------------|
| **Purpose** | Flag ADCP bins above the water surface | — |
| **Algorithm** | `bin_distance > (nominal_depth − measured_depth)` → above surface | — |
| **Flags assigned** | GOOD (1), BAD (4) | — |

**Overlap**: None. ioos_qc has no ADCP-specific surface detection check.

---

## Summary of Overlap

### Strong overlap (equivalent QC concepts, different implementations)

| IMOS Check | ioos_qc Equivalent | Notes |
|------------|-------------------|-------|
| `ImosGlobalRangeQC` | `qartod.gross_range_test` | ioos_qc adds suspect band; same core algorithm |
| `TimeSeriesSpikeQC` | `qartod.spike_test` | Different algorithms (Hampel vs three-point average); same purpose |
| `StationarityQC` | `qartod.flat_line_test` | ioos_qc adds tolerance and severity levels |
| `DensityInversionSetQC` | `qartod.density_inversion_test` | ioos_qc requires pre-computed density; IMOS computes internally |
| `RateOfChangeQC` | `qartod.rate_of_change_test` | ioos_qc normalises by time (units/sec); IMOS uses adaptive threshold |

### Partial overlap (related but different scope or approach)

| IMOS Check | ioos_qc Partial Match | Notes |
|------------|----------------------|-------|
| `ImosRegionalRangeQC` | `qartod.climatology_test` | IMOS: static site table; ioos_qc: season/depth climatology |
| `VerticalSpikeQC` | `qartod.spike_test` | IMOS uses ARGO normalisation formula; ioos_qc uses simpler method |
| `ImosImpossibleLocationSetQC` | `qartod.location_test` | IMOS: site-keyed bounds; ioos_qc: global bbox + range_max |
| `ImosImpossibleDateQC` | `axds.valid_range_test` | ioos_qc general range check can cover dates |
| `ImosImpossibleDepthQC` | `qartod.gross_range_test` | ioos_qc has no geometry-aware depth check |
| `ImosInOutWaterQC` | `axds.valid_range_test` | ioos_qc has no deployment-window-aware flag-preserve semantic |

### IMOS checks with no ioos_qc equivalent (IMOS-only)

| IMOS Check | Gap Description |
|------------|-----------------|
| `SalinityFromPTQC` | No inter-variable flag propagation in ioos_qc |
| `CTDSurfaceSoakQC` | No soak-period detection in ioos_qc |
| `SurfaceDetectionByDepthSetQC` | No ADCP bin surface detection in ioos_qc |

### ioos_qc checks with no IMOS equivalent (ioos_qc-only)

| ioos_qc Check | Gap Description |
|--------------|-----------------|
| `qartod.attenuated_signal_test` | Low-variance/range detection (rolling window std or range); IMOS only detects exact flatline |
| `argo.speed_test` | Platform velocity check; no equivalent in IMOS |
| `argo.pressure_increasing_test` | Monotonic pressure check for casts; IMOS has no equivalent |
| `qartod.climatology_test` (seasonal/depth) | Full seasonal × depth climatology; IMOS only has static site ranges |
| `qartod.gross_range_test` `suspect_span` | Graduated gross-range severity (SUSPECT zone); IMOS is binary good/bad |

---

## Key Architectural Differences

| Aspect | IMOS Toolbox Python Port | ioos_qc |
|--------|--------------------------|---------|
| **API style** | Class-based (`QCRoutine` subclasses with `run(dataset)`) | Function-based (standalone functions returning flag arrays) |
| **Config source** | File-based (`.txt` config files in repo) | Argument-based (thresholds passed at call time) |
| **Dataset coupling** | Tightly coupled to `IMOSDataset` (xarray-based) | Loosely coupled — operates on raw numpy/pandas arrays |
| **Flag upgrade rule** | Hard upgrade-only merge via `run_qc_chain` | `aggregate()` uses QARTOD precedence table |
| **Multi-variable routines** | Yes (`QCSetRoutine` operates on entire dataset) | No — each function operates on a single variable |
| **Mode awareness** | Explicit `timeSeries` vs `profile` mode | Not mode-aware — same functions for both |
| **Flag scheme** | IMOS Set 1 (0/1/2/3/4/9) | QARTOD (1/2/3/4/9) — no 0 (RAW) or 2 (PROBABLY_GOOD) |
| **Unevaluated state** | `0` (RAW) — default before any QC | `2` (UNKNOWN) — used when test cannot compute |
