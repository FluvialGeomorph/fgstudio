# Stream DEM mosaic design

Current state: FG Studio 9051 / isolated fluvgeo 9056 retains source acquisition,
viewing, analysis references, Survey Event settings and automatic masks, and adds
the small real-data mosaic and saved-Reach-mask trial described below.
Full Stream DEM mosaic execution remains pending. The standalone horizontal-warp
primitive has no app caller. See the [remediation record](terrain-gis-remediation.md)
for the completed engineering corrections across steps 06–14 and their limits.
Tile preview/detail functionality is accepted; further tile-preview features are
not a prerequisite to assembly.

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

Implemented settings policy (9037/9045):

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
ID after parentage/date validation; this increment creates no Reach Events.
Revisions retain previous snapshots. The local store rejects stale study,
selection or definition state and duplicate Reach Event links across definitions.
The implementation uses a (0, 0) grid-alignment anchor within the saved real-world CRS. The specific alignment convention remains unconfirmed; do not interpret it as an arbitrary CRS or move saved grids automatically.
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
Event to its own source tile origin. Proposed fixed anchor: (0, 0) in analysis CRS.

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

Use a raster template to fix target CRS, resolution, extent and alignment. Avoid
interpolation for aligned sources. When projection/alignment requires it, use
explicit bilinear interpolation for continuous elevation. Rasterize binary masks
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

## Implemented masks and pending assembly

Previous masking increment (9050 / fluvgeo 9055): `mask_terrain_mosaic()` applies the saved
Reach mask to the existing small real-data mosaic with native terra crop/mask.
CRS horizontal components, spacing and cell alignment match the saved Event grid;
no resampling is needed. The DEM retains its compound NAVD88 CRS and metre unit,
while the membership mask retains its 2D CRS. terra's warning about the full-CRS
difference is covered explicitly by the real-data test, not handled by stripping
or reassigning CRS metadata. The saved Study Area target is NAVD88 international
feet; increment 9051/9056 now converts the masked result with metres / 0.3048 and records vertical EPSG:8228. Matching study and
Event identities control display. Original downloads and published masks remain
unchanged; the result is still a development trial, not published Event terrain.

The real 192-by-256-cell window retains 30,205 valid elevation cells after masking.
Worker elapsed time was 8.83 seconds including startup. Nine real-data backend
assertions and eight UI assertions passed, including wrong-Event display exclusion.
The existing Shiny build-version warning remains. Input checksums matched and the
rendered masked plot was inspected. Full Stream processing was not run.

First real-data mosaic increment (9049 / fluvgeo 9054): the backend now exposes
`mosaic_terrain_tiles()` for compatible source-grid tiles. FG Studio's
`launch_terrain_mosaic_trial()` runs it in a separate process. An explicitly
configured `fgstudio.mosaic_trial` result path enables a read-only development
preview under Define a Survey Event, after Analysis masks; ordinary sessions do not show it or dispatch
new terrain work. The result is a small portion of a Reach, not a published
Stream/Survey Event product. This increment retains native source alignment and
does not resolve the future analysis-grid convention or vertical reconciliation.
See article 13 for the trial route and the backend terrain-tile-mosaic contract.

Measured first trial: two original Float32, metre-valued, EPSG:6344 source windows
across a tile boundary in Spencer Creek mainstem Reach R2 produced a 192-by-256
cell mosaic at native 1 m spacing. Worker elapsed time was 9.51 seconds including
startup. Eight opt-in backend assertions passed using real source samples and
unchanged input checksums; five app assertions passed with an existing Shiny
R-build-version warning. Original download hashes matched before/after the actual
worker. The plot and Shiny render were checked. These adjacent windows establish
joining and sample preservation, not conflicting-overlap policy qualification,
full-scale performance or scientific acceptance. No saved products were replaced.
The paired article and generated call map were refreshed; freshness/bridge checks
and 435 local documentation links passed. This increment used focused real-data
tests and package installation, not the full legacy backend suite or a new
full-package check. Existing unrelated working-tree documentation edits were retained.

Saving or reopening Survey Event settings prepares masks for all assigned
Streams automatically. The optional developer map selector chooses a completed mask to view; normal sessions omit it.
There is no Stream processing picker, Create masks button, or manual preflight
approval. Optional notes are not a save requirement.

fluvgeo uses native terra operations and compressed file-backed Byte GeoTIFFs.
Shared Study Area masks and unchanged geometry/grid/recipe outputs are reused.
Publication consolidates native summaries and checksums; managed reopening uses
metadata checks rather than repeated raster scans. Workers prepare cached display
rasters. Cancellation/failure stops the worker before removing owned staging;
recorded abandoned jobs are reclaimed only after their owners exit. Older saved
outputs retain compatibility. No arbitrary cell, row, file-size or duration
admission rule is introduced. Article 12 and the backend event-masks schema own
the exact interfaces.

