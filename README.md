# FluvialGeomorph Studio

An independent browser workspace for defining studies and, eventually, producing
FluvialGeomorph L1 analyses. `ohwm2` is a reference for useful interactions, not a
parent application or deployment target.

## Current scope

The **Survey Collections** tab discovers reported lidar acquisitions for a saved
Study Area, displays metadata/footprints and saves checkbox selection intent.
Reopening restores selections offline. Planned collections are selectable; saving
does not download data or create Survey Events. Query results distinguish failures
from empty/partial responses. This uses USGS 3DEP and USIEI catalog layers, not an
exhaustive clearinghouse; cross-listed records need later identity review.

In **Plan acquisition**, choose an included Survey Collection, review reported
product links, check Existing DEM and/or Lidar point cloud, then **Update
acquisition plan** and **Save selections**. Reopening restores the saved plan.
Unknown access is unresolved, not unavailable. Links are unverified provider
reports; no download or terrain processing occurs. DEM acquisition is the first
planned execution path; point-cloud processing remains a later capability.

Discovery and planning share one coverage map. **Inspected only** isolates the
focused footprint; **Custom comparison** lets you toggle footprints without
changing saved inclusion. Zoom buttons return to the Study Area or visible set.
Product review shows reported DEM pixel size: 1 m or finer is required but does
not prove suitability. Download/visual review and multi-source Event assembly
remain next capabilities; acquisition plans can already be revised and resaved.

In **DEM files**, choose a saved Stream and a collection with DEM in your plan,
then **Find source DEM files**. The shared map shows the Stream AOI in green and
checked file bounds in purple. The first adapter supports USGS source-directory
links only; unsupported links are reported explicitly. File size and resolution
evidence are metadata, not verified raster properties. Review starts in the
session and is not yet a download step. **Select all** checks all returned tiles;
**Save file choices** retains them for offline reopening. Save the collection's DEM
acquisition plan first. Partial queries remain incomplete even when all are selected.

FG Studio now supports local Study Area, Stream and Reach definition, including
saved-Reach splitting and combining. It is not yet an L1 execution app: Survey
Event/terrain setup, report generation and Enterprise access remain future UI
work. Backend capabilities elsewhere in fluvgeo are not automatically exposed here.

## Start or reopen a study

1. Enter a working Study Area name and optional purpose/customer question.
2. Select **Create Study Area**. The app saves a real fluvgeo context GeoPackage
   and reads it back before displaying the saved draft.
3. Review the compact status table and its **Next** action.
4. Refresh the browser, select the saved study and choose **Open study**. The
   identity and purpose persist. Choose **Workspace - New** to start another;
   saved studies remain intact. Unsaved edits require confirmation before leaving.

## Rename saved Streams or Reaches

Choose **View** above the map to see saved Stream/Reach names and click an area
for its identity and parent details. Toggle layers to reveal overlapping areas.
Editing modes reserve map clicks for their active tool. Saved-feature dropdowns
zoom to the selected geometry; rename lists sort alphabetically. Reach rename
choices display **Stream / Reach**, ordered by Stream then Reach name.
**3. Saved Streams and Reaches** lists the nested hierarchy and area status.

Use **Rename Stream** or **Rename Reach** beside the study title, choose the
saved record, edit its name and **Save name**. Save or Clear unfinished geometry
selections first. Names must be unique within their parent. Only the display
name changes; IDs, geometry, Survey Events and earlier revisions are retained.

Channel candidate lists run **downstream to upstream**, for both upstream and
downstream search results and retained Reach segments. Branch ordering is
deterministic, not a mainstem choice or station numbering. Unsupported topology
is marked **Order unresolved**; geometry is never reversed or repaired to sort it.
Saved-Reach cuts are available through **Split existing**. Pre-assembly and
Stream cutting remain later steps of the approved design.

## Draw a boundary

Not sure where the study should end? Choose **Study Area - Select watersheds** (also
available before creating a study). Click near a channel, select **Snap to stream**,
review the orange channel and snapped point, then **Explore this stream**. Compare
the HUC12, upstream basin and upstream/downstream channels using the layer control.
Black marks your original click. Requests may be cancelled. Click within 200 m of
a mapped channel; distant downstream tracing is not substituted for snapping.

