# Project plan

## Goal and design authority

Let a browser user define a study and progress to desktop-equivalent L1 analysis
with less installation and conceptual overhead. Work backward from L1 Report
inputs, reuse fluvgeo, and design QGIS views alongside the Shiny workflow.
FG Studio is independent of ohwm2; neither existing apps nor the production
ArcGIS toolbox are migration test targets. The owner reviews working increments
and chooses the next functional step. Do not infer authorization for new terrain
or scientific operations from this roadmap.

Owner clarification: deliver a reviewable UI update every development turn, with
the preview refreshed and the changed controls identified. Use established
FluvialGeomorph terminology (Survey Event, Survey Collection, Stream, Reach).
Ask before introducing an unfamiliar domain concept; do not expose internal
"acquisition group" implementation names as a new analyst concept. Review the UI
backlog before adding further terrain-processing functionality.

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

## Current terrain workflow and next decision

Previous masking increment (9050/9055) applies the saved Reach mask to the real
mosaic and displays it only for the matching Survey Event. The existing horizontal
grid already matches. Source NAVD88 metres differ from the saved NAVD88
international-foot target. Increment 9051/9056 now performs that explicit conversion, with the same horizontal grid and NoData. Retain the
small real-data development loop before full Stream assembly or publication.

The next feature has begun with a deliberately small real-data trial (9049/9054):
native source-grid mosaicking of two downloaded DEM windows in part of Reach R2,
shown in an opt-in app preview. It does not publish a Stream DEM or resolve the
target-grid/vertical questions below. Continue with actual small Reach subsets,
not synthetic rasters or whole-Stream iterative tests. The mosaic design and
current handoff record the exact boundary.

FG Studio 0.0.0.9048 with isolated fluvgeo 2026.09.22.9053 implements source
acquisition and viewing, Study Area analysis references, Survey Event settings,
and automatic Study Area, Stream and Reach masks. Engineering remediation covers
the existing developer articles 06–14. See the
[remediation record](../features/terrain-gis-remediation.md) for scope, measured
worker results and verification limits; the
[current handoff](../checkpoints/current/terrain-acquisition.md) retains the
remaining review state.

Downloaded DEMs remain available across compatible metadata revisions. Selecting
a saved file starts its preview; optional integrity refresh remains available.
Saving or reopening a Survey Event prepares or reuses masks for its assigned
Streams automatically. Preflight and source-review modules are retained internal
capabilities, not mounted analyst steps or approval prerequisites.

Stream DEM mosaics, source reconciliation and vertical transformations remain
future work. The standalone horizontal-warp backend has no app caller. The
initial numeric grid alignment convention is not author-confirmed; preserve
existing grids until it is resolved. A grid's cell alignment is within the saved
real-world CRS, not a replacement CRS. Follow the
[mosaic design](../features/dem-mosaic-design.md) and
[R spatial workflow](../workflows/r-spatial.md) before further processing work.

The owner accepted tile preview/detail functionality and requested no additional
tile-preview features. UI review takes priority over extending terrain processing.
Use established Survey Event, Survey Collection, Study Area, Stream and Reach
terminology. Internal acquisition-group identifiers do not define a new analyst
entity. FGDB Survey Events remain Reach-owned; app settings retain explicit links.

Preserve ADR 0007: acquisition uses the saved Stream polygon. Source resolution
of 1 m or finer alone does not establish suitability. Preserve unknown metadata.
Study Area mid-resolution terrain and point-cloud processing are separate scopes.
Apply ADR 0009 to future reference/epoch/unit reconciliation; recording a target
does not qualify an elevation transformation or complete NSRS modernization.

Other pending capabilities include boundary import, Stream geometry editing,
pre-assembly cuts, child/Event reconciliation, terrain assembly, report integration,
L1 execution and Enterprise authentication/edit transport. Only saved-Reach
splitting is exposed from ADR 0005. These are not an ordered implementation
commitment or authorization to add scientific operations.

Developer documentation follows ADR 0006 and the
[paired maintenance workflow](../workflows/developer-documentation.md).
Human and agent development must remain interchangeable. The completed navigation
pilot supports concise routes and articles; speed/context savings remain unproven.
Use the [R package workflow](../workflows/r-package-development.md) for development
and keep live/local diagnostics opt-in.

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

Analyst UI must follow useful user outcomes, not mirror backend stages. Checks run
automatically when saved Survey Event settings determine the work; show masks for visual review
and only actionable failures with routes to correct inputs. Do not expose backend
reports, approval gates or save buttons without an identified analyst decision.

Current increment 9052 joins the existing real-window mosaic, masking and foot
conversion in one background job with cancellation and completed-result reuse.
Mask visualization is disabled by default to conserve DEM-processing resources;
its temporary developer switch is slated for removal after integration. Next,
connect this verified small-area lifecycle to durable Survey Event DEM products;
keep unresolved source/grid cases explicit and continue using real small extents.

Increment 9053 now saves and reopens the qualified Reach-portion DEM with the
Survey Event, including a GeoTIFF download in normal app sessions. This completes
the initial local publication/reopening path, not full Stream processing. Continue
with source/grid qualification and complete Stream assembly, verifying on small
real extents before any scale run. The edition schema owns current scope/guards.
