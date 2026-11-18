# Cross-section deconfliction, regions and layout

Status: local prototype. The owner accepts the channel, left descending-bank
floodplain (LOB), right descending-bank floodplain (ROB), their polygon-derived
centerlines and default cartographic smoothing as the starting artifacts.
Deconfliction is the high-value workflow; intelligent defaults take priority over
further browser editing. Hydraulic acceptance, calculations, governed publication,
whole-section additions and legacy export remain open.

## Analyst outcome

Cross Sections reads the selected Event's saved Flowline, Flowline Points and
Hydro DEM. Midwest REM starting levels are 103/109 ft, relative to 100. Channel
must be below floodplain. Analytical/display REMs are precomputed and reused.
The analyst reviews three polygons, independent raw/smoothed centerlines,
numbered candidates, ordered boundary targets and remaining geometry warnings.
Drafts use standard cross_section naming with explicit table metadata.

Additional floodplain vertices are unchecked by default. When enabled, multiple
vertices may occur anywhere within their own floodplain component; there is no
one-bend cap or centerline-only restriction. Saving a draft retains geometry
and exact lineage without accepting its hydraulic suitability.

## Regions and direction evidence

cross_section_regions() partitions the hole-filled outer footprint into three
multipart regions and disconnected components, without joining gaps. The saved
Flowline runs downstream to upstream; its right side is LOB. Voronoi skeletons
and longitudinal routes use maintained centerline facilities. Douglas-Peucker
simplification and smoothr Chaikin passes propose cartographic smoothing; paths
leaving their own polygon or becoming nonsimple retain the raw route and a flag.
Default boundary spacing is 2 m and smoothing uses two Chaikin passes. The copied
legacy toolbox Centerline raster-thinning implementation is not used.

