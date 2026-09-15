# FluvialGeomorph Studio

An independent browser workspace for defining studies and, eventually, producing
FluvialGeomorph L1 analyses. `ohwm2` is a reference for useful interactions, not a
parent application or deployment target.

## First working increment

1. Enter a working Study Area name and optional purpose/customer question.
2. Select **Create Study Area**. The app saves a real fluvgeo context GeoPackage
   and reads it back before displaying the saved draft.
3. Review **What is known** and **What comes next**.
4. Refresh the browser, select the saved study and choose **Open study**. The
   identity and purpose persist. **Start another study** leaves the first intact.

## Draw a boundary

Not sure where the study should end? Use **Explore drainage** on the map (also
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

These are reference candidates for deciding Study Area and Stream scope, not saved
FG records. The basin is catchment-based, not an exact pour-point delineation;
channel results are distance-limited. Adopting/combining candidates is a future
reviewed step. Exploration sends the selected coordinates to USGS public services,
not your saved study boundary/name/purpose. Results clear when leaving exploration
or changing study/revision. Save unfinished boundary work before switching modes.

After opening or creating a study, click the map's **magnifying glass**, type a
nearby public place and state, and choose a suggested match to zoom there. You can
also zoom manually. Search only moves the map; it leaves saved and unfinished
boundaries unchanged. Choose the polygon
tool, click around its boundary, then click the first point to finish. Review the
drawing and select **Save boundary** below the map. For vertex changes, use the
map's edit tool, finish with its **Save** control, then **Save boundary**.

The saved boundary appears when you reopen the study. Each save retains the prior
GeoPackage revision and the same Study Area identity. Drawing/removing a candidate
does not change the saved boundary. Import and watershed selection are required
future alternatives, not yet implemented. No DEM clipping, analysis CRS, Stream,
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
retained under Saved record details, not mixed into the current Purpose.

## Define Streams

Open a Study Area and use **3. Define Streams** below the map. Enter the initial
Stream names, one per line, optionally explain the selection, then select
**Save Streams**. Review the whole initial list before saving. The saved inventory
reopens with stable Stream identities linked to this Study Area; it survives
later name, Purpose and boundary revisions. No CSV or technical IDs are needed.

This form records names, not Stream areas or channel geometry. The separate
exploration mode can query reference networks without adopting them. Neither
operation clips terrain or creates Reaches. A Study Area
polygon is not required to start the inventory. Finish/save any pending boundary
work first; entered Stream text is carried across revisions of the same open study.
Reopening or switching studies discards unsaved form text. Appending, renaming or
removing saved Streams is not yet implemented; the initial-definition function
refuses replacement of existing hierarchy/network records.

## Run on the development workstation

From the repository root in R, with development dependencies available:

```r
# Once, or after deliberately updating the local backend snapshot:
source("dev/scripts/prepare-dev.R")
# Start the app:
source("dev/scripts/run-dev.R")
```

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
and metadata links; the current context holds Study Area identity, notes and its
optional drawn boundary.

## Development

Read `AGENTS.md` and `dev/goals/project-plan.md`. Scientific methods and hierarchy
validation belong to fluvgeo. This app owns modular UI, session state and storage
orchestration. Review each working increment with the owner before selecting the
next scientific workflow step.
