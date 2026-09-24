# Analyst terrain source reviews (FGSTUDIO_TERRAIN_REVIEW_1)

Current availability: this retained annotation module is not mounted in the
analyst workflow. The schema does not introduce a review/save prerequisite for
masks or authorize DEM processing. Article 14 documents its internal call path.

App-owned review annotations live beside the study context in
terrain-reviews/<group-and-stream-hash>/review-<six-digit-revision>-<random-id>.json.
They are immutable editions, independent of source files and scientific products.
The latest edition is selected by revision. An exclusive directory lock prevents
concurrent saves; a crashed writer's lock requires developer inspection before
removal. Pending JSON is renamed only after writing; pending files are not loaded.

The record retains creation time, an input fingerprint, the preflight input/source
selection hashes and source identities/hashes, ordered review rows, overlap rule,
Float32 output intent and processing_authorized=false. Rows contain source_id,
assessment (unresolved, matches_target, conversion_required), elevation_unit,
evidence and prior_operations. Every verified source occurs exactly once; row
order is explicit source priority. Overlap is first_valid or last_valid. Unknown
assessment/unit is the default. Reviewed rows require evidence and operation
history. A match requires a known unit matching the saved target unit. This is
analyst testimony, not automatic validation of datum, epoch, geoid or suitability.

Reopening requires a fresh preflight. Its request, context/selection/group hashes,
source selection hashes and source identities/hashes must match the fingerprint.
Older reviews are retained but not applied to changed inputs. A newer saved review
blocks a stale editor save. The store also checks current saved request and hashes
of metadata files before writing. Source TIFFs are not rehashed during this short
annotation save: the record is tied to the last preflight snapshot, and any future
execution must independently revalidate receipts, raster hashes and all settings.

Missing/failed source hashes block review initialization. A grid REVIEW remains a
REVIEW regardless of analyst annotations. Reviews perform no source relabelling,
unit conversion, resampling, masking, product publication or scientific acceptance.
No backend schema or FGDB identity changes are introduced.

Routes: R/terrain_source_review.R, R/stream_dem_preflight.R, R/study_store.R and
tests/testthat/test-terrain-source-review.R. Article 14 explains the user flow.
