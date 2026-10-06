# Legacy-derived feature compatibility audit

- Status: active implementation gate
- Reviewed: 2026-10-06
- Scope: FG Studio-driven open-source derived vector features implemented so far

## Purpose

FG Studio development is grounded evidence for both `fluvgeo` ArcPy replacement
functions and the still-developing FGDB interoperability specification. This
audit prevents a functioning local workflow from being mistaken for a completed
replacement when its legacy output contract has not been verified.

## Current findings

| Feature | Legacy producer | Current compatibility status | Required follow-up |
|---|---|---|---|
| `stream_network` | `_04_StreamNetwork.py` | Layer name is retained. The open producer now retains the exact nullable text `ReachName` field used for later Reach assignment. Modern topology/accumulation fields are additive. ArcGIS-managed `OBJECTID`, geometry and length fields remain driver concerns. | Extend the FGDB compatibility profile with the complete verified Stream Network contract before declaring the ArcPy producer fully replaced; compare representative multi-version legacy outputs. |
| `flowline` | `_05a_Flowline.py`, then mutated by `_06_FlowlinePoints.py` | New candidates retain internal review layers and additionally write a portable `flowline` layer with `ReachName`, kilometer `from_measure`, and kilometer `to_measure`. Old local candidate revisions are reopened through an additive in-memory compatibility normalization. | Preserve optional/versioned ArcGIS smoothing evidence when importing it; do not fabricate `InLine_FID` or `SmoLnFlag` for the different open smoothing method. |
| `flowline_points` | `_06_FlowlinePoints.py` | Backend construction is in progress. The replacement profile is explicitly distinct from the existing metre-based R-client profile and retains `ReachName`, `POINT_X`, `POINT_Y`, kilometer `POINT_M`, `Z`, and additive `km_to_mouth`. | Complete FG Studio UI/persistence and real-data review; qualify optional calibration fields and behavior before claiming calibrated-route replacement. |

## Interpretation

The local algorithm or user workflow can be functionally useful before the full
replacement contract is complete. Documentation must say which state applies:

- **workflow implemented**: the analyst can perform and review the local step;
- **legacy-compatible output implemented**: required schema and semantics pass
  deterministic constructor/validator tests; or
- **ArcPy capability replaced**: applicable versions, optional behavior,
  downstream consumers, and portable export are qualified with no known blocking
  compatibility gaps.

Only the second and third states establish backward-compatible production
claims. Update this audit when another historically produced vector feature is
selected for FG Studio development.
