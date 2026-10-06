# Application architecture

FG Studio is a local-first Shiny client for defining Study Areas and progressing
through Stream/Reach geometry, Survey Collection acquisition, analysis references,
Survey Events and DEM processing. fluvgeo owns scientific methods and domain
persistence. FGDB defines the enterprise data model and delivery requirements.
The analyst guide owns operating instructions; numbered developer articles and
`agent-routes.md` trace implementation.

The app-wide bslib theme is Bootstrap 5 Bootswatch Flatly. Standard tab navigation
is used throughout, including the Study Workspace sidebar. Theme colors and tab
states come from Flatly rather than module-specific CSS overrides.

## Session and storage boundaries

`fgstudio_app()` creates the application; `run_app()` supplies the local data root.
Study modules receive a store interface rather than constructing user paths.
The store tracks saved context revisions and separately managed acquisition,
mask and DEM editions. Revision guards reject stale writes. A save publishes a
new snapshot, retaining prior contexts and evidence.

New/Open and explicit reload govern session selection. The opaque study key in
the URL reopens the latest saved revision. Unsaved drawing, selection and form
state remains session-local; explicit reopening discards it. Pending-work guards
protect task, mode and metadata changes from accidental draft loss.

The shared local catalog is intended for a trusted single analyst. Authentication,
tenancy, concurrent enterprise editing and arbitrary uploads are not implemented.
Enterprise transport is a separate contract, not a interchangeable database URL.

## Geometry and map interaction

Leaflet and leaflet.extras provide display, navigation and drawing events. sf,
lwgeom and fluvgeo implement CRS-aware geometry. Display coordinates are never a
substitute for the saved analysis frame. Completed valid polygons form boundary
candidates; edits invalidate previews until checked again. Saving recomputes from
current inputs and preserves identity/provenance.

Reference discovery is cancellable and retains service outcomes separately from
candidate selection. Stream construction clips selected flowlines to the Study
Area, buffers retained lines and clips the area. Reach creation inherits Stream
buffer/CRS evidence; combination and splitting preserve versioned piece identities.
Schemas and ADRs own containment, identity and dependent-record constraints.

Saved-feature labels, popups and zoom belong to View mode; edit modes retain
noninteractive context layers. Renaming changes display names, not identities,
source evidence or channel ordering. Purpose is separate from provenance notes.
The map search changes viewport only.

## Terrain workflow

1. Collection discovery records acquisition/product intent at Study Area scale.
2. Source file selection and acquisition use the saved Stream polygon and immutable
   receipts. Inspection opens bounded displays with session cache reuse.
3. The CRS tab records horizontal and vertical targets. Survey Events record
   Collection/Stream membership and output cell size.
4. `event_masks_server()` prepares/reuses the saved grid/domain in a background
   worker. Mask visualization is an optional diagnostic, disabled by default.
5. `survey_event_dems_server()` serializes assigned Streams through
   `terrain_dem_trial_job()`. `terrain_dem_request()` binds saved inputs and mask;
   `terrain_dem_sources()` resolves receipt-backed files in source order.
6. The worker calls fluvgeo crop/merge, mask and international-foot conversion.
   `study_dem_store()` publishes immutable local editions. Display-only Stream
   tabs reopen their own eligible edition.
7. Hydro Modify saves cutline-adjusted Hydro revisions and derives immutable
   synthetic Stream Network candidates without changing the source DEM edition.
8. Flowline reads one exact Hydro/network pair, uses retained NHDPlusV2 evidence
   to select the intended terrain path, prepares bounded smoothing candidates,
   divides the chosen path by ordered Reach evidence and saves one immutable
   local Reach-Flowline candidate revision.

The integrated DEM path requires aligned grids and NAVD88 metre sources with an
international-foot target. Differing-grid and other vertical operations remain
separate integration work. The mosaic design owns unresolved scientific choices,
including confirmation of the initial shared grid anchor. Saved grids are retained.

## Worker and publication lifecycle

Pass paths and serializable settings across process boundaries; workers open their
own rasters. Expensive computation uses native file-backed GIS operations.
Controllers snapshot inputs, reject stale completions and stop workers before
cleaning owned staging. Successful editions are retained on failure/cancellation.
Recorded process ownership permits conservative abandoned-stage recovery.

The Event UI shows one DEMs card with Stream tabs and optional details. Processing,
failure and pause messages describe actionable state. Internal reports and source
annotations are developer facilities, not analyst prerequisites or processing inputs.

## Domain objects and storage

Use [the storage crosswalk](../../vignettes/storage-model.Rmd) to relate operations
to FGDB entities, GeoPackage feature layers/tables and external GeoTIFF products.
The intended terrain design processes Stream DEMs and shares explicit editions
with Reach analyses. Synthetic networks and Flowline candidates are immutable
local children of the exact Hydro/network revisions they consume. FGDB's existing
hydro DEM ownership rule requires revision for Stream-scale sharing, and local
Flowline candidates still require governed Reach-owned Survey Event and Dataset
Edition identities before delivery.

## Durable data

FGDB ADR-0025 requires filesystem GeoTIFF DEMs and GeoPackage vectors/tables with
linked metadata. The internal DEM edition RDS index supports local reuse; network
and Flowline stores add hashed GeoPackage revisions with RDS/JSON indexes.
Portable folder binding and enterprise transfer remain unfinished. Source
originals and prior output editions are preserved. Detailed contracts live in
the schemas; method evidence lives in feature records, not this architecture
overview.
