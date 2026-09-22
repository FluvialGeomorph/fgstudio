# Terrain GIS assessment and remediation plan

Status: engineering remediation across implemented steps 06–14 delivered, 2026-09-22;
the initial-grid convention remains an explicit scientific question. This assessment applies
[R spatial processing](../workflows/r-spatial.md) to the workflow beginning at
06 Source DEM files and continuing through source inspection, analysis setup,
Survey Events, masks, preflight, and the horizontal-warp/source-review additions.
It does not authorize new scientific defaults or claim remediation is complete.

## Historical increment 1 delivery (9047 / 9052)

FG Studio 9047 / isolated fluvgeo 9052 implements complete source catalog paging,
removal of download size/healthy-duration caps, stable-source reuse after metadata
refresh, and saved availability independent of current selection editions.
Article 06 and the backend receipt/catalog contracts describe current behavior.
The findings below retain the audit baseline; F1/F2 and the availability/reuse
portion of F4 are addressed by this increment. Repeated integrity reads (F3)
remain the next step, followed by mask lifecycle and terrain assembly.

Focused backend discovery/download and app files/download/inspection tests passed.
The local HTTP transfer test required worker permission; the directory-symlink
test skipped because this account cannot create directory symlinks. A live query
through a worker using the previously saved synthetic public fixture returned
COMPLETE with one matching DEM. The earlier combined collection/discovery smoke
check returned no USGS fixture collection; it did not test the changed DEM path.
The actual app saved-history worker also verified the existing synthetic local
source and retained its original attempt for inspection. No analyst inputs or
source bytes were changed by these checks.

Preview: http://127.0.0.1:8782/ (HTTP 200; served complete-paging text). Review
Survey Collections → DEM files → Saved source DEM files and Download location.
Dynamic table/inspection binding is covered by module tests. Browser automation
could not attach; a separate headless attempt was also unavailable. Do not claim
interactive visual acceptance. The old port 8781 session remains running because
automatic approval review rejected stopping a session with potentially unsaved work.
No production library upgrade, commit, or deployment occurred.

## Current implementation and remaining boundaries (9048 / 9053)

The remediation covers every existing workflow article, 06 through 14. It does
not add a new mosaic or vertical-transformation feature. The following supersedes
the audit-baseline findings and historical implementation sequence below.

| Step | Assessment and delivered correction |
| --- | --- |
| 06 Source DEM files | Complete paging and uncapped healthy transfers remain. Saved-file reopening now checks records/metadata without rehashing every raster; optional integrity checks remain. Downloaded inputs retain their acquisition receipts. |
| 07 Inspection | One cold source checksum instead of three/four. Session-owned metadata and bounded display caches invalidate on receipt, file/sidecar size/time or backend-version changes. Explicit integrity refresh is retained. File selection automatically starts a preview; metadata is collapsed below the image. No healthy-work timeout. |
| 08 Analysis CRS | Retained explicit real-world projected CRS selection and native sf/PROJ validation. No substitute CRS introduced. Unsupported datum/epoch operations remain explicit scope boundaries. |
| 09 Vertical reference | Retained structured known/unknown reference, unit and epoch inputs. No inferred datum or automatic elevation conversion was added. |
| 10 Survey Event | Retained established terminology, saved choices and automatically prepared masks. Numeric initial-grid alignment remains an unresolved author convention; existing grids are unchanged. |
| 11 Preflight | Retained internal metadata screening only. It is unmounted and does not create an analyst approval gate or block mask creation on source-quality annotations. Review flags are not proof of GIS incompatibility. |
| 12 Masks | Native terra construction retained. Shared Study Area raster reused across Streams; redundant count scan and inverse-mask verification removed. Reopening checks metadata without raster scans; deliberate checksum verification remains available. Display preparation moved into workers with a session cache; failure/cancellation cleans owned staging after worker termination. |
| 13 Horizontal warp | Deleted custom-helper dependency and exhaustive R cell comparison removed. Native global summaries and GDAL warp retained, including explicit no-vertical-shift protection. Application cell/row/disk-estimate caps and forced working precision/memory settings removed. Affine rotation/unequal spacing and ordinary overviews no longer receive blanket rejection. Float32 storage remains default. |
| 14 Source review | Retained unmounted annotation functionality; corrected article text that falsely described a current visible approval step. No new review/save prerequisite. |