Tangent distance (20 m initially) measures a local chord along a polygon
centerline. It is separate from cartographic smoothing. Visibility-adjusted
floodplain matching prevents a connector from jumping across a channel
indentation. Short tangent windows and raw-source use are distinct from missing
direction evidence. Centerlines remain geometric proxies, consistent with the
owner's proposed three-region model, rather than measured flow paths. See
[HEC guidance](https://www.hec.usace.army.mil/confluence/rasdocs/ras1dtechref/6.3/basic-data-requirements/geometric-data/cross-section-geometry).

## Perpendicular channel cuts

Sections begin half a spacing upstream of the Reach outlet and increase in
mutable Seq order. These are Reach-local layout distances, not calibrated river
measures. Each channel cut follows the normal to the local channel-centerline
chord, using the saved Flowline tangent with an explicit warning when channel
centerline direction is unavailable. It contains its sampled Flowline station
and uses the connected channel interval containing that station.

Method polygon-centerline-v6 removes channel-width minimization and channel
rotation for conflict reduction. Confluences may therefore produce wide cuts.
Channel contacts remain explicit instead of being hidden by a narrower skewed
cut. Actual departure from perpendicular is recalculated after manual edits.
The historical channel angle_limit_deg argument remains accepted for API
compatibility; v6 constructs zero-rotation channel cuts.

## Ordered anchors and nonintersecting routes

The owner requires the same station rank at both channel banks and the LOB/ROB
outer edges. cross_section_boundary_chains() intersects each participating
floodplain component's boundary with channel and outer-floodplain boundaries,
merges connected linework and orients open chains with the corresponding
centerline (Flowline fallback). Chainage follows the actual shared edge, avoiding
nearest-centerline projections that can fold in bends. Closed/ambiguous chains
and disconnected components are not forced into a fabricated global sequence.

cross_section_order_anchors() verifies bank rank and assigns the proposed outer
positions as a sorted set to increasing Seq on each connected boundary chain.
A bounded angular proposal search reduces contacts and angular departure before
rank assignment. Infeasible sorted targets can then be refined inside their
neighbors' ordered interval using containment and angle checks, before freezing.
A small numerical separation prevents coincident targets. Channel banks remain
fixed. Bank-order conflicts or unavailable chains remain explicit rather than
rotating the channel. These boundary chains and planned outer targets are
reviewable artifacts. Chainage uses the feature CRS unit, recorded in measure_units.

cross_section_ordered_routes() constructs legs to those fixed targets in station
order. Contained straight connections within the floodplain rotation bound are
preferred. Previously accepted legs and all other channel cuts are barriers.
Feasible straight legs are reserved before missing legs receive detours, so an
early added route does not unnecessarily force later straight legs to bend.
If extra vertices are enabled, constrained GEOS triangulation, igraph paths
through triangle portals and visibility shortcuts provide polygon-contained
alternatives. A routed endpoint cannot slide along the boundary to evade a
neighbor. Every accepted leg reaches its assigned target and stays in its own
component; legs are never shortened to hide contacts. Multiple-segment routes
have no single rotation angle, so that field is missing. A failed complete route
leaves a flagged bank-only leg and retains its planned target for review.

This is a deterministic geometric method, not a universal feasibility guarantee.
Order is a structural constraint alongside all-pair contact, self-crossing,
orientation, boundary-gap and containment checks. Ambiguous branch directions,
end caps, insufficient boundary extent and channel contacts require review.

## Review and persistence

Candidates and permanent Seq labels appear by default. Advanced tuning and
existing manual correction controls are collapsed. Ordering boundaries and
Ordered boundary targets are optional Layers; the latter show generated planned
positions, including targets without a completed leg. Candidate popups describe
actual bank/outer order and departure from perpendicular. Editing with boundary
chains supplied refreshes actual order diagnostics without moving geometry.
Generated planning evidence remains distinct from later manual edits.

Polylines have at least four vertices, with adjacent left_bank_vertex and
right_bank_vertex identifying the channel. Floodplain bend counts, routed flags,
normal-direction components, anchor construction status and actual order flags
are additive diagnostics. Manual editing retains candidate IDs; deletion
resequences Seq. Extra vertices do not change the legacy endpoint fields' names,
types or coordinate units.

Draft/input schema 5 and method v6 save cross_section, boundary_chains,
boundary_anchors, hydraulic_regions, region_components, centerline/raw/skeleton,
source footprints, side_support and layout_metadata. Prior drafts remain on disk
and do not match v6 fingerprints. The retired loess support field stays typed
missing; tangent and cartographic parameters retain separate fields. Local IDs
do not settle governed FGDB identity. See [draft storage](../schemas/cross-section-drafts.md),
article 18 and the [FGDB contract](../../../FGDB/dev/schemas/cross-section-feature-contract.md).

cross_section_rem_artifact() publishes persistent analytical/display GeoTIFFs,
limits and exact source/recipe/output hashes. Flowline Points queues Reaches
sequentially while active; Cross Sections reuses these files or prepares a
missing Reach. Water levels and layout controls do not invalidate the REM.
A matching saved draft reopens without recalculating layout. Changing controls
can also reuse another saved draft for those exact settings. The inherited
150-coordinate-unit corridor can truncate floodplain evidence (150 m in this
project); these are local preparation assets rather than governed REM products.

## Verification and further development

Focused tests cover partition/containment, descending-bank labeling, explicit
missing evidence, endpoint rank repair, fixed-target routing, multi-bend routes,
perpendicularity at a synthetic confluence with a shorter skewed alternative,
manual order diagnostics, exact field contracts and GeoPackage reopening.
Saved R1 sections 19/30 and LOB 35-39 are opt-in real-data review cases. Current
measurements and preview state belong in the resumable checkpoint.

The owner's proposed subdivision centerlines (informal quartile guides) are a
potential adaptive extension for wide/ambiguous channel, LOB or ROB polygons.
Centerlining two halves does not guarantee equal quarter widths, areas or flow.
Such guides could supply deterministic extra waypoints/directions while ordered
anchors and nonintersection remain constraints. This proposal is not implemented
or a new default; channel bend geometry would require a separate explicit contract.
Cross-Reach handling, broad data/performance qualification and legacy export remain open.
