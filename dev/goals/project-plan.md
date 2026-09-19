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

The owner selected FG Studio developer documentation as the next increment:
sequential vignettes and pkgdown, evaluated flow/pkgnet outputs, compact agent
routes and paired maintenance guidance (ADR 0006). This does not authorize new
scientific tools or an Enterprise deployment. Human and agent development modes
must remain interchangeable as complexity grows.

The [first navigation pilot](../governance/navigation-pilot-2026-09-19.md) is
complete: both source-only and documentation-assisted runs answered the three
core questions correctly. Keep the routes/articles and their small corrections;
speed/context savings and the graph's marginal value remain unproven. The next
decision returns to the owner's choice of functional increment, not broader
documentation machinery.

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