Measured with isolated backend 9053, R 4.6.0, terra 1.9.46 and GDAL 3.12.1:
actual cold/warm worker previews of a 2000-by-2000 synthetic downloaded source
took 10.21/9.18 seconds, including process/library startup; both returned at most
512-by-512 display values. Warm-cache regression tests prohibit an additional
source hash. Worker startup still dominates this small fixture; this is not a
claim of instant viewing or a benchmark of multi-gigabyte source files.

An opt-in read-only-input diagnostic created all three Streams' masks for
one existing Event at unchanged 1 m spacing, in temporary directories. Stream
grids were 8974x10688, 5631x3764 and 4525x3551. Worker creation took 27.80, 15.87
and 13.64 seconds, with sampled peak worker RSS 1681, 979 and 949 MiB respectively.
Reopening took 9.88, 10.15 and 9.44 seconds, including worker startup. No diagnostic
products were published; saved input checksums were unchanged and temporary
outputs were removed. These are measured single-worker results, not concurrency
or arbitrarily large dataset certification.

The affected backend tests (masks, metadata, warp, source download/discovery) and
app tests (files, viewing, masks, CRS, vertical reference, Events, source review)
passed. The backend source-view test confirms warm reuse without source hashing,
explicit refresh and modification invalidation. Directory-symlink tests skipped
under this Windows account. Existing package/R build-version warnings remain.

Final preview 9048 is http://127.0.0.1:8784/ with isolated backend 9053. HTTP 200 and new
viewing/automatic-mask controls were verified; worker execution was tested
separately. Interactive browser acceptance is not claimed. Older previews remain
running to preserve potentially unsaved work.

Final verification: changed articles 07/12/13/14 rebuilt; all 431 local links
across 18 pages and 16 article exports/navigation entries passed. The final live
mask worker verified ownership recording, cached display and reservation cleanup
while preserving published masks. The bounded backend archive check completed
with zero errors, one non-ASCII-code warning and two dependency/global-binding
notes; legacy tests/examples and vignette/manual checks were excluded. The check
requires a valid Windows locale (`LC_ALL=C`). Its unused-backend-ps note followed
removal of disk admission checks; that unused dependency was subsequently removed
from source after confirming there are no backend ps calls. The app declares ps
directly for process ownership checks. No additional raster changes followed.

Owner direction permits replacing app-generated products from superseded custom
processing. Inventory found 34 published mask rasters in six Stream/Event outputs, all with
the native terra cell-center recipe from backend 9051, plus 57 downloaded source
DEMs and no raster files in staging. No saved mask met that replacement condition;
none was deleted. Downloaded originals are inputs, not app-generated derivatives.

New outputs also use geometry/grid/recipe keys for reuse across metadata-only
edits. Older outputs without keys conservatively require exact input matches.
Recorded staging can be reclaimed after both its app and worker processes exit;
unknown legacy staging is not deleted based on age. A cleanup regression caught
an unavailable ps helper before delivery; the implementation uses the installed
package's exported ps_pids API and the corrected regression passes.

Initial-grid convention is unresolved:
legacy toolbox steps use the input DEM as snapRaster, but that does not identify
a canonical first grid for the new cross-Event design. No saved grids were moved.
The standalone warp's external georeferencing/mask, scale/offset and datum/epoch
limitations are documented API scope, not claims about terra/GDAL capability.

## Audit baseline

The deviations are substantial, but concentrated in application restrictions,
repeated verification, custom validation, and workflow design around otherwise
appropriate native GIS operations. A wholesale replacement of the backend is
unnecessary. Preserve streamed acquisition, original source files, file-backed
terra/GDAL operations, background workers, explicit analysis grids, and separation
of horizontal and vertical operations. Remove unsupported restrictions and
redundant work before adding further processing stages.

