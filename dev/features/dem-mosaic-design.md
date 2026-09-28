# Stream DEM mosaic design

The app assembles and reuses assigned Stream DEMs serially from saved Event
settings. The supported path assembles consecutive compatible NAVD88 metre tiles,
bilinearly resamples each source-grid run onto the saved same-horizontal-CRS Event
grid, then merges in saved first/last-valid order before masking and international-
foot conversion. Source spacing/alignment may differ. Cross-CRS integration and
portable folder binding remain separate work.

This document owns the intended processing contract. Implemented behavior,
author requirements and unresolved proposals are distinguished below. Historical
test counts do not establish scientific approval of a proposed method.

## Required workflow

1. Require the analyst to define one planar horizontal analysis CRS for the Study
   Area before creating masks or DEMs. Use sf for vectors and terra for rasters.
   Store resolved WKT, identifier when available, horizontal units and definition
   provenance. Validate projected coordinates, transformation availability and
   suitability for the Study Area. Do not inherit the basemap CRS or treat an
   existing free-text analysis-reference note as a validated CRS.
2. Define Survey Event membership from Survey Collections using
   retained acquisition dates and source evidence. Retain explicit membership.
3. Require one analyst-selected output cell size per Survey Event, which may differ
   from source resolution. Define that Event grid and create a Study Area
   One/NoData mask. Derive aligned Stream and Reach masks from that mask.
4. Produce one floating-point DEM per Stream/Event from all included,
   receipt-verified tiles, using first/last overlap precedence and the Stream mask.
5. Save the recipe, masks, output and verification evidence. Downstream products
   inherit the applicable masks and grid. Publish only validated completed output.
   Reprocessing does not create another Survey Event.

FG Studio owns the analyst workflow and cancellable workers; fluvgeo owns CRS,
grid/mask construction, raster processing, validation and provenance. PROJ handles
coordinate operations, GEOS geometry operations, and GDAL underlies raster warps
through terra. No ArcGIS runtime is introduced.

## Survey Event membership and FGDB semantics

Default to **the same calendar month of acquisition**, not publication, download,
file modification or raster creation month. Current retained evidence in
`fluvgeo/R/survey_collections.R` includes USGS `collect_start`/`collect_end`, USIEI
`collectiondate`, provider IDs and raw metadata. Tile-local acquisition evidence
can refine a collection interval only when its meaning and tile link are known.

Membership policy:

- A valid acquisition interval wholly within one calendar month proposes that
  month's Survey Event membership. Retain original endpoints; a month label is not an exact date.
- Show collections, source identities, date evidence and conflicts for review.
  The project convention groups dates; it does not prove identical acquisition
  conditions or scientific compatibility.
- Multi-month/year intervals, year-only dates, missing endpoints and conflicting
  evidence remain unresolved for automatic month assignment. Do not use an
  interval midpoint, invent a first-of-month date, or merge chains of overlapping
  intervals into an increasingly long Event.
- An analyst can resolve membership using documented evidence, including one
  acquisition spanning a month boundary. Retain provider evidence and date precision; analyst rationale is optional.
  Missing year must be resolved before creating an FGDB Event.
- Stable IDs are distinct from date labels. Reprocessing changes a product edition.

No demonstrated improvement over the owner's month convention was found in the
currently retained metadata. Do not claim a better automatic classifier or infer
flight dates from GeoTIFF creation tags. Implement the conservative convention
and evidence review before considering a new temporal clustering algorithm.

FGDB requires year, permits optional month/day, prohibits day without month, and
uses non-unique YYYY/YYYY-MM labels. Its normative Survey Event is Reach-owned.
The app's Survey Event setup links Stream DEMs and Study Area, Stream and Reach
masks to applicable Reach Survey Events. Persist explicit links; do not join only on
labels or silently change FGDB ownership. Several Collections can supply an Event.

