# Cross-section layout MVP

Status: owner-accepted method-v11 baseline, 2026-11-19. The owner considers the
current result an "80% solution," sufficiently performant and good for now.
This closes the active cross-section development increment, including the
accepted method-v10 channel-pruning recipe retained within v11. Residual shape
improvements are parked unless the owner reopens them. Acceptance covers this
per-Reach geometric workflow; hydraulic calculations, model acceptance,
enterprise publication and legacy-format export have separate contracts.

The subsequent two-method direction is governed by
[FGDB ADR-0027](../../../FGDB/dev/decisions/adr-0027-two-cross-section-methods-and-reference-families.md):
RAS-style uses bankfull centerline stationing for new work/rework; simple retains
Flowline referencing for legacy compatibility. Follow the
[implementation plan](../goals/cross-section-implementation-plan.md). The baseline
behavior described here remains Flowline-stationed until that integration lands;
stationing changes do not reopen optional v11 geometry optimization.

## Design intent and stopping point

Automatic deconfliction is the principal value of this tooling. Produce
intelligent, deterministic defaults with minimal analyst input, reducing the
need to hand-draw HEC-RAS-style cross sections. The channel, left descending-bank
floodplain (LOB) and right descending-bank floodplain (ROB) are independently
reviewable compartments. Their polygons and centerlines expose how direction
and routing were derived, so hydraulic engineers can review the artifacts.
These compartments can support separate future calculations; geometry alone
does not implement or validate hydraulic formulas.

