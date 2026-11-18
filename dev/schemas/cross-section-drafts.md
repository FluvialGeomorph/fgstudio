# Local cross-section drafts

Status: local preparation profile, not governed FGDB publication. FGDB's
cross-section-feature-contract.md owns standard naming and metadata.

study_cross_section_store() publishes immutable Study-local
cross-sections/<revision>/cross-sections.gpkg drafts. Standard cross_section
retains ReachName, integer Seq and exact double endpoint fields in feature CRS
units. Opaque candidate_id is local identity; Seq is mutable review order.
Layout spacing, tangent distance, cartographic settings, floodplain rotation
bound, extra-vertex permission, REM thresholds/reference/units and method remain
explicit columns. The retired layout_direction_window_m remains typed missing.
No descriptive variables are encoded in feature-class names.

## Version and geometry

Draft/input schema 5 uses polygon-centerline-v6. Earlier drafts remain on disk
and do not match the current input fingerprint. Geometry has at least four XY
vertices; adjacent integer left_bank_vertex/right_bank_vertex identify the
channel. Optional floodplain bends have no vertex cap or centerline-only
restriction. Existing backend profiles retain their historical restrictions.

Channel cuts are perpendicular to their local channel-centerline tangent;
width minimization and conflict-driven channel rotation are removed. The saved
Flowline supplies direction with a warning if channel direction is unavailable.
Actual channel_rotation_deg and channel_skewed are refreshed after edits.
Channel contacts, self-crossings, orientation and coverage remain explicit.

Each side retains region_id, supported/inferred flags, bend count/presence,
routed flag, leg status, nullable rotation in degrees, source/visibility evidence
and normal_dx/normal_dy direction components. no_floodplain means zero mapped
width, distinct from a missing leg. no_ordered_route means a complete route to
its assigned outer target could not be constructed under the selected settings.
Multiple-segment routes have no single rotation angle. Straight generated legs
respect the declared rotation bound. Manual edits retain manual_review status.

## Ordering evidence

boundary_chains is a LINESTRING layer with chain_id, region_id, role and oriented.
Bank and outer roles follow actual shared channel/floodplain edges within each
component. Whole-channel left_channel_bank/right_channel_bank arcs also check
bank order across floodplain component changes. Their directions follow station
order; ambiguous arcs retain an explicit flag. Components are never bridged.

boundary_anchors is a POINT layer with candidate_id, Seq, side, role, region_id,
chain_id, proposed_measure, measure, status and measure_units. It records generated
bank anchors and planned outer targets. Chainage is in feature CRS units, not
necessarily metres. Sorted outer positions are assigned to Seq order with small
numerical separation. Targets stay fixed during routing. Planned targets may
remain even when the corresponding candidate leg could not be constructed.
Channel-bank anchor rows provide separate whole-channel ordering evidence.

Actual *_order_status and *_order_conflict fields are recomputed from current
section geometry when boundary chains are supplied to cross_section_layout_review().
channel_left_order_status/channel_right_order_status, channel_order_conflict and
channel_order_review distinguish whole-channel rank problems or unavailable
evidence. Generated anchor planning evidence remains distinct from later manual
edits. Saving refreshes actual diagnostics; it does not silently sort edited
endpoints, move banks or repair geometry.

## Other evidence and lifecycle

Existing layers retain three multipart hydraulic_regions, region_components,
centerline/raw/skeleton, region_diagnostics, outer footprints, original inundation
when available, side_support and layout_metadata. The latter stores JSON-valued
lineage, settings, parameters, software, creation time, schema and draft review
state. Matching drafts reopen these layers directly without recalculating layout.

result.rds is the local reopening index; provenance.json repeats portable
provenance. Fingerprints include exact Study/Event/Flowline Points hashes, Reach
identity and complete upstream lineage. Publication re-resolves inputs, rejects
stale revisions, hides PENDING writes and verifies the GeoPackage hash on reads.
Manual edits preserve candidate keys; deletion resequences Seq. Saving may retain
flagged geometry for review and does not constitute hydraulic acceptance.

REM preparation is separate from draft revisions: persistent external rem.tif,
display.tif and preparation JSON/RDS under cross-section-preparation/<hash> retain
exact inputs/recipe/output hashes. Water levels and layout controls do not
invalidate the REM. Flowline Points queues preparation; Cross Sections reuses it
or prepares a missing Reach. These are local assets, not governed REM editions.

Governed cross-section/Survey Event/Dataset Edition identity, accepted calibrated
stationing, legacy-profile export and enterprise transfer remain unfinished.
