# Drainage exploration and Stream construction

The Geometry workspace supports reference exploration, Study Area boundary
selection and Stream construction. Reference-service results are candidates;
analysts explicitly select geometry to adopt. Saved names, boundaries and
provenance are independent of transient map navigation.

## Reference exploration

A map location can be snapped to a nearby mapped stream and used to discover
reference channels and watershed candidates. NLDI/NHDPlusV2 requests run in a
cancellable worker. Empty results, partial results, warnings and failures are
reported distinctly. Changing location invalidates the previous candidate state.
Reference display does not write Study geometry.

Candidate channels are ordered downstream to upstream using the whole reference
network. Upstream/downstream query results remain separately identifiable.
The map and compact candidate controls share available screen space. View mode
identifies saved Streams/Reaches and zooms selected records.

## Study Area adoption

Drawing and selected watershed candidates produce a reviewable boundary preview.
Saving publishes a context revision with source evidence. Unfinished geometry
blocks conflicting actions; clearing a draft retains the saved boundary.
`dev/schemas/boundary-selection.md` owns containment and publication requirements.

## Stream construction

Selected flowlines are clipped to the saved Study Area in an appropriate planar
CRS, buffered using the chosen width, then clipped again to the Study Area. The
preview distinguishes retained lines/area from source geometry. Coincident
boundaries use backend CRS-aware predicates; Leaflet coordinates are display only.
Source identities and clipping evidence survive publication.

A successful save appends the Stream, retains candidate/buffer context for another
Stream and clears the completed selection/name. Duplicate or stale selections
cannot publish. Saved inventory and inherited Reach construction use the same
record identities. Stream geometry replacement/removal remain separate work.

## Ownership and verification

`drainage_explorer`, `network_reference`, `drainage_inventory`, `mod_boundary` and
`stream_selection` coordinate session state and the local store. fluvgeo owns
service adapters, CRS-aware geometry and persisted context/evidence. Articles
02-04 explain the callbacks; the Stream selection schema owns exact geometry and
metadata fields.

Tests exercise service failures, stale results, cancellation, containment,
clipping, coincident boundaries, repeated Stream creation and preservation of
saved records. Test doubles are scoped and restored; analyst previews run in fresh
processes. Live-service diagnostics are opt-in. Runtime/workstation procedures
belong to `dev/workflows/r-package-development.md` rather than feature history.
