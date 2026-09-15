# Boundary selection evidence (app-local version 1)

This is FG Studio companion evidence, not a change to the FGDB or fluvgeo context
schema. A successful selection save adds a `boundary-selection-<random>.gpkg`
beside the study revisions. Its `selected_polygons` layer retains one feature
per explicitly selected source polygon in EPSG:4326, with these fields:

- candidate_key: app-derived SHA256 key from source type and source identifier.
- source_type: huc12 or basin.
- source_id: supplied HUC12 identifier, basin origin COMID, or an explicitly
  labeled geometry hash when no source identifier was supplied.
- name: supplied geographic name or a clearly labeled descriptive fallback.
- retrieved_at: source request's UTC retrieval time.
- source_description: WBD 2025 or NLDI/NHDPlusV2 basin method description.
- selected_at: UTC time of the explicit save operation.
- geometry: selected source polygon snapshot (not the combined boundary).

The new context's analyst note identifies this relative filename, layer, SHA256,
union method and optional user rationale. The context retains the combined Study
Area boundary and its existing identity, Purpose and children. Source IDs are
not FG identities. Repeated discovery of the same source retains the first
snapshot for that selection session; no silent refresh of selected geometry.

Source count, identifiers and geometric equality are checked after writing the
evidence file. Revision publication is non-replacing and guarded by expected
source revision. An evidence file may survive a later failed revision; reopening
the highest saved context, not presence of an evidence file, establishes state.
