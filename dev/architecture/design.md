# Application architecture

For the app's role in the wider project and its analyst audience, start with
`vignettes/fgstudio.Rmd`. `vignettes/guide-study-workflow.Rmd` owns operating
instructions; the numbered developer series and agent route table own task-to-
implementation explanations. Article 01 documents the context-routing experiment,
including the limits of current efficiency evidence. See the documentation-audiences feature.

## Accepted direction

Owner requirement, 2026-09-15: inside/outside and coincidence analysis must be
CRS-aware and use mature GIS R tooling. Leaflet's Web Mercator display is not a
processing CRS. Do not implement raw-coordinate topology in the app or remove
CRS labels to force planar predicates. The shared backend owns projection,
clipping, numerical precision and validation. Stream selection now follows
clip lines -> buffer retained portions -> clip area; see
[the current evidence contract](../schemas/stream-selection.md).

User-directed, 2026-09-14: create fgstudio independently from ohwm2, using working
increments to design the new-project-to-L1 experience. Keep existing apps and the
ArcGIS toolbox intact. Backend capabilities belong to fluvgeo and should also
serve QGIS. Begin with local storage; ultimately support approved FGDB read/write
access on USACE ArcGIS Enterprise. Enterprise transport/authentication are unknown.

## Terrain workflow (9048 / fluvgeo 9053)

Increment 9050 / fluvgeo 9055 reuses the saved Reach mask for the small real-data
mosaic through `launch_terrain_mask_trial()` and `mask_terrain_mosaic()`. The
trial display is bound to its Study Area and Survey Event. Horizontal grid
compatibility is checked separately from the DEM's vertical CRS; full source CRS
and units survive masking. Source metres versus saved target international feet
are shown explicitly. No target-unit product is published by this increment.

Increment 9049 / fluvgeo 9054 adds an opt-in real-data mosaic development preview
through `R/terrain_mosaic_trial.R`. Its worker calls `mosaic_terrain_tiles()` on
small source windows; its read-only display is mounted by `survey_event_settings.R` only when the
local launcher supplies a completed trial result. There is no full Stream
dispatch, Study Area mutation or Survey Event publication in this increment.
Article 13 and the mosaic design distinguish this source-grid path from future
analysis-grid assembly.

Articles 06–14 and the [agent routes](agent-routes.md) trace the implemented
boundaries. The [remediation record](../features/terrain-gis-remediation.md)
retains qualification evidence; the [mosaic design](../features/dem-mosaic-design.md)
owns scientific choices and pending assembly work.

- Source acquisition uses cancellable workers, complete catalog paging, streamed
  original downloads and immutable receipts. Reopening saved availability reads
  records and metadata without hashing every DEM.
- Source viewing starts on file selection. A worker opens paths, verifies a cold
  source once and creates a bounded source-window preview. Session-owned metadata
  and display caches reuse unchanged inputs; explicit integrity refresh is
  available. Metadata stamps are change indicators, not cryptographic guarantees.
- Analysis setup persists the Study Area's horizontal and vertical target
  definitions through fluvgeo context writers. It does not transform terrain.
  Tab-local reload restores saved study revisions and discards transient edits.
- Define a Survey Event is a main Study Area tab after Analysis setup. It records
  Collection/Stream membership, retained date evidence, output cell size and
  optional existing Reach Event links. Legacy acquisition-group sidecars are an
  internal persistence contract, not a new FGDB entity. The initial numeric grid
  alignment convention is unresolved; existing saved grids remain unchanged.
- Saving/reopening a Survey Event automatically prepares or reuses masks for
  assigned Streams in a background worker. fluvgeo uses native terra
  rasterize/classify/crop/mask, shared Study Area raster reuse, native publication
  summaries and geometry/grid/recipe keys. Reopening avoids repeated value scans.
  Masks require no source DEM receipt or vertical operation.
- The store publishes complete mask staging directories as immutable editions.
  Only the optional developer troubleshooting mode prepares bounded mask display rasters in session caches. Cancellation stops
  and joins workers before cleanup; recorded abandoned staging is reclaimed only
  after owning app and worker processes have exited. Unknown staging is retained.
- Preflight diagnostics and source-review annotations are not mounted in the
  analyst workflow. Their retained controllers/store contracts are documented in
  articles 11/14. Neither is an analyst approval gate for masks.
- The standalone horizontal-warp primitive uses native GDAL processing and terra
  summaries, Float32 default storage and GDAL-selected working precision. Explicit
  horizontal-only controls prevent unintended elevation changes. It has no app
  caller; Stream DEM assembly and vertical transformations remain unimplemented.

