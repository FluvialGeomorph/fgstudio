# Checkpoint: Stream DEM mosaic design

- Updated: 2026-09-20
- Status: CRS save/reload and documentation pass in 9036/9044; Event settings next

Vertical target metadata now uses context schema 7 with known/unknown/inapplicable
coordinate epoch, distinct frame epoch, explicit height type/elevation unit and
intended model fields. Prior contexts and source references are retained; no
vertical operation or source conformity is asserted. Both CRS menus use a page
overlay with viewport-aware sizing. Read the vertical feature and schema contract.

Latest owner review accepts the CRS UI and requests documentation plus save/reload
repairs before Event settings. Read `dev/features/vertical-reference-design.md`:
the target metadata contract is implemented, with no vertical transformations. The 9034
form removes manual attribution/rationale and organizes optional details into
disclosures. Hidden uninitialized acquisition inputs retain saved selections;
explicit clearing still counts as an edit. See the CRS feature for verification.

NSRS owner direction (2026-09-20): read ADR 0009 before further CRS work. Prepare
for NATRF2022/NAPGD2022/SPCS2022; distinguish acquisition dates from coordinate
epochs, exact elevation units from datums, and definitions from qualified local
operations. Retain historic analyst conversion evidence. No hidden vertical
transforms or unit changes. This design update changes no runtime or source data.

2026-09-20 owner steering: replace the blank input as the normal CRS selection
experience. Research in `dev/features/crs-discovery-design.md` confirms geographic
Explorer deep links and a static public catalog, not a documented remote bbox
search API. Recommend an EPSG projected pick list with whole-area screening,
reference links and local validation. Implemented with the installed local PROJ
catalog; epoch-dependent horizontal frames cannot yet be saved for analysis.
Vertical planning declarations can be saved without operation qualification. See the analysis CRS feature
record for current verification and runtime evidence.

## Owner direction

The owner supplied nine mosaic requirements after accepting tile previewing:
mandatory Study Area planar CRS; acquisition-time Event grouping (historically
same month); one Stream/Event DEM; first/last overlaps; native ground cell size;
Stream NoData; shared grid; hierarchical One/NoData masks; floating-point processing.
Later clarification supersedes native-resolution retention: require one chosen
output cell size per Event, possibly different from source spacing. Equal-size
Events share boundaries through one Study Area anchor; different sizes need not.
See `dev/features/dem-mosaic-design.md` and ADR 0008. These supersede the earlier
same-source-grid-only proposal. Guided CRS selection is implemented in 9033/9043;
Event settings, masks and mosaics remain pending.

Read FGDB conceptual model and ADRs 0005/0012: year is required, month/day optional,
labels are not identities, and Events are Reach-owned. Proposed local acquisition
groups link Stream DEMs/masks to those Events. USGS acquisition intervals and
USIEI collection-date text support conservative month proposals; no demonstrably
better automatic grouping method was found. Ambiguous dates need evidence review.

Analysis setup now validates and persists a projected Study Area CRS with automatic
action evidence in an immutable revision. After vertical specification, implement Event membership and
required output cell-size selection. No grid clarification is pending. Defaults
proposed for review include first-valid overlap, cell-center mask membership,
bilinear elevation resampling when required, and Float64 storage. Horizontal
processing must not accidentally invoke vertical shifts for compound CRS inputs.

No additional preview functionality is needed. The complete intended input set
still requires joint preflight, and assembly is separate from scientific acceptance.

## Verified foundation

9036 save/reload and documentation pass: 756 app assertions and backend isolation
checks pass. Both editors show local feedback; reload restores the saved study
from its tab URL and both definitions reappear. Nine articles/site and code-map
checks pass; package check has only its existing non-ASCII warning. See
`dev/governance/documentation-review-2026-09-20.md`. Backend remains 9044.

Previous vertical increment: 9035/9044. Full app suite passes 739 assertions;
final focused vertical app checks pass 24. Backend context/vertical regression
passes 174, with two optional gt report skips. Nine articles/site rebuilt; map
68 nodes, 85 static edges, 19 bridges with freshness/lookup checks passing.
Dropdown JavaScript contract fixture passes; browser attachment remains unavailable.
See the vertical feature record for final package-check evidence.

Previous picker increment: 9033/9043; 702 app assertions and 39 focused backend
assertions pass. Final catalog correction adds WGS84 datum-ensemble projections.
See `dev/features/study-analysis-crs.md` for final checks and limitations.

Previous CRS increment: 9032/9042; see `dev/features/study-analysis-crs.md` for exact
evidence. Backend 127 assertions pass (one optional gt report skip). App full run:
688 passes and one stale test expectation; corrected expectation and all 39 focused
download assertions pass. All 15 new CRS assertions passed. Eight articles/site
rebuilt; map 65 nodes, 79 static edges, 18 bridges. Package checks: no errors,
existing warnings/notes only; backend legacy tests/examples intentionally excluded.

FG Studio 9031 / fluvgeo 9041 provide saved selections, original downloads,
immutable receipts, checksum verification, metadata inspection and bounded
source-grid overview/detail. Latest evidence: 673 full app assertions, 73 focused
backend assertions (one existing symlink skip), real-worker/native-image checks,
all seven developer vignettes, and code-map freshness checks. Package checks have
no errors and only documented existing warnings/notes. See the feature record
for missing optional packages and intentionally excluded unsafe legacy tests.

Both repositories are on main. Download work is committed at fgstudio cf47b8b /
fluvgeo a378771; inspection changes remain uncommitted. No commits, pushes,
production changes or shared-library upgrades were performed in this handoff.

## Routes and preservation

- `dev/goals/project-plan.md`: single current direction.
- `dev/features/dem-inspection.md`: accepted behavior and detailed qualification.
- `vignettes/dev-06-stream-dem-files.Rmd`, `dev-07-dem-inspection.Rmd` and
  `dev/architecture/agent-routes.md`: paired human/agent call-flow navigation.
- Sibling fluvgeo `dev/schemas/stream-dem-downloads.md` and
  `dev/schemas/stream-dem-inspection.md`: exact implemented contracts.
- Sibling fluvgeo `dev/features/terrain-clipping.md`: experimental status and
  limitations; not an approved ready-made mosaic pipeline.

Preserve every `.local-data` study, selection and original asset. The preview was
restarted at http://127.0.0.1:8780/ in a fresh 9035 process; HTTP 200, vertical
controls and overlay configuration were verified. Browser automation could not synchronize
with existing tabs, so no visual browser QA is claimed for this increment.
Logs: `dev/check-output/vertical-preview.*.log`. Use `dev/scripts/run-dev.ps1` and
Studio's isolated `dev/local-library`; identify the listener before restarting.
Synthetic test data remains under ignored `dev/check-output`.

The accumulated pre-design handoff is preserved in
`../archive/terrain-inspection-before-mosaic-design-2026-09-19.md`. Do not use its
historical next-preview prompts as current direction.
