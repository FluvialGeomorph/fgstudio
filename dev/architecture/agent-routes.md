# Agent entry routes (FG Studio scope)

For project purpose or audience, read `vignettes/fgstudio.Rmd`; for analyst
operations, `vignettes/guide-study-workflow.Rmd`. These orient the task without
replacing the implementation routes below. Article 01 explains the context-routing
pilot and its limits; the dated governance record retains experimental evidence.

Start with the matching row and the named source/test. Read its article when
intent, callbacks or persistence need explanation; it is not a mandatory full
read for every lookup. Do not load every feature history or the entire generated
network by default. These are
reviewed navigation routes, not automatically proven runtime call sequences.

| Task | Article | App source | First tests | Backend boundary |
| --- | --- | --- | --- | --- |
| Complete source DEM paging / uncapped transfers / saved availability across refresh | 06 | stream_dem_files.R, stream_dem_download.R, study_store.R | test-stream-dem-files.R, test-stream-dem-download.R | discover_stream_dem_files; run_stream_dem_download; immutable receipts retained; history is not analysis binding |
| Saved DEMs hidden after metadata revision; Survey Event terminology and suggested choices | 06, 10 | stream_dem_files.R, survey_event_settings.R, study_store.R | test-stream-dem-files.R, test-survey-event-settings.R | Existing Stream geometry/collection compatibility; legacy group API stays internal |
| Source vertical/unit review, explicit priority and saved overlap rule | 14 | terrain_source_review.R, stream_dem_preflight.R, study_store.R | test-terrain-source-review.R | App-owned annotations; terrain-source-review schema; no processing authorization |
| Horizontal raster operation qualification and Float32 storage before assembly | 13 | No app caller yet; sibling fluvgeo/R/warp_terrain_horizontal.R | sibling test_warp_terrain_horizontal.R | warp_terrain_horizontal; horizontal-terrain-warp schema |
| Automatic Event masks / all assigned Streams / native terra raster operations / saved-output reuse | 12 | event_masks.R, survey_event_settings.R, study_store.R | test-event-masks.R | write_event_masks, read_event_masks; event-masks schema |
| Internal preflight diagnostics (not mounted in analyst UI) | 11 | stream_dem_preflight.R, survey_event_settings.R, study_store.R | test-stream-dem-preflight.R | preflight_stream_dem; inspect_stream_dem_download |
| Survey Event navigation / optional notes / required cell size | 10 | survey_event_settings.R, mod_study.R, study_store.R | test-survey-event-settings.R | propose_survey_acquisition_groups, write_survey_acquisition_group, read_survey_acquisition_group |
| JavaScript runtime contracts / verification entry points | 01 | map_search.R, study_analysis_crs.R, inst/www/network-reference.js | test-javascript.R; javascript/ fixtures; dev/scripts/check-tests.R | Existing isolated backend; no implicit installation |
| CRS save feedback / restored definitions / reload to saved study | 02, 08, 09 | mod_study.R, study_analysis_crs.R, study_vertical_reference.R | test-study-reload.R, test-study-module.R, test-study-analysis-crs.R, test-study-vertical-reference.R | read_study_context; existing immutable CRS writers |
| Vertical target / epoch / model specification; CRS dropdown clipping | 09 | study_vertical_reference.R, study_analysis_crs.R, mod_study.R, study_store.R | test-study-vertical-reference.R; test-javascript.R | study_vertical_crs_candidates, validate_study_vertical_reference, set_study_vertical_reference; study_context schema 7 |
| Study Area CRS picker / local catalog / validation / saved WKT / hidden-input pending guards | 08 | study_analysis_crs.R, mod_study.R, study_store.R, mod_survey_collections.R, stream_dem_files.R | test-study-analysis-crs.R, test-survey-collections.R, test-stream-dem-files.R | study_crs_candidates, validate_study_analysis_crs, set_study_analysis_crs |
| Source DEM download / receipts / cancellation / retry | 06 | stream_dem_download.R, study_store.R | test-stream-dem-download.R, test-stream-dem-files.R | prepare_stream_dem_download, run_stream_dem_download, read_stream_dem_download, cancel_stream_dem_download |
| Stream DEM files / saved choices / acquisition AOI | 06 | stream_dem_files.R, mod_survey_collections.R, study_store.R | test-stream-dem-files.R | discover_stream_dem_files, write_stream_dem_selection, read_stream_dem_selection |
| Survey Collection discovery / shared map / resolution / product plan (ADR 0007) | 05 | mod_survey_collections.R, study_store.R | test-survey-collections.R | discover_survey_collections, survey_collection_products, write_survey_collection_selection, read_survey_collection_selection |
| Startup, session or revision lifecycle | 02 | app.R, mod_study.R, study_store.R | test-study-module.R, test-study-store.R | start_study_context, read_study_context, revise_study_context |
| Boundary adoption | 02, 03 | mod_boundary.R, polygon_selection.R, study_store.R | test-boundary.R, test-polygon-selection.R | combine_study_area_polygons, check_study_area_containment |
| Discovery or service feedback | 03 | drainage_explorer.R, network_reference.R, drainage_inventory.R | test-drainage.R, test-network-reference.R | locate_drainage_stream, get_drainage_context |
| Stream selection/order/buffer | 03 | stream_selection.R, study_store.R | test-stream-selection.R, test-stream-repeat.R | preview_stream_corridor, add_study_stream_corridor, order_drainage_flowlines |
| Reach Add/Combine | 04 | reach_selection.R, reach_merge.R, study_store.R | test-reach-selection.R | read_study_stream_segments, add_study_reach_corridor, merge_study_reaches |
| Reach Split | 04 | reach_split.R, study_store.R | test-reach-split.R | preview_study_reach_split, split_study_reach |
| Names, identification, selection zoom | 01, 02 | study_feature_names.R, saved_feature_display.R, mod_boundary.R | test-feature-names.R, test-saved-feature-display.R | rename_study_feature |