The most concrete correctness defect is a broken horizontal-warp dependency:
both source and installed development backend call a removed `.fg_mask_blocks`
helper. The public API failed on a 4-by-4 synthetic source during this assessment.
The app does not currently call that primitive, so this does not explain every
earlier mask/UI failure. It does invalidate claims that the current backend's
horizontal-warp path is ready for integration.

## Evidence boundary

- Reviewed fgstudio `main` at `8f89aef` (0.0.0.9046) and fluvgeo `main` at
  `52669bc` (2026.09.21.9051). Both working trees were clean at audit start.
- Read source, selected tests, developer routes, current checkpoint, and the
  mosaic/mask decisions. Traced the app-to-backend paths for steps 06–14.
- Checked the isolated development runtime: R 4.6.0, terra 1.9.46, sf 1.1.2,
  Shiny 1.14.0, fluvgeo 2026.9.21.9051; sf and terra report GDAL 3.12.1,
  PROJ 9.7.1, and GEOS 3.14.1.
- Ran only a bounded reproduction of the missing helper and public warp failure,
  using the existing horizontal fixture in a temporary directory. Removed those
  temporary files. No analyst data were processed or changed.
- Did not rerun historical large-data checks, provider downloads, or the full test
  suite. Did not restart or inspect the running browser app. UI observations below
  describe current source, not a newly verified live session.
- Historical timings and saved-DEM integrity checks in the checkpoint are prior
  evidence, not measurements repeated by this audit. This is a focused assessment,
  not certification of all fluvgeo functions or scientific results.

## Findings

### F1 — Step 06 truncates discovery before collection filtering

**High priority; confirmed source behavior.**
[discover_stream_dem_files.R](../../../fluvgeo/R/discover_stream_dem_files.R)
requests only `offset=0`, default 200 records, maximum 500. It filters that page
by source directory and Stream intersection afterwards. Thus a large catalog
response can omit relevant files before collection matching. PARTIAL is correctly
reported, but there is no continuation path in this function to finish discovery.
This is an incomplete acquisition workflow, not evidence of missing terrain.

Remediation: paginate the provider's documented API with cancellation, stable
identity deduplication, and clear completion/error status. Page size is a transport
choice; it must not become a total eligible-file cap. Keep bounded request/idle
recovery and provider rate handling. Verify current provider pagination semantics
before implementation. Do not infer coverage from catalog bounding boxes.

### F2 — Step 06 still rejects large or long-running downloads

**High priority; confirmed contradiction of the owner's size-limit direction.**
[stream_dem_download.R](../../../fluvgeo/R/stream_dem_download.R) sets 10 GiB per
file, 50 GiB per attempt, two hours per file, and eight hours per attempt. Values
must be finite, so unlimited operation is not an available setting. The app
[download controller](../../R/stream_dem_download.R) also kills work after eight
hours, including verification-only work, and displays these restrictions.

Streaming curl transfers, immutable original assets, receipts, and kill/join
before incomplete-file cleanup are sound foundations. Connection and stalled
transfer timeouts have a different purpose from killing a healthy large transfer.

Remediation: remove dataset-size and healthy-transfer-duration admission limits
from backend, controller, UI, and applicable tests. Preserve cancellation and
recoverable network failure handling. Respect explicit metered-download controls
only if actually requested; none is established here. Update old request manifests
compatibly so a retry does not silently restore the former restrictions.

### F3 — Steps 06–07 repeatedly read entire source files for routine viewing

**High priority; confirmed call chain, performance cost not benchmarked here.**
[inspect_stream_dem_download.R](../../../fluvgeo/R/inspect_stream_dem_download.R)
validates the receipt with a full hash, then calls
[inspect_terrain_vertical_reference.R](../../../fluvgeo/R/inspect_terrain_vertical_reference.R),
which hashes before and after metadata inspection. That is three full source-byte
reads for one metadata inspection. A
[preview](../../../fluvgeo/R/preview_stream_dem_download.R) adds another full hash:
four reads before accounting for the actual display sampling. Each detail-window
request repeats this path. Reopening a download also launches full verification.

