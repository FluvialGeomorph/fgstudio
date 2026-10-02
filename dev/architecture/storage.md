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
