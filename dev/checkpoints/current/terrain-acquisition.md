# Terrain workflow: current handoff

FG Studio 9069 / isolated fluvgeo 9061. The app uses bslib's Bootstrap 5 Flatly
theme and standard tabs consistently, including the Study Workspace sidebar.
Study navigation includes CRS. The owner directed practical resampling to
the selected Event cell size; cell-boundary anchor controls and clean-coordinate
requirements are unnecessary. Same-horizontal-CRS bilinear resampling is integrated
after compatible source-tile assembly and before masking/foot conversion. Mixed
source cell sizes and alignments now use ordered source-grid runs on the same
Event template; source CRS and elevation units must still agree.

Survey Events automatically checks references and displays Datum transformations
only when a datum choice is required. Same-datum projection, grid and unit changes
hide the controls; distinct realizations remain subject to review. It discovers reference-pair candidate
operations and stores explicit analyst choices in immutable JSON plans. The
selector never preselects an operation. Missing grids, ballpark and epoch-dependent
operations are unavailable. Matching references and the existing NAVD88 unit-only
case record no datum change. Execution of the selected pipeline remains pending.

## Resume from maintained owners

- `dev/goals/project-plan.md`: accomplished scope and next owner decision.
- `dev/features/dem-mosaic-design.md`: scientific contract, implementation limits,
  consolidated real-data measurements and remaining source/vertical compatibility.
- `vignettes/guide-study-workflow.Rmd`: current analyst procedure.
- `vignettes/dev-13-stream-dems.Rmd` and `dev/architecture/agent-routes.md`:
  processing call paths. Articles 11/12/14 cover inputs, masks and editions; terrain-developer-tools.Rmd covers standalone diagnostics.
- `dev/schemas/survey-event-dem.md`: local edition format and lifecycle.

## Local review setup

Preview: http://127.0.0.1:8800/?study=85fbe60be7c1f957bf3d5f3e9e41f401
Launcher: `dev/check-output/run-dem-tabs-preview.R` (ignored local aid).
Select Survey Events, 2019-12, then a Stream tab. Mainstem and both tributaries
already have saved GeoTIFFs; routine review must reuse them. No development target
or mask-diagnostic option is needed. DEM details distinguish previous aligned
editions from new bilinear editions and report mixed source/output spacing.

The owner requires all future reviews in the whole app with normal navigation
and saved Study context. Port 8801 also serves the whole app, launched with ignored
`dev/check-output/run-whole-app-preview.R`. Open the Study link with the same
`study` parameter, then Survey Events and 2019-12. Datum review sits before mask
and DEM preparation; the actual references match, so its controls remain hidden.
A brief checking message provides feedback during discovery. The previous
standalone dropdown screen is retired as an owner-facing preview.

Use the isolated `dev/local-library` and workstation instructions. Diagnostic
records under ignored `dev/check-output/real-reach-mosaic/` include
`feet-result.rds`, `full-reach-result.rds`, `full-stream-result.rds` and
`event-queue-result.rds`. Use actual small windows for further method development,
not repeated whole-Stream/workspace builds. Do not install over shared fluvgeo.

## Remaining work

Next: qualify and integrate execution of the explicitly selected pipeline and
bind verified horizontal/vertical operation provenance to resulting DEM editions.
The first bounded execution check is retained in fluvgeo's
`test_terrain_selected_operation_execution.R`: an exact unit-conversion pipeline
preserves values/NoData, but direct GDAL GeoTIFF output has a stale band-unit label.
A warped VRT plus explicit target CRS/unit metadata during final materialization
passes the check. Datum shifts and full worker integration remain unqualified.
ADR 0009 owns the scientific contract. `terrain-transform-plan.md` and sibling
fluvgeo `terrain-transform-candidates.md` specify implemented planning. The actual
Event has 57 selected sources and one reference pair needing no datum change.

Cross-CRS integration, other vertical operations and
FGDB portable folder binding remain open. Do not move saved grids
or infer a new scientific method from existing code. The horizontal-warp primitive
has no app caller. External GeoTIFF DEMs remain mandatory under FGDB ADR-0025;
GeoPackages hold vectors/tables, and edition.rds is only an internal index.

This increment changes fgstudio and the sibling backend; only the isolated
fgstudio development library is updated. No commit, deployment or data retirement
is implied. Earlier recipe-v1 aligned and v2 single-grid resampled editions remain
reusable on identical inputs;
read-only checks matched all three actual Stream editions. Recipe versions use
R's canonical packageVersion spelling (for example, 2026.9.24.9057).

Conditional review checks pass: 35 backend assertions and 104 app assertions
(two installed-package R-build-version warnings). Explicit choice and saved-plan
restoration are covered by module tests; the datum example has missing-grid and
ballpark candidates, neither selectable. Both preview URLs serve fresh processes;
browser automation timed out. Previous resampling qualification passed 96 backend
and 108 app assertions; the mixed-grid review worker took 10.25 seconds.
The previously run broader app suite retains an unchanged
case-sensitive test expecting `Vertical reference` while the UI says `Vertical
Reference`; neither source nor test was changed by this increment. The full
backend suite needs unavailable ArcGIS credentials and local GDB fixtures.
CRS tab markup checks pass. The affected Event/request tests passed 56 assertions
with one stale fixture-path failure: the opt-in Reach fixture points to an older
mask edition than the current saved mask. No analyst mask was replaced by the
test. The bounded explicit-operation execution qualification passes 8 assertions.
The documentation site rebuilt and its local links passed verification.
The prior backend 9060 archive checks (tests/examples/vignettes/manual skipped; optional
suggestions not required) completed with no errors, one unchanged non-ASCII
source warning and two notes. Targeted terrain and app tests ran separately.
