# Stream selection evidence

Candidate browsing order (9020 onward) is transient, not an FG Stream identity or a
scientific stream-order metric. The backend returns source-row mapping, source
ID, navigation_order and order_status. The app requests whole-network
downstream-to-upstream ordering with a NULL origin for both query lists;
the older discovery-origin traversal is superseded. Unresolved candidates
remain selectable, visibly labelled after the ordered portion. COMIDs stay the
checkbox keys regardless of row order. Saving clears selection/name/rationale
but retains the candidate pool and buffer settings for the next Stream.
The discovery origin remains retrieval context, not the candidate sort anchor.
Reach selection uses selection_id (whole COMID or local piece ID), not necessarily
COMID; see [the piece contract](../../../fluvgeo/dev/schemas/reach-pieces.md).

One explicit save publishes a new context revision and a companion
`stream-selection-<uuid>.gpkg`, layers `selected_lines` and `clipped_lines`. The existing context schema
holds Stream ID, Study Area ID, name and area. COMIDs never become FG identities.

The companion retains selected WGS84 NHDPlusV2 geometry, source_id (COMID), name,
candidate_key, discovery direction(s), retrieved_at and source_description.
Backend-added fields: `fg_stream_id`, `fg_buffer_distance`, `fg_buffer_unit`,
`fg_buffer_m`, `fg_buffer_method`, `fg_selected_at` (UTC), `fg_buffer_clipped`
and `fg_removed_m2` (9025 onward), plus `fg_original_m` and `fg_retained_m`
(9027 onward, measured in the local metric processing CRS). Context notes record
relative evidence filename, layer, Stream ID and SHA256. This is not a normalized
provenance table or an automatically checked evidence link on read.

Buffer convention: distance on each side, metres or international feet (0.3048 m).
sf transforms/densifies geographic edges and uses GEOS to clip lines, buffer
retained portions, then clip the area in one local WGS84 azimuthal equidistant
CRS. The projected MULTIPOLYGON retains that CRS; it is not the terrain analysis
CRS. Leaflet receives a WGS84 display copy. No line reversal, topology repair or
floodplain delineation is inferred. Disconnected parts remain visible.

Publication recomputes from server-held lines/parameters. Crossing selections are
clipped rather than rejected. Fully outside/point-only selections cannot create
a Stream. Original geometry remains unchanged in `selected_lines`; the processed
`clipped_lines` layer retains source IDs/attributes only for retained features.
Preview reports selected/retained feature counts and channel lengths, the
unclipped buffer outline and removed area. Grey lines are original selections;
gold lines/area are retained geometry. The backend contract documents geographic
densification (100 m), metric overlay precision (1 mm), the fixed numerical
line-clipping/containment margin (2 mm), and discarded remnants (at most 4 mm).
These are numerical settings, not positional accuracy or a user-selected
floodplain tolerance. The final area clips to the unexpanded parent. Regional
parents are limited to 6 degrees wide/high between 80 S and 80 N; no dateline
crossing. No CRS labels are removed to force planar topology.
Source IDs must be unique and nonempty. Existing spatial Streams are
appended to, not replaced. One names-only Stream can receive an area by exact ID;
several missing areas cannot be mixed with supplied areas in the current format.
Other hierarchy records and relative links are retained.

Evidence is written and reread before the context. This is not a multi-file
transaction: failure can retain orphan evidence for inspection. Stale revisions
and existing destinations fail closed. Retain the entire study folder when moving
this local workspace; earlier contexts are never overwritten.
