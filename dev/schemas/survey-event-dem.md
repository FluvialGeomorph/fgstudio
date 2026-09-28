# Local Survey Event DEM editions

The accepted storage boundary is GeoPackage vectors/tables with external filesystem
GeoTIFF DEMs and linked metadata, per
[FGDB ADR-0025](../../../FGDB/dev/decisions/adr-0025-folder-deliverables-and-geotiff-terrain.md).
The [completed Esri tests](../../../FGDB/dev/experiments/geopackage-raster/FINAL-FINDINGS.md)
reject the tested GeoPackage numerical-raster round trip. Do not migrate DEMs into
GeoPackages. Analyst download/export controls are not part of this workflow.
The GeoTIFF payload below follows the selected format; its internal RDS index does
not yet fulfill the portable [folder metadata requirements](../../../FGDB/dev/schemas/local-project-folder-requirements.md).
Folder binding, relocation qualification and enterprise transfer remain unfinished.

The app-owned `study_dem_store()` adapter stores immutable local output editions
under `<study>/event-dems/editions/<random-id>/`. Backend raster calculations
remain in fluvgeo. Output scope identifies a Reach, Stream or bounded portion; neither
publication nor a successful test establishes complete source observations or scientific
acceptance of other source combinations.

The edition contains `dem-international-feet.tif` and `edition.rds` with schema
`FGSTUDIO_DEM_EDITION_1`, scope, UTC creation time, byte size, input binding,
processing recipe and compact trial/provenance/display information. Its primary
raster path is relative, resolved only inside the managed edition. The binding
identifies the Study, saved context revision, Survey Event settings revision and
Survey Collection selection. The recipe records source/mask file identity metadata,
backend version, overlap order, units, bilinear resampling and ordered source-grid
run handling (recipe v3). Mixed-grid mosaic metadata retains source resolutions
and source-index runs with their original alignment and interpolation halo.
Single-grid metadata retains its existing spacing/halo fields. Source paths remain provenance; a saved
DEM can be displayed without development fixture options.

Newly calculated trials retain `execution` with schema `FGSTUDIO_DEM_EXECUTION_1`:
completion time, `native_same_crs` implementation, source/output WKT, horizontal
and elevation-conversion methods, datum-operation declaration, and fluvgeo,
terra, sf and linked geospatial versions. `selected_plan` and `proj_pipeline`
are NULL for this native same-CRS producer; no PROJ operation is fabricated.
Publication preserves this record verbatim in `edition.rds`. Cached copies retain
the original evidence rather than claiming a new calculation. This additive
metadata does not change the raster recipe or force existing DEMs to rebuild.

Reopening exposes the original recipe's backend version with `saved_dem`.
`terrain_dem_provenance_ui()` displays retained conversion-input/output references,
methods, datum declaration and backend version. Missing historical information is
shown as not recorded. Existing editions are not rewritten or supplemented from
current Study settings or transformation plans. Full WKT is available in a nested
disclosure; opening it reads saved metadata without scanning pixels.
The Software used disclosure lists only the execution record's package and linked
geospatial versions. It never fills historical gaps from the current runtime.

Workers write only into unique managed staging directories. An already verified
cached DEM can be copied and metadata-checked in a worker instead of recomputed.
Completion rechecks the current binding and trial input recipe. Publication writes
the record and atomically renames the directory into editions on the same volume.
Published editions are never overwritten by a new job. Stale results do not publish.
Cancel/failure/session close stops the worker before deleting its staging directory.
Stage cleanup rejects edition paths and paths resolving outside the managed root.
App/worker PID records permit conservative recovery of abandoned staging only when
both recorded owners have exited; incomplete/unknown owner records are retained.

Reopening reads the small edition record and checks raster presence/byte size; it
does not scan pixels or recalculate hashes. The local managed-file assumption and
size check are not cryptographic integrity verification. Corrupt/missing editions
are skipped. The current strict revision binding excludes earlier results after
settings changes; metadata-only reuse across revisions is future work. Completed
recipe-v1 editions from fluvgeo 2026.09.24.9057 remain reusable against the exact
original input recipe, including paths, sizes, modification times, scope, extent
and selection. Their method remains no-resampling; upgrading the app does not
rebuild unchanged accepted DEMs. Recipe-v2 single-grid bilinear editions from
fluvgeo 2026.09.28.9058 are likewise reusable against the exact earlier recipe.
Recipe-v3 mixed-grid editions from fluvgeo 2026.09.28.9059 and 9060 also remain reusable
after adding transformation planning; its scientific producer is unchanged.
Canonical packageVersion strings omit leading zeroes in date components.

Transformation plans are separate local JSON records under the
[planning schema](terrain-transform-plan.md). They do not yet participate in the
DEM recipe or authorize cross-reference processing. The next execution increment
must bind the saved choice and verified executed pipeline into each resulting
edition, without changing the provenance of existing same-CRS editions.

## Requests, scope and selection identity

Supported scopes are `reach`, `reach_portion`, `stream` and `stream_portion`.
The recipe identifies the target Reach/Stream, optional source-CRS extent and
ordered candidate/file IDs, selection paths and acquisition attempts. An extent
change invalidates reuse. Sources can be original downloaded files or bounded
real-data diagnostic windows. With saved-source resolution enabled, publication
and reopening reject changed selections; receipt checks do not rehash every view.

Full Reach/Stream grid dimensions and alignment must match the corresponding saved
mask before publication. Portion scopes remain for older and bounded diagnostics.
Available mosaic/masked intermediate paths become relative at publication and are
resolved inside the edition on reopening, including earlier staging-path records.
This does not fabricate missing intermediates in cached-final-only editions.

`find_dem(binding, recipe=NULL, stream_id=NULL, scope=NULL)` optionally filters by
Stream and scope. Normal Event tabs request their own Stream edition. Unfiltered
lookup remains backward compatible for older single-result callers. The session
queue publishes Streams independently and serially after current-input checks;
it does not change the storage contract or scientific method.

## Review and qualification

One DEMs card contains Stream maps and optional technical details. Ordinary saved
output needs no development options. No download handler or static exposure of
Study directories is part of the output workflow. See the analyst guide for
controls and article 13 for request/worker/display ownership.

Verification covers real DEM publication with exact file checksum equality,
fresh adapter/session reopening, stale binding/selection rejection, Stream-scoped
lookup and managed cleanup protection. Raster calculations are independently
qualified in fluvgeo. Cross-CRS integration, metadata-only reuse
across revisions and portable folder relocation remain unfinished.