The preview extracts at most 512-by-512 values after GDAL downsampling; its R
matrix is bounded display data, not full-raster materialization. Float64 there is
a small display intermediate, not a requirement to store analytical DEMs at
Float64. Preserve accurate native-window inspection. Forcing base-raster reads
with `-ovr NONE` can be appropriate for that view, but need not govern every overview.

Remediation: separate acquisition/integrity verification from cached metadata and
display reads. Record validated asset identity at publication; reuse inspection
and overview results for unchanged managed assets. Define explicit invalidation
for replacement, external modification, missing files, and requested integrity
checks. File size/mtime are change indicators, not cryptographic proof. Do not
simply disable integrity checking everywhere. Remove the inspection controller's
30-minute hard cutoff for healthy local work. Benchmark cold and warm viewing.

### F4 — Saved asset availability remains coupled to selection snapshots

**Medium priority; confirmed design, disappearance not reproduced this turn.**
[study_store.R](../../R/study_store.R), `dem_download()`, accepts metadata-only
study revisions when Stream and Collection evidence still match. This corrects
part of the previous invisibility problem. It nevertheless locates attempts by
the latest selection filename and exact retained collection metadata/snapshot.
A refreshed selection can hide otherwise intact original assets from that lookup.

Remediation: distinguish “stored locally” from “selected for this analysis.” Reuse
assets by supported stable source identity while retaining immutable selections
as provenance. Clearly identify stale selection relationships without implying
the bytes disappeared or automatically assigning them to a different source.
Verify saved-project reopen and refresh without re-downloading unchanged assets.

### F5 — Horizontal warp is broken and remains over-restricted

**High priority; failure reproduced; not currently mounted in the app.**
[warp_terrain_horizontal.R](../../../fluvgeo/R/warp_terrain_horizontal.R):

- `.fg_horizontal_scan()` and `.fg_horizontal_compare_aligned()` call
  `.fg_mask_blocks`, which has no definition in backend source or the installed
  namespace. Public `warp_terrain_horizontal()` fails with that missing-function
  error on the existing tiny compound-CRS fixture.
- The 50-million combined-cell cap and 65,536-column cap remain, together with a
  speculative uncompressed-output disk admission formula.
- Custom R row/matrix logic scans values and compares every aligned output cell
  to reconstructed source values, including explicit Float32 byte conversion.
  This belongs, where needed, in small independent acceptance tests rather than
  a compulsory production audit of every output cell.
- Source eligibility is restricted to a narrow static, projected, east/north,
  square, north-up, internally georeferenced subset. Any listed sidecar, including
  an overview, is rejected. These are this primitive's qualification restrictions,
  not general terra/GDAL limitations.
- Float64 working precision, exact transformation threshold, disabled overviews,
  single thread, and fixed 64 MiB warp/cache settings are imposed without a
  representative performance justification in this path.

Remediation: do not restore the deleted custom helper merely to make tests pass.
Replace compulsory custom scans with justified native checks; remove arbitrary
admission rules. Evaluate a file-backed terra template-based `project()` or
`resample()` path against the installed API. Retain a narrow native GDAL invocation
where a demonstrated option requirement warrants it. GDAL through `sf::gdal_utils`
is authoritative open-source processing, not inherently a violation.

Do not remove protection against unintended vertical/unit transformations while
simplifying. Classify each unsupported source representation separately: ordinary
overviews, sidecar georeferencing, scale/offset, internal masks, and dynamic/datum
operations have different meanings. Document actual supported operations rather
than treating every restriction as a scientific necessity or accepting everything.

### F6 — Masks now use native GIS, but still duplicate expensive work

**Medium priority; confirmed source behavior.**
[event_masks.R](../../../fluvgeo/R/event_masks.R) now uses file-backed terra
`rasterize`, `classify`, `crop`, `mask`, and native `global` summaries. The former
per-cell polygon tests and arbitrary mask size caps are gone. Those improvements
should remain. Intrinsic numeric/grid representability checks are distinct from
invented dataset admission caps.

Remaining costs: each Stream independently writes the same Study Area
mask; writing counts cells, verification scans again, and parent verification
creates additional cropped/inverse-mask rasters. `read_event_masks()` rehashes and
repeats full verification, including those temporary writes, on saved-output reuse.
Native functions make these operations scalable but do not make repetition free.

