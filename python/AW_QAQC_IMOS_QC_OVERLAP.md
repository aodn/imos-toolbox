# AW_QAQC ↔ IMOS Toolbox QC Overlap Analysis

## IMOS QC Flag Scheme (Set 1 — IMOS Standard Flags)

| Flag | Value | Description | Classes |
|------|-------|-------------|---------|
| 0 | `raw` | No QC performed | raw |
| 1 | `good` | Good data | good |
| 2 | `probablyGood` | Probably good data | probablyGood |
| 3 | `probablyBad` | Bad data, potentially correctable | suspect, spike, step, dup |
| 4 | `bad` | Bad data | bad, bound, seq, test, unreal, discont, land |
| 9 | `missing` | Missing value | missing |

## AW_QAQC → IMOS QC Flag Mapping

| AW Flag | AW Anomaly Type | IMOS Flag | IMOS Class | Overlap Notes |
|---------|-----------------|-----------|------------|---------------|
| **Bad** | Large sudden spike | **4 (Bad)** | spike → 3 or bad → 4 | IMOS `imosTimeSeriesSpikeQC` covers this. IMOS maps spikes to flag 3 (probablyBad) by default; AW treats large spikes as outright Bad (4). |
| **Bad** | Persistent values (flatline) | **4 (Bad)** | — | **No direct IMOS auto-QC equivalent.** IMOS has no flatline/stuck-value detector. Manual QC would flag as `bad`. |
| **Bad** | Impossible values: out of sensor range | **4 (Bad)** | bound → 4 | Direct overlap: `imosGlobalRangeQC` flags out-of-range values as flag 4 (bad). |
| **Bad** | Impossible values: zero values | **4 (Bad)** | — | **No specific IMOS auto-QC.** Partially caught by `imosGlobalRangeQC` if 0 is outside the global range, but no dedicated zero-value check. |
| **Bad** | Impossible values: negative values | **4 (Bad)** | — | **No specific IMOS auto-QC.** Same as above — caught only if the global/regional range excludes negatives. |
| **Bad** | Date from last maintenance >5 months | **4 (Bad)** | — | **No IMOS equivalent.** IMOS has no maintenance-schedule-based flagging. |
| **Suspect** | Date from last maintenance >3 months | **3 (probablyBad)** | — | **No IMOS equivalent.** |
| **Suspect** | Constant offset | **3 (probablyBad)** | step → 3 | Partially covered. IMOS `imosRateOfChangeQC` may detect sudden shifts. Manual QC comment `sensor_drift` is related. No dedicated offset detector. |
| **Suspect** | RAW values requiring local correction | **3 (probablyBad)** | — | **No IMOS equivalent.** IMOS does not track calibration model status. |
| **Bad** | Maintenance window | **4 (Bad)** | — | Partially covered by `imosInOutWaterQC` (flags data outside deployment window). No general maintenance-window flag. |
| **Suspect** | Impossible values: out of range for water type | **3 (probablyBad)** | bound → 4 | Covered by `imosRegionalRangeQC`. IMOS flags these as flag 4 (bad) rather than suspect. |
| **Suspect** | Sudden shift | **3 (probablyBad)** | step → 3 | Partially via `imosRateOfChangeQC`. Manual QC comment `sensor_instability` applies. |
| **Suspect** | Drift | **3 (probablyBad)** | — | **No IMOS auto-QC.** Manual QC comment `sensor_drift` is the only coverage. |
| **Suspect** | High variability / oscillation | **3 (probablyBad)** | — | **No direct IMOS auto-QC.** `imosStationarityQC` is related but specific to ADCP. |
| **Suspect** | Clusters of spikes | **3 (probablyBad)** | spike → 3 | Partially covered by `imosTimeSeriesSpikeQC` (point-by-point), but no cluster-aware logic. |
| **Suspect** | Small sudden spike | **3 (probablyBad)** | spike → 3 | Covered by `imosTimeSeriesSpikeQC` (threshold-dependent). |
| **Suspect** | Missing values | **9 (Missing)** | missing → 9 | IMOS uses flag 9 for missing data. The concept maps, but IMOS does not flag gaps as "suspect" — they are simply marked missing. |
| **Suspect** | Inter-sensor disagreement | **3 (probablyBad)** | — | **No IMOS auto-QC.** No cross-sensor consistency check exists in the toolbox. |

## Summary of Overlap

