# ADR 0007: Iterative terrain acquisition and Survey Event assembly

Status: owner requirements accepted, 2026-09-19. Implementation is incremental.

## Decision

- Discovery and acquisition planning share one coverage map. Visibility is
  independent of inclusion and product intent; isolate an inspected footprint or
  compare an explicit set without deselecting acquisitions.
- A precomputed DEM must have ground pixel size **1 m or finer**. Coarser DEMs
  cannot supply this analysis; obtain point clouds to construct suitable terrain.
  Unknown resolution requires verification, not assumed eligibility. Resampling
  coarse data to 1 m is not a substitute for adequate source resolution.
- Adequate pixel size does not establish suitability. Downloaded DEMs need visual
  inspection and processing/provenance review, including hydro-flattening. An
  unsuitable DEM leads back to source discovery/product planning and potentially
  point-cloud acquisition. Study configuration is revisable, not a one-way wizard.
- A Reach Survey Event may be assembled from **one or more Survey Collections**.
  Clearinghouse distribution seams are not event boundaries. Keep individual
  source identities and contributions; dates/names alone cannot prove common
  acquisition or authorize merging. A source can contribute to multiple Reaches.

## Acquisition extent clarification

Owner decision: use the saved **Stream polygon** as the high-resolution terrain
acquisition AOI, not the whole Study Area. Study Area catalog discovery remains
useful for finding surveys; it is not the download footprint. No whole-Study-Area
high-resolution acquisition option is required. Provider tiles may extend beyond
the AOI; tile transport extent must not be confused with the intended terrain AOI.

The new workflow targets a **Stream Survey Event DEM** assembled from the needed
source datasets. If Reach-extent DEMs remain necessary, derive them from that
Stream Survey Event DEM rather than independently acquiring/processing terrain
for each Reach. Historically both Stream-first and direct Reach DEM production
were used (owner-reported practice, not a repository audit).

Still open: whether Reach DEMs need physical persistence or can be generated on
demand; the representation of Stream-level survey/terrain identity and its links
to existing Reach Survey Events. This decision does not silently change the
current Reach-associated Event schema or prescribe mosaicking algorithms.

## Implementation boundary

Study Area terrain is a separate future role: broader-scale analyses such as
watershed delineation can usually use mid-resolution DEMs. This is not a reason
to download high-resolution terrain for the entire Study Area. Defer its physical
storage/API/schema scaffolding until that workflow is designed; retain distinct
terrain scope, resolution, purpose and provenance in the eventual design rather
than assuming one DEM per Study Area serves all uses. No new FGDB fields added.

Shared map controls; explicit USGS dem_gsd_meters evidence and resolution screen;
editable saved product plans with revision history. USIEI point spacing is not
DEM pixel size. Missing evidence stays unknown. Neither selected nor planned
means downloaded, inspected, suitable or accepted.

## Required subsequent implementation

Asset download/registration and visual terrain review; durable acceptance or
rejection with rationale, metadata and asset identity; source-to-Event links
allowing multiple source contributions. Preserve rejected candidates and prior
choices as evidence, and invalidate/review downstream decisions when inputs change.
Do not automatically create Events from catalog records or add mosaic/point-cloud
processing algorithms without the owner-led design step. No Enterprise schema
migration is implied by this local design record.