The accepted balance favors complete, contained, ordered, nonintersecting
sections over cosmetic perfection or exhaustive search. The tightly fanned
LOB 109-114 result is an accepted limitation of the present bounded search,
not an automatic next development task or proof that a better shape is
impossible. Do not weaken accepted pruning, restore length minimization or
expand search merely to make every remaining candidate look ideal. Additional
browser editing, polygon subdivision/quartile guides and further optimization
are unselected options. The next planning discussion is the
[XS 268 reference decision](../goals/project-plan.md#near-term-decision-gate-the-xs-268-issue)
before further feature expansion; this record does not choose a new reference.

## Final requirements and intelligent defaults

- Represent channel, left descending-bank floodplain (LOB) and right
  descending-bank floodplain (ROB) as separate review polygons, each with an
  independently derived centerline. Preserve disconnected components and source
  inundation evidence. Use maintained Voronoi skeleton/route and cartographic
  smoothing facilities rather than the copied legacy toolbox Centerline code.
- Start at channel REM 103 ft and floodplain REM 109 ft, relative to 100. Keep
  channel below floodplain. Precompute and persist analytical/display REMs for
  reuse across sessions and layout settings.
- Use 20 m cross-section spacing along the saved Flowline, beginning half a spacing upstream of the Reach
  outlet. Number sections by mutable integer Seq increasing upstream. Use 20 m
  centerline tangent distance, 2 m polygon-boundary spacing and two Chaikin
  smoothing passes. Tangent distance measures direction; the latter two settings
  control geometric centerline construction and smoothing.
- Prefer channel XS segments perpendicular to local channel-centerline direction.
  Preserve their sampled stations and complete connected channel crossings.
  Width/length minimization is excluded. Available Flowline direction is an
  explicitly flagged fallback when polygon-centerline direction is unavailable.
- Deconflict automatically with minimal analyst input. Bank and outer-endpoint
  rank must follow section station order. Cross sections must not intersect or
  touch one another, including coincident overbank endpoints. Seek meaningful
  outer-edge spacing where feasible; numerical separation alone is not the
  distribution objective, and no universal hydraulic minimum is asserted.
  Preserve geometry/coverage evidence when a complete valid
  result cannot be constructed; never shorten a segment to conceal a conflict.
- Allow additional floodplain vertices by default. Prefer feasible straight
  segments, adding multiple bends when needed anywhere inside their component.
  There is no one-bend cap or centerline-only placement restriction. Maintain
  ordered outer targets during joint planning; final routes must reach their
  assigned targets and cannot slide an endpoint past a neighbor.
- Treat channel-only and either one-sided overbank as legitimate. A channel-only
  cross section has two bank vertices. A straight one-sided cross section has
  three. Do not fabricate a floodplain or duplicate a bank coordinate to satisfy
  a vertex minimum. Distinguish absent mapped overbanks from failed construction
  or incomplete terrain evidence.
- Make polygons, independent raw/smoothed centerlines, section numbers, ordering
  boundaries, planned outer targets and current geometry diagnostics reviewable.
  Use channel XS segment, LOB XS segment and ROB XS segment. Reserve cutline for
  Hydro Modify drawings. Existing manual corrections are optional; further
  in-browser editing is lower priority than automatic defaults.
- Support every saved Stream and Reach with matching Flowline Points and Hydro
  inputs. Retain valid Reach selection while inputs reopen. Present loading and
  computation feedback above the map before potentially slow work begins.
- Save/reopen immutable local drafts using the standard cross_section table and
  explicit parameter/provenance metadata. Preserve established ReachName, Seq
  and endpoint names, types and coordinate units. Keep local candidate identity
  distinct from governed FGDB identity. Save-time validation rechecks lineage;
  draft persistence does not confer hydraulic acceptance.

Centerline tangent distance is the distance along a polygon centerline used to
estimate local direction; it is not a smoothing control. Boundary spacing
samples the polygon for Voronoi skeleton construction, while smoothing passes
control the cartographic proposal. The polygon skeleton supplies a route, not
a guarantee that every smoothed proposal remains contained. Inferred support
means geometric direction evidence supplied through an indirect/contained
association or fallback; it is not an observed hydraulic flow measurement.
Keep direction uncertainty, absent mapped overbanks, failed routing and terrain
coverage as separate diagnostics.

## Current geometric method

cross_section_regions() partitions the hole-filled outer footprint into three
multipart parent regions and disconnected components without joining gaps.
Voronoi skeletons and longitudinal routes use maintained centerline facilities.
Douglas-Peucker simplification and smoothr Chaikin passes propose smoothing;
paths leaving their polygon or becoming nonsimple retain the raw route and a
flag. Visibility-aware direction matching remains within its own component.
Short tangent windows, raw paths and unavailable direction are distinct evidence.
These centerlines are geometric direction proxies, not measured hydraulic flow
paths. See [HEC cross-section geometry guidance](https://www.hec.usace.army.mil/confluence/rasdocs/ras1dtechref/6.3/basic-data-requirements/geometric-data/cross-section-geometry).

cross_section_layout() constructs full channel crossings through the sampled
stations. Contacting or bank-order-conflicted channel sections, with or without
mapped overbanks, and up to two eligible neighbors on
either side receive joint angular search; other sections remain fixed. The
2.5-degree grid is searched within 30 degrees by default, preferring smaller
maximum tested departures. Strict bank rank and all-pair nonintersection are
hard constraints. Cyclic boundary chainage prunes finite constraint search;
actual directed bank arcs and GEOS contacts independently audit the result.
Windows are bounded to 64 sections and 50,000 nodes. Failed, ambiguous or
exhausted windows retain original flagged geometry. Larger-angle review begins
above 15 degrees; that threshold and the search bound are local review policy,
not universal hydraulic limits. The owner accepted the baseline's remaining
angular-review candidates for this MVP.

cross_section_order.R extracts directed shared bank/outer edges and whole-channel
bank arcs. Proposed outer positions are assigned in Seq order and, when needed,
refined within ordered neighbor intervals before freezing. Ambiguous/closed
chains and disconnected components retain explicit diagnostics.

cross_section_ordered_routes() reserves feasible straight overbank segments
before routing missing ones. Accepted segments and other channel crossings are
barriers. GEOS constrained triangulation, igraph triangle-portal routing and
visibility shortcuts supply contained routes to fixed targets. Bends require
sf >= 1.1-2 and GEOS >= 3.10. Every constructed segment reaches its assigned
outer target and remains in its own component. Missing routes retain a bank
endpoint and an explicit status, independently of legitimate no_floodplain.

## Review, persistence and operation

Orange identifies geometry or direction review; it does not alone mean a
candidate is unusable. Review recomputes actual contacts, bank order, orientation,
angular departure, boundary gaps and containment after edits. Generated targets
remain planning evidence. A zero boundary gap alone does not establish coverage.

The owning [draft schema](../schemas/cross-section-drafts.md) specifies versioned
storage, typed fields, layers and readers/writers. The [FGDB contract](../../../FGDB/dev/schemas/cross-section-feature-contract.md)
owns standard naming and records the portable draft binding. Parameters belong
in tables rather than descriptive feature-class names. The retired compatibility
column is documented only in the structural contract.

Cross-section REMs are persistent local preparation assets with exact input,
recipe and output hashes. Water levels and layout settings do not invalidate
those rasters. Matching saved drafts reopen without recomputing geometry.
Loading reuses already validated Flowline Points within the same context and
revision; source changes invalidate that session reuse. New input validation,
REM preparation and the polygon/centerline/deconfliction stages have visible
feedback. Publication still revalidates exact upstream lineage.

## Verification and scope boundaries

Controlled package tests cover region containment, descending-bank labels,
channel station/width preservation, joint nonintersection/bank ordering,
infeasible-search fallback, fixed-target multi-bend routing, legitimate absent
and one-sided overbanks, explicit failure/coverage statuses, geometry editing,
legacy fields and mixed-size GeoPackage round trips. Real Study results are
opt-in qualification evidence, not automatic fixtures. The performance audit
records measured stage costs and representative Reach checks in
[cross-section performance](../performance/cross-sections.md).

Processing is per Reach. Cross-Reach deconfliction, unresolved bounded channel
searches, ambiguous branch directions, further subdivision guides,
hydraulic calculations, governed publication and legacy export remain separate
work. The existing REM corridor may truncate terrain evidence; data coverage is
always separate from geometric validity.

## Accepted channel polygon pruning

The owner accepts the method-v10 channel polygon pruning approach and its
defaults after reviewing large, hooked, stubby and narrow arms on R2. This is
the channel-preparation baseline for cross-section development, not a pending
proposal. Channel preparation uses the **channel polygon's own raw medial
centerline** as its geometric reference. The saved Flowline identifies the
longitudinal skeleton route; it does not supply the cleanup envelope or local
width. Boundary-distance discs along the channel centerline, padded by 0.5 m,
identify off-route lobes. A native overlay against the envelope expanded by 1 m
screens out shallow raster-edge chips before per-lobe evaluation. Eligible lobes
have one connected attachment curve, at least 1 m attachment depth, and depth
at least half the attachment endpoint chord width. Tangent advance is retained
as a diagnostic, not a rejection rule for hooked/parallel arms. A numerical band
of boundary spacing times 1e-7 stabilizes attachment extraction. Eligible lobes
are removed in one overlay along the envelope; no repeated whole-channel splits
or recursive pruning occur. The reference route, component count and valid
geometry are protected; all other original banks remain unchanged. Failed
topology guards retain the source channel with explicit review status.
Padding/depth defaults are independent of boundary sampling and converted from
metres to feature-CRS units. They are geometric review defaults, not universal
hydraulic or tributary classification rules. Raw channel, depth-screened
candidate/removed lobes and reference centerline are
retained for review. Removed areas remain in the total floodplain partition.

Keep this accepted pruning recipe stable in subsequent work. A routing failure is not evidence
that pruning should be weakened or its removed areas excluded from overbanks.

## Current centerline and bend routing

If global skeleton anchors fall in disconnected fragments and route extraction
fails, centerline construction retries within the connected skeleton component
with the greatest longitudinal span. Boundary clearance and coordinates break
ties. Existing successful routes remain unchanged, and fragments are never
joined. Region diagnostics record route_fragment_fallback and the selected
route_span_fraction. This prevents a tiny detached endpoint fragment from
discarding the main route of an otherwise usable polygon.

When ordered targets put a straight leg beyond its angular bound, optional
routing can first try one genuine bend at half the endpoint distance, with its
initial direction clamped to the angular bound. Both endpoints stay fixed;
containment and all-pair nonintersection still apply. This single proposal is
only used when needed, not a default bend on every leg, and does not relax the
straight-leg bound. Existing polygon/group routing remains the fallback.

When a bank cannot see its floodplain centerline directly, a contained geodesic
association supplies explicitly inferred direction evidence. Contained paths can
also seed full outer-boundary targets. Group repair releases earlier reservations
in difficult neighborhoods, reuses a constrained mesh, and tries four priorities.
It first maximizes complete routes, then reduces crowding of their interiors.
Clearance preference is derived from neighboring bank spacing, not a channel-width
or section-length objective. Banks and ordered targets stay fixed. Search is
bounded and unresolved cases remain flagged. The [R2 investigation](../performance/cross-sections.md#r2-sinuosity-investigation)
owns qualification evidence; accepted R1/R2 method-v11 drafts are the current references.

The loading cue occupies a reserved status slot. Its synchronous-work fallback
appears only after 650 ms of continuous Shiny busy time; short worker polls do not
replace phase text or shift the controls/map.

## Whole-bend endpoint distribution and route quality

Channel preparation and cross-section routing are separate stages of the
accepted method; routing limitations do not invalidate accepted pruning.
The [tight-bend audit](../performance/cross-sections.md#remaining-tight-bends-and-endpoint-distribution)
records the original causes and current qualification. Current stations
are sampled along the saved Flowline, while channel direction comes from the
polygon centerline. These references can diverge in tight bends. Map numbers
currently sit at channel-bank midpoints rather than at sampled stations.
Changing the spacing reference requires an explicit placement decision and
preservation of established Flowline distance metadata.

Bank-order/contact repair precedes overbank construction also where mapped
overbanks exist. After initial fixed-target routing, a whole-bend pass considers
crowded endpoints, incomplete legs and legs with multiple bends. Overlapping
neighborhoods form families of at most 32 sections. Bank vertices remain fixed;
other sections are barriers. The planner jointly tests isotonic spreading,
two relaxed allocations, an even allocation and the incumbent targets, with three
deterministic routing priorities and one reusable mesh per component.
Existing valid paths can guide continuous, contained deformation to the new
targets before rebuilding routes from the mesh. Fixed graph geometry, boundary
clearance and point/triangle associations are reused; current obstacle contacts
are always recomputed.

Useful target separation is derived from median neighboring bank spacing / 4,
capped at 0.7 of the available boundary arc per slot. This is an adaptive
geometric preference, not a hydraulic minimum. Completion takes precedence over
spacing deficits, then unnecessary turns and backtracking. A replacement must
complete the entire family and preserve every already complete leg. Target order,
polygon containment and nonintersection remain hard constraints. If no feasible
improvement is found, the existing family is retained. Changed target measures
and group-selection flags are persisted with method v11; pruning artifacts and
the schema-9 field contract are unchanged. No section-length objective is used.
The near-term [XS 268 decision gate](../goals/project-plan.md#near-term-decision-gate-the-xs-268-issue)
owns the deferred question of changing the linear-reference basis.
