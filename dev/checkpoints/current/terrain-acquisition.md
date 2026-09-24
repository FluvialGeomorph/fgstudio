# Terrain workflow: current handoff

## Current implementation and review

Latest: FG Studio 9053 / isolated fluvgeo 9056. Ordinary app preview:
http://127.0.0.1:8791/?study=85fbe60be7c1f957bf3d5f3e9e41f401
Open Survey Events -> 2019-12 -> DEM. The card now identifies a saved Reach portion
and offers Download DEM (GeoTIFF). The launcher is ignored
`dev/check-output/run-saved-dem-preview.R`, with development processing/fixture
options disabled. Mask visualization remains disabled; native bslib collapse
was already owner-verified and was not retested.

The previously verified real-window DEM is now an immutable edition beneath the
actual Study's event-dems/editions directory. `study_dem_store()` adds preparation,
publication, reopening and guarded cleanup methods to `local_study_store()`.
The qualified small-area producer can publish after current binding checks; the
ordinary app can reopen/display/download without any development fixture option.
Only a Reach portion is saved, not a complete Reach or Stream DEM. Exact lifecycle,
metadata and future limitations: `dev/schemas/survey-event-dem.md` and article 13.

Actual worker transfer/publication plus fresh-store reopening, download equality
and map verification completed in 5.95 seconds. Raster computation was not rerun:
the existing cached DEM was copied and metadata-checked in the worker. Saved DEM
and downloaded file match the prior result checksum; original input/settings
checksums remain unchanged. Real-data tests cover publication, stale selection
rejection, edition protection, abandoned-job cleanup, normal view/download and
existing job cancellation/reuse. No synthetic rasters or full Stream runs.

The saved result comes from the same 192-column by 256-row windows in part of
Spencer Creek mainstem Reach R2. Horizontal EPSG:6344 at 1 m, vertical EPSG:8228
NAVD88 international feet, Float32, existing Reach mask and NoData preserved.
No resampling or datum transformation. Prior fixture/cache/provenance remain under
ignored `dev/check-output/real-reach-mosaic/`; `saved-result.rds` records this edition.

Remaining work: full Stream source assembly and qualification against saved grids,
then complete Stream coverage/publication. Continue verifying source combinations
on small real extents. Initial grid convention for general cases remains unconfirmed;
this work reused the already-matching saved grid. The production-style local
edition interface currently accepts only explicitly labeled Reach portions; expand
its scope contract when complete Stream production is actually implemented.

The developer builder is still enabled with fgstudio.dem_trial and the existing
fixture/cache options when needed. Its pipeline remains native mosaic -> mask ->
international feet, with cancellation and reuse. No backend API changed this turn.

Verification handoff: publication/reopening/download/map passed against the actual
Study, and the initial focused suites passed 15 storage/view assertions, 12 job
assertions and 7 preview assertions. Two added abandoned-job cleanup assertions
have not yet run: R startup failed with OpenBLAS memory allocation exhaustion.
Older live R previews consume roughly 1.2–3 GB each. Permission to stop obsolete
previews on ports 8781–8790 (retain 8791) was requested and is still pending; do
not assume approval. Current 8791 preview is running. Source documentation is
updated; generated call-map/articles still need refreshing after memory is freed.
Run the focused test-study-dem-store.R with the real fixture, install this exact
fgstudio snapshot into dev/check-output/doc-library, then run the existing
ignored dev/check-output/document-saved-dem.R with normal workstation/Pandoc and
single-thread environment settings. Do not repeat DEM raster processing.
