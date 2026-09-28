# Terrain workflow: current handoff

FG Studio 9062 / isolated fluvgeo 9057. The owner accepted the aligned-grid DEM
increment and considers the UI polished enough for now. Documentation is
consolidated; no new processing feature is selected by this handoff.

## Resume from maintained owners

- `dev/goals/project-plan.md`: accomplished scope and next owner decision.
- `dev/features/dem-mosaic-design.md`: scientific contract, implementation limits,
  consolidated real-data measurements and remaining grid/vertical choices.
- `vignettes/guide-study-workflow.Rmd`: current analyst procedure.
- `vignettes/dev-13-stream-dems.Rmd` and `dev/architecture/agent-routes.md`:
  processing call paths. Articles 11/12/14 cover inputs, masks and editions; terrain-developer-tools.Rmd covers standalone diagnostics.
- `dev/schemas/survey-event-dem.md`: local edition format and lifecycle.

## Local review setup

Preview: http://127.0.0.1:8800/?study=85fbe60be7c1f957bf3d5f3e9e41f401
Launcher: `dev/check-output/run-dem-tabs-preview.R` (ignored local aid).
Select Survey Events, 2019-12, then a Stream tab. Mainstem and both tributaries
already have saved GeoTIFFs; routine review must reuse them. No development target
or mask-diagnostic option is needed. The previous preview returned HTTP 200;
interactive browser navigation was not automated.

Use the isolated `dev/local-library` and workstation instructions. Diagnostic
records under ignored `dev/check-output/real-reach-mosaic/` include
`feet-result.rds`, `full-reach-result.rds`, `full-stream-result.rds` and
`event-queue-result.rds`. Use actual small windows for further method development,
not repeated whole-Stream/workspace builds. Do not install over shared fluvgeo.

## Remaining work

Differing-grid integration, confirmation of initial grid placement, other vertical
operations and FGDB portable folder binding remain open. Do not move saved grids
or infer a new scientific method from existing code. The horizontal-warp primitive
has no app caller. External GeoTIFF DEMs remain mandatory under FGDB ADR-0025;
GeoPackages hold vectors/tables, and edition.rds is only an internal index.

The working tree includes the completed increments and unrelated earlier edits;
no commit, deployment, data retirement or new raster build is implied.
