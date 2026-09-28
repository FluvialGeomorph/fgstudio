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

## Implemented local hierarchy

The application supports:

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

## Terrain workflow and remaining scope

The same-horizontal-CRS DEM workflow includes:
source acquisition/viewing, saved Study analysis references, Survey Event settings,
automatic masks, serial Stream assembly, NAVD88 international-foot conversion,
immutable local GeoTIFF publication and reuse, bilinear resampling to the selected
Event cell size, and per-Stream map review. Source tiles may differ in spacing or
alignment while sharing their full CRS and elevation units. Consecutive compatible
tiles are assembled before resampling, preserving saved source priority.

Survey Events follows saved inputs. One DEMs card contains Stream tabs and optional
technical details; messages appear for processing, failure or pause. No backend
approval screens, extra source/Stream pickers or output-download/save controls.
Masks remain hidden except optional development troubleshooting.

Transformation candidate review and saved analyst selection are implemented as
a planning step before cross-CRS execution. Destination CRS selection alone
does not choose a datum transformation. Present feasible horizontal/vertical
operations with their applicability, accuracy and resource requirements; no
automatic selection, including a sole candidate. Preserve the selected and
executed pipeline in each DEM's provenance. This scientific choice is required
under [ADR 0009](../decisions/adr-0009-nsrs-modernization-and-explicit-vertical-operations.md),
and is distinct from a backend approval screen. Selected-pipeline DEM execution
remains to be integrated; existing same-CRS processing remains unchanged.

The [mosaic design](../features/dem-mosaic-design.md) owns the current processing
contract, measured real-data evidence and unresolved choices. The
[edition schema](../schemas/survey-event-dem.md) owns local persistence. The
[analyst guide](../../vignettes/guide-study-workflow.Rmd) owns UI procedure; article
13 and [agent routes](../architecture/agent-routes.md) trace implementation.

Next feature selection remains with the owner. Remaining terrain work includes
cross-CRS integration, other vertical operations, and FGDB
portable folder binding. Grid placement is an internal implementation detail;
no analyst anchor decision or clean-coordinate requirement is needed. The
standalone horizontal-warp primitive has no app caller. Preserve saved grids and
retain actionable unsupported-case failures until methods are resolved. Do not
infer authorization for a new scientific operation from this list.

Follow [R spatial processing](../workflows/r-spatial.md): native terra/GDAL,
file-backed large rasters, no arbitrary processing caps, and small actual DEM
windows for development. Full Stream runs require a specific integration question.
FGDB ADR-0025 requires filesystem GeoTIFF DEMs with GeoPackage vectors/tables and
linked metadata; the internal RDS index does not complete portable delivery.

Preserve acquisition ADR 0007 and reference/vertical-operation ADR 0009. FGDB
Survey Events remain Reach-owned; app settings retain explicit links. Do not expose
internal acquisition-group identifiers as analyst terminology.

Other pending work includes boundary import, Stream geometry editing, pre-assembly
cuts, child/Event reconciliation, downstream L1/report integration and Enterprise
authentication/edit transport. These are not an ordered implementation commitment.

Developer documentation follows ADR 0006 and the paired maintenance workflow.
Human and agent development must remain interchangeable; generated navigation is
not scientific authority. Keep local diagnostics opt-in.

## Standing safeguards

- Shared fluvgeo methods own CRS-aware geometry, scientific validation and evidence.
  Leaflet display coordinates are not the terrain analysis CRS.
- Preserve prior contexts and evidence; explicit reopening discards transient work,
  not saved records. Unsupported/missing evidence must not be guessed.
- Start the analyst preview in a fresh R process, never a test process. This
  prevents test bindings from entering the analyst runtime.
- Keep user-facing methods deterministic; development AI assistance does not
  authorize a deployed agentic service.
- The app remains a trusted, single-analyst local preview. No production client,
  shared package library or Enterprise deployment is implied.
- Existing active studies are retained. The earlier authorized retirement of four
  trial studies is not standing permission to clear current studies.

The current handoff records the local review setup and unresolved work. Measured
terrain evidence is consolidated in the mosaic feature record; do not restore
superseded development steps as standing instructions.
