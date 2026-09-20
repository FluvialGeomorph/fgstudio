# Project plan

## Goal and design authority

Let a browser user define a study and progress to desktop-equivalent L1 analysis
with less installation and conceptual overhead. Work backward from L1 Report
inputs, reuse fluvgeo, and design QGIS views alongside the Shiny workflow.
FG Studio is independent of ohwm2; neither existing apps nor the production
ArcGIS toolbox are migration test targets. The owner reviews working increments
and chooses the next functional step. Do not infer authorization for new terrain
or scientific operations from this roadmap.

## Accomplished: local study hierarchy (9022)

As reviewed on 2026-09-18, the working tree implements:

- Durable Study Area creation/reopening, editable name and Purpose; drawn or
  selected watershed boundaries with explicit save and child-area checks.
- Cancellable drainage discovery, lightweight NHDPlusV2 reference display,
  named candidate lists, service-outcome feedback and compact responsive mapping.
- Streams assembled from selected flowlines: clip lines to Study Area, buffer
  retained lines, clip area to Study Area, preserve source evidence, repeat.
- Reaches assembled from one or more retained segments/pieces, inheriting Stream
  buffer settings; combine saved same-Stream Reaches or split a supported saved
  Reach at a snapped map point, with explicit identity and provenance handling.
- Stream/Reach renaming; downstream-to-upstream candidate ordering; View-mode
  labels/popups, selection zoom and a nested saved inventory. Reach rename lists
  display Stream / Reach and sort by Stream first, then Reach.

The owner explicitly accepted the Stream, Reach creation/combination, rename and
split interactions and now describes the app as very functional. This is user
acceptance, not a claim of comprehensive browser automation or production readiness.
See [the documentation review](../governance/documentation-review-2026-09-18.md)
for evidence, test-version boundaries and the current uncommitted-work caveat.

## Current task and next decision

The 2026-09-20 documentation orientation pass places FG Studio within the wider
project and separates analyst guidance from the retained developer/context-routing
layer. See [documentation audiences](../features/documentation-audiences.md).

Package development follows the current
[R workflow](../workflows/r-package-development.md). JavaScript contracts use the
package test entry point; existing custom execution wrappers still need review
against standard R facilities. Live/local diagnostics remain opt-in.
This does not change the next functional step or authorize new scientific work.

Latest increment (9036/9044): CRS documentation and save/reload feedback are
implemented after owner acceptance of the compact UI. Both target definitions
are persisted in immutable revisions; reload now reopens the tab's saved study.
See the [CRS documentation review](../governance/documentation-review-2026-09-20.md)
and feature records for verification. Study Area vertical target specification is
implemented, with structured epoch/model/unit fields in context schema 7 and
metadata-only save/reopen. Both CRS dropdowns escape clipping containers.
See [vertical reference](../features/vertical-reference-design.md) for the exact
implemented boundary. Source compatibility, qualified coordinate operations and
epoch export are still future work; Event membership/cell-size setup is next.

2026-09-20 owner review: refine the horizontal form, remove manual Recorded by/Why
requirements and fix false pending acquisition edits when opening a saved study.
Implemented in 9034; qualification is recorded in the analysis CRS feature.
That vertical specification is implemented in 9035 before Event membership/output cell size.
The [vertical/epoch design](../features/vertical-reference-design.md) records the
implemented target and remaining source/export metadata contracts, with NGS/PROJ/GDAL guidance.
This is specification work; no new vertical operations are enabled.

All CRS work must prepare for NSRS modernization (NATRF2022, NAPGD2022,
SPCS2022). [ADR 0009](../decisions/adr-0009-nsrs-modernization-and-explicit-vertical-operations.md)
records epoch/reference/unit provenance, preservation of legacy sources and explicit
analyst-directed elevation operations. Current validation is not complete modernized
NSRS support; qualify the installed PROJ/GDAL stack and resources before execution.

2026-09-20 refinement: improve CRS selection before moving to Event settings.
The owner wants guided discovery rather than a blank text box, using
SpatialReference.org and EPSG identifiers while preserving planar analysis.
See [CRS discovery design](../features/crs-discovery-design.md) for verified
Explorer links/catalog behavior and limitations. The guided local PROJ picker is
implemented in 9033/9043, including coverage/unit filters and authoritative links.
Epoch-dependent frames remain exploration-only until explicit epoch handling is
qualified. Vertical target specification is now implemented; Event settings follow.

