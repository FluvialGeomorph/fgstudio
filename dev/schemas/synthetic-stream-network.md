# Synthetic stream candidate schema

## Purpose

This contract stores the first-cut, terrain-derived `stream_network` candidate
for analyst review without treating it as accepted FGDB content.

## Binding

One immutable revision belongs to one Study, Survey Event, Stream, Hydro cutline
revision and Hydro DEM SHA-256. Publication must reject changed context, drawing
revision or Hydro output. The threshold is positive hectares. Outlet evidence
records the terminal and available next-downstream COMID, crossing or terminal
endpoint, search distance, selected boundary cell/elevation and method.

## Files

- `routing.tif`: conditioned routing surface; never replaces the Hydro DEM.
- `fill-depth.tif`: positive elevation change evidence on the source grid.
- `flow-direction.tif`: resolved D8 code grid.
- `flow-accumulation.tif`: upstream-cell count grid.
- `stream-network.gpkg`, layer `stream_network`: maximal lines between heads,
  junctions and outlet with cell/accumulation/length attributes.
- `result.rds`, `provenance.json`, `outlet.rds`: internal index, portable method
  evidence and outlet evidence.

## Lifecycle

Jobs write only to `processing-<id>`. `study_stream_network_store()` atomically
renames a complete, still-current job to `<revision>`. Failed, cancelled or stale
jobs are discarded. Reopening selects the newest complete revision matching the
current Hydro SHA-256. Older revisions and all source/Hydro terrain remain.

Changing the initiation threshold creates a new immutable revision by reusing
the saved direction and accumulation rasters and rebuilding only the vector.
