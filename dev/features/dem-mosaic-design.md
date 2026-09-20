# Stream DEM mosaics and analysis masks

Status: owner requirements clarified, 2026-09-19; CRS selection implemented in
9032/9042. Event settings, masks and mosaic execution remain pending.
Supersedes the earlier compatible-source-grid-only proposal. Tile preview/detail
is accepted and complete. See `study-analysis-crs.md` for implemented CRS behavior.
No masks or mosaics have been executed.

## Required workflow

1. Require the analyst to define one planar horizontal analysis CRS for the Study
   Area before creating masks or DEMs. Use sf for vectors and terra for rasters.
   Store resolved WKT, identifier when available, horizontal units and definition
   provenance. Validate projected coordinates, transformation availability and
   suitability for the Study Area. Do not inherit the basemap CRS or treat an
   existing free-text analysis-reference note as a validated CRS.
2. Assemble Survey Collections into acquisition groups for Survey Events using
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

## Acquisition grouping and FGDB semantics

Default to **the same calendar month of acquisition**, not publication, download,
file modification or raster creation month. Current retained evidence in
`fluvgeo/R/survey_collections.R` includes USGS `collect_start`/`collect_end`, USIEI
`collectiondate`, provider IDs and raw metadata. Tile-local acquisition evidence
can refine a collection interval only when its meaning and tile link are known.

Proposed implementation policy:

- A valid acquisition interval wholly within one calendar month proposes that
  month's group. Retain original endpoints; a month label is not an exact date.
- Show collections, source identities, date evidence and conflicts for review.
  The project convention groups dates; it does not prove identical acquisition
  conditions or scientific compatibility.
- Multi-month/year intervals, year-only dates, missing endpoints and conflicting
  evidence remain unresolved for automatic month assignment. Do not use an
  interval midpoint, invent a first-of-month date, or merge chains of overlapping
  intervals into an increasingly long Event.
- An analyst can resolve membership using documented evidence, including one
  acquisition spanning a month boundary. Retain rationale and date precision.
  Missing year must be resolved before creating an FGDB Event.
- Stable IDs are distinct from date labels. Reprocessing changes a product edition.

No demonstrated improvement over the owner's month convention was found in the
currently retained metadata. Do not claim a better automatic classifier or infer
flight dates from GeoTIFF creation tags. Implement the conservative convention
and evidence review before considering a new temporal clustering algorithm.

FGDB requires year, permits optional month/day, prohibits day without month, and
uses non-unique YYYY/YYYY-MM labels. Its normative Survey Event is Reach-owned.
A proposed local Study Area acquisition group links Stream DEMs and mask families
to applicable Reach Survey Events. Persist explicit links; do not join only on
labels or silently change FGDB ownership. Several Collections can supply an Event.

Authority: sibling FGDB `dev/schemas/conceptual-data-model.md` (Survey Event time
and accepted derivation), `dev/decisions/adr-0005-governed-foundation-scope.md`, and
`dev/decisions/adr-0012-reach-derivation-and-hierarchical-aggregation.md`.
No FGDB schema migration is performed here.

## CRS, resolution and shared grid

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
- Proposed boundary rule: cell-center polygon inclusion, recorded and tested.
  Boundary cells can straddle a polygon geometrically; the mask defines raster
  membership. Do not silently enable all-touched inclusion. Test exact-edge and
  very narrow polygon cases.
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

Proposed elevation storage: Float64 (FLT8S) for intermediate and final DEMs with
explicit NoData and lossless compression, avoiding narrowing Float64 inputs.
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
revisions, group/date evidence, CRS WKT/units, grid anchor/resolution/extent, mask
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
without partial publication. Test Float64 values not representable in Float32.

## Next implementation boundary

Persisted Study Area CRS selection/validation is implemented. Next add reviewed
acquisition grouping, required Event output cell size, grid/mask preflight and the
cancellable Stream DEM worker. Cross-Event grid semantics are now resolved.
No more tile previews or broad documentation pass is required. Update paired
human/agent routes and rebuild map/site when capabilities/call paths change;
this design-only update adds none.

Primary references (reviewed 2026-09-19; qualify installed versions):
[sf transformations](https://r-spatial.github.io/sf/reference/st_transform.html),
[terra projection/templates](https://rspatial.github.io/terra/reference/project.html),
[terra merge](https://rspatial.github.io/terra/reference/merge.html),
[terra rasterization](https://rspatial.github.io/terra/reference/rasterize.html),
[terra raster writing](https://rspatial.github.io/terra/reference/writeRaster.html),
and [GDAL warp](https://gdal.org/en/stable/programs/gdalwarp.html).