In Explore mode, zoom in to see **NHDPlusV2 reference channels** in blue before
clicking. This is a lightweight USGS vector-tile overlay, not a full geometry
download into R. The map layer control can hide it. Display tiles are generalized
guidance; snapping still uses the service's network. Viewed tile coordinates go
to USGS. If a service request fails, retry the same selected point; expand
**Last failed request details** to distinguish transport errors from unresolved
responses. A blank reference layer is not proof that streams are absent.

On wider screens, map and exploration controls appear side by side. Expand any
of the four **Discovered features** lists to see supplied names and source IDs.
Repeated names remain separate features; unnamed channels are labeled honestly.
Selection alone does not save a boundary. Each type distinguishes **Request
failed**, **No matches**, and **Unresolved** when the service client did not retain
enough evidence to tell the difference. Sources and longer explanations remain
available in collapsed sections.

These are reference candidates for deciding Study Area and Stream scope, not saved
FG records. The basin is catchment-based, not an exact pour-point delineation;
channel results are distance-limited. Exploration sends the selected coordinates
to USGS public services, not your saved study boundary/name/purpose.

### Select a watershed boundary

1. Discover polygons, then choose **Select polygons**. Expand **HUC12** or
   **Upstream basin** and check candidates, or click their outlines on the map.
   Lists and map highlights show the same choices; use lists for overlapping polygons.
2. To add another HUC12, switch to **Find watersheds**, click near another channel,
   snap and explore again. Earlier candidates and choices remain. Switch back to
   **Select polygons** to add the next one. **Undo** and **Clear selection** are available.
3. Select **Preview boundary**. Review the gold combined boundary and polygon-part
   count. Disconnected parts and holes are retained, not silently repaired.
4. Select **Save reviewed Study Area boundary**. It replaces only that study's
   boundary in a new revision; child records and earlier revisions remain intact.
   A companion GeoPackage retains selected source geometry, identifiers and times.

If exploring before study creation, create the named study in the **New** tab;
your map position, completed drainage results and choices carry into it. Active
requests are cancelled at creation; completed results need no repeat query.
Preview again and save. Changing choices invalidates
the preview. Opening another study discards the selection, preventing cross-study
assignment. Save or clear selected polygons before switching to drawing or saving
child records. Merely checking boxes, previewing or refreshing does not save.

After opening or creating a study, click the map's **magnifying glass**, type a
nearby public place and state, and choose a suggested match to zoom there. You can
also zoom manually. Search only moves the map; it leaves saved and unfinished
boundaries unchanged. Choose the polygon
tool, click around its boundary, then click the first point to finish. Review the
drawing and select **Save boundary** below the map. For vertex changes, use the
map's edit tool, finish with its **Save** control, then **Save boundary**.

The saved boundary opens with **View** selected under **Working on**. Choose
**Study Area**, then **Select watersheds** or **Draw / edit polygon**.
Both save methods reject a boundary that excludes saved Stream or Reach areas,
identifying the affected records. Names-only children remain spatially unknown.
Nothing is automatically clipped or moved. Each save retains the prior
GeoPackage revision and the same Study Area identity. Drawing/removing a candidate
does not change the saved boundary. File import remains a future alternative.
No DEM clipping, analysis CRS, Stream,
Reach, Survey Event or scientific acceptance is inferred. L1 analysis, report
downloads and ArcGIS Enterprise access are not implemented yet.

## Edit a Study Area name

Select **Edit name** beside the saved study title, change the name, then select
**Save name**. Cancel leaves it unchanged. The saved-study list updates, and the
new name persists when reopened. Study identity, boundary and notes are retained;
the prior revision is preserved. Save any unfinished boundary changes first, or
reopen the study to discard them before renaming.

**Edit purpose** below the customer question works the same way. Update the
wording or leave it blank, then select **Save purpose**. Supporting notes are
retained in the saved GeoPackage, not mixed into the current Purpose. Technical
record notes and general map/CRS explanations are intentionally omitted from the
working screen; their retention and coordinate semantics are described here.