The owner accepted the DEM tile preview/detail tools on 2026-09-19 and explicitly
requested no more tile-preview functionality. The next direction is Stream DEM
mosaicking. The acquisition/inspection foundation is ready for that design;
compatibility of the complete intended source set is not yet established.

The owner has now specified a mandatory Study Area planar CRS, same-month
acquisition grouping, one DEM per Stream/Event, first/last overlap handling,
user-selected Event output cell size, Stream NoData masking, shared alignment and hierarchical
Study Area/Event, Stream and Reach masks with floating-point processing.
Read [Stream mosaic design](../features/dem-mosaic-design.md) and
[ADR 0008](../decisions/adr-0008-study-analysis-crs-and-terrain-masks.md).
CRS selection/validation and guided discovery are implemented in 9033/9043; see
[Analysis CRS](../features/study-analysis-crs.md). Each Event has one user-selected
output cell size, possibly different from its sources. One Study Area grid anchor
ensures identical cell boundaries across equal-size Events. Different-size Events
need not share boundaries. After vertical specification, implement acquisition grouping and required Event
cell-size selection, followed by masks and execution. Mosaics/masks are not yet
implemented.
No source transformations have run.

Current accepted foundation (fgstudio 9031 / fluvgeo 9041):

- Study Area Survey Collection discovery and saved acquisition plans.
- Stream-scoped DEM file choices, original downloads, immutable receipts and
  checksum-verified reopening/reuse.
- Cancellable metadata inspection, tile overview and native source-window detail.

[DEM inspection](../features/dem-inspection.md) retains verification evidence and
historical increments. Download work is committed at fgstudio cf47b8b / fluvgeo
a378771; inspection changes remain uncommitted on main in both repositories.
The [current handoff](../checkpoints/current/terrain-acquisition.md) is consolidated
for mosaic design, rather than retaining multiple competing next-preview steps.

Preserve ADR 0007: acquisition uses the saved Stream polygon; the eventual Stream
Survey Event terrain may draw on multiple Survey Collections. Source DEMs must
be 1 m or finer, but pixel size alone does not establish suitability. Unknown
metadata remains unknown. FGDB Reach Event ownership is preserved through explicit
acquisition-group links; physical Reach DEM persistence remains a design question.
Study Area mid-resolution terrain and point-cloud
processing are separate future scopes. Do not add more tile-preview functions as
an assumed prerequisite to mosaicking.

The preceding FG Studio developer-documentation increment is complete:
sequential vignettes and pkgdown, evaluated flow/pkgnet outputs, compact agent
routes and paired maintenance guidance (ADR 0006). This does not authorize new
scientific tools or an Enterprise deployment. Human and agent development modes
must remain interchangeable as complexity grows.

The [first navigation pilot](../governance/navigation-pilot-2026-09-19.md) is
complete: both source-only and documentation-assisted runs answered the three
core questions correctly. Keep the routes/articles and their small corrections;
speed/context savings and the graph's marginal value remain unproven. Its original
next-step direction is historical; use the current task above.

Approved design not fully implemented: pre-assembly piece cuts and Stream
splitting use the shared lineage model in [ADR 0005](../decisions/adr-0005-custom-segment-editing.md).
Only saved-Reach splitting is currently exposed. Child/event reconciliation
requires a separate reviewed workflow; unsupported dependencies must still block.

Other remaining scope: boundary import, spatial Stream editing/removal, multiple
names-only Stream area assignment, cross-Stream overlap/network acceptance policy,
Survey Event and terrain-assembly UI, durable report integration, L1 execution and Enterprise
authentication/edit transport. Backend availability is not app availability.
These are future capabilities, not an ordered implementation commitment.

## Standing safeguards

- Shared fluvgeo methods own CRS-aware geometry, scientific validation and evidence.
  Leaflet display coordinates are not the terrain analysis CRS.
- Preserve prior contexts and evidence; explicit reopening discards transient work,
  not saved records. Unsupported/missing evidence must not be guessed.
- Start the analyst preview in a fresh R process, never a test process. This
  preserves the lesson from the 9015 leaked-test-double containment failure.
- Keep user-facing methods deterministic; development AI assistance does not
  authorize a deployed agentic service.
- The app remains a trusted, single-analyst local preview. No production client,
  shared package library or Enterprise deployment is implied.
- Existing active studies are retained. The earlier authorized retirement of four
  trial studies is not standing permission to clear current studies.

Historical increment evidence remains in the feature records and ADRs; dated
"next" statements there describe their original slice, not the current plan.
