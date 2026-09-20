# Downloaded DEM metadata inspection

Owner acceptance, 2026-09-19: the tile-preview changes look fine and no further
tile-preview functionality is requested. Close this feature increment and move
to [Stream mosaic design](dem-mosaic-design.md). Acceptance covers the app's
functionality, not an automatic suitability decision for every downloaded tile.

## Accepted implementation: source-window detail (9031 / 9041)

The owner directed the next step after the overview. Drag a rectangle on a
preview and select **Inspect selected area**. This reads that source pixel window
through the existing cancellable, receipt-bound worker. Repeat to inspect finer
detail; **Preview elevations** returns to the full tile. Each view reports its
source row/column range and whether data are native or still sampled.

The 512-cell dimension cap remains. A window at or below that cap is read without
source-cell downsampling; the browser may still scale the image to fit. Larger
windows remain nearest-neighbour samples. The colour scale is recalculated per
view. Pixel windows do not establish geographic or Stream coverage, ground
resolution, hydro-flattening status, or suitability. No derived study files,
decisions, or Events are saved.

Each displayed result has a unique brush ID. Old brushes cannot be used against
new results. Plot y coordinates are converted to top-row order; nested windows
retain absolute source offsets. Empty/outside brushes and invalid backend windows
fail visibly. Original raster and receipt checks remain in force.

Earlier increment descriptions and qualification below are historical.

- Focused backend download/preview suite: 73 assertions passed, with the existing
  directory-symlink skip. Covers exact windows, one-cell NoData, native/sample
  status, out-of-bounds/fractional/negative rejection, and unchanged source bytes.
- Focused app inspection suite: 41 assertions passed, including nested offsets,
  top-row orientation, old-brush rejection and full-tile reset.
- Full app suite: 673 assertions passed, with backend containment/cancellation
  mocks restored. Known sf/shiny/testthat R-version build warnings remain.
- Real callr worker produced a 256 by 256 native detail from the existing synthetic
  download. `dev/check-output/dem-detail.png` was visually inspected. The script
  `dev/scripts/check-dem-inspection-local.R <attempt> --preview` now checks both
  full-tile and native-window paths, without downloads or owner study changes.
- Developer site/article 07 and code map rebuilt: 63 nodes, 77 static edges,
  16 reviewed bridges; freshness and direct/indirect/anchor checks passed.
- FG Studio 9031 package check (`--no-tests --no-manual`) completed with no errors;
  all seven vignettes passed. The existing non-ASCII warning remains. Full tests
  ran separately as recorded above. Log: `dev/check-output/fgstudio.Rcheck/00check.log`.
- fluvgeo 9041 limited package check (`--no-tests --no-examples --no-manual`)
  completed with no errors, one existing warning and two existing notes. The
  optional-package and unsafe legacy-test limits documented below remain.
  Log: `dev/check-output/backend-detail-check/fluvgeo.Rcheck/00check.log`.
- Fresh 9031 preview verified HTTP 200 at `http://127.0.0.1:8780/`; logs are
  `dev/check-output/preview-detail.*.log`. Detail controls are rendered with the
  elevation view. The owner subsequently accepted the preview functionality.

## Earlier increment: elevation overview (9030 / 9040)

After accepting metadata inspection, the owner directed the next step. **Preview
elevations** now requests a receipt-verified whole-tile overview in the same
cancellable worker. The view uses source pixel orientation, a per-tile elevation
colour scale, declared band unit (or unknown), and grey for sampled missing cells.
Metadata-only inspection remains available. Both actions clear stale results.

The backend limits each display dimension to 512 without enlarging the source,
samples nearest neighbours from base pixels (ignoring existing overviews), applies
band scale/offset, and explicitly samples the embedded validity mask. External
sidecars are excluded. The original file is rehashed after rendering data is read.
Only worker-temporary display files are created; no study assets or receipts are
modified. The app receives a bounded matrix, not a process-local raster handle.

This is the first visual overview, not a north-up spatial map, native-resolution
inspection, valid-data footprint or suitability decision. Small features and
NoData holes may be missed. Source pixel aspect is retained as square display
cells, not an assertion of ground aspect ratio. Hydro-flattening, ground resolution,
processing history and durable suitability rationale still need review.

Qualification for this increment is recorded below. Earlier 9029 evidence remains
historical. Changes build on the accepted, still-uncommitted metadata increment.

- Full app suite: 662 assertions passed; containment/cancellation mocks restored.
  Includes explicit preview invocation, stale-file clearing, unknown units and
  successful drawing of constant/all-missing grids.
- Real callr worker and successful UI rendering passed against the existing
  synthetic USGS acquisition. The 512 by 512 display was rendered to
  `dev/check-output/dem-preview.png` and visually inspected. Source grid remained
  2000 by 2000; no new download or owner study mutation occurred.
- The repeatable local script accepts `--preview` after its explicit attempt path.
  It exercises the worker, writes the test image under ignored check-output, and
  checks the returned preview panel.
