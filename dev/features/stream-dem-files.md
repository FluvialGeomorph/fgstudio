# Stream-scoped source DEM file discovery

Owner-directed next increment, 2026-09-19. From Survey Collections / DEM files,
choose a saved Stream polygon and an included collection with DEM in its plan.
Find source DEM files uses a cancellable worker and fixed public USGS metadata
endpoints. The shared map displays Stream AOI (green) and checked file bounds
(purple). Select all / Clear operates on the returned intersecting tiles. The
selected-tile table scrolls within 220 px; the checkbox list within 180 px.
Short labels and collapsed search details reduce vertical space.

Empty completed searches explicitly distinguish the selected Stream from the
broader Study Area. Owner screenshots confirmed expected IA Eastern 2019 results;
no collection-switching defect was established. The collapsible Download review
shows selected/returned counts, saved state, reported MB (a subtotal when sizes
are missing), unknown sizes, and unknown/coarser-than-1-m resolution. Partial
catalog results remain explicitly incomplete. This is preparation only, not a
transfer executor or suitability decision. Next: explicit cancellable acquisition
of saved file choices, preserving original files and provenance for inspection.

Backend ownership: fluvgeo::discover_stream_dem_files. USGS OPR / 1 m source
directory links supported; other links/providers explicitly UNSUPPORTED. Directory
matching is exact, not guessed from dates or names. sf intersects reported bounds
with the Stream. No raster data are read/downloaded or coverage percentages
computed. File size, pixel-size evidence, format and publication date are shown;
publication is not acquisition, and bounds are not valid-elevation footprints.
Resolution can remain unknown even when a file is listed.

Save file choices writes a new immutable GeoPackage per Stream/collection pair,
retaining all returned records, explicit selected IDs, Stream/collection evidence
and query status. Reopening the same context and source snapshot restores choices
offline. Stale context/file revisions, changed geometry/source evidence, or a DEM
collection not in the saved acquisition plan block saving. Refresh requires draft
choices to be saved first. Switching Stream/collection discards unsaved choices.
Query cap is PARTIAL; Select all means all returned tiles, not guaranteed complete
coverage. No asset registration, download, mosaic, suitability decision
or Event creation is implied. Those are subsequent slices. Existing study files,
the production toolboxes, ohwm2 and shared libraries are unchanged.

Study Area DEM clarification is recorded in ADR 0007: future mid-resolution terrain
for watershed work is distinct from Stream high-resolution acquisition. No storage
or FGDB schema scaffolding for that future role is added now.

## Evidence

Owner accepted the empty-result/download-review changes and requested a new-chat
pause. The final documentation build succeeded (55 nodes, 69 static edges,
11 reviewed bridges); the restarted preview returned HTTP 200. Resume via
`dev/checkpoints/current/terrain-acquisition.md`. Download execution is not built.

Empty-result/download-review refinement: 25 focused backend and 30 focused app
assertions passed; two existing app dependency build-version warnings. Includes
zero selection, saved state, partial results, unknown sizes/resolution and coarse
tiles. No downloads, service changes or study-data mutations. Full suites were
not rerun for this presentation-only refinement.

Bulk selection / saved-choice increment: focused backend tests passed 23
assertions; focused Studio tests passed 21. Full Studio suite passed 591
assertions, zero failures and two existing package build-version warnings.
Synthetic tests cover bulk selection, immutable round trips, offline restoration
and stale-context/source/file guards. No live service requalification was needed
for these UI/persistence changes; no raster downloads or active-study mutations.
Developer documentation rebuilt successfully; generated map has 55 nodes,
69 static edges and 11 reviewed bridges. Freshness and bridge checks passed.

The preceding discovery increment was qualified as follows:

Focused backend tests: 17 assertions passed. Focused Studio tests: 8 new module
assertions and 33 Survey Collection assertions passed; existing shiny/sf R-build
warnings only. Full Studio suite: 578 assertions passed, zero failures, two
existing build-version warnings. Live synthetic public Omaha AOI resolved source file
62640657d34e85fa62bd0234, 10,295,641 reported bytes, pixel size unknown. A separate
synthetic location correctly returned a successful empty catalog result. No
raster downloaded; no active user studies touched. Full fluvgeo suite and R CMD
check have not been rerun. Interactive browser acceptance remains owner review.

Developer article 06 and agent routes updated; pkgdown rebuilt successfully.
Generated map: 55 nodes, 69 static edges and 10 reviewed bridges; freshness and
bridge checks passed. Existing missing public-site URL diagnostic remains.
