# Storage documentation

The human storage crosswalk is `vignettes/storage-model.Rmd`. It starts with FGDB
objects and their ownership, then relates functions to GeoPackage feature layers/
tables and external GeoTIFF products. The numbered articles' Data objects and
storage tables give operation-level inputs, outputs and persistence effects.

FGDB owns the conceptual model, feature catalog, kernel relations, platform
crosswalk and folder-delivery contract. Distinguish accepted invariants from
proposed physical bindings. Local source acquisitions, masks and Stream DEMs are
preparation assets; they are not automatically governed Reach Survey Event content.
Do not equate Survey Collection with FGDB Collection or internal app definitions
with an additional hierarchy level.

Maintain this mapping when a function's domain inputs, outputs, parent linkage or
physical representation changes. Exact revision/staging/cache filenames stay in
implementation schemas; they do not drive the primary explanation. Current app
representations must not be labelled fully FGDB-conformant without the binding
and qualification required by FGDB.

The intended terrain architecture processes Stream DEMs once and lets Reaches
reference the applicable edition. Reach-specific spatial analysis does not imply
an independently stored DEM. FGDB's existing hydro DEM ownership contract needs
revision for this direction; its physical association binding remains undefined.

Archived projects may retain only Reach-Survey-Event hydro DEMs. Preserve those
assets at their actual extent with their Event association and provenance; do not
require reconstructing Stream terrain. The mapping must support both legacy
Reach-scoped assets and new shared Stream assets. Asset extent and identity are
distinct from the identities of consuming Reach Events.

Synthetic stream candidates are local preparation assets beneath the exact
Hydro cutline revision in `stream-network/<revision>`. Each immutable revision
contains routing, fill-depth, direction and accumulation GeoTIFFs,
`stream-network.gpkg`, outlet evidence and method/software
provenance. `study_stream_network_store()` rejects reopening or publication when
the Hydro output SHA-256 no longer matches. Candidates are not accepted FGDB
`stream_network` content merely because extraction completes.

Flowline candidates are another local preparation layer, stored beneath the
exact synthetic-network revision in `flowline/<revision>`. A completed immutable
revision contains `flowlines.gpkg`, `result.rds` and `provenance.json`.
The GeoPackage holds `raw_stream_flowline`, `smoothed_stream_flowline`,
internal `reach_flowlines`, legacy-compatible `flowline`,
`selected_network_segments` and, when applicable,
`reach_boundaries`. `study_flowline_store()` binds the candidate to hashes of the
Study context, local event setting, Hydro output, network GeoPackage, retained
reference and Reach mapping. Its `PENDING` marker makes incomplete directories
unreadable; reopen also verifies the saved GeoPackage hash and required layers.

The `flowline` layer retains exact legacy `ReachName`, `from_measure`, and
`to_measure` fields with kilometer measures. Additive Reach IDs/order and method
evidence support the open workflow. This portable producer contract is distinct
from the future normalized FGDB base table; neither may be used to erase the
other's requirements.

These candidates are complete inputs for the local Flowline Points step but are
not governed FGDB Flowlines. The store deliberately creates no `flowline_id`,
Reach-owned `survey_event_id`, Dataset Edition or acceptance record. The current
Spencer event setting is local and must later be reconciled with governed
Reach-owned Survey Events before enterprise publication. Prior revisions remain
on disk when inputs or smoothing choice change; only exact matches are current.

Flowline Points candidates are stored at Study scope in
`flowline-points/<revision>`, rather than beneath the already deep Flowline
lineage. This keeps paths usable by Windows, `fs`, and GDAL. The location does
not weaken lineage: `study_flowline_points_store()` fingerprints the exact Study
and Event files, every included Hydro revision/output, every Flowline
revision/GeoPackage, and station spacing. Each completed revision contains
`flowline-points.gpkg` (layers `flowline_points` and `stream_connections`),
`result.rds`, and `provenance.json`; a `PENDING` marker excludes incomplete
writes. Reopening verifies the complete Study-wide input fingerprint and output
hash.