## Define Streams

1. Save the Study Area boundary, then choose **Streams** under **Working on**.
   The checked radio is the active task; button color is not a mode indicator.
   Follow the **Do next** table beside the map. Reopening a saved study restores
   geometry, not temporary discovery; empty candidates mean you need to explore.
2. Use **Find channels** to snap/explore if needed. Choose **Select lines**, expand
   the upstream/downstream lists and check the segments for one Stream. Map clicks
   and checkboxes share a selection; gold highlights the selected lines. A
   successful discovery switches to **Select lines** and opens the candidate lists.
   Checking a new feature zooms to it with surrounding map padding. This also
   applies to watershed polygon checkboxes; unchecking and synchronized checkbox
   updates do not move the map.
3. Enter a **Stream name**, **Buffer on EACH side**, and unit. Feet means
   international feet (0.3048 m), not US survey feet. No distance is preselected.
4. **Preview Stream** shows the area, polygon-part count and containment result.
   The local metric buffer defines an analysis extent, not a floodplain delineation.
   Disconnected parts are retained, not repaired.
5. **Save Stream** retains identity, area, selected lines and buffer settings.
   Repeat for another Stream; previous Streams remain intact.

Selected flowlines are first clipped to the Study Area, then buffered; the buffer
is clipped to the Study Area again. Gold shows the retained channel and area;
grey lines show original selections and a dashed grey outline shows the buffer
before area clipping. The summary reports retained channel length and removed
buffer area. If too much channel or floodplain is excluded, enlarge
the Study Area, then preview again. Original line evidence is preserved. Pending
Stream choices survive parent edits; preview again against the new boundary.
Explicit reopening/browser refresh discards unsaved discovery/choices, never
saved geometry. Geographic coverage is not hydrologic network acceptance.

The map grows with browser height and receives more width on larger screens.
Hover over its card to use the standard expand control for full-screen viewing.
Both channel lists use downstream-to-upstream network order, independent of
the discovery origin. Features with unresolved order remain listed last;
the numbering is a browsing sequence, not a scientific stream-order metric.
After saving a Stream, the next form retains discovery and buffer settings,
opens Select lines, and asks for a new selection and Stream name. No restart or
study reopening is needed. Click an empty map location to find more channels
when no lines are selected, then select **Snap to stream**. With an unfinished
selection, the app keeps it and explains how to continue; **Find channels** also
lets you deliberately explore while retaining checked lines. Original source
geometry remains unchanged.

Snap and Explore show an animated service indicator and elapsed time both beside
the controls and in an app-level notification. This is activity, not an estimated
completion percentage. Cancellation, timeout and failures clear it. The map layer
menu lists only available task-relevant overlays; unchecked layers remain listed
so they can be turned back on.

The optional names-only form remains collapsed below the map. One names-only
Stream can receive a corridor by existing identity. Several such Streams require
all areas together, not yet supported by this incremental editor. Editing/removing
spatial Streams remain later steps. Reach definition is described below. No terrain processing or
Enterprise loading occurs here.

## Define Reaches

1. Choose **Reaches** under **Working on**, then choose a saved **Parent Stream**.
2. Check one or more retained NHDPlus segments, or toggle their blue lines on
   the map. All checked segments become one Reach. Review or enter its name.
3. Select **Preview Reach**, review the gold extent, then **Save Reach**.
4. Repeat for the next segment. Saved Reaches appear in purple; their source
   segments are grey and no longer offered as available choices.

Buffer distance, units and method come from the Stream; there is no separate
Reach width to enter. Reach areas clip to the Stream extent. Adjacent buffers
may overlap at segment ends. This uses retained local evidence, not another
USGS query. Missing or changed evidence requires recovery, not guessing.
Changing the selection requires a fresh preview. Assigned segments remain
unavailable for creating another new Reach.

To combine existing records, choose **Combine existing**, check the Reaches
under this Stream, and choose **Keep this Reach's identity**. Review the combined
name, then **Preview combination**. The summary shows retired identities and
Survey Events to reassign. **Save combined Reach** creates a new revision;
earlier revisions retain the originals. Event IDs and dates do not change.
Linked network/terrain-manifest records need separate reconciliation and block
this merge; no external links are silently rewritten.