Articles live in `vignettes/`, app sources in `R/`, tests in `tests/testthat/`.
Backend symbols are in sibling **fluvgeo**, not this package. Read its AGENTS.md
before entering that repository. Exact piece contracts live in
`../fluvgeo/dev/schemas/reach-pieces.md` relative to the fgstudio repository root.
QGIS and ohwm2 are not alternate implementations to modify automatically.

For backend evidence, go directly to these sibling fluvgeo paths after reading
its instructions:

| Question | Backend source | Backend tests |
| --- | --- | --- |
| Stream clipping/containment | `R/study_stream_corridor.R` | `tests/testthat/test_study_stream_corridor.R` |
| Saved-Reach combination and dependencies | `R/study_reach_merge.R` | `tests/testthat/test_study_reach_corridor.R` |
| Reach split and piece publication | `R/split_study_reach.R`, `R/study_reach_pieces.R` | `tests/testthat/test_study_reach_split.R` |

Merge dependency checks are context-wide: any non-null `network` or
`folder_manifest` blocks the operation. Survey Events alone do not; their retired
Reach parent IDs are reassigned. Verify these guards in source before changing them.

## Indirection that must not disappear from the mental model

Downloaded DEM inspection: `R/stream_dem_inspection.R` consumes the download
module's `inspection_context`; its callr worker invokes
`fluvgeo::inspect_stream_dem_download`. Article 07 explains receipt binding,
ordinary/embedded metadata, cancellation and session-owned metadata/display caching.
Choosing a file automatically starts a preview; optional integrity rechecking
forces a fresh checksum. Healthy work has no elapsed-time cutoff. Tests:
`tests/testthat/test-stream-dem-inspection.R`.

Visual overview: the same worker's preview branch calls
`fluvgeo::preview_stream_dem_download`; `draw_dem_preview` renders its bounded
numeric matrix in source pixel order. Article 07 describes sampling and limits.

Detail selection: `dem_brush_window` translates the current view's unique brush
to an absolute source pixel window. The worker passes it to the same backend API;
result `window`/`native` distinguish exact-cell data from sampled windows. Tests in
`test-stream-dem-inspection.R` cover nested offsets and stale-brush rejection.

DEM download review: `R/stream_dem_files.R`, `output$acquisition` summarizes
checked metadata and saved state. The child `stream_dem_download_server` starts
the separate transfer/verification worker; article 06
explains missing sizes/resolution and Stream-versus-Study-Area search scope.

`reach_split_server` → `store$split_reach` (returned closure) → local `revise`
→ function argument `writer=fluvgeo::split_study_reach` → `read` → `on_saved`
→ `current` observer → new editor. Article 04 explains the controls and boundaries.

The generated `call-network.json` records pkgnet's package-local static network,
source hashes and explicitly reviewed bridge edges. It is not a multi-repository
complete call graph. Use the query/check script described in the documentation
workflow before relying on it; missing edges are not proof of missing calls.
