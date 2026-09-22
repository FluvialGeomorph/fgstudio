# Stream DEM mosaics and analysis masks

Current remediation route: [terrain GIS assessment and plan](terrain-gis-remediation.md).
The 2026-09-22 audit identifies remaining acquisition restrictions, repeated I/O,
and a reproduced broken horizontal-warp dependency. Earlier verification claims
below do not establish readiness of the current source. Implementation remains
pending the proposed reviewable increments beginning at Source DEM files.

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

The Event setup panel persists one immutable GeoPackage per group revision,
retaining UUID identity, reviewed selected-collection and Stream membership,
source/date evidence, required year, optional month, optional notes and positive output
cell size in the saved planar CRS's units. Existing Reach Events can be linked by
ID after parentage/date validation; this increment creates no Reach Events.
Revisions retain previous snapshots. The local store rejects stale study,
selection or group state and duplicate Reach Event links across groups.
The implementation uses a (0, 0) grid-alignment anchor within the saved real-world CRS. The specific alignment convention remains unconfirmed; do not interpret it as an arbitrary CRS or move saved grids automatically.
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
Area/Stream/available Reach envelopes and uncompressed one-byte mask/four-byte
Float32 DEM estimates without allocating raster cells. The backend also retains
the optional Float64 estimate. It validates group revisions,
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
and final DEMs, with explicit NoData and lossless compression. Float64 working
precision is independent of disk storage. Float64 storage remains explicit
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
without partial publication. Test realistic Float32 storage rounding and optional
Float64 preservation separately from unintended elevation-unit conversion.

## Next implementation boundary

Owner UI correction (9042): use Define a Survey Event terminology, native choices
from saved Survey Collections and prefilled known dates/DEM-associated Streams.
Do not expose legacy acquisition-group API names as a new analyst concept.
Each development turn must provide an updated UI for owner review. UI feedback
takes priority over further terrain processing. The DEM file panel now uses the
existing geometry/collection compatibility check when reopening old choices;
metadata-only study revisions no longer hide valid saved sources. A read-only
check of the current local project found 57 TIFFs and compatible receipt sets of
16, 31 and 10 files; choices were revision 33 while the context was revision 36.
211 focused assertions passed across files/downloads, Survey Event settings,
preflight, masks, collections and source review. Original source files were not
changed or redownloaded. Existing sf/Shiny build-version warnings remain.
Receipt checksum verification also succeeded for all 57 existing source DEMs.

Persisted CRS, reviewed acquisition-group/output-cell-size setup, grid/source
preflight and hierarchical masks are implemented. Backend 9048 qualifies a bounded
static same-reference horizontal warp. Next bind reviewed source references/units,
receipts, overlap order and masks to the cancellable Stream DEM worker. Datum/epoch
operations and nonidentity scale/offset remain unqualified. Revalidate all inputs
and receipt hashes at execution; do not reuse a session preflight PASS as approval.
Cross-Event grid semantics are resolved.
No more tile previews or broad documentation pass is required. Article 10 and the
paired agent route trace this settings increment; update those routes and the
map/site as processing capabilities are added.

App 9041 implements the source-review portion of this boundary. After preflight,
analysts can compare embedded CRS/band-unit evidence with the saved target,
record per-file assessments and prior conversions, move files earlier/later,
choose first/last-valid overlap and save an immutable review. Fresh preflight
reopens matching editions. Changed evidence starts a new review; stale editors
cannot overwrite a newer edition. Unresolved assessments remain explicit, and
annotations neither clear grid issues nor authorize processing. Article 14 and
the app terrain-source-review schema own the UI and persistence contracts.
The next increment must reconcile this evidence with actual inputs and a verified
mask before enabling cancellable DEM assembly. Backend 9049 is unchanged.

