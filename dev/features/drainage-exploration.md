# Explore drainage to frame a study

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
The opt-in `dev/scripts/check-drainage-services.R` repeated all four retrievals
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