Backend functions own scientific raster operations. App modules own session
state, dispatch, progress and presentation; the local store owns durable paths,
input revisions and publication. Pass paths/settings across process boundaries,
not live SpatRaster pointers. No shared runtime or Enterprise deployment follows
from local development.

## Reach editing foundation (9022)

`reach_selection_server`, `reach_merge_server` and `reach_split_server` implement
Add new / Combine existing / Split existing in the shared map's Reaches task.
The local adapter calls fluvgeo's retained-segment/piece readers, previews and writers.
The app cannot supply an independent Reach buffer or arbitrary source geometry.
See [the feature and evidence boundary](../features/reach-selection.md).

- `R/app.R`: app assembly and loopback launcher, exported as fgstudio_app/run_app.
- `R/mod_study.R`: namespaced module, per-session current study and feedback.
- `R/mod_boundary.R`: map/editor lifecycle and task routing; selection helpers
  maintain separate draft/preview/save state for boundaries, Streams and Reaches.
- `R/study_feature_names.R`, `R/saved_feature_display.R`: name-only revisions,
  Stream-first Reach rename choices, saved-feature identification, zoom and inventory.
- `R/study_store.R`: ordinary local storage adapter, injectable into the module.
  Calls fluvgeo::start_study_context/read_study_context; does not duplicate schema
  logic or invent scientific metadata.
- `tests/testthat`: persistence, invalid input, preservation, module transitions,
  session state and escaped UI content. No remote service dependency.

