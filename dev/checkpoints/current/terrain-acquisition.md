# Resume: Source reconciliation and Stream DEM assembly

## Current state

FG Studio 0.0.0.9046 automatically prepares masks for all Streams in a saved Survey
Event. Backend fluvgeo 2026.09.21.9051 uses standard native terra raster operations;
custom per-cell geometry tests and arbitrary processing-size/time/disk-estimate
cutoffs are removed. Saved matching editions are verified and reused. The only
mask selector is for viewing completed outputs. Backend source preflight and
manual source-review controls remain unmounted. DEM mosaics are still pending.

Owner priority now is UI review before further processing. Every development turn
must provide an updated preview and exact review directions. Use established
Survey Event terminology; legacy acquisition-group API names stay internal.
9042 restores saved DEM choices after metadata-only revisions using the existing
geometry/collection compatibility check. The Survey Event tab has native choices
from saved collections, prefills known dates/associated Streams, and shows no empty
saved-event field. Do not add further functionality before addressing owner UI feedback.

The prior mask work was committed before this increment (fgstudio 7e1c36e,
fluvgeo e62c6cf); both repositories started clean on main. New qualification code
and documentation are uncommitted. Only the app's isolated backend library was
upgraded. Existing analyst sessions were not restarted. No analyst study
or original source asset was used as a development fixture.

## Implemented foundation

- Study hierarchy, collection selection, original DEM acquisition, receipts and
  inspection are available. No further tile preview work is requested.
- Horizontal CRS and structured vertical target/epoch metadata are saved. No
  vertical operation, datum migration or elevation-unit conversion is enabled.
- Immutable acquisition groups retain membership, dates, spacing and optional
  existing Reach Event links. FGDB Reach-owned Event identities are unchanged.
- Preflight verifies current source/group evidence and reports metadata issues
  and grid estimates. PASS is never execution approval or coverage acceptance.
- Review DEM sources is available below preflight in Event setup. App-owned JSON
  editions retain all verified file identities/hashes and analyst decisions.
  Unknowns remain explicit; grid issues are never cleared by annotations. Source
  rasters must be rehashed at execution; annotation saving only rechecks metadata.
- Masks share the zero anchor and Event spacing, use strict center membership,
  exclude exterior/hole boundary centers and intersect parent NoData. Missing
  Reach polygons block a family; no-Reach Streams produce two masks. Publication
  checks current inputs and preserves previous editions. The UI has no persisted
  edition browser yet; backend read_event_masks verifies saved families.
- warp_terrain_horizontal admits static east/north projected CRSs with the same
  identified, semantically equivalent 2D geodetic base and one exact grid-free
  operation. It retains full compound source evidence, uses a separate horizontal
  processing definition and explicit -novshift, and preserves elevation units.
  Aligned outputs undergo exact comparison at the chosen storage precision; other
  grids use bilinear interpolation. Float32 storage is the owner-approved default;
  Float64 working precision is independent, and Float64 storage is explicit opt-in.
  App preflight reports Float32 storage estimates. Hashes, metadata and
  pixel readability are checked before verified.json is written last.

The installed GDAL control converts a synthetic US-survey-foot compound source
from 123.123456789 to about 37.5281 with a 2D metre target. The guarded primitive
preserves the original value. This is a real local-library qualification result,
not proof of vertical-datum accuracy or source acceptance.

## Boundaries for the next step

Read the R-development workflow, mosaic feature, ADR 0008 and ADR 0009. Follow
sibling fluvgeo's AGENTS and backend assessment workflow. Source vertical/unit
compatibility and prior manual conversions remain unresolved. The qualified warp
refuses datum/epoch changes, ensembles, bound/angular/3D definitions, external
sidecars, rotated or anisotropic grids and nonidentity scale/offset. It does not
validate projection suitability, assemble tiles, apply mask pixels or certify
coverage. No NGS/NSRS modernization or geoid operation has been qualified.

Revalidate all current revisions, receipts and hashes at execution. Do not reuse
preflight PASS as approval. Assemble compatible neighboring tiles with an
interpolation halo before warping, retain explicit first/last-valid source order,
and apply the Stream mask after assembly. Preserve zero, negative, fractional
elevations at Float32 storage precision. Use explicit Float64 only when justified
by higher-precision sources. Missing coverage remains NoData; do not fill it implicitly.

Mask families default to 50 million cells. The horizontal primitive defaults to
50 million combined source/output cells. Both limit row width to 65,536 columns
and check available disk space without reserving it. GDAL warp/cache are each
limited to 64 MiB, not a total process-memory guarantee. Large-study performance
and live-provider compatibility remain unqualified. Failed attempts are retained
without a verified manifest; callers must check current revisions before publishing.

## Evidence and routes

