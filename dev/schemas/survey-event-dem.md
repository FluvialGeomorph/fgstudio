# Local Survey Event DEM editions

The app-owned `study_dem_store()` adapter stores immutable local output editions
under `<study>/event-dems/editions/<random-id>/`. Backend raster calculations
remain in fluvgeo. Current output scope is explicitly `reach_portion`; neither
publication nor a successful test claims full Reach/Stream coverage or scientific
acceptance of other source combinations.

The edition contains `dem-international-feet.tif` and `edition.rds` with schema
`FGSTUDIO_DEM_EDITION_1`, scope, UTC creation time, byte size, input binding,
processing recipe and compact trial/provenance/display information. Its primary
raster path is relative, resolved only inside the managed edition. The binding
identifies the Study, saved context revision, Survey Event settings revision and
Survey Collection selection. The recipe records source/mask file identity metadata,
backend version, overlap order and units. Source paths remain provenance; a saved
DEM can be displayed and downloaded without development fixture options.

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
settings changes; metadata-only reuse across revisions is future work.

The Survey Events DEM card shows saved status, explicit Reach-portion coverage,
the DEM and a Shiny `downloadHandler` GeoTIFF download. The download serves only
the selected saved result; study directories are not exposed as static resources.
The real-window developer builder remains opt-in. Full Stream source assembly,
source/grid qualification and complete Stream output publication remain unfinished.

Verification uses the existing small real DEM window, exact file checksum equality
for publication/download, fresh adapter/session reopening, stale binding rejection,
and managed cleanup protection. No synthetic rasters or new raster calculations
are needed to qualify this storage increment.