Remediation: prepare/reuse the Study Area/Event mask once for a matching geometry,
CRS, anchor, and cell size; derive Stream/Reach products from it. Consolidate
necessary publication checks and separate cheap reopening from deliberate deep
integrity verification. Reuse products by relevant processing dependencies,
including the recipe, rather than unrelated metadata revisions alone. Retain
the established hierarchy and saved outputs during any manifest transition.

### F7 — Worker use is sound; display and cleanup need follow-through

**Medium priority; source risks, no new runtime performance measurement.**
[app masks](../../R/event_masks.R) dispatches file paths/settings through callr,
checks request freshness, and stops workers on cancellation/session end. That is
appropriate. `draw_event_mask()` still samples the saved raster during
`renderPlot()`. The result is bounded to about 250,000 cells, but source I/O occurs
in the main Shiny process and repeats on redraw. Do not label it a full-raster
memory failure; measure its latency and move/cache preparation if needed.

Mask staging has no complete lifecycle cleanup after killed or failed workers;
verification also uses default process temporary storage. Ordinary `on.exit`
cleanup is insufficient for forced process termination.

Remediation: use job-owned scratch locations; stop workers before cleanup, retain
valid editions, and reclaim abandoned staging safely. Generate/cache suitable
display products in workers where needed. Do not change analytical resolution to
make plotting faster. Keep the existing background mechanism unless a concrete
deficiency warrants replacing it.

### F8 — Scientific authority and implementation defaults became conflated

**High priority before analytical DEM assembly.** The retained design distinguishes
owner requirements (shared analysis grid, Event cell size, mask hierarchy,
first/last source precedence) from proposals. For example,
[mosaic design](dem-mosaic-design.md) calls the specific `(0, 0)` anchor proposed,
while code fixes it and saved-mask validation requires it. A shared anchor is
established; this audit does not establish approval of that exact coordinate.
Do not change existing grids automatically to resolve a documentation conflict.

[Preflight screening](../../../fluvgeo/R/preflight_stream_dem.R) flags projected-2D,
rotation/anisotropy, differing reader metadata, and a 1 m source-spacing screen.
Some may reflect project criteria, some limited implementation scope. Trace their
authority before turning any REVIEW result into a processing rejection. Missing
vertical declarations must not be replaced with an inferred datum. Ordinary and
embedded metadata comparison can be useful, but string differences alone are not
proof of a scientifically incompatible source.

Steps 08–10 already separate analysis CRS, vertical target, and Event settings;
these are useful scientific inputs. Dynamic/epoch handling remains unfinished
scope, not a reason to substitute another CRS. The earlier preflight/source-review
modules remain in source but are no longer mounted in the current event module.
Do not restore manual diagnostic approval as a prerequisite for masks.

Remediation: resolve the small set of consequential unconfirmed defaults using
author methods/reference examples, then ask only questions still unresolved.
Distinguish supported scientific operations from informative screening and genuine
input errors. Preserve the user's established terminology and input reuse.

### F9 — Verification and documentation no longer describe the same state

**High priority; confirmed evidence gap.** Focused mask testing missed a dependency
used by horizontal warp. The existing warp tests contain useful independent
bilinear and vertical-unit controls, but also assert internal choices such as
Float64 working type and the exact disk admission formula. Such assertions cannot
justify those choices. Update only obsolete expectations; retain scientific tests.

The mosaic feature still says no analyst masks were executed, while the checkpoint
records two saved Events and six completed Streams. Old checkpoint prose
also describes superseded mask limits. Historical “passed” counts must not imply
current readiness after dependent code changes. Legacy methods such as
`get_dem()`, `hydroflatten_dem()`, and `get_terrain_leaflet()` demonstrate native
raster operations, but their service, unit, CRS, and display assumptions are not
drop-in authority for this acquisition workflow. `clip_terrain_to_aoi()` itself
contains an exhaustive output comparison and needs assessment before reuse.