Authority: sibling FGDB `dev/schemas/conceptual-data-model.md` (Survey Event time
and accepted derivation), `dev/decisions/adr-0005-governed-foundation-scope.md`, and
`dev/decisions/adr-0012-reach-derivation-and-hierarchical-aggregation.md`.
No FGDB schema migration is performed here.

The Define a Survey Event panel persists one immutable GeoPackage per definition revision,
retaining UUID identity, reviewed selected-collection and Stream membership,
source/date evidence, required year, optional month, optional notes and positive output
cell size in the saved planar CRS's units. Existing Reach Events can be linked by
ID after parentage/date validation; the definition writer creates no Reach Events.
Revisions retain previous snapshots. The local store rejects stale study,
selection or definition state and duplicate Reach Event links across definitions.
The implementation retains its (0, 0) alignment as an internal convention.
Owner clarification (2026-09-28): no clean-coordinate requirement or analyst
anchor control is needed; resampling to the selected cell size is the practical
workflow. Existing saved grids remain unchanged.
See article 10 and sibling fluvgeo's `dev/schemas/survey-acquisition-groups.md`.
USIEI free-text formats beyond explicit ISO day/date intervals remain unresolved.

## CRS, resolution and shared grid

Preflight remains an internal metadata diagnostic, not a mounted analyst step.
It reports saved-source evidence, grid envelopes and estimates without creating
rasters. These reports do not establish coverage or scientific suitability and
are not approval prerequisites for mask creation. Article 11 and the backend
preflight schema describe the retained interface. Automatic mask preparation
validates its own geometry and settings.

Keep original files and source CRS declarations unchanged. Transform analysis
copies. Changing the selected CRS after products exist requires a new grid/product
revision and downstream invalidation, not relabeling existing coordinates.

Record source physical cell spacing with linear-unit conversion where needed:
2.5 US survey feet is approximately 0.762001524 metres, not 2.5 metres. Projection
changes cell footprints and can require interpolation; preserving nominal ground
resolution does not guarantee identical footprints everywhere. Angular units,
anisotropic/rotated grids and mixed source resolutions require explicit preflight
treatment. The analyst chooses the Event output cell size explicitly, considering
cross-Event comparisons and desired granularity. That value can be finer or
coarser than source spacing, but upsampling does not improve source information
or satisfy the existing 1 m source-suitability criterion for coarse source data.

**Owner clarification:** one Study Area CRS and fixed coordinate anchor; one
user-specified cell size per Event. All rasters within an Event share cell
boundaries. Events with equal cell sizes also share cell boundaries. Events with
different cell sizes need not share boundaries, and cross-resolution raster math
requires explicit alignment. Non-integer ratios do not create nested grids merely
by sharing an anchor. Grid persistence must store cell size in the selected CRS's
linear units and use the same anchor across Events, never independently snap each
Event to its own source tile origin. The existing (0, 0) convention remains an
internal detail, not a pending analyst decision or a scientific requirement for
round-number cell boundaries.

Mixed source resolutions are allowed through explicit resampling onto the chosen
Event grid. Report source versus output spacing and the resampling method; do not
split an acquisition into multiple Events to work around source resolutions.

## Masks and NoData

- The Study Area/Event mask uses the selected CRS and Event spacing, with its
  envelope snapped outward using the persisted Study Area anchor. Values are 1
  inside the polygon and NoData outside, including holes.
- Stream/Reach masks occupy exact subwindows of the parent grid and intersect
  parent masks, so children cannot introduce valid cells outside a parent.
- Use standard terra rasterize with touches=FALSE and native cell-center semantics.
  Reclassify background zero to NoData and apply parent rasters with crop/mask.
  No custom point-in-polygon or edge-correction algorithm is required.
- Store cropped, aligned Stream/Reach extents to limit high-resolution storage.
  Shared alignment does not mean identical stored extents; explicitly align or
  extend when an operation requires it.
- Masks define analysis domain, not observed coverage. A mask cell can be 1 while
  its DEM is NoData because no valid source covers it. Do not fill those gaps.