App 9041 adds tested review persistence, reopening, source ordering, stale-edition
and pending-edit guards. Final verification and preview details are recorded in
the mosaic feature. Browser-tool attachment failed during the synthetic visual
check; do not claim that browser interaction was verified from this session.

Focused backend tests passed 150 assertions, including 55 horizontal-warp assertions
covering default Float32, optional Float64, storage rounding/range checks,
the default-warp control, NoData preservation, independent
bilinear expectations, real reprojection, horizontal feet, cropped/extended
windows, stored coordinate epochs, refusal paths, input mutation and failed verification. Final package,
app and site check results are recorded in the mosaic feature.
Legacy backend tests/examples are not run automatically: report scripts can write
outside temporary fixtures and optional gt/fluvgeodata are unavailable here.

- dev/features/dem-mosaic-design.md: owner requirements and current verification.
- dev/decisions/adr-0008-study-analysis-crs-and-terrain-masks.md: grid/mask rules.
- dev/decisions/adr-0009-nsrs-modernization-and-explicit-vertical-operations.md:
  source/reference/epoch and explicit-operation boundaries.
- vignettes/dev-13-horizontal-warp.Rmd and dev/architecture/agent-routes.md:
  paired navigation; no app call-map bridge exists until there is a real caller.
- Sibling fluvgeo R/warp_terrain_horizontal.R,
  tests/testthat/test_warp_terrain_horizontal.R and
  dev/schemas/horizontal-terrain-warp.md: qualified primitive and exact contract.
- R/event_masks.R and R/study_store.R: current worker/publication pattern.
- Sibling fluvgeo R/event_masks.R and dev/schemas/event-masks.md: mask verification.
- R/stream_dem_preflight.R and sibling fluvgeo R/preflight_stream_dem.R:
  current source screening and shared grid/group validation.
- R/terrain_source_review.R, tests/testthat/test-terrain-source-review.R,
  dev/schemas/terrain-source-review.md and article 14: saved analyst review workflow.

Preserve all .local-data studies, source assets and previous editions. No commit,
production backend upgrade, FGDB migration or deployment is part of this increment.
A fresh local preview may be started separately to expose the new app controls.
The 9042 preview was restarted in a fresh process at http://127.0.0.1:8781 using
the existing .local-data store and isolated backend; HTTP startup returned 200.
Its launcher is the ignored dev/check-output/run-9041-preview.R (loads current
source); R_CACHE_ROOTPATH points to dev/check-output/r-cache. Review DEM files and
Define a Survey Event first. No real-study review or raster was saved by the agent.
211 focused assertions and 431 documentation links passed for the UI correction.
All 57 existing source DEMs also passed read-only receipt checksum verification.

Define a Survey Event is now a main Study Area tab immediately after Analysis setup.
Analysis setup provides a Continue to Define a Survey Event button. The event form
has no membership/date rationale field or save requirement; provider date evidence
is retained automatically, and older analyst notes survive edits.

9043 verification: 175 focused app assertions and 23 backend assertions passed;
Study module tests passed again after updating the Next hint. Documentation built
and 431 local links passed. Bounded backend R CMD check (tests/examples excluded)
finished with zero errors, one existing non-ASCII warning and two existing notes.
Browser attachment timed out; HTTP 200 confirmed the main event module and Continue
button, with no old nested event module. No analyst records were changed.

The preflight startup failure was reproduced as Windows access denied creating
processx supervisor pipes in the sandbox. The identical read-only worker succeeded
outside the sandbox. Launch the preview with worker permission. UI 9044 separates
worker errors (with technical details) from completed REVIEW/BLOCKED reports.
Saved 2019 sources return REVIEW; the saved 2008 event needs a DEM acquisition plan.
Analyst records were read only during diagnosis.

9045 supersedes the manual preflight/source-review UI: neither module is mounted.
Create masks automatically validates geometry/CRS/grid/resources, writes and verifies
masks, and displays the saved rasters with boundary overlays. User approval of
backend diagnostics is not required. DEM data are not mask prerequisites. No
backend methods or existing analyst records were changed in this UI increment.

PAUSED for owner GIS guidance: source edits are uncommitted and not yet loaded into
the analyst preview. Do not resume scientific implementation before incorporating
the owner's additional guidance. The already-running end-to-end verification
completed for all three Streams in each of the two saved Events at unchanged 1 m
spacing (about 79 seconds per Event). New mask editions were published; saved
study/Event input checksums were unchanged. Backend isolated library is 9051.
App preview session 30094 is still the earlier 9045 UI; source 9046 automatic
preparation is not yet in that preview. Backend focused mask tests passed (26),
app mask orchestration/display tests passed (25). Remaining review includes saved
output reuse, final docs/metadata consistency, and owner-approved preview refresh.