Remediation: check affected callers when removing shared helpers, and record the
source/runtime version of evidence. Reconcile current feature, schema, article,
and checkpoint status as each increment lands. Preserve historical evidence as
history. Do not run broad suites repeatedly in place of relevant dependency checks.

## Proposed implementation sequence

The owner authorized remediation across every remaining implemented step, not
just step 06. Continue independent fixes without waiting for another resume cue.
Provide reviewable UI changes and report verification as work proceeds. This
authorization does not resolve an unknown scientific convention or request a new
mosaic/vertical-transformation feature.

| Order | Work and ownership | Minimum acceptance evidence | User review outcome |
| --- | --- | --- | --- |
| 1 — Return to 06 | fluvgeo: complete paginated discovery; remove acquisition caps. fgstudio: remove matching hard cutoffs and obsolete limits text; distinguish stored assets from active selections. | Mock paginated provider with matching files beyond page one; simulated healthy transfer exceeding former thresholds without huge fixtures; missing/corrupt assets remain identifiable; saved-study reopen and metadata refresh preserve availability. | Source DEM files shows saved availability, complete discovery status, and useful download progress without arbitrary size restrictions. |
| 2 — Make inspection inexpensive | Separate receipt verification, metadata cache, and display products across fluvgeo/store/inspection controller. | Instrument byte-read/hash calls to prove warm metadata/preview requests avoid full hashes; preserve stale/missing-asset detection and native-window/NoData correctness; measure one representative cold/warm view. | Select a downloaded file and see its useful preview/metadata without redundant inspect/approve steps. |
| 3 — Finish native mask lifecycle | Reuse shared parent masks; consolidate checks; lightweight reopen; job scratch cleanup and cached display. | Small analytical hole/parent/grid fixtures; exercise cache hit/miss and cancel/failure; run a representative saved Event at its unchanged cell size and reopen it; observe runtime and scratch behavior. | Survey Event masks appear automatically, reopen promptly, and are visually reviewable. No stream selection or preflight approval. |
| 4 — Repair the existing horizontal primitive | Remove broken custom validation and invented restrictions; preserve explicit horizontal-only behavior. | Public warp regression, independent interpolation/unit/NoData cases, and a wide native raster fixture pass. | Current mask/viewing UI remains reviewable. The existing backend-only warp does not become a new manual UI step; mosaic assembly is separate future scope. |

Before increment 4, determine the approved anchor coordinate, applicable source
quality criteria, interpolation choice, and source precedence where existing
evidence does not settle them. Do not send the owner a questionnaire for routine
library options. Do not start new vertical transformation work under this plan.

Across increments, preserve original DEMs, saved studies, Event identities, and
completed editions. Support existing manifests explicitly; create new output
editions when a processing recipe changes. Use the isolated development backend,
not the shared installation, and refresh the actual preview for each implementation
review. Include startup of a real worker in that review to catch the previously
observed Windows processx permission problem. A served page alone is insufficient.

## External technical references

These establish package behavior, not the project's scientific choices:

- [terra project](https://rspatial.github.io/terra/reference/project.html): an
  output raster template specifies the target geometry; resampling changes values.
- [terra global](https://rspatial.github.io/terra/reference/global.html): native
  summaries support large rasters; arbitrary custom callbacks can materialize data.
- [terra rasterize](https://rspatial.github.io/terra/reference/rasterize.html):
  native polygon rasterization and documented inclusion options.
- [GDAL warp](https://gdal.org/en/stable/programs/gdalwarp.html): native warp,
  memory/working datatype controls, coordinate operations, and vertical-shift options.
- [GDAL translate](https://gdal.org/en/stable/programs/gdal_translate.html):
  source windows, output sizing, overview selection, and scale/offset handling.

## Completion condition for the remediation

An analyst can reopen source DEMs, finish discovery/download, inspect useful
previews, define an Event, and review its masks/terrain without unnecessary
backend approval steps. Large inputs run through native file-backed operations
without invented admission caps or repeated exhaustive audits. The resulting
scientific behavior is supported by author methods and independent checks, and
the delivered UI, source, backend library, and documentation describe the same
tested increment.