### Strong overlap (direct IMOS auto-QC equivalents)

- Out-of-sensor-range → `imosGlobalRangeQC` (flag 4)
- Out-of-range for water type → `imosRegionalRangeQC` (flag 4)
- Large/small spikes → `imosTimeSeriesSpikeQC` (flag 3)
- Missing values → IMOS flag 9

### Partial overlap (related but not exact)

- Sudden shift / constant offset → `imosRateOfChangeQC` (flag 3)
- Maintenance window → `imosInOutWaterQC` (deployment bounds only)
- Manual QC comments cover: spike, sensor_drift, climatology_outlier, zero_measurements, sensor_instability, invalid_data

### No IMOS equivalent (gaps)

| AW_QAQC Check | Gap Description |
|----------------|-----------------|
| Flatline / persistent values | No stuck-value detector |
| Zero values (where impossible) | No parameter-specific zero check |
| Negative values (where impossible) | No parameter-specific sign check |
| Maintenance schedule flags (>3mo / >5mo) | No metadata-driven maintenance age check |
| RAW values needing local correction | No calibration status tracking |
| Drift detection | No trend/slope detector (only manual comment) |
| High variability / oscillation | No general variance anomaly detector |
| Spike clusters | No cluster-aware spike logic |
| Inter-sensor disagreement | No cross-sensor consistency check |

## Key Flag-Level Differences

| Aspect | AW_QAQC | IMOS |
|--------|---------|------|
| Flag levels | 2 (Bad, Suspect) | 10 (0–9), effectively 5 used |
| Spike severity | Distinguishes large vs small | Single spike test, threshold-tunable |
| "Suspect" mapping | Orange / use with caution | Flag 3 = probablyBad (correctable) |
| "Bad" mapping | Red / do not use | Flag 4 = bad |
| Metadata-driven flags | Maintenance age, calibration | Deployment dates only (`imosInOutWaterQC`) |

## IMOS Automated QC Routines Reference

| # | Routine | Description |
|---|---------|-------------|
| 0 | `userManualQC` | User manual QC (interactive) |
| 1 | `imosCorrMagVelocitySetQC` | Correlation magnitude velocity check |
| 2 | `imosDensityInversionSetQC` | Density inversion check |
| 3 | `imosEchoIntensitySetQC` | Echo intensity check |
| 4 | `imosEchoIntensityVelocitySetQC` | Echo intensity velocity check |
| 5 | `imosEchoRangeSetQC` | Echo range check |
| 6 | `imosErrorVelocitySetQC` | Error velocity check |
| 7 | `imosGlobalRangeQC` | Global range check |
| 8 | `imosHorizontalVelocitySetQC` | Horizontal velocity check |
| 10 | `imosImpossibleDateQC` | Impossible date check |
| 11 | `imosImpossibleDepthQC` | Impossible depth check |
| 12 | `imosImpossibleLocationSetQC` | Impossible location check |
| 13 | `imosInOutWaterQC` | In/out of water check |
| 14 | `imosPercentGoodVelocitySetQC` | Percent good velocity check |
| 15 | `imosRateOfChangeQC` | Rate of change check |
| 16 | `imosRegionalRangeQC` | Regional range check |
| 17 | `imosSalinityFromPTQC` | Salinity from P & T check |
| 18 | `imosSideLobeVelocitySetQC` | Side lobe velocity check |
| 19 | `imosStationarityQC` | Stationarity check (ADCP) |
| 20 | `imosSurfaceDetectionByDepthSetQC` | Surface detection by depth check |
| 21 | `imosTier2ProfileVelocitySetQC` | Tier 2 profile velocity check |
| 22 | `imosTiltVelocitySetQC` (probably good) | Tilt velocity check (probably good) |
| 23 | `imosTiltVelocitySetQC` (bad) | Tilt velocity check (bad) |
| 24 | `imosTimeSeriesSpikeQC` | Time series spike check |
| 25 | `imosVerticalSpikeQC` | Vertical spike check |
| 26 | `imosVerticalVelocityQC` | Vertical velocity check |

## IMOS Manual QC Predefined Comments

| Internal Name | Comment |
|---------------|---------|
| spike | spike |
| sensor_drift | Sensor data is drifting |
| climatology_outlier | Sensor data is inconsistent with climatology |
| zero_measurements | Sensor data measured is zero |
| sensor_instability | Instrument instability |
| invalid_data | unexpected sensor data |
