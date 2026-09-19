# Checkpoint: Terrain acquisition handoff

- Updated: 2026-09-19
- Status: paused at owner request; ready for a new chat

## Objective

Continue FG Studio toward browser-based L1 analysis through owner-reviewed working
increments. Next proposed slice is downloading explicitly saved source DEM tiles,
not new terrain algorithms. The owner approved the latest UI and requested this
documentation pause. Do not resume implementation merely because this file exists.

## Read first

1. Workspace and repository AGENTS.md; `.agents/workstation.md` before R execution.
2. `dev/goals/project-plan.md` and `dev/decisions/adr-0007-iterative-terrain-acquisition.md`.
3. `dev/features/stream-dem-files.md` for behavior and dated verification.
4. `vignettes/dev-06-stream-dem-files.Rmd` for the human call-flow explanation;
   `dev/architecture/agent-routes.md` for concise source navigation.
5. Sibling `fluvgeo/dev/schemas/survey-collections.md` before backend changes.

## Current state and completed work

- fgstudio 0.0.0.9027, main; observed HEAD d697f75 (`added documentation`).
- fluvgeo 2026.09.19.9037, main; observed HEAD 96e2888 (`added reach split/merge`).
- Both contain substantial modified/untracked work from this development loop.
  These features are working-tree state, not committed releases. Refresh status;
  preserve existing edits. No commits or pushes were performed for this handoff.
- Study hierarchy/Stream/Reach editing precedes the current acquisition work.
- Survey Collections: USGS/USIEI discovery for Study Area, product planning,
  immutable saved selections, shared map and distinct service outcomes.
- DEM files: saved Stream polygon AOI; supported USGS source-directory matching;
  intersecting reported file bounds; selectable tiles, Select all/Clear, scrolling
  details, explicit Save file choices and compatible offline restoration.
- Collapsible Download review presents counts, known size/subtotal, missing sizes,
  unknown/coarser-than-1-m resolution and saved state. No transfer execution exists.
- Backend: `discover_stream_dem_files`, `write_stream_dem_selection`,
  `read_stream_dem_selection`. App: `R/stream_dem_files.R`, parent
  `R/mod_survey_collections.R`, persistence adapter `R/study_store.R`.

## Resolved confusion — do not reopen as an established defect

For Spencer Creek mainstem, a direct metadata query returned 31 tiles for
IA_Eastern_1_2019 and zero for IA_Eastern_2_2019. Owner screenshots subsequently
showed the corresponding tile list and successful-empty status. The owner
identified the difference between Study Area discovery and Stream acquisition
scope, saved file choices, and accepted the clarified wording. No stale-result or
collection-switching defect was established. The exact cause of the original
transient blank display was not independently reproduced.

Unchecked tiles do not appear in the selected-tile table or map overlays. The new
review reports selected/returned counts and explains selection. Empty successful
queries now say the collection may cover other parts of the Study Area; this is
not a claim that the provider has no DEMs anywhere.

## Evidence and verification

- Latest refinement: 25 focused backend + 30 focused app assertions passed.
  Two app warnings concern dependencies built under R 4.6.1 (runtime R 4.6.0).
- Prior full app suite: 591 passes, zero failures, two build-version warnings,
  before the final presentation-only refinement. Do not call it a full test of
  the final revision. Full fluvgeo suite and R CMD check were not rerun.
- Latest pkgdown rebuild succeeded, with expected missing-public-URL diagnostic.
  Generated map: 55 nodes, 69 static edges, 11 reviewed bridges; freshness and
  bridge checks passed. Final runtime HTTP check returned 200.
- Owner accepted the UI. This is not comprehensive browser automation evidence.

## Runtime and data preservation

Preview was running at http://127.0.0.1:8780/ at pause. Verify current process/port
before restarting; PIDs are intentionally not a restart contract. Launch from
fgstudio with `dev/scripts/run-dev.ps1` in a fresh R process, never a test process.
Backend is installed only in `fgstudio/dev/local-library`; shared libraries and
ohwm2/QGIS/ArcGIS production runtimes are unchanged. Docs build uses a separate
`dev/check-output/doc-library` and ignored `docs/` output.

Preserve `.local-data` and all its hierarchy/selection revisions. The owner has
saved DEM choices there. Do not clear studies, manufacture missing metadata or
automatically download their tiles. Existing file-choice GeoPackages record intent,
not acquired assets. Unsaved checkbox drafts are discarded when switching pairs.

## Next safe action and open decisions

After the owner resumes, inspect source/status, then propose the smallest download
contract: explicit start, saved choices, supported source URLs, bounded/cancellable
worker, temporary/incomplete-file handling, non-destructive publication, provenance
and clear per-file outcomes. Decide source-asset destination and verification before
writing a new asset schema; local preview paths are not an approved enterprise model.
Keep downloads distinct from raster inspection and scientific acceptance.

Standing constraints:

- High-resolution AOI is Stream, not Study Area. File bounds are not valid-data
  footprints; NoData masking is intentional, not a missing-data percentage test.
- DEMs must be 1 m or finer, but resolution alone cannot approve suitability
  (including hydro-flattening). Unknown resolution is not a confirmed failure.
- Survey Event can use multiple Survey Collections; never infer unique surveys
  from catalog titles/dates. FGDB Collection is a different concept.
- Preserve source CRS/vertical/provenance uncertainty. Do not infer vertical datum,
  perform transforms, mosaic/clip terrain, or create Events in a download slice.
- Mid-resolution Study Area terrain, persistent Reach DEMs and Stream/Event linkage
  need future design. User-facing tools remain deterministic; no agentic AI runtime.
- Maintain human articles and agent routes together. Keep UI compact; no extra
  responsive-preview fixtures. Owner remains in control of toolbox/API design.