Use native Shiny moduleServer and testServer, packaged in an ordinary R package
scaffolded with usethis. Use bslib Bootstrap 5 layout/cards; no copied ohwm2 server,
custom UI framework or golem runtime is required for this bounded foundation.
This follows Posit's [modules](https://shiny.posit.co/r/articles/improve/modules/),
[testing](https://shiny.posit.co/r/articles/improve/server-function-testing/) and
[layout](https://shiny.posit.co/r/articles/build/layout-guide/) guidance, reviewed
2026-09-14. These sources support the patterns, not a claim of production readiness.

## Storage contract

Survey Collection selection is an independent immutable GeoPackage sidecar series,
not a context schema change. The new tab calls shared fluvgeo discovery/IO methods;
only saved candidate/product intent changes. Version 2 adds acquisition_plan;
version 1 reads with an empty plan, without implicit product defaults.
See [Survey Collections](../features/survey-collections.md)
and developer article 05. Acquisition, Survey Events and terrain processing remain
separate steps. FGDB Collection continues to mean a grouping of Study Areas.

Adapter groups (exact signatures remain in `R/study_store.R`):

| Responsibility | Methods |
| --- | --- |
| Catalog and Study Area metadata | create, read, catalog, rename, set_purpose |
| Boundary | save_boundary, save_selected_boundary |
| Streams | define_streams, save_stream, stream_segments |
| Reaches | preview_reach, save_reach, preview_reach_merge, merge_reaches, preview_reach_split, split_reach |
| Hierarchy names | rename_feature |
| Local acquisition groups and Event spacing | acquisition_groups, save_acquisition_group |

The adapter returns a
small presentation record only after rereading the saved backend context. A random
128-bit hex folder key is app storage identity, NOT the Study Area UUID. The backend
owns that UUID. Catalog/reads accept only opaque keys, never a browser-supplied path.
Every new draft uses a new folder. Context revisions are immutable, sequential
`revision-000001.gpkg` files beside the original `study.gpkg`; the catalog reopens
the highest numbered revision. Stale expected paths are rejected, and backend
non-replacing publication prevents collision overwrites. This is not a complete
multi-user transaction model. No overwrite/delete operation is exposed.
Failures preserve partial/completed files for inspection; unreadable folders are
counted in the UI rather than silently presented as valid studies.

The module holds current selection per session. The local catalog is intentionally
shared by sessions on this single-analyst workstation. Authentication, tenancy,
concurrent editing, arbitrary uploads and backend replacement are not implemented.
Receipt-backed source DEM downloads are supported by the separate acquisition flow.
Do not expose this app on a shared host yet. A storage seam reduces coupling; it
does not establish that Enterprise integration is an interchangeable connection.

## Evidence boundaries

Verified: source contracts and local tests described in the feature record.
Verified user feedback: the owner accepted Study Area and Stream definition,
Reach creation/combination, renaming and saved-Reach splitting. Watershed selection
is implemented; polygon import remains future work. Unknown: final
FGDB schema and Enterprise service access. Proposed future capabilities are not
authorization to implement another geospatial operation.

## Mapping and candidate lifecycle

Use Leaflet (R leaflet) + leaflet.extras drawing controls and sf geometry, with
fluvgeo retaining domain persistence/validation. This follows the documented
[Leaflet Shiny integration](https://rstudio.github.io/leaflet/articles/shiny.html)
and [drawing toolbar](https://trafficonese.github.io/leaflet.extras/reference/draw.html).
The installed drawing bindings were checked for all-features, edit-start and
deletion events. Only completed, valid single polygons become save candidates;
starting another draw/edit/delete clears the candidate. No silent geometry repair.

Each opened revision has an isolated module/map ID. Switching studies or saving
disposes the old editor's event observers; inactive editors cannot save. The map
is rebuilt only at a study/revision boundary, not per vertex, with a
canvas-preferred renderer. The drawing tool accepts one boundary; saved hierarchy
and candidate layers can contain many features. Throughput for large networks
or rasters has not been qualified by this local hierarchy workflow.

Saved-feature identification is active in View only, keeping labels/popups from
consuming editing clicks. Dropdown zoom uses sf-transformed geographic bounds;
it changes neither the selection's identity nor its geometry. Labels and popup
values are escaped. Layer controls let users reveal overlapping Stream/Reach areas.

WGS 84 GeoJSON coordinates are converted to sf without changing their meaning.
Map display projection is not terrain analysis CRS. OpenStreetMap tiles disclose
viewed-area requests; retain attribution.

## Place search

Owner-requested compact UI follows ohwm2/R/draw_xs_map.R: the collapsed Leaflet
Search magnifying glass and inline suggestions replace the separate form.
Keep Photon, rather than copying ohwm2's Nominatim service configuration. A
1.2-second typing pause sends public place text through Shiny/httr2 to Photon;
selecting a match lets the existing Leaflet control move the map. It never
redraws the map, changes a boundary candidate, saves
a revision or imports geocoder geometry into the study. Search observers are
disposed with the boundary editor. Results and search text are not persisted.

Use the [Photon API](https://github.com/komoot/photon/blob/master/docs/api-v1.md)
with at most five matches, a ten-second timeout, a process-wide one-second request
guard and bounded in-memory reuse of 100 queries. No bulk searches or retries.
The public service's
[usage/availability limitations](https://github.com/komoot/photon#photon)
make this a preview dependency, not a high-throughput production service promise.
The server-owned fgstudio.photon_url option allows another Photon deployment.
Search disclosure is in the input tooltip and README; the old Map and coordinate
information panel was removed.
Labels use textContent in Leaflet result nodes; result coordinates are validated
before map navigation. Request tokens reject obsolete responses. The R bridge
uses leafletProxy to return results, not to replace the map. The search-options
formatter accommodates both installed Leaflet Search callback signatures.
Deterministic tests inject search results and failures without network access.

## Name editing

9020 extends name editing to saved Streams/Reaches via a separate modal and
`rename_feature` adapter calling `fluvgeo::rename_study_feature`. Parent-scoped
duplicate checks live in fluvgeo. Same-study draft protection and stale revision
checks apply; only the display-name column changes. Immutable source evidence
retains its historical name and is still linked by identity, not current label.
Saved-Reach splitting is implemented under ADR 0005; pre-assembly and Stream
cutting remain future entry points. Versioned piece evidence is owned by fluvgeo.

Edit name opens a prefilled modal; explicit Save name calls the existing
fluvgeo::revise_study_context(study_area_name=...) through the adapter's common
revision writer. Empty names fail validation, unchanged names do not create a
revision, and stale source paths fail closed. Rename changes only the display
name: identity, geometry, CRS, notes and child records remain backend-owned.
The catalog updates after rereading the saved revision. Unsaved boundary work
must be saved or explicitly discarded by reopening before entering name editing,
so a revision refresh cannot silently discard the current drawing.

## Purpose editing

`set_purpose(key, purpose, expected_path)` uses the same immutable revision writer
with fluvgeo 9020's explicit `study_area_purpose` field (schema 6). It does not
replace analyst_notes. New FG Studio drafts store their question in that field;
older app drafts read the original creation notes from study.gpkg as a fallback,
not the latest accumulated provenance notes. No writes occur while reopening.
Blank UI text maps to NA_character_, meaning intentionally unspecified, not
permission to fall back to an older question. Unchanged values do not save.
The Edit purpose modal uses the same stale-revision and unfinished-drawing guards
as Edit name. Supporting notes remain in the context GeoPackage; the old
Saved record details panel is no longer displayed.
Only the isolated app backend library is upgraded; no production client change.

## Initial Stream inventory

`mod_streams` exposes the existing fluvgeo::define_study_streams() contract through
adapter define_streams(key, names, rationale, expected_path). The common revision
writer can call either the existing context editor or Stream-definition API.
Both reread the published snapshot and reject stale paths/collision overwrites.
The presentation record includes stream_inventory and can_define_streams; the
latter requires absent Streams, Reaches, Survey Events and linked network, not
merely a zero Stream count. Domain enforcement remains in fluvgeo.

One-per-line names are explicitly entered and normalized; duplicate names ignoring
case are refused, never silently merged. Save supplies a truthful UI-selection
note plus optional user rationale; no scientific delineation rationale is invented.
The backend generates Stream IDs/parentage and retains all existing Study Area
metadata, geometry and evidence. Names alone do not imply polygons or flowlines.

The module shows a saved inventory after publication. Existing inventory is not
offered as a replaceable initial form. A local save-once guard plus the normal
revision/lifecycle guard prevents duplicate submissions. Stream entry is carried
across same-study name/Purpose/boundary revisions, but not navigation to another
study. A pending boundary blocks Stream publication until finished/saved, avoiding
loss of the drawing. Old module observers are disposed on context transitions.
No new dependency, backend code/schema or enterprise integration is introduced.

## Drainage exploration

The subsequent owner-approved slice uses fluvgeo 9021 retrieval functions and
hydrogeofetch, with callr for cancellable background requests. Explore mode shares
the boundary map but has isolated, non-editable overlay groups and no storage
adapter. Before study creation an exploration-only map is available. No candidate
is adopted automatically. See [the feature contract](../features/drainage-exploration.md)
for snapping, source, timeout, partial-result and lifecycle boundaries.

The 9007 follow-up separates lightweight USGS NHDPlusV2 tile display from detailed
feature retrieval. The client uses leafem's bundled Protomaps renderer only for
reference display, with explicit mode/zoom limits and no event interception.
Failed worker requests retain transport evidence for meaningful retry guidance;
the shared fluvgeo scientific/persistence contracts are unchanged.

9008 uses fluvgeo 9022's additive per-layer outcome field to distinguish explicit
empty results, transport errors and ambiguous responses. Available/unavailable
compatibility is retained. Named candidate inventories and responsive compact
layout are client presentation only; their source-row links are session-local,
not new FG identities or selections. No persistence boundary is changed.

The owner accepted stepwise selection and clarified geometry
construction: selected HUC12s/basin define a Study Area; selected Stream/Reach
flowlines are retained and buffered using user-defined distances to produce
their analysis extent polygons. Shared buffering methods belong in fluvgeo;
client controls supply explicit parameters and preview/confirmation. This is
implemented for Study Area, Stream and Reach definition, not automatic floodplain mapping.
See the feature record's accepted geometry construction clarification.

9010 implements Study Area polygon selection only. The selection helper owns
server-retained HUC12/basin candidates, choices and preview state. Browser values
are identifiers checked against that pool, never accepted geometry or file paths.
The read-only drainage helper still has no storage adapter. Selection can carry
from pre-study exploration into explicit creation, or across revisions of the
same study; explicit opening of another study discards it. Draft polygons block
competing drawing/child-publication operations until saved or cleared.

The app storage adapter saves a separate source-evidence GeoPackage before
publishing a new context revision through the existing fluvgeo writer. The note
records its relative filename and SHA256. Old revisions remain unchanged. These
two outputs are not a single transaction: a failed revision may leave orphan
evidence, which is retained for inspection, not interpreted as a completed save.
See the [selection evidence contract](../schemas/boundary-selection.md).

## Stream corridors and edit lifecycle (9011)

The map opens saved boundaries in View with a Working on selector for Study Area,
Streams and Reaches. Creation and same-study revisions carry completed discovery, clicked/
snapped location, map bounds, pools and selections. Live jobs are cancelled, not
transferred. Explicit open/switch starts fresh transient state. Previews are never
carried across revisions: the changed parent must be checked again. Pending
Stream choices can remain during parent editing, but cannot publish while parent
changes are unfinished. No unsaved browser-refresh persistence is claimed.

`stream_selection_server` owns checked COMID choices, a 2,000-line pool, form
parameters and preview lifecycle. At most 500 lines enter a shared backend
preview. Browser IDs are checked against server-held sf, not browser geometry.
Adapter `save_stream` calls fluvgeo::add_study_stream_corridor; identities,
buffering and evidence publication stay in fluvgeo. The names-only API remains
unchanged. See [the evidence contract](../schemas/stream-selection.md).

Both app boundary writers call fluvgeo::check_study_area_containment before
publication and polygon evidence writes. Stream/Reach areas outside the proposed
parent block saving with names; names-only records remain unknown. This is a
conservative app rule for owner review, not a global FGDB acceptance rule or a
breaking change to the legacy context writer. As revised by the owner in 9016,
selected Stream lines are clipped first; their buffer is clipped to the parent
and disclosed before save. The backend's regional CRS and fixed numerical
precision contract applies, not the superseded strict-line rule. Reach creation,
combining and splitting clip inherited buffers to their parent Stream. General
spatial editing, cross-Stream overlap policy, scientific network acceptance and
Enterprise integrity remain separate future contracts.

## Single task navigation (9012)

9015 runtime isolation: never launch the analyst app in a test R process.
`run-dev.ps1` starts fresh R; `check-tests.R` verifies test doubles
are restored. A local mock inside Shiny's test evaluation leaked past the suite
and made the subsequently launched app reject every containment check. Explicit
`with_mocked_bindings` scope plus separate launch processes prevent recurrence.

9013 adds session-scoped service activity: native indeterminate progress plus
elapsed seconds, both beside the controls and in a persistent Shiny notification.
The callr worker stays asynchronous. Finish, error, launch failure, timeout,
Cancel, mode departure and editor destruction clear activity; no fictitious
completion percentage is shown. Available-overlay controls derive from the same
reactive discovery/selection/preview state, not a fixed list of potential layers.
Stream mode omits watershed candidates; View omits transient discovery.

Owner feedback exposed overlapping controls: Edit/Define were ordinary actions,
not selected states, and a reopened study had no transient discovery candidates.
Replace these buttons and visible map-mode controls with one Working on radio:
View, Study Area, Streams and (since 9018) Reaches. The Study Area task alone exposes boundary method.
A router updates the hidden compatibility map_mode input used by existing helpers;
guards retain unfinished parent work and show a notice beside the task selector.
No geometry is written by changing task. Do next derives guidance from current
discovery, selection, form and preview state. Successful channel retrieval switches
to Select lines and opens the line lists. Stream mode displays only line inventories.

9017 distinguishes empty-map clicks from candidate-shape clicks in Stream mode.
An empty-map click with no pending selection switches to Find channels and retains
the clicked location. Candidate clicks continue to toggle lines. A pending
selection blocks that automatic switch with guidance; explicit Find channels can
still explore while retaining choices. Saving rebuilds the form with candidate
pool and buffer defaults, empty selection/name, and next-Stream instructions.
The map uses bslib's filling/full-screen card, not a custom resize mechanism.

Workspace - New now starts a fresh transient session; creation/open selects Open
so New can be clicked again. Pending geometry or names-only form work prompts
before discard; saved projects are never removed. Pre-creation exploration still
carries into creation. Remove the redundant Start another study button and raw
Saved record details / Map and coordinate information sections from the UI.
Evidence remains in GeoPackages; source/CRS/storage guidance remains in README,
attribution/search tooltip and the compact public-service disclosure.

Current increment (9051 / isolated fluvgeo 9056) converts the masked real Reach
window from NAVD88 metres to international feet using native terra arithmetic,
metres / 0.3048. The horizontal grid stays EPSG:6344 at 1 metre; no resampling or
datum transformation occurs. The new compound CRS carries vertical EPSG:8228.
The opt-in preview appears after Event settings in Survey Events, bound to the
matching Study Area/Event. The Study Workspace uses bslib's collapsible sidebar;
a bordered main navigation group contains Geometry, Collections, Analysis and
Survey Events. This result is a small development trial, not published Event DEM.

Increment 9052 integrates the three qualified small real-window DEM operations
into one cancellable worker with completed-result reuse. The normal Event view
omits mask troubleshooting and all mask-display cache generation. The optional
development flag and local trial cache contract are maintained in the mosaic
design and articles 12/13. Full Stream/Event publication remains future work.

Increment 9053 adds app-owned immutable local DEM editions through
`study_dem_store()` (see `dev/schemas/survey-event-dem.md`). The existing worker
can save its verified Reach portion while current input bindings still match.
Ordinary sessions reopen and download the edition without development options.
Full Stream coverage is not implied by storage publication.