Verification (9041): the full app suite passed 855 assertions. A final tile-title
display refinement was then checked with 79 focused assertions across source
review, preflight and Event setup (34 review assertions). Existing sf/Shiny R
build-version warnings remain. Tests use temporary metadata stores and synthetic
sources, with no analyst-data writes. Browser attachment failed for the synthetic
preview, so live browser interaction/layout is not claimed as verified.
The package installed into the documentation-only library. The local site passed
431 links across 18 pages and 16 article exports. The regenerated map passed
freshness/bridge checks (82 nodes, 103 static edges, 23 reviewed bridges). No
backend runtime was upgraded in this increment and no site was published.

Primary references (reviewed 2026-09-19; qualify installed versions):
[sf transformations](https://r-spatial.github.io/sf/reference/st_transform.html),
[terra projection/templates](https://rspatial.github.io/terra/reference/project.html),
[terra merge](https://rspatial.github.io/terra/reference/merge.html),
[terra rasterization](https://rspatial.github.io/terra/reference/rasterize.html),
[terra raster writing](https://rspatial.github.io/terra/reference/writeRaster.html),
and [GDAL warp](https://gdal.org/en/stable/programs/gdalwarp.html).

## Current mask implementation (9046/9051)

Masks prepare automatically for all Streams assigned to a saved Survey Event.
The backend uses standard terra rasterize/classify/crop/mask and global summaries.
Outputs are compressed disk-backed Byte GeoTIFFs with BigTIFF support. There are
no arbitrary cell-count, row-width, elapsed-time or estimated-space cutoffs.
Matching saved masks are verified and reused. Current inputs are checked before
publication; cancelled or failed attempts remain unpublished. The map selector
chooses a completed output to view, not a Stream to process.

Historical verification of the earlier implementation follows; its custom strict-edge
rule and size restrictions are superseded.

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

## Historical horizontal primitive delivery (backend 9048; superseded by 9053)

The backend now provides warp_terrain_horizontal for static projected grids that
share an identified, semantically equivalent 2D geodetic reference. It uses an
explicit exact grid-free pipeline, a separate horizontal source definition and
-novshift, retaining full original compound evidence. Backend 9049 defaults to
Float32 storage with Float64 working precision and optional Float64 storage.
Aligned output is compared with source cells at the chosen storage precision; other grids use
bilinear interpolation. Original hashes, band units, output grids and pixel
readability are verified before a manifest is written. This is a backend prerequisite,
not a new app action or completed Stream DEM pipeline.

On the installed GDAL 3.12.1 / PROJ 9.7.1 stack, an unguarded control warp converts
synthetic compound-source US-survey-foot values to metres. The guarded operation
preserves Float32 source samples; explicit Float64 output also preserves higher precision. Tests distinguish
this unwanted unit conversion from intended bilinear interpolation. Compound
source declarations are retained as evidence rather than erased or assigned to
unrelated target vertical metadata.

Limits: projected east/north axes, static 2D base with matching authority identity,
no datum/epoch operations, no external sidecars, square north-up affine grids,
identity scale/offset, supported real single-band types, 50 million combined
source/output cells by default, and 65,536 columns. Space admission is an estimate,
not a reservation. Projection suitability and source vertical/unit compatibility
remain unresolved for analyst inputs. No modernized NSRS or geoid operation has
been qualified. Compatible neighboring tiles must be assembled before this warp
with interpolation halos; apply masks after assembly. Article 13 and sibling
fluvgeo's horizontal-terrain-warp schema own the developer and exact contracts.

Verification (9039/9048): 139 focused backend assertions passed, including 45
horizontal-warp assertions and a real stored-coordinate-epoch refusal fixture.
The full app suite passed 821 assertions with no failures; existing sf/Shiny
R build-version warnings remain. Backend source build and limited R CMD check
--no-manual --no-vignettes --no-tests --no-examples completed with zero errors,
one existing non-ASCII warning in survey_collections.R and two existing notes
(undeclared methods dependency and unrelated globals/imports). Legacy reporting
tests/examples remain excluded for the fixture-safety and optional-dependency
reasons above. The final epoch test and help clarification followed that check;
the focused suite passed and backend 9048 was reinstalled only in the app's
isolated library. App code remains 9039. No analyst preview was restarted.
The local documentation build passed 392 local links across 17 pages and 15
article navigation/text exports. Code-map freshness and reviewed-bridge checks
passed without regeneration because app code and graph inputs did not change.
The expected missing public-site URL diagnostic remains; no site was published.

Owner storage correction (9040/9049): Float32 is now the default DEM storage;
Float64 storage is explicit opt-in and working precision remains Float64.
The preflight table reports four bytes per DEM cell, retaining eight-byte backend
estimates for compatibility. Aligned comparisons account for storage rounding;
Float32 range overflow is refused before output creation. This corrects an
overly conservative proposal based on hypothetical Float64 inputs, not an owner
requirement. No assembly action or elevation conversion is introduced.
Verification: 150 focused backend assertions (55 horizontal) and 822 full app
assertions passed, including actual stored Float32 precision, optional Float64,
rounding/range refusal and the displayed preflight estimate. Existing R
build-version warnings remain. Only the isolated development backend is upgraded.
Backend source build and limited R CMD check with tests/examples/vignettes/manual
excluded completed with zero errors and the same one warning and two notes as
9048; the focused terrain tests above cover this increment separately.
The local site passed 392 links across 17 pages and 15 article exports. The
regenerated code map passed freshness/bridge checks (76 nodes, 93 static edges,
22 bridges); only the app version and changed source hashes differ. The expected
missing public URL diagnostic remains. No site was published or preview restarted.

Define a Survey Event is now a main Study Area tab immediately after Analysis setup.
Analysis setup provides a Continue to Define a Survey Event button. The event form
has no membership/date rationale field or save requirement; provider date evidence
is retained automatically, and older analyst notes survive edits.

Preflight recovery (9044): worker launch errors show actionable status and expandable
technical details; completed REVIEW and BLOCKED screens remain distinct. The local
Windows preview must permit background worker creation. Read-only diagnosis verified
the same saved-data worker succeeds outside the sandbox. All 94 focused assertions
passed, including startup failure, completed review/blocker results and cancellation.

Owner simplification (9045): Survey Event UI exposes Create masks and visual output,
not grid/source preflight reports or source-assessment save/approval controls. The
mask writer already validates context, geometry, grid and resources automatically.
No DEM prerequisite is introduced for masks. App display reads the generated raster,
samples a bounded overview and overlays its saved boundary in the analysis CRS.
Failures identify correction routes; no backend scientific behavior changed.
Validation for 9045: 61 focused assertions passed. A real background worker created
and verified a small temporary Study Area/Stream/Reach mask set with no DEM inputs;
the generated raster preview was rendered and visually inspected. HTTP verification
confirmed Create masks and Mask to view are served and both manual panels are absent.

## Current GIS remediation (FG Studio 9048 / fluvgeo 9053)

The current processing contracts supersede the historical constraints above:
[remediation assessment](terrain-gis-remediation.md), articles 07/12/13 and sibling
backend inspection/mask/warp schemas. Source viewing uses one cold hash and
session-owned caches; masks reuse a shared Study Area raster, consolidate native
checks, cache worker-prepared display rasters and clean stopped job staging.
Horizontal warping uses native summaries without custom cell traversal or
application size/disk admission rules. Float32 storage remains the default;
GDAL chooses working precision. No new mosaic or vertical-transformation feature
is introduced by this remediation.

The owner has not approved a particular numeric grid anchor. Legacy toolbox
processing uses the input DEM as `arcpy.env.snapRaster` (tools 02, 07, 08, 09, 10),
while the new design requires one shared Study Area grid across equal-resolution
Events. That evidence does not identify a canonical first grid for this new
workflow. Preserve saved grids; resolve initial-grid selection in project terms
before changing it. A coordinate alignment convention is not a replacement CRS.
