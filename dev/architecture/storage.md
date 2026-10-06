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