The horizontal-warp primitive uses native summaries and GDAL-selected working
precision with Float32 default storage. Explicit horizontal-only controls retain
source vertical evidence and prevent unintended elevation conversion. Affine
source rotation and unequal spacing are supported. Remaining external
georeferencing/mask, scale/offset and datum/epoch restrictions are this API's
scope, not universal GIS limitations. See article 13 and the backend
horizontal-terrain-warp schema.

Before enabling Stream DEM assembly, resolve source reference/unit compatibility,
source precedence and the initial grid convention, then bind current sources and
masks to a cancellable worker. Retained source-review annotations (article 14) are
not currently exposed and do not authorize a raster operation.

The specific numeric grid anchor is not author-confirmed. Legacy toolbox steps
snap to an input DEM; that does not identify a canonical first grid for the new
cross-Event design. Preserve saved grids until the convention is resolved.
Coordinates such as (0, 0) describe cell alignment inside the real-world CRS,
not an arbitrary replacement CRS.

Primary API references retained from the design review:
[sf transformations](https://r-spatial.github.io/sf/reference/st_transform.html),
[terra projection/templates](https://rspatial.github.io/terra/reference/project.html),
[terra rasterization](https://rspatial.github.io/terra/reference/rasterize.html),
[terra raster writing](https://rspatial.github.io/terra/reference/writeRaster.html),
and [GDAL warp](https://gdal.org/en/stable/programs/gdalwarp.html).
Use installed help and the R spatial workflow when implementing these operations.

Owner UI correction (2026-09-23): review DEM results in Survey Events,
after Event settings, rather than a top-of-app development panel. The current
trial renders only for its saved Study Area. Use portable ASCII separators in
these labels to avoid Windows locale substitutions such as <U+00D7>.

International-foot increment (9051 / fluvgeo 9056): native terra arithmetic
converts the existing masked real window using the exact 0.3048 metre/foot
factor. Horizontal EPSG:6344 coordinates and the 1 m grid remain unchanged;
vertical CRS becomes EPSG:8228. Elevation range is 669.9174–712.9763 ft.
Worker time was 11.76 seconds including startup. Eleven backend assertions and
seven app assertions passed. The bounded sample comparison includes Float32
rounding and NoData; source hashes remain unchanged. Source-test CRS assignment
emitted PROJ database warnings despite successful reopened CRS/unit checks.
The converted plot was visually inspected. Full Stream scale was not exercised.
Study Workspace now uses bslib's collapsible sidebar; the bordered main tabs are
Geometry, Collections, Analysis and Survey Events. The result remains an opt-in
small real-data trial, not a published Survey Event DEM.

## Integrated small Reach DEM job (9052)

Normal sessions hide mask troubleshooting and pass no display-cache directory to
mask workers. They do not prepare overview rasters, load mask selector labels or
render mask maps. Compact preparation progress and actionable errors remain.
Developers may set `options(fgstudio.mask_diagnostics = TRUE)` before startup.
This temporary UI hook is intended for removal after DEM integration; analytical
mask generation/reuse remains a backend dependency. The owner verified the native
bslib sidebar collapse; do not add custom collapse logic or extensive tests.

With the development options `fgstudio.dem_trial = TRUE`, `fgstudio.mosaic_trial`
pointing to the existing real fixture, and `fgstudio.dem_trial_cache` naming an
existing developer-owned directory, selecting the matching saved Event runs one
background job: native source-grid mosaic, saved Reach mask, then international
feet. The three existing fluvgeo primitives retain their scientific contracts.
No additional analyst steps or scientific choices are introduced.

`terrain_dem_trial_job()` manages cancellation, stale context exclusion and
session shutdown. Each job has a unique directory. A completed result index is
written only after the worker returns and the saved input snapshot still matches.
The recipe includes source/mask/context/Event paths, sizes, modification times,
overlap order, backend version and units. This is a local development cache,
not a cryptographic integrity check or production Survey Event publication.
Matching completed outputs are reopened without rerunning raster processing.
Failed/cancelled staging is removed only after the worker stops. Completed trial
outputs remain for development review; there is no production cache lifecycle yet.

Verification of increment 9052: 37 mask assertions, 7 preview assertions and 12
job-lifecycle assertions passed. The actual combined worker took 9.76 seconds;
64 sampled outputs match the previous real DEM including NoData. Reopening
reused the completed result with unchanged modification time. Source checksums
are unchanged. Full Streams and synthetic raster fixtures were not processed.

## Saved Survey Event DEM editions (9053)

`study_dem_store()` now adds immutable local editions beneath the Study directory.
The combined job publishes only while its saved binding remains current. Existing
verified trial output is copied in a worker; raster computation is not repeated.
Normal app sessions can reopen, display and download saved GeoTIFFs without the
trial options or cache. The DEM card clearly labels this result as a Reach portion.
It does not claim a complete Stream DEM. The exact storage/lifecycle contract is
in `dev/schemas/survey-event-dem.md`; `tests/testthat/test-study-dem-store.R` covers
real-file publication, fresh reopening, download equality, staleness and cleanup.
Full Stream assembly and publication remain the next integration scope.