The layer retains the legacy `ReachName`, `POINT_X`, `POINT_Y`, `POINT_M`,
`POINT_M_uncalibrated`, `calibration_diff`, and `Z` fields and the established
`km_to_mouth` field. The FG Studio replacement profile declares all four measure
fields in kilometers. Additive Reach identity/order, local distance, sampling,
origin, Stream parent/confluence, network-scope, and unit fields do not replace
that portable contract. Stream corridors determine parentage; only the one
outlet Stream starts at zero, and tributaries inherit their parent-Flowline
confluence measure. These are local current/base-event candidates, not accepted
FGDB longitudinal reference frames.

Cross-section drafts use immutable Study-scoped `cross-sections/<revision>`
directories with `cross-sections.gpkg`, `result.rds` and `provenance.json`.
`study_cross_section_store()` fingerprints exact Study/Event/Flowline Points
lineage, rejects stale publication, hides PENDING writes and verifies output
hashes on reopening. The standard feature table is `cross_section`; explicit
layout/REM metadata columns and the `layout_metadata` table carry descriptive
variables. Drafts retain three multipart hydraulic regions, disconnected
components, polygon skeletons, raw/smoothed centerlines and component diagnostics
with footprint/support evidence. Tangent distance,
boundary spacing and Chaikin passes are distinct metadata; the retired support
distance column is typed missing rather than repurposed.
Method v10 / draft schema 9 retains perpendicular-first channel segments, ordered boundary
targets and fixed-target polygon routing, leg status, rotation and diagnostics.
cross_section_channel_deconflict() supplies joint angular repairs for channel-only
contact windows. cross_section retains generated outcome status, actual rotation,
typed degree-valued search/review bounds and rotation/limit review flags. Bounded
search failure keeps original flagged geometry. Banks freeze before overbank routing.
Endpoint bank indices permit channel-only and one-sided cross sections without
duplicate edges; section_parts describes geometry separately from leg status
and coverage. Two or more vertices use explicit integer bank indices, bend
counts and routed flags; manual
addition/removal retains candidate identity. boundary_chains LINESTRINGs and
boundary_anchors POINTs add directed shared edges/whole-channel bank arcs and
generated bank/planned outer targets, linked to candidate IDs/Seq with explicit
feature-CRS chainage units. Actual order and channel skew refresh on edit/save;
generated targets remain source planning evidence. Anchors follow candidate ID
assignment, deletion and resequencing without creating governed identities.
Incompatible drafts do not match the current method fingerprint; explicit cleanup
may retire obsolete automatic drafts while preserving accepted/edited evidence.
REM preparation is a separate persistent local asset under
cross-section-preparation/<input-recipe-hash>, with external analytical/display
GeoTIFFs and preparation JSON/RDS retaining exact lineage and output hashes.
Flowline Points queues preparation; Cross Sections reuses it or builds a missing
Reach once. Water levels, bend permission and layout tuning do not invalidate it.
Flowline Points can share its already-validated loaded inputs with Cross Sections
within the same session and exact context/Event/revision key. This is reactive
session state, not a new stored entity. Deferred opening paints progress before
cold validation; the background layout worker reports three named phases and
returns elapsed stage timings.
The local draft profile is `dev/schemas/cross-section-drafts.md`. Opaque local
candidate keys survive corrections and resequencing but do not establish
governed cross-section identity or acceptance. FGDB's cross-section naming
contract owns the naming rule; enterprise normalization and legacy export
remain distinct unfinished bindings.

Channel preparation retains channel_outer_raw, channel_reference_centerline and
channel_branch_review beside the prepared channel_outer layer. Cleanup uses a
native depth-screened, single-attachment envelope method; attachment_depth and
cleanup_status add review evidence without changing chord depth/advance units.
The one-pass removal guards validity, component count and the reference route.
The raw polygon channel centerline supplies geometry and local width. Removed
lobes remain within the LOB/ROB partition of the total floodplain. Branch dimensions
declare feature-CRS measure_units. Logical per-side geodesic_direction/group_routed
fields and side_support direction_status retain generated method evidence; run
parameters carry lobe, clearance and group-budget policies. These additions do
not create governed channel/branch identities or accepted hydraulic flow paths.
