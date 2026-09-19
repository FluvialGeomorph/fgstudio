# Survey Collections: discovery and selection intent

Owner-approved slice, 2026-09-19. **Survey Collection** means a reported lidar
acquisition candidate, distinct from FGDB **Collection** (groups Study Areas)
and a Reach-associated **Survey Event**. These are not synonyms.

The new tab searches the saved Study Area against USGS 3DEP published lidar
index layer 24 and NOAA USIEI topographic lidar layer 2. It shows literal
acquisition/status/availability reports, links, identifiers, retrieval dates and
footprints. These layers are not exhaustive; the 3DEP index is not a live WESM
endpoint. Other catalogs and WESM snapshot ingestion remain future adapters.

Checkboxes record intent, including planned or unknown-status candidates. They
do not download data, verify links, establish scientific comparability, create
Survey Events or assign Reaches. Catalog-qualified record IDs are not asserted
unique acquisitions; cross-listing reconciliation remains a later decision.

Find, inspect, select, Save selections and reopen offline. Query outcomes are
separate from acquisition status. The worker is cancellable. A failed query is
not a zero-result finding. Selected records absent from refreshed results retain
their older metadata and retrieval evidence rather than being silently dropped.

Save creates `survey-selection-NNNNNN.gpkg` beside the context, with query boundary,
all reviewed records, selected flags, raw metadata and query evidence. Earlier
snapshots/context files are unchanged. Stale revisions or changed boundaries
block publication. Shared methods live in fluvgeo; the app owns worker lifecycle,
controls and sidecar routing. This is not an enterprise schema migration or a
multi-user transaction system. See developer article 05 for call paths.

## Verification (2026-09-19)

Subsequent owner decision: acquisition targets the saved Stream polygon only,
while catalog discovery stays at Study Area scope. Target Stream Survey Event
DEMs; any necessary Reach DEMs are derivatives. Reach derivative persistence and
Stream survey identity remain open. See ADR 0007; no download/Event code was
changed by recording this clarification.

Shared coverage/resolution refinement (9025/9035): discovery and planning tabs
share a viewport-height, full-screen-capable map. Inspected, included and custom
visibility modes never write inclusion/product state. Both zoom targets are
explicit. Positive finite USGS dem_gsd_meters is shown; NOAA point spacing is not
used as DEM cell size. The <=1 m screen is not suitability acceptance.
ADR 0007 records iterative download/inspection/replanning and multiple source
collections per Survey Event as required future capabilities. Current planning
can be revised; downloads, inspection decisions and Event assembly are not built.

Focused verification: 46 backend assertions and 33 app assertions passed, zero
failures, two existing app sf/shiny build-version warnings. UI construction is
covered; interactive browser acceptance remains the owner's next review. Full
package suites and R CMD check were not rerun for this refinement.

Owner accepted the discovery/selection UI. The next approved increment adds
explicit DEM and POINT_CLOUD acquisition intent, with DEM acquisition first and
point-cloud processing deferred. Choose a selected collection, check products,
Update acquisition plan, then Save selections. No downloads or Events occur.
USGS source-DEM and point-cloud links are separate reported evidence. General
USIEI access is not promoted to product-specific availability. Unknown does not
mean unavailable. Deselecting a collection drops its current plan on save;
prior snapshots remain. Version 1 snapshots reopen with an empty plan.

Acquisition-plan verification: backend focused suite 28 passes; full FG Studio
suite 564 passes, zero failures, two existing sf/shiny build-version warnings.
Coverage includes product-link separation, unknown metadata, rejected unselected
or unsupported product choices, v1 compatibility, v2 round trip and deselection.
No full fluvgeo suite or R CMD check was rerun for this increment.

Live synthetic Omaha check completed both catalogs (1 USGS / 6 USIEI records).
USGS reported distinct DEM and point-cloud links; USIEI retained literal product
descriptions and unresolved product-specific access. Temporary DEM-plan snapshot
round trip passed. No linked product downloaded. USGS category `Meets` is provider
classification, not availability. pkgdown and code-map checks completed; only the
existing missing public-site URL diagnostic remains. Browser acceptance of this
new planning panel is still for the owner to assess.

Full FG Studio suite: 555 passes, zero failures, two existing R-build-version
warnings. Focused backend Survey Collection/opportunity suite: 47 passes, zero
failures/warnings; two existing report tests skipped because gt was unavailable
in that test library. The entire fluvgeo suite was not rerun for this additive API.
Final focused app suite added reopened re-save, changed-boundary and same-study
draft-retention checks: 23 passes, zero failures, the same two R-build-version warnings. Strict agentic
context validation passed. This slice did not rerun full R CMD check.

Live synthetic Omaha AOI: USGS returned one record, USIEI six, including historical
acquisitions and Fall 2026 Planned/Funded. Both queries completed and a temporary
selection GeoPackage reopened correctly. NOAA rejected encoded `outFields=%2A`
but accepted the equivalent literal `*`; the adapter normalizes only that fixed
token. No access-link download, user-data mutation or browser acceptance is
claimed by this smoke check. The legacy toolbox and shared runtime were untouched.
