# Parser Format Matrix

This matrix tracks parser-to-format coverage in the Python port and is backed by
`tests/test_parser_format_matrix.py` in CI.

| Parser | CLI command | Formats (initial support) |
|---|---|---|
| SBE19 | `parse-sbe19` | `.cnv` |
| Aquatec | `parse-aquatec` | `.txt`, `.dat`, `.csv` |
| SBE26 | `parse-sbe26` | `.tid` |
| SBE37 | `parse-sbe37` | `.asc`, `.cnv` |
| SBE37SM | `parse-sbe37sm` | `.asc`, `.cnv` |
| SBE39 | `parse-sbe39` | `.asc` |
| SBE56 | `parse-sbe56` | `.cnv`, `.csv` |
| WQM | `parse-wqm` | `.dat`, `.raw` |
| WetStar | `parse-wetstar` | `.raw` + matching `.dev` |
| ECOTriplet | `parse-ecotriplet` | `.raw` + matching `.dev` |
| ECOBB9 | `parse-ecobb9` | `.raw` + matching `.dev` |
| DR1050 | `parse-dr1050` | text exports (`.txt`/`.dat` style) |
| XR | `parse-xr` | classic `.dat` and Ruskin text exports |
| Vemco | `parse-vemco` | `.csv` |
| NIWA | `parse-niwa` | `.DAT3` ASCII |
| RCM | `parse-rcm` | `.txt` |
| Starmon Mini | `parse-starmon-mini` | `.dat` |
| Starmon DST | `parse-starmon-dst` | `.dat` |
| YSI 6-Series | `parse-ysi6` | `.dat` (binary) |
| Sensus Ultra | `parse-sensus-ultra` | `.csv` |

## Notes
- Current tests validate command registration and extension-gating behavior for
  parsers that enforce suffix checks.
- Parsing fidelity tests for real instrument files are planned as separate
  fixture-based regression tests.
