# Cross-section implementation handoff

## Owner direction and scope

Deconfliction is the high-value capability. Preserve the accepted channel, LOB
and ROB polygons, independent polygon centerlines, 2 m boundary spacing and two
Chaikin passes. Tangent distance is separate from cartographic smoothing. The
copied legacy toolbox Centerline code is not used. Midwest defaults are 103/109
ft relative to 100. Additional floodplain vertices remain unchecked by default;
when enabled they may occur anywhere in the component without a one-bend cap.
Prioritize intelligent defaults over further browser editing. Number by Seq.

On 2026-11-18 the owner directed ordered boundary anchors followed by
nonintersecting routing, and removed channel-width minimization because it
skewed cuts at confluences. Channel cuts now stay perpendicular to local
centerline direction. The owner's subdivision-centerline / informal quartile
proposal is a possible adaptive guide for wide/ambiguous channel/LOB/ROB regions,
not an implemented default. Centerlining two halves does not guarantee equal
quarter width, area or flow. Channel bends require a separate geometry contract.

## Current implementation

fluvgeo/R/cross_section_layout.R uses polygon-centerline-v6. Connected channel
cuts contain sampled Flowline stations and have zero deliberate channel
rotation. Missing channel-centerline direction uses the Flowline reference with
an explicit flag. Width minimization is removed. Bounded floodplain angular
alternatives remain tentative endpoint proposals; they do not override final
rank constraints. Original polygons/centerlines are unchanged; their independent
artifact fingerprint stays polygon-centerline-v2.

cross_section_order.R extracts directed shared bank/outer chains and whole-channel
bank arcs across floodplain component changes. Bank rank is checked in station
order. Proposed outer positions are assigned in Seq order and, if needed,
refined within neighboring ordered intervals before freezing. Feasible straight
legs are reserved before missing legs receive polygon-contained detours. Fixed
targets cannot slide along the boundary to evade a neighbor. Other channel cuts
and accepted legs are barriers. Unavailable routes and channel contacts remain
explicit. Numerical margins use small native buffers; containment is audited
against the original polygons.

cross_section_deconflict.R uses GEOS constrained triangulation, triangle portal
igraph routing and visibility shortcuts. Fixed endpoints tolerate numerical
boundary roundoff without moving the requested target. Optional routing requires
sf >= 1.1-2 / GEOS >= 3.10; the isolated library has sf 1.1.2 / GEOS 3.14.1.
There is no floodplain bend-count cap. Channel bank indices remain adjacent;
channel multiple-vertex geometry is not implemented.

Draft/input schema 5 stores standard cross_section plus boundary_chains and
boundary_anchors, alongside existing polygon/centerline/footprint/source evidence.
Anchor chainage uses feature CRS units recorded explicitly. Generated bank and
planned outer anchors remain distinct from manual edits. Review refreshes actual
bank/outer rank, channel skew, contacts and coverage. Anchor foreign keys/Seq
follow candidate ID assignment, deletion and resequencing. Publication rejects
method/identity mismatches. Prior revisions remain on disk and do not match v6.

The app provides optional Ordering boundaries and Ordered boundary targets in
Layers. Candidates/Seq numbers remain visible; advanced/manual controls remain
collapsed. Exact matching drafts can be reused when changing controls, avoiding
layout recomputation. The current preview should retain 103/109 and extra
vertices false. Both straight/routed settings are saved for immediate comparison.
Persistent precomputed analytical/display REMs remain independent of layout
controls; all 11 saved 2019-12 Reaches have preparation assets.

## Evidence and unresolved work

Owner review after v6 recognizes two-vertex channel-only cutlines and one-sided
overbanks as legitimate geometry, with perpendicular-ish, nonintersecting
channel cuts. This is the next contract refinement, not implemented by v6:
current constructor/validator/editor still require four vertices and duplicate
banks for absent overbanks. no_floodplain is already a legitimate status.
For R1, 1/2 have no contacts; 3-10 have genuine channel contacts. Removing
duplicate coordinates alone will not resolve those contacts. A bounded-angle
developer probe found one ordered, disjoint two-point outlet layout with up to
30-degree departures; this is exploratory evidence, not a proposed automatic
threshold or proof that smaller departures are infeasible.

Section 27's orange flag was numerical: LOB rotation -30.00000000017617 degrees,
with no other geometry/order/coverage flags. The display comparison now uses
the backend's 1e-7-degree tolerance at the 30-degree review threshold. All
generated lines still use the provisional term candidate; this is separate
from requiring correction.

Focused geometry/order tests cover endpoint rank repair, whole-channel rank,
perpendicularity with a shorter skewed confluence alternative, fixed targets,
numerical boundary roundoff, multi-bend routing, and reserving later straight
legs when filling an early gap. Established legacy-validator tests and targeted
Rd checks pass. App/store checks include new evidence layers, anchor foreign
keys and seven-vertex GeoPackage reopening. R coordinate matrix row labels are
not portable geometry; compare coordinate values, not those labels.

Opt-in final R1 evidence is under ignored dev/check-output/ordered-r1.rds.
At 103/109 ft, 20 m spacing/tangent distance, 2 m boundary spacing, two Chaikin
passes and a 30-degree floodplain bound, there are 84 sections and no floodplain
contacts or boundary-order conflicts. Straight defaults leave LOB 31/32
incomplete. Optional routing completes them with two total added vertices,
retaining other straight legs. Sections 19/30 are perpendicular with complete
legs; LOB 35-39 are straight, complete and ordered in both modes. All 148 routed
floodplain legs remain within their own component (maximum numerical outside
length about 1e-6 m), with unchanged banks and source centerlines.

Eight channel sections (3-10) contact one another at the broad outlet. Five
show channel-bank rank problems. They remain flagged instead of being rotated
into narrower cuts. This is the primary next geometry/direction review case;
extra floodplain vertices do not resolve it. The inherited 150-coordinate-unit
REM corridor and unavailable further downstream terrain remain limitations.
Cross-Reach conflicts, hydraulic calculations, governed publication and legacy
export remain open. These are targeted checks, not full release qualification.

The fresh whole-app preview was verified in 2019-12 / Spencer mainstem / R1.
Both cached settings reopen with the explicit no-layout-recomputation status;
routed mode shows zero incomplete floodplain legs and two added vertices.
It is left on straight defaults, additional vertices unchecked, REM hidden,
Candidates/Seq labels visible and one map zoom step enlarged. New Ordering
boundaries / Ordered boundary targets layers are present and optional. Rotation
counts ignore numerical angular roundoff below 1e-6 degrees; popups round angles
for display. The documentation build and 781 local links pass. Initial study
opening and first layout generation remain substantial work; no broad speed
qualification is claimed. A three-panel review figure is retained under ignored
dev/check-output/ordered-cross-sections-r1.png. Known host locale and installed
binary R-version startup warnings remain.

## Runtime

Resolve R/Pandoc through .agents/workstation.md; use fgstudio/dev/local-library.
Run substantial R work sequentially. Launch dev/scripts/run-dev.R in a fresh
separate process on port 8780, with the whole app and saved Study context.
Never use a test process as preview. Preserve existing uncommitted feature work
and pre-existing FGDB staged/unstaged changes. No commit, shared-library update,
customer deployment or production qualification is implied.
