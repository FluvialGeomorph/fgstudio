# Stream DEM mosaics and analysis masks

Status: Event group settings implemented in 9037/9045, read-only grid/source
preflight in 9038/9046 and hierarchical masks in 9039/9047. Mosaic execution remains pending.
Owner grid requirements clarified 2026-09-19.
Supersedes the earlier compatible-source-grid-only proposal. Tile preview/detail
is accepted and complete. See `study-analysis-crs.md` for implemented CRS behavior.
Masks are verified with temporary synthetic fixtures. No analyst masks or DEM
mosaics have been executed by development checks.

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

Implemented settings policy (9037/9045):

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

The Event setup panel persists one immutable GeoPackage per group revision,
retaining UUID identity, reviewed selected-collection and Stream membership,
source/date evidence, required year, optional month, rationale and positive output
cell size in the saved planar CRS's units. Existing Reach Events can be linked by
ID after parentage/date validation; this increment creates no Reach Events.
Revisions retain previous snapshots. The local store rejects stale study,
selection or group state and duplicate Reach Event links across groups.
The anchor is fixed at (0, 0); changed CRS/selection evidence requires review.
See article 10 and sibling fluvgeo's `dev/schemas/survey-acquisition-groups.md`.
USIEI free-text formats beyond explicit ISO day/date intervals remain unresolved.

Verification (9037/9045): installed app tests passed 789 assertions with zero
failures/skips. `R CMD build` and `R CMD check --no-manual` completed; the sole
check warning is the existing non-ASCII text in `mod_survey_collections.R`.
The direct backend contract run passed 186 assertions with one `gt`-dependent
report skip; 22 assertions exercise the new grouping contract. It covers proposals,
immutable read/write, integer/fractional spacing and Reach parentage/date conflicts.
No live services or `.local-data`
studies were used. Browser layout and source-set compatibility are not qualified
by these tests. An expanded backend context test run encountered eight report
errors and two skips because optional `gt` is unavailable in this runtime; those
report paths are outside this increment. The full legacy backend suite was not
run because it contains report scripts writing outside temporary fixture directories.
The local pkgdown site and paired navigation map were rebuilt: freshness/bridge
checks passed, with 293 local links across 14 pages and 12 article exports verified.
The site remains local; the existing missing-public-URL diagnostic is expected.

## CRS, resolution and shared grid

Implemented preflight: choose one saved Event group and Stream, then explicitly
check current saved sources in a cancellable worker. It computes snapped Study
Area/Stream/available Reach envelopes and uncompressed one-byte mask/eight-byte
Float64 estimates without allocating raster cells. It validates group revisions,
membership, hierarchy, CRS and receipt-bound selected files, and reports source
spacing in native units and metres, alignment, and blocking/review issues.
Changed context or collection revisions require reviewing/resaving group settings.
Missing acquisitions remain explicit BLOCKED rows. Results are timestamped session
snapshots, not persisted approval. Article 11 and the backend preflight schema
define the exact checks. Angular/rotated/anisotropic grids and metadata conflicts
remain review items. Nominal projected spacing is not ground-resolution proof;
coverage, pixel readability and source vertical/epoch reconciliation are unresolved.

Verification (9038/9046): 60 focused backend assertions passed, including 38 new
preflight assertions. The full installed app suite passed 803 assertions with no
failures/skips. Source build and `R CMD check --no-manual` completed with the same
pre-existing non-ASCII warning. Tests use synthetic source files and temporary
receipt stores; analyst studies, live services and the running preview were not
used. Full legacy backend reporting remains outside this bounded check for the
runtime/fixture limitations noted above.
The local site and navigation map were rebuilt; map freshness/bridge checks and
324 local links across 15 pages and 13 article exports passed. No site was published.

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
- Implemented boundary rule: strict cell-center polygon interior, recorded and tested.
  Centers exactly on exterior or hole boundaries are NoData.
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

Persisted CRS, reviewed acquisition-group/output-cell-size setup, grid/source
preflight and hierarchical masks are implemented. Next qualify horizontal-only
source operations before the cancellable Stream DEM worker. Revalidate all inputs
and receipt hashes at execution; do not reuse a session preflight PASS as approval.
Cross-Event grid semantics are resolved.
No more tile previews or broad documentation pass is required. Article 10 and the
paired agent route trace this settings increment; update those routes and the
map/site as processing capabilities are added.

Primary references (reviewed 2026-09-19; qualify installed versions):
[sf transformations](https://r-spatial.github.io/sf/reference/st_transform.html),
[terra projection/templates](https://rspatial.github.io/terra/reference/project.html),
[terra merge](https://rspatial.github.io/terra/reference/merge.html),
[terra rasterization](https://rspatial.github.io/terra/reference/rasterize.html),
[terra raster writing](https://rspatial.github.io/terra/reference/writeRaster.html),
and [GDAL warp](https://gdal.org/en/stable/programs/gdalwarp.html).

## Implemented mask increment (9039/9047)

Event setup exposes explicit, cancellable mask-family creation for one Stream.
The backend reuses preflight group validation and snapping; no DEM is required.
All existing Reaches must have polygons. Strict center membership excludes exact
exterior/hole boundary centers, and every child intersects its parent. All-NoData
masks remain valid domain results with an explicit zero included-cell count.

The writer uses compressed Byte GeoTIFFs, up to 65,536 centers per block and
matching parent row/column reads. Default admission limits a family to 50 million
cells and each mask to 65,536 columns, requiring available disk space of four
uncompressed payloads plus 256 MiB. Space is not reserved. Large-study performance
has not been qualified. Reopening verifies grids, values, parent containment,
counts and hashes; a manifest is written last. The app rechecks revisions/hashes
and publishes a new edition by directory rename. Failed/cancelled staging remains
unpublished; prior editions remain intact. The UI shows the new edition path and
counts; a persisted edition browser remains future work. Backend reopening is
available through read_event_masks(). See article 12 and the backend mask schema.

Verification (9039/9047): 94 focused backend assertions passed, including 34 mask
assertions for holes, exact edges, narrow polygons, parent subwindows, fractional
spacing across disk blocks, no-Reach families, resource rejection, interruption,
immutable editions, changed manifest grid/parent records, count mismatch and
corruption. Full app and installed-package tests passed 821 assertions with zero
failures/skips; only the existing sf/Shiny R build-version test warnings remain.
Source build and R CMD check --no-manual completed with the single pre-existing
non-ASCII warning in mod_survey_collections.R. The final backend-only reopening
and count guards were checked with the focused suite after that app check and
installed into the isolated library. Shared runtimes and analyst data were not
changed. Browser layout, full-size performance and live source compatibility were
not qualified. Legacy backend reporting limitations remain as recorded above.
The local documentation site and navigation map were rebuilt: freshness/bridge
checks passed (76 nodes, 93 static edges, 22 reviewed bridges), and 357 local links
across 16 pages and 14 article exports passed. The site is local; the expected
missing-public-URL diagnostic remains. No site was published.
