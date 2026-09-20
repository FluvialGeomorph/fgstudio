# Explore drainage to frame a study

## Current behavior and historical evidence

As of 9022, exploration, Study Area polygon adoption and Stream corridor creation
are implemented and owner-reviewed. Both channel lists use downstream-to-upstream
whole-network order (9020), superseding the origin-anchored ordering in the 9017
entry below. Selected Stream lines are clipped before buffering (9016), superseding
earlier strict-line rejection. Working on offers View, Study Area, Streams and
Reaches; Workspace - New replaces Start another study.

Use [README](../../README.md) for the current analyst path, the
[Stream contract](../schemas/stream-selection.md) for evidence, and the
[project plan](../goals/project-plan.md) for remaining work. The following dated
increment records preserve debugging lessons and verification history. Their
"next", "pending" and "not implemented" statements apply to those slices,
not to current availability. The owner later accepted Stream specification as
functional; earlier browser-review requests are not standing repeat-test requests.

## Larger map, continued Stream entry and network ordering (9017 / backend 9028)

Owner accepted the clip-first fix and requested better map sizing, consecutive
Stream entry and channel-ordered candidates. The map now uses an uncapped 72vh
bslib filling card (360px minimum) with its standard full-screen control. Wider
screens allocate more columns to the map; small screens still stack controls.
No custom resize framework or responsive-preview fixture is introduced.

Owner clarified that clicking the map for the second Stream did nothing, with no
error. The Select lines mode ignored new-location clicks; this is distinct from
a failed save or unavailable service. An empty-map click now starts a new location
and switches to Find channels when no lines are selected. Clicks on candidate
lines still select them. Pending selections are preserved with an explicit prompt;
Find channels remains an intentional way to explore while retaining a selection.

Initialize Select lines, distance and units directly from the retained draft,
rather than relying solely on queued updates. Clear the completed selection,
name and rationale, retain discovery and map bounds, and prompt for the next
Stream. Regression tests cover consecutive saves, rebuilt defaults and subsequent
map clicks. Interactive acceptance of the updated browser behavior remains owner
review.

Channel lists use fluvgeo::order_drainage_flowlines, backed by sfnetworks and
igraph. Start at the latest navigation COMID, follow upstream/downstream edges
depth-first, and keep branches together. The service's NHDPlus downstream
digitization convention is a prerequisite, not inferred terrain flow direction.
Source IDs deterministically break branch ties; no mainstem preference is guessed.
Unreachable, unsupported or ambiguous ordering stays visible and labelled last.
Earlier discovery pools may include features unreachable from the latest origin.
No additional web requests, geometry changes or scientific network acceptance.