- Use compressed disk-backed masks/outputs and block processing. Estimate cell
  counts and disk needs; even a binary Study Area-wide mask can be very large.
  Do not allocate a full high-resolution Study Area matrix in R.
- Apply the Stream mask after projection/assembly. Preserve the source halo
  needed for interpolation; masking tiles too early can create artificial seams.
  The mask does not require acquiring elevation across the whole Study Area.

## Overlap, transformations and floating point

Apply [ADR 0009](../decisions/adr-0009-nsrs-modernization-and-explicit-vertical-operations.md):
NSRS readiness requires epoch/reference/model provenance and explicit elevation
operations. Preserve legacy declarations and prior analyst conversions; no implicit
NAPGD2022 relabeling, geoid correction or elevation-unit conversion during mosaicking.

Proposed default: **first valid value** in an explicitly saved source order,
ignoring NoData when a later source supplies a valid cell. The owner also permits
last-value precedence. Do not average/blend overlap cells or use directory order
as source priority.

Use a raster template to fix target CRS, resolution, extent and alignment. The
normal worker explicitly uses bilinear resampling for continuous elevation on the
chosen Event grid, including when source cells already coincide. Rasterize binary masks
on their template; do not bilinearly resample masks. Combine compatible neighboring
tiles before warping where needed to prevent artificial interpolation seams.

Owner-approved elevation storage: Float32 (FLT4S) by default for intermediate
and final DEMs, with explicit NoData and lossless compression. GDAL selects working
precision; no fixed Float64 working type is required. Float64 storage remains explicit
opt-in when higher-precision inputs need preservation; it is not a requirement.
Masks can be integer. Float storage does not make interpolated values identical
to source samples. Preserve zero, negative and fractional elevations; correctly
apply source scale/offset and NoData. Test precision after writing and reopening.

Horizontal normalization must not silently change vertical datum or elevation
units. Retain compound/3D CRS evidence and qualify horizontal-only operations.
GDAL can apply vertical corrections for suitable compound-CRS single-band inputs;
a horizontal target alone is not proof that elevation values remain unchanged.
Existing experimental clipping is not a qualified replacement pipeline (see
`fluvgeo/dev/features/terrain-clipping.md`).

## Execution, evidence and tests

Manifest: saved Stream/Collection selections, file IDs/receipts/hashes, geometry
revisions, Survey Event membership/date evidence, CRS WKT/units, grid anchor/resolution/extent, mask
hashes/boundary rule, source priority, resampling, datatype/NoData, vertical
handling and software versions. Preserve originals and previous successful outputs.

Stage artifacts in an attempt directory. Cancellation/failure must not expose
partial output as complete. Reopen and verify CRS, dimensions, spacing, alignment,
datatype, mask application and hashes before publishing a product edition.
Assembly remains distinct from final scientific acceptance.

Tests: independent expected values for adjacent/overlapping tiles; first-valid
precedence/NoData; holes and parent/child masks; fractional/negative/zero values;
unit conversion; CRS rejection and real projection; aligned cropped extents;
mixed-source-resolution resampling; equal-size cross-Event snapping and different
Event sizes; date precision/ambiguity; and cancellation/reopening
without partial publication. Test realistic Float32 storage rounding and optional
Float64 preservation separately from unintended elevation-unit conversion.

Owner-directed development sequence (2026-09-23): use small subsets of the actual
downloaded DEMs, not synthetic rasters. Exercise the actual mosaic worker on a
small Reach or part of a Reach for function trials, correctness checks and
parameter tuning. Use a window spanning relevant source overlap/seams and preserve the
required interpolation support. Reuse that subset for terra-function experiments
and parameter changes. Keep trial outputs temporary and separate from published
Stream DEMs. Whole-Stream validation follows a stable small-area implementation;
do not process all assigned Streams or the workspace as an iterative test harness.
Small-area results must be identified as development previews, not complete
Stream terrain or evidence of full-scale performance.

