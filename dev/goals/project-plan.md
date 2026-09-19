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

Resumed on 2026-09-19 after owner acceptance of the download-review UI.
The owner approved the [download design](../features/dem-download-proposal.md).
It is implemented in fgstudio 9028 / fluvgeo 9038 and verified through synthetic
tests and a bounded live source download. Detailed check limits are in the
[feature record](../features/stream-dem-files.md). See the
[acquisition checkpoint](../checkpoints/current/terrain-acquisition.md) for context.

Implemented through fgstudio 9027 / fluvgeo 9037 (committed at resumed inspection):

- Study Area-scoped Survey Collection discovery, selection and saved product plans.
- Stream-scoped DEM file discovery for supported USGS source directories, with
  shared map, Select all/Clear, scrollable tile controls and details.
- Immutable saved file choices and compatible offline reopening.
- Compact Download review: counts, reported sizes, missing/coarse resolution and
  saved state. Empty results explain Stream versus Study Area scope.

New increment: explicit, cancellable download of saved DEM file choices with
original-source evidence and failure-safe local storage. Sequential transfers,
immutable receipts, checksums, offline verification and retry are implemented.
Next review is owner acceptance of the working download UI. Subsequent terrain
inspection needs its own owner-led design; no mosaic, reprojection, clipping,
suitability acceptance or Survey Event creation is implied.

Acquisition AOI is the saved Stream polygon, not the full Study Area. Target
Stream Survey Event terrain; derive Reach DEMs only if needed. Physical Reach DEM
persistence and Stream-level survey identity/linkage remain design questions.
Future Study Area DEMs may serve mid-resolution watershed analyses; do not scaffold
their storage or broaden high-resolution acquisition now. Point-cloud processing
and Reach Survey Event assignment remain future steps.

Owner clarification: iterative discovery → acquire → inspect → revise is required,
not a one-way wizard. DEMs must be 1 m or finer, but still need suitability review.
A Survey Event may use several distributed Survey Collections. See
[ADR 0007](../decisions/adr-0007-iterative-terrain-acquisition.md) for requirements
and the explicit implemented/future boundary.

Owner-selected functional slice: discover and select **Survey Collections** for
later acquisition/processing, not manual event entry. Distinguish FGDB Collection
(Study Area container) and Reach Survey Event. See the
[feature boundary](../features/survey-collections.md).

The preceding FG Studio developer-documentation increment is complete:
sequential vignettes and pkgdown, evaluated flow/pkgnet outputs, compact agent
routes and paired maintenance guidance (ADR 0006). This does not authorize new
scientific tools or an Enterprise deployment. Human and agent development modes
must remain interchangeable as complexity grows.

The [first navigation pilot](../governance/navigation-pilot-2026-09-19.md) is
complete: both source-only and documentation-assisted runs answered the three
core questions correctly. Keep the routes/articles and their small corrections;
speed/context savings and the graph's marginal value remain unproven. Functional
development has resumed with the Survey Collection slice above.

Approved design not fully implemented: pre-assembly piece cuts and Stream
splitting use the shared lineage model in [ADR 0005](../decisions/adr-0005-custom-segment-editing.md).
Only saved-Reach splitting is currently exposed. Child/event reconciliation
requires a separate reviewed workflow; unsupported dependencies must still block.

Other remaining scope: boundary import, spatial Stream editing/removal, multiple
names-only Stream area assignment, cross-Stream overlap/network acceptance policy,
Survey Event and terrain UI, durable report integration, L1 execution and Enterprise
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