- Final backend download/preview suite: 64 assertions passed, including source
  preservation, bounded dimensions, row ordering, mask/scale/offset handling and a
  valid scaled value equal to the original NoData sentinel. One existing symlink
  test remains skipped because the account cannot create directory symlinks.
- Developer site/article 07 rebuilt. Code map: 62 nodes, 76 static edges and 16
  reviewed bridges; freshness and direct/indirect/anchor checks passed.
- FG Studio 9030 package check (`--no-tests --no-manual`): no errors, all seven
  vignettes passed; one pre-existing non-ASCII warning in
  `R/mod_survey_collections.R`. Tests ran separately as recorded above.
- fluvgeo 9040 limited package check (`--no-tests --no-examples --no-manual`):
  no errors; existing non-ASCII warning plus two dependency/global-binding notes.
  Missing optional `fluvgeodata`/`gt` and unsafe legacy test exclusions remain as
  documented below. Logs: `dev/check-output/preview-package-checks.log` and
  `dev/check-output/backend-preview-check/fluvgeo.Rcheck/00check.log`.
- Fresh 9030 preview returned HTTP 200 with preview/inspect/cancel controls at
  `http://127.0.0.1:8780/`. Logs: `dev/check-output/preview-elevation.*.log`.

Implemented 2026-09-19 in fgstudio 9029 / fluvgeo 9039 following the owner's
direction to proceed to the next step. This is the first inspection increment.

In DEM files, expand **Inspect downloaded DEM metadata**, choose a downloaded
file and select **Inspect selected file**. A cancellable background worker checks
receipt identity, containment, size and checksum, then compares ordinary GDAL
metadata with embedded compound-CRS metadata. It reports columns/rows, affine
transform, column/row spacing in source CRS units, horizontal unit, pixel type,
declared NoData, band unit and vertical declarations. Missing values stay unknown.

Inspection reads original source files without generating terrain or updating
receipts. Results are session-only and re-run explicitly; they are not durable
acceptance records. Context changes clear results and stop workers. File-choice
changes discard late results. The worker has a 30-minute watchdog covering hashing
and metadata reads. Download/verification activity makes inspection unavailable.

The original 9029 increment checks metadata readability, not every pixel. Source-coordinate spacing is
not automatically a ground-resolution determination. The 1 m requirement, valid
coverage, visual review, hydro-flattening, processing history and suitability remain
unreviewed. There is no raster map preview, clipping, resampling, Event assignment
or acceptance action in this increment.

Backend compatibility is additive: a new receipt-bound inspection export and a
`grid` member in each existing vertical-reference reader observation. Install the
backend before loading this app version. No other client or shared library upgrade
is required. See sibling fluvgeo `dev/schemas/stream-dem-inspection.md`.

## Qualification

- Full app suite: 647 assertions passed, with backend containment and cancellation
  mocks restored. Final focused inspection suite: 20 assertions passed after
  explicit observer priorities and successful-render coverage were added.
- Backend download/receipt suite: 57 assertions passed; one directory-symlink test
  skipped because the account cannot create those links. Vertical-reference suite:
  46 assertions passed, covering declarations, missing evidence and angular spacing.
- The real callr worker inspected the existing synthetic USGS test acquisition:
  2000 by 2000 cells, 2.5 US survey feet spacing, Float32, declared NoData -999999.
  Successful UI rendering and SHA display passed. No new download was needed.
- Repeatable local check: `dev/scripts/check-dem-inspection-local.R <attempt>`.
  The script accepts an explicit test attempt; do not run it on active owner work
  without identifying the intended source. It performs read-only inspection.
- Known workstation warnings: sf, shiny and testthat built under R 4.6.1 while
  registry-default R is 4.6.0. The full legacy backend suite remains excluded
  because older tests write/delete HOME reports or invoke credentialed services;
  prior limited package-check findings remain in `stream-dem-files.md`.
- Developer site rebuilt through article 07. Code map: 61 nodes, 75 static edges
  and 15 reviewed bridges; freshness/direct/indirect/anchor checks passed. Expected
  pkgdown diagnostic: no public site URL configured. Nothing was published.
- App `R CMD check --no-tests --no-manual`: no errors; all seven vignettes and
  code/help checks passed. One existing non-ASCII warning in
  `R/mod_survey_collections.R`. Tests ran separately as described above.
  Log: `dev/check-output/fgstudio.Rcheck/00check.log`.
- Backend limited `R CMD check --no-tests --no-examples --no-manual`: no errors,
  one existing non-ASCII warning and two existing dependency/global-binding notes.
  Optional `fluvgeodata`/`gt` are unavailable. Log:
  `dev/check-output/backend-inspection-check/fluvgeo.Rcheck/00check.log`.
- Fresh 9029 preview returned HTTP 200 at `http://127.0.0.1:8780/`; inspection
  panel and inspect/cancel controls are present. Preview logs are under
  `dev/check-output/preview-inspection.*.log`.

Source and tests are routed through developer article 07 and
`dev/architecture/agent-routes.md`. This is functional qualification, not owner
browser acceptance or scientific qualification of the sample terrain.