## Implemented processing and ownership

The normal Event workflow needs no development fixture or configured Stream.
`survey_event_settings_server()` supplies saved context to
`survey_event_dems_server()`, which queues assigned Streams in saved order through
one `terrain_dem_trial_job()`. Automatic masks gate readiness. A completed matching
edition is reused; success or failure advances the queue. Pause retains completed
products and stops unfinished work; resume retries only unfinished Streams.

`terrain_dem_request()` binds saved geometry, Event settings, Stream mask, vertical
target and source selection. `terrain_dem_sources()` resolves member Collections,
current file selections and acquisition receipts in saved precedence order.
Receipt reopening checks existence/size against retained transfer evidence, not a
fresh raster hash. Source identities are rechecked before publication and reuse.

One worker calls fluvgeo `mosaic_terrain_tiles()` -> `mask_terrain_mosaic()` ->
`terrain_to_international_feet()`. The mosaic call receives the saved mask as a
grid template. File-backed crops retain a two-cell halo at the larger of source
and output spacing, merge applies first-valid precedence, then native terra
bilinear resampling places the assembled surface on the exact Event grid. Mask
values are applied afterwards. Source tiles share their full CRS/elevation units
and the template's horizontal CRS. Consecutive same-grid tiles are joined before
resampling; compatible tiles separated in source priority are not reordered.
Runs outside the output extent are omitted and newly adjacent compatible runs
are joined, preventing irrelevant inputs from splitting contributing tile seams.
Every source-grid run uses the same full target template. A small-window comparison
found that independently cropping target extents changed native interpolation
weights at source-coverage edges; source reads remain bounded by the support halo.
Native first/last-valid merge combines the resampled runs without another
interpolation or overlap averaging. Source compound CRS and units survive resampling; no
coordinate or datum transformation is performed. NAVD88 metres are then divided
by 0.3048, with Float32 output and vertical EPSG:8228.
Source files and earlier successful editions are retained.

`study_dem_store()` stages and publishes immutable external GeoTIFF editions.
See [the edition schema](../schemas/survey-event-dem.md) for bindings, scope,
reopening, stale-result rejection and cleanup. The RDS index is internal; it does
not fulfill FGDB's portable folder metadata contract. Follow FGDB ADR-0025 and
its Esri findings through [R spatial processing](../workflows/r-spatial.md).

## Analyst presentation

Survey Events starts with date selection, Event Settings and Define a Survey Event.
Creation is expanded for the first Event and collapsed when saved Events exist.
One DEMs card contains Stream tabs, maps and an optional unbordered DEM details
expander. Tabs select a view, not work. No nested DEM cards, routine output badges,
Waiting/Ready notifications, preflight approval or output-download/save buttons.
Only actual processing, failure or pause produces a queue message. Details group
grid, source, storage, method and timing metadata; limited development previews
retain a plain-text scope label. Units and the NoData legend remain visible.

Masks are automatic backend dependencies. Their optional troubleshooting display
is disabled by default and is a candidate for removal after integration. Normal
preparation does not show transient boundary-progress screens.

## Verification evidence

The following measurements characterize the exercised real-data workload.
Inputs are actual downloaded Spencer Creek DEMs; diagnostic records remain under
ignored `dev/check-output/real-reach-mosaic/` and are not shipped fixtures.

| Output | Grid (rows x columns) | Recorded worker time | Independent checks |
| --- | --- | --- | --- |
| R2 development window | 192 x 256 | 8.87 s, saved-record verification | 64 sampled cells |
| Full Reach R1 | 1,353 x 1,265 | 9.27 s | 846,914 valid cells; saved/reopened |
| Mainstem Stream | 8,974 x 10,688 | 18.86 s | 80 source/mask samples including tile seam |
| East unnamed tributary | 5,631 x 3,764 | 11.44 s | 64 source/mask samples |
| West unnamed tributary | 4,525 x 3,551 | 10.16 s | 64 source/mask samples |

