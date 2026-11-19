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

Draft/input schema 9 uses polygon-centerline-v11. Incompatible earlier methods
do not match the current input fingerprint. Explicit lifecycle cleanup may
retire superseded automatic drafts after checking edits and retaining the accepted
baseline; this is separate from immutable publication. Geometry has at least two XY
vertices; adjacent integer left_bank_vertex/right_bank_vertex identify the
channel. Optional floodplain bends have no vertex cap or centerline-only
restriction. Existing backend profiles retain their historical restrictions.

Banks may be cross section endpoints: two vertices represent the channel alone;
three represent the channel and one straight overbank. Absent or failed legs
contribute no placeholder edge. no_floodplain is legitimate mapped absence;
failed construction retains its distinct status and boundary-gap warning.
Neither implies that terrain coverage is sufficient. Complete legs require
positive geometry; no_floodplain cannot have a positive leg. Current layouts reject
duplicated adjacent vertices. section_parts describes constructed geometry as
channel_only, channel_left_overbank, channel_right_overbank or
channel_both_overbanks; it is not an acceptance or coverage classification.

Channel segments prefer perpendicular to their local channel-centerline tangent;
channel contact/bank-order windows, including those with mapped overbanks, may
use joint bounded angular deconfliction before overbank construction without a
width objective. The saved
Flowline supplies direction with a warning if channel direction is unavailable.
Actual channel_rotation_deg and channel_skewed are refreshed after edits.
Channel contacts, self-crossings, orientation and coverage remain explicit.
channel_deconfliction_status distinguishes perpendicular/resolved_rotation,
unresolved_contact, unavailable_bank_order, search_limit, no_feasible_grid,
unresolved_order and manual_review. Actual channel_rotated, channel_skewed and
channel_limit_exceeded refresh after edits. The latter two use explicit per-row
channel_rotation_review_deg (15 initially) and channel_angle_limit_deg (30
initially). Matching layout_channel_rotation_review_deg and
layout_channel_angle_limit_deg columns retain run policy in degrees. These
provisional geometry bounds do not establish hydraulic acceptance. Windows
include up to two eligible neighbors on each side and have 64-section/50,000-node
limits. Finite-grid failure leaves original flagged geometry. Banks freeze
before overbank routing; generated angular status is distinct from current
contact/order diagnostics. Bank edits set manual_review.

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
numerical separation, then method-v11 bend planning can improve their distribution
jointly with routes. Final selected targets stay fixed during individual routing. Planned targets may
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

Schema 9 retains channel_outer_raw (the threshold-derived outer channel),
channel_reference_centerline (its raw polygon-derived medial route), and
channel_branch_review polygons. Branch review retains integer branch_id, double
mouth_width/depth/advance in explicit feature-CRS measure_units, and logical
removed. advance is extent along the local reference-centerline tangent, not
global chainage; depth is maximum distance from the mouth segment. channel_outer
and the channel hydraulic region contain the prepared mainstem channel. Capped
areas remain in the total floodplain and are partitioned into LOB/ROB.

Branch review adds double attachment_depth (maximum distance from the full
attachment curve, in measure_units) and text cleanup_status: removed,
retained_wide_attachment, retained_reference or retained_topology_guard.
Existing mouth_width/depth/advance keep their chord/local-tangent meanings.
Only depth-screened lobes with a single connected attachment enter this review
layer; it is not an inventory of every shallow raster-edge chip. Run parameters
declare 0.5 m padding, 1 m depth, 0.5 depth/chord ratio and the numerical
attachment-band tolerance. Advance no longer gates removal. Cleanup preserves
the reference route and source component count. Matched region artifacts retain
an explicit prepare_channel choice; the normal app path enables it.

region_diagnostics adds logical route_fragment_fallback and double
route_span_fraction (selected connected skeleton component's Flowline-measure
span divided by the full skeleton-node measure span; measured only for a
fallback). A failed global-anchor route can retry within the component with the
greatest longitudinal span. Original/unavailable routes have a missing fraction; no
disconnected fragments are joined or deleted from the skeleton evidence.

Run parameter overbank_angle_bend declares the optional clamped-initial-angle
waypoint proposal for an ordered target beyond the straight angular bound.
It uses half the endpoint distance, keeps both endpoints fixed and must pass
containment/nonintersection checks. It does not impose a bend on feasible
straight legs or relax the straight-leg angular bound.

Per-section logical left/right_geodesic_direction and left/right_group_routed
retain generated direction-association and group-selection evidence. They do not
assert hydraulic acceptance and remain source-method evidence after manual edits.
side_support direction_status distinguishes geodesic_centerline from a visible
centerline projection. layout_metadata parameters declare channel lobe criteria,
reference/padding, group-search budgets and the crowding/clearance policy. Banks
and ordered targets remain fixed during group repair. The selected family first
maximizes complete routes, then reduces interior crowding without a channel-width
or section-length objective.

The owner accepts the method-v10 channel-pruning recipe and defaults as the
preparation baseline. This acceptance does not change schema versions, confer
hydraulic acceptance or approve unresolved bank-order/overbank-routing issues.
The feature record owns the accepted method and pending refinements.

Method v11 keeps that pruning recipe and schema-9 fields. A bounded whole-bend
pass jointly tests outer target measures and contained routes, with fixed banks
and external sections as barriers. Complete families take priority over adaptive
endpoint spacing, then turn quality. Accepted target measures and existing
left/right_group_routed flags survive publication/reopening. Method identity
prevents automatic reuse of older layouts; it does not invalidate matching REMs
or regional preparation artifacts. Earlier immutable drafts remain evidence.

channel_oriented and outer_chord_oriented are separate logical diagnostics.
The established oriented column remains their conjunction; its meaning is not
repurposed. Bent overbanks can turn the endpoint chord without reversing channel
bank order. The app uses channel_oriented for bank-reversal highlighting and
reports the chord condition separately in summaries/popups. Actual containment,
intersection and boundary-order checks remain independent requirements.

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