See [bslib filling cards](https://rstudio.github.io/bslib/articles/cards/) and
the [backend ordering contract](../../../fluvgeo/man/order_drainage_flowlines.Rd).

Verification (2026-09-15): backend ordering tests passed (12 assertions), including
branch isolation, disconnected/cyclic inputs, shuffled rows and geographic versus
projected CRS. The retained Spencer Creek reference network orders from COMID
14804475 through connected branches. FG Studio package check is **OK**, with
420 assertions passing; two test warnings concern installed sf/Shiny packages
built under R 4.6.1 rather than this runtime's R 4.6.0. Runtime-isolation and both
repositories' context validation passed. Tests use temporary studies; existing
analyst studies were not modified. Browser layout/click acceptance remains the
owner's next review, not claimed by these automated checks.

## Clip-first and CRS-aware topology (9016 / backend 9027)

Owner correction: clip selected flowlines to the Study Area before buffering,
then clip the buffer. Owner requirement: all inside/outside and coincidence
analysis must use mature CRS-aware R GIS tooling. The shared backend now uses
sf/GEOS in a local metric CRS, with sf/lwgeom geographic densification. No
unlabelled geographic topology or Web Mercator distance analysis. Numerical
precision and the regional processing domain are explicit in
[the Stream selection contract](../schemas/stream-selection.md).

Preview reports retained channel lengths and counts. Original selected lines
turn grey after preview; retained lines and area are gold. Publication preserves
original lines and processed lines in separate evidence layers. No source or
active study is changed by diagnostics. The provided COMID 14804475 at 1,000 ft
now passes preview/save/reopen against a copy of the saved Spencer Creek boundary;
approximately 17.74 m remains. The earlier outside-line rejection described
below is superseded, not a reason to ask the owner to choose a different segment.

Verification: the full app suite and runtime-isolation check pass; package
build/check for 0.0.0.9016 finishes with `Status: OK`. The real-boundary diagnostic
also passes through Shiny preview/save and adapter reopen in its own test store.
The analyst app is launched afterward in a separate fresh R process.

## Historical test/runtime isolation correction (9015)

The continued owner blockage after 9014 was reproduced without any geometry:
running the navigation test left `fluvgeo::check_study_area_containment` replaced
by `function(...) data.frame(status="outside")`. The analyst app had then been
started in that same R process. Thus its preview gate rejected every Stream.
The preceding synthetic geometry fixes did not establish a clean analyst runtime.

Replace the test's environment-scoped mock inside `testServer` with an explicitly
scoped `with_mocked_bindings` block; assert the original function is restored and
that a subsequent preview passes. Add a full-suite runtime-isolation check and
start the app in its own fresh process through `run-dev.ps1`. No scientific
geometry rule or backend version changes in this correction; retain 9026.
The saved Spencer Creek Study Area was inspected read-only and is unchanged.

Verified 2026-09-15: all 370 app assertions passed, followed by an explicit
identity check confirming the containment function was restored after the suite.
The owner supplied candidate COMID 14804475 and 1,000 ft. Its public NLDI geometry
has 486.10 m outside the saved boundary out of 503.82 m total, so that candidate
correctly fails the separate line-coverage gate. Immediate inside neighbor
14803897 (635.96 m, none outside) passed 1,000-ft (304.8 m) clipping and actual
publication/reopen on a copy, with source hash/current revision unchanged.
Evidence: `dev/check-output/saved-boundary-corridor-460c6ade9e4`; the comparison
map and cached neighbors are in `dev/check-output/saved-boundary-corridor-5d5843762b9e`.
These checks establish the runtime correction and a real boundary-edge save, not
the owner's intended complete Stream membership. No Stream was added to the
active study. The app is launched only by a separate fresh-process invocation.

## Checkbox focus and clipping regression (9014 / backend 9026)

Newly checked watershed polygons or flowline features trigger a map fit with
35-pixel padding and maximum zoom 16. Only additions trigger this: removing a
check, mirrored list synchronization and map-click selection do not move the
view. Existing highlights remain for comparison with adjacent selections.

The owner reported another clipped-area save rejection. A synthetic slanted
boundary reproduced it: the exact GEOS polygon predicate reported outside, but
the robust GEOS outside-difference operation returned no geometry. Shared
containment now uses that empty-difference verification after polygon predicate
failure. Strict line coverage is unchanged; no tolerance or boundary expansion.
Tests cover preview, app save gating and backend publication/reopen. The exact
owner's transient selection was not retained, so this is a reproduced failure
class, not a replay of that selection.
Any remaining containment failure is shown in both the preview status and Do
next guidance before save; the app must not invite saving an unverified preview.

Verification: R CMD check Status: OK with 366 assertions. The subsequent
preview-warning guard passed the full 368-assertion source suite; the existing
Shiny build-version warning remains. Backend focused tests passed 55 Stream and
11 polygon assertions. Strict context validation passed in both repositories.
Saved user studies were not modified. On-screen interaction acceptance remains
owner review; this turn used deterministic tests, not a live browser replay.

## Current owner refinement (9013 / backend 9025)

Snap/Explore display indeterminate progress and elapsed time in the control area
and an app-level notification, cleared on every completion/cancellation/failure
path. Layer menus list available, task-relevant overlays only; hidden available
layers remain listed so they can be restored. Stream mode shows channel candidates
and previews instead of irrelevant watershed overlays. No extra requests are made
when switching tasks.

Boundary-coincident lines are valid Stream choices. Shared fluvgeo now checks
line coverage and clips buffer overflow to the Study Area. Gold is the area to
save; the dashed original outline and removed-area summary disclose clipping.
The analyst may enlarge the parent and preview again if more floodplain is
needed. Source lines are not clipped or altered. Both preview and publication
use the same shared rule and retain clipping evidence. Existing saved projects
are untouched. This supersedes the older whole-buffer rejection described in
the chronological notes below.

Verification: 356 source assertions passed after the service-state and portability
fixes, with the existing Shiny build-version warning. Package check completed
with 355 passing assertions and one non-ASCII portability warning; the superscript
unit label was then changed to an R Unicode escape and its source check was clean.
Strict context validation passed for fgstudio and fluvgeo. Browser attachment
again timed out, so animation/layer-menu visual acceptance remains owner review.

Owner-approved 2026-09-14: click near a stream, snap to the closest mapped stream,
then present discovered features to guide Study Area/Stream decisions. This
complements drawing and initial named Stream inventory, not a new analysis step.

## User path

Before creating a study, use the exploration map; in an open study select
**Explore drainage** on the same map used for drawing. Search/zoom/pan, click near
a channel, and select **Snap to stream**. Black shows the click; orange shows the
identified channel and snapped point. Review the channel before **Explore this
stream**. Use layer toggles to compare HUC12, upstream basin, upstream channels
and downstream path. Results pose concrete scope/Stream-selection questions.

Snap is limited to 200 m. More distant NLDI raindrop-trace results are refused;
zoom in and click closer instead. HUC12 uses WBD 2025 at the snapped point. The
basin aggregates NHDPlusV2 catchments, not an exact clicked-point delineation.
Network queries are explicitly distance-limited (default 50 km, maximum 200 km
per direction); completeness is unknown. Missing layers do not assert no coverage.

No candidate is saved, assigned to FG hierarchy or used to replace a drawing.
Adoption, combination and persistence of selected reference geometries remain
the next owner-reviewed design step. Exploration results are ephemeral and clear
on mode/study/revision changes and browser refresh. Coordinates go to USGS public
services; project names, purposes and saved polygons are not transmitted.

## Architecture and verification

Shared retrieval lives in fluvgeo 9021, using hydrogeofetch 2.0.3. fgstudio's
drainage_explorer owns UI, review sequence and reference overlays only; it has no
storage adapter. callr workers keep the Shiny process responsive. At most one
worker runs per explorer; new location/request, Cancel, inactive revision,
mode change, session closure or 120-second deadline terminates that worker.
Worker startup/error and per-layer failures remain visible. This single-user
preview is not a qualified multi-user service or high-throughput deployment.

Drawing and reference overlays have separate groups. A pending drawing blocks
exploration until saved or explicitly discarded. Request results cannot mutate
the boundary candidate. Backend tests inject service outcomes; module tests
inject worker lifecycle/results, keeping automated tests independent of USGS.

Verification, 2026-09-14: fluvgeo's 30 focused backend assertions passed; the
complete fgstudio package check (`R CMD check --no-manual`) passed with 216
assertions. Tests cover
partial-result rendering, error recovery, cancellation, stale-location/revision
guards, mode separation and deadlines, in addition to existing persistence tests.
One existing Shiny/R build-version warning remains within the tests.

Live service evidence at a public Madison-area example: COMID 13294318, snap
distance 0.36 m, HUC12 070900020702, one basin, 129 upstream flowlines and 24
downstream flowlines at 30 km. A first nearby request returned HTTP 502; retry
succeeded. This qualifies one service example, not availability everywhere.
The opt-in `dev/scripts/check-drainage-services-live.R` repeated all four retrievals
through the actual app worker and verified process cancellation successfully.

The full fluvgeo legacy suite was not run: it includes unrelated authenticated
service calls and report tests that remove/write files outside temporary test
folders. No production client/library or saved user study was changed. Browser
automation could not attach to the existing tab (debugger synchronization timeout);
visual interaction and usefulness of the alternatives remain owner review.
Both repositories passed strict reproducibleai context validation (only existing
repository-owned seed-change notices). The network-enabled local preview was
restarted at port 8780 for owner review. Changes remain uncommitted.

## Reference channels and failed-request feedback (9007)

Owner accepted discovery functionality/metadata and requested visible linework
after a snap failed despite a nearby clicked point. The black marker confirms
the click was received; a service outage remains a plausible inference, not a
verified diagnosis of those earlier attempts. No historic request log exists.

Use the USGS Fabric **NHDPlusV2 network vector tiles** as a transparent blue
reference overlay. Fabric's Tiles interface is distinct from full Features
downloads. No background Features query or study writer is introduced. Browser
requests go directly to USGS, only in Explore mode with the layer enabled at zoom
12 or closer. Tile level 14 is reused at closer scales; this is display guidance,
not geometry for analysis or snapping. Reference canvases are non-interactive
and below study/drawn features, so they cannot intercept point selection.

The existing leafem dependency supplies its bundled Protomaps canvas renderer;
fgstudio has a small adapter for an XYZ template and explicit zoom/mode lifecycle,
avoiding leafem's automatic feature popups. No new web-map framework is introduced.
Protomaps Leaflet is in maintenance mode; its documented remaining use case is
Leaflet-dependent applications, which fits this bounded display layer. It is not
a decision to use it for future high-throughput interactive vector analysis.
An evaluated leaflet.extras2 binary lacked its development-only Protobuf helper;
it is not used or declared as an application dependency.

The worker now retains upstream warnings when an error occurs and reports explicit
HTTP/connection failures separately from the 200 m distance refusal. A NULL or
malformed result remains unresolved, never presumed to be an outage or distance
failure. The point is retained for same-point retries. Expandable last-request
details are session-only, escaped, and clear on a new request/location or mode exit.

Service evidence: WebMercatorQuad tile 14/6015/4125 returned HTTP 200, 4,130 bytes,
approximately 1.2 seconds in one request, internal layer nhdflowline_network.
A request with the browser Origin received Access-Control-Allow-Origin: *.
These checks verify compatibility, not a comparative performance benchmark or SLA.

Sources: [USGS Fabric Features and Tiles](https://api.water.usgs.gov/docs/fabric-pygeoapi/),
[live tileset metadata](https://api.water.usgs.gov/fabric/pygeoapi/collections/nhdflowline_network/tiles?f=json),
[Protomaps Leaflet scope](https://docs.protomaps.com/pmtiles/leaflet).

Verification, 2026-09-14: the JavaScript contract checks passed for zoom/mode
gating, overlay toggles, map-instance isolation, pointer handling and disposal.
The actual callr worker preserved structured error details across the process
boundary. The live public Madison example again returned the same snapped COMID
and all four candidate layers; worker cancellation passed. No saved study was
read or written by the smoke test. Browser automation could not attach, so visual
tile rendering, interaction and actual renderer tile-error propagation remain
unverified browser acceptance items (a mocked tileerror event is not live evidence).
The final 9007 package check completed with Status: OK and 229 passing assertions;
one existing Shiny build-version warning remains inside the tests. The evaluated,
unused leaflet.extras2 package was removed from the disposable app-local library.

## Compact candidate review (9008 / fluvgeo 9022)

Owner requested less vertical scrolling, a distinction between request failure
and no matches, and named collapsible inventories for all four feature types.
The map and exploration controls now share responsive columns on wide screens;
compact study summaries and collapsed background explanations keep the next
action closer to the map. Narrow screens stack the same controls. No separate
responsive-preview artifact is produced.

Each returned feature remains one entry, including repeated stream names. Lists
show supplied names plus source identifiers; unnamed channels use their source
IDs, and missing IDs are explicitly identified using session-local row numbers.
The basin fallback describes its relationship to the snapped COMID, not an
invented geographic name. Lists are alphabetical with bounded scrolling; names
and all service text are escaped. This is review only, not adoption or persistent
identity assignment. No saved project schema or writer changes.

fluvgeo adds `status$outcome` without changing available/unavailable compatibility:
available, no_features, service_unavailable, or unresolved. Per-layer warnings
are retained before failure classification. An explicit empty sf response or an
empty containing-HUC filter establishes no matches for that query; a transport
error establishes request failure. NULL alone establishes neither. Installed
hydrogeofetch 2.0.3 source confirms some helpers catch errors and return NULL
without retaining transport evidence; these remain explicitly unresolved rather
than guessing. No upstream client patch or alternate service stack is introduced.

Only FG Studio's isolated backend library is upgraded. ArcGIS/QGIS production
clients, ohwm2, FGDB storage and saved user studies are unchanged.

The live navigation response contained COMIDs but no names. FG Studio therefore
opts into `get_drainage_context(include_names = TRUE)`: one attribute-only
hydrogeofetch `get_nhdplus` Fabric query for the combined distinct channel IDs,
not one query per segment or another geometry download. Names are joined by
COMID without changing geometry/order. Above 500 distinct IDs the optional name
request is skipped to bound the preview; the reason is shown in request details.
Missing/blank names are labeled "name not supplied", not evidence that a channel
has no geographic name. Name lookup failure retains all successful geometry.
Sources: [USGS Fabric](https://api.water.usgs.gov/docs/fabric-pygeoapi/) and installed
hydrogeofetch get_nhdplus/query_usgs_oafeat source, verified with an attribute-only
two-COMID public query returning "Yahara River" and one blank name.

Verification: 45 focused fluvgeo assertions passed; the FG Studio package check
completed with Status: OK and 249 passing assertions (one pre-existing Shiny
build-version warning in tests). The first check stalled on an unrelated
Bioconductor repository index; rerun used a temporary process-only CRAN profile,
not a change to user configuration. The map JavaScript contract tests passed.
No full fluvgeo legacy suite was run because unrelated tests invoke authenticated
services and write/delete reports outside temporary test folders; this boundary
remains as documented for the earlier slice. Browser automation again timed out
attaching to the existing tab, so visual acceptance remains owner review.

Final unchanged live smoke script completed successfully: COMID 13294318 at
0.36 m, one named HUC12, one upstream basin, 129 upstream and 24 downstream
features. Attribute-only enrichment returned all 152 distinct COMIDs, including
Yahara River names; blank GNIS names stayed unspecified. Structured error
transport and worker cancellation also passed. No user study records were touched.

## Owner review and selection proposal (9009)

Owner accepted the compact right-hand exploration panel and collapsible feature
inventories. The repeated request to compact the "right panel" was interpreted
as the remaining left-hand workspace panel: New/Open tabs now show one form at
a time; optional Purpose is collapsed. Inputs, save behavior and study identity
remain unchanged. Start another study returns to New. No selection code added.

Owner identified these candidate roles: individual/groups of HUC12 polygons or
upstream basin for Study Area; groups of flowlines for Streams; individual
flowlines for Reaches. These are candidate choices, not mandatory segmentation
rules or a declaration that reference hydrography is final analysis geometry.

Interaction accepted in the subsequent owner clarification below; not yet implemented:

- Choose the target: Study Area boundary, Stream channel, or Reach course.
- Explicit Select mode separates feature clicks from the existing exploration
  point/snap operation. Linked checkboxes and map highlighting show the same
  selection; search by name/ID and clear/undo remain available.
- A compact selection summary retains selected candidates across exploration
  clicks within the same study. A new retrieval must not silently erase them;
  changing studies must not carry them into another study.
- Preview the union for polygons or the selected channel geometry for lines.
  Disconnected pieces/branches are visible for review, not silently removed or
  accepted as a single logical channel. Source feature IDs/snapshots are retained.
- Save explicitly to a new or existing named hierarchy member, selecting its
  parent. Existing named Streams must be offered for geometry assignment rather
  than creating duplicate Streams. No hierarchy is inferred from GNIS names.
- Stream channel and Reach course are distinct from their area polygons. The
  subsequent owner clarification authorizes user-specified buffering to produce
  these extents, not an automatic default width.
- Suggested next slice: Study Area polygon selection/preview/save first, retaining
  HUC12 choices across clicks for multi-HUC selection, then Stream groups and
  Reaches. Current retrieval finds the HUC12 at the snapped point, not a complete
  menu of adjacent HUC12s. Later group helpers must label partial returned
  networks truthfully; selecting a shared name is not proof of connectivity.

9009 verification: the complete app source test suite passed, including workspace
tabs and existing create/open, Purpose, boundary, Stream and exploration tests.
One pre-existing Shiny build-version warning remains. This presentation-only
increment did not rerun live services or the full package check; the preceding
9008 package/live checks remain separately recorded above. Visual acceptance of
the compact left panel remains owner review. Saved records were not changed.

### Accepted geometry construction clarification

Owner accepted the left-panel update and the proposed stepwise specification of
nested Study Area, Stream and Reach geometry. Individual or combined HUC12s are
suitable Study Area boundaries; the previously accepted upstream-basin option
remains available. Selected Stream flowline groups and their nested Reach
flowlines will be buffered by a user-defined distance sufficient to enclose the
floodplain of interest, producing Stream and Reach extent polygons. Retain the
selected lines as well as the resulting polygons and the buffering parameters.
These are analyst-defined analysis extents, not a computed floodplain delineation.

Buffering belongs in shared fluvgeo methods, with clients exposing selection,
distance/units and preview/confirmation. No buffer size is inferred from stream
names or network attributes. The proposed UI convention is distance from the
line on each side, explicitly distinguished from total corridor width; confirm
this convention when designing that tool. Parent-boundary crossings and buffer
overlap need an explicit reviewed rule, not silent clipping or changed distances.
This clarification records intent only; no buffering or selection was implemented.
Study Area polygon selection/combined preview/explicit save remains the next slice.

## Study Area polygon selection (9010 / fluvgeo 9023)

Implemented the approved first selection slice, not Stream/Reach buffering.
Find watersheds retains the existing point/snap workflow. Select polygons enables
map clicks and linked HUC12/basin checkboxes. Server-retained candidates accumulate
across discovery requests, including failed requests; earlier source snapshots
are not silently refreshed. The pool is bounded at 200 candidates. Names remain
labels, not keys. Upstream/downstream lists remain review-only.

Selection changes invalidate the combined preview. Preview calls the shared
fluvgeo spherical-union method, displays a gold boundary and polygon-part count,
and retains holes/disconnected parts without repair. Save requires the current
preview and an existing study, preserves identity/Purpose/children, and publishes
a new revision with source-evidence linkage. Saving clears pending choices to
prevent duplicate writes. Invalid/stale/inactive events cannot publish. See the
[source-evidence contract](../schemas/boundary-selection.md).

Pre-study choices carry only into explicit creation. Opening another saved study
discards them; revisions of the same study may retain the candidate pool. Selected
polygons block competing drawing and child-publication operations until saved or
cleared. No source URLs or browser-supplied geometry are used for saving. Source
retrieval still has no storage adapter; explicit selection/save is separate.

Owner-authorized reset: four local study folders and all 28 GeoPackages were moved
out of `.local-data` into `dev/check-output/retired-studies-before-polygon-selection`.
All file SHA256 hashes matched after the move. This is a recoverable backup, not
permanent deletion, and includes every prior revision and associated record in
those folders. No other repository's datasets or shared libraries were changed.

Verification: 9010 package check Status: OK, 282 passing assertions, one existing
Shiny build-version warning in tests. Focused fluvgeo tests passed 11 polygon
combination and 45 drainage assertions. Full legacy backend tests remain excluded
for the previously documented unrelated authenticated/destructive test boundary.
Live public Madison HUC12/basin selection combined to one polygon part and saved
with matching identity/geometry and retained source evidence in a separate test
folder; the active study directory remained empty. Both repositories passed
strict context validation. Interactive map/list appearance remains owner review.

## Stream selection and creation/edit usability (9011 / fluvgeo 9024)

Owner reported that creating a study after exploration lost useful work. The
9010 handover retained polygon choices but not completed drainage results or map
position. 9011 carries these explicitly, including channel candidates, without
re-querying; pending requests are cancelled. Explicit reopen/switch still clears
unsaved exploration. No active saved study was removed in this increment.

Saved boundaries reopen in View mode with explicit Edit/Define Streams actions.
Compact tables show known status, next actions, source information and preview
counts. The accepted nested cards and collapsible feature lists remain.

Stream mode exposes linked map/checkbox selection for upstream/downstream lines,
explicit Stream name and per-side buffer distance/unit, Preview and Save.
COMIDs deduplicate shared upstream/downstream results; names remain labels.
The pool retains first source geometry across requests, limited to 2,000 candidates
and 500 selected lines per preview. sf/S2 buffering and contained publication are
shared backend methods. The Stream inventory updates after saving; another
spatial Stream can be appended with a new identity. Selected lines/parameters
are retained separately as described in the Stream evidence contract.

Boundary edits that exclude saved Stream/Reach areas fail with affected names.
New Stream buffers outside the parent cannot save. Pending Stream choices can
survive a parent edit but need a fresh preview after its new revision. This
conservative coverage policy is for owner review; no automatic clipping, tolerance,
directed-network acceptance or general FGDB compliance claim is introduced.
Cross-Stream overlap and spatial Stream/Reach editing remain future decisions.

9011 verification: R CMD check Status: OK; 309 assertions passed with one existing
Shiny build-version warning inside tests. Backend focused checks passed 33 Stream
corridor and 11 polygon-combination assertions. Public Madison check selected
COMID 13293416 from 152 returned channel candidates, buffered at 100 m, saved and
reopened with parent coverage and source evidence verified. Evidence and retrieved
context are under `dev/check-output/stream-selection-4f68341d7927`, not active data.
Both repositories passed strict context validation (repository-owned customization
notices remain). Browser automation failed to synchronize the existing tab and
timed out opening a fresh temporary tab; visual acceptance remains owner review.

## Task clarity and Stream entry (9012)

Owner accepted tables but found the multiple action/mode controls ambiguous and
Stream entry difficult to follow. Verified code evidence: button colors were
static action styling, not selected state; reopening clears transient candidate
pools, and Stream entry did not show a state-specific next action. These explain
the workflow gap; they do not establish a specific service failure in the owner's
session (none was captured in the running server output inspected).

Use one Working on selector (View/Study Area/Streams), a boundary-method choice
only for Study Area, and an immediately visible Do next table. Stream mode shows
channel inventories, switches to selection after discovery and expands checkbox
lists. Selecting a task never saves. Existing pending-parent guards and the
selection/preview/save contract remain. Workspace - New replaces the redundant
Start another study action; unsaved edits prompt before discard. Low-value raw
record/map disclosures leave the working screen, not the stored evidence/docs.

Scope: FG Studio presentation/session orchestration only. No backend, containment,
buffering, data schema, production client or active saved-study changes.

9012 verification: package check Status: OK (329 assertions). A subsequent
blocked-switch warning-visibility fix passed the full 331-assertion source suite;
final status-wording cleanup passed 73 focused drainage/navigation assertions.
The existing Shiny build-version warning remains. Strict context validation
passed. The browser connection again timed out attaching to the app, so live
visual acceptance remains owner review rather than a claimed browser test.