Mainstem has 10,890,882 valid cells. Stream samples checked conversion within
0.0001 international foot and exact NoData. The Event queue reused mainstem and
built the two tributaries serially; all three distinct editions reopened. Earlier
small-window trials verified unchanged originals and Float32 sample preservation.
These runs qualify the exercised aligned inputs, not all possible source cases.

Same-CRS resampling qualification uses the retained real seam window with 0.5,
2 and 3.3 m shifted output grids. Independent four-neighbor calculations check
64 fine-grid samples; an uncropped reference checks interpolation support at
window edges and the seam. Checks retain compound CRS, units, Float32 output and
source hashes. The actual app worker also exercises a 2 m window crossing the
saved Reach boundary, outside-mask NoData and immutable publication/reopening.
A separate 128 x 96-cell 2 m review window from original downloaded sources took
9.14 seconds in the worker. These are small-area correctness/integration results,
not a full-Stream resampling performance measurement.

Mixed-grid qualification adds 2 m mean-aggregated and shifted 1 m derivatives of
the actual seam window. Checks cover first/last precedence, interleaved grid
priorities, NoData fallback, noncontributing inputs, exact Event geometry, unchanged
sources and staging cleanup. The app worker exercises mixed inputs through mask,
conversion and immutable publication. The 128 x 96-cell 2 m mixed-grid review
window took 10.25 seconds. These are controlled derivatives of real elevations,
not independently acquired surveys or full-Stream performance qualification.

Focused UI/storage/source/queue checks cover saved reuse, one active worker,
failure retention, pause/resume and stale display exclusion. The final presentation
checks passed with known installed-package R-build-version warnings. UI acceptance
is owner feedback; it is not comprehensive browser automation or production
qualification. Continue parameter development on small actual DEM windows.

## Remaining decisions and work

- Before enabling cross-CRS execution, present feasible horizontal/vertical datum
  transformation candidates and require a saved analyst choice, even for a sole
  candidate. Record the exact selected and executed operation, not just source
  and target CRS names. Candidate applicability, accuracy, grid/model resources,
  epochs, input binding, invalidation and provenance follow the transformation
  selection contract in
  [ADR 0009](../decisions/adr-0009-nsrs-modernization-and-explicit-vertical-operations.md).
  The planning selector and immutable JSON storage are implemented under Survey
  Events > Datum transformations. Selected-pipeline execution and its binding to
  DEM editions remain unfinished. The current Event's 57 source files share one
  reference pair requiring only the supported NAVD88 unit conversion.
- Integrate cross-CRS processing separately from supported same-CRS resampling
  of mixed source spacing/alignment. The standalone
  `warp_terrain_horizontal()` primitive has no app caller; article 13 describes
  its supported operation profile. Its existence does not qualify every input.
- Other vertical references, datum/epoch changes and mixed source compatibility
  need explicit methods and provenance under ADR 0009.
- Implement FGDB portable folder metadata binding, relocation qualification and
  enterprise transfer separately from the completed local GeoTIFF edition path.
- Broader downstream L1 analysis remains outside the DEM assembly scope.

Human implementation route: [article 13](../../vignettes/dev-13-stream-dems.Rmd).
Analyst procedure: [Study workflow](../../vignettes/guide-study-workflow.Rmd).

## Shared Stream terrain direction

Process the DEM at Stream scale and let Reach analyses reference its applicable
edition and use their own spatial domains. Do not require independent DEM creation
or persistent raster copies solely because there are multiple Reaches. Temporary
windowed reads/crops are execution choices, not new governed terrain identities.

The app implements Stream assembly/reuse. Hydro-modification, explicit downstream
Reach/Event asset associations and portable delivery remain to be integrated.
FGDB's existing Reach-Survey-Event hydro DEM ownership rule needs a corresponding
revision; exact relationship tables/keys are not defined here. Preserve Reach
ownership of other derived features while separating shared raster identity and
extent from the identity of its consumers. See the storage-model article.