### Split a saved Reach

1. Choose **Reaches**, its parent Stream, **Split existing**, and the Reach.
2. Enter the **New Reach name**. Choose which portion keeps the existing name
   and identity (downstream by default).
3. Click on or near the blue line. The cut snaps to the selected Reach within
   200 metres. Review the black cut point, gold downstream portion and teal
   upstream portion. Width is inherited from the Stream.
4. Select **Save split**. The new Reach appears within the same Stream;
   earlier revisions and source evidence remain unchanged.

Changing the retained side requires **Preview split** again. Use **Clear** to
discard the cut. The current tool requires one connected, unbranched Reach
without dependent Survey Events or linked terrain/network records. These cases
require reconciliation; events are never silently duplicated or reassigned.
**Add new** instead uses unassigned segments/pieces, with its name field above
the list. If all segments are assigned, use **Split existing** to create another
Reach from one already defined.

## Run on the development workstation

From the repository root in R, with development dependencies available:

```r
# Once, or after deliberately updating the local backend snapshot:
source("dev/scripts/prepare-dev.R")
```

Start the app from PowerShell in a **new R process**, separate from preparation
and testing:

```powershell
./dev/scripts/run-dev.ps1
```

Do not source `run-dev.R` after running tests in the same R session. Test doubles
must never be able to affect the analyst preview.

Open <http://127.0.0.1:8780>. Stop the R process to stop the app. The preparation
script installs the sibling fluvgeo checkout only into `dev/local-library`, then
documents and tests this package. It does not update shared libraries or ohwm2.
Development requires devtools, pkgload, testthat, withr and the package Imports;
reproducibleai is loaded from the sibling source for context validation.

For an installed package with its dependencies:

```r
fgstudio::run_app(data_dir = "path/to/studio-data")
```

## Storage and safety

This is a **trusted single-analyst local preview**, bound to loopback. Drafts are
saved under `.local-data/` on the computer running R and survive browser/app
closure. This folder is excluded from Git and package builds. Back it up if you
want to retain trials. Names and drawn geometries remain on this computer;
explicit drainage-exploration clicks send coordinates to USGS as described above.
The browser requests OpenStreetMap basemap tiles over the internet; those requests
disclose the viewed map area to the tile service. The basemap is not a terrain
source, and saving does not depend on a tile download succeeding.
Place searches send only the entered search text to the public Photon service
(OpenStreetMap data), not the study name or boundary automatically. Do not enter
confidential information. Search requires internet access; if unavailable, manual
map navigation and boundary saving remain available. This limited preview uses
Photon's public demo; broader deployment requires a supported service/hosting
decision. Developers can set `options(fgstudio.photon_url = "https://your-host/api/")`
to use another Photon instance without changing the UI.

The local study selector lists this workspace's drafts; it is not a multi-user
authorization system. Do not host this prototype for shared users. Future FGDB
access needs explicit Enterprise authentication, authorization and edit contracts.
Future terrain bundles will retain GeoPackage vectors/tables, external GeoTIFFs
and metadata links; the current context holds Study Area identity and Purpose,
boundary, Streams and Reaches. Companion GeoPackages retain selected source
geometry, buffer settings and, after splitting, versioned piece assignments.
Move or back up the entire study folder, not only its latest context file.

## Development

### Developer documentation

The pkgdown site contains public API reference and a numbered developer series:
application lifecycle, discovery/Streams, Reach editing, and code navigation.
Build locally with `./dev/scripts/build-docs.ps1`, then open `docs/index.html`.
The diagrams use flow; the agent index uses pkgnet plus explicitly reviewed
indirect connections. This does not publish a website or modify saved studies.

Human and agent development must remain interchangeable. Changes to call paths
must update the relevant article and agent route together; see
the repository workflow at `dev/workflows/developer-documentation.md`.

Read `AGENTS.md` and `dev/goals/project-plan.md`. Scientific methods and hierarchy
validation belong to fluvgeo. This app owns modular UI, session state and storage
orchestration. Review each working increment with the owner before selecting the
next scientific workflow step.
