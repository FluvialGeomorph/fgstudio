# Agent entry routes (FG Studio scope)

Start with the matching row and the named source/test. Read its article when
intent, callbacks or persistence need explanation; it is not a mandatory full
read for every lookup. Do not load every feature history or the entire generated
network by default. These are
reviewed navigation routes, not automatically proven runtime call sequences.

| Task | Article | App source | First tests | Backend boundary |
| --- | --- | --- | --- | --- |
| Startup, session or revision lifecycle | 01 | app.R, mod_study.R, study_store.R | test-study-module.R, test-study-store.R | start_study_context, read_study_context, revise_study_context |
| Boundary adoption | 01, 02 | mod_boundary.R, polygon_selection.R, study_store.R | test-boundary.R, test-polygon-selection.R | combine_study_area_polygons, check_study_area_containment |
| Discovery or service feedback | 02 | drainage_explorer.R, network_reference.R, drainage_inventory.R | test-drainage.R, test-network-reference.R | locate_drainage_stream, get_drainage_context |
| Stream selection/order/buffer | 02 | stream_selection.R, study_store.R | test-stream-selection.R, test-stream-repeat.R | preview_stream_corridor, add_study_stream_corridor, order_drainage_flowlines |
| Reach Add/Combine | 03 | reach_selection.R, reach_merge.R, study_store.R | test-reach-selection.R | read_study_stream_segments, add_study_reach_corridor, merge_study_reaches |
| Reach Split | 03 | reach_split.R, study_store.R | test-reach-split.R | preview_study_reach_split, split_study_reach |
| Names, identification, selection zoom | 01, 04 | study_feature_names.R, saved_feature_display.R, mod_boundary.R | test-feature-names.R, test-saved-feature-display.R | rename_study_feature |

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

`reach_split_server` → `store$split_reach` (returned closure) → local `revise`
→ function argument `writer=fluvgeo::split_study_reach` → `read` → `on_saved`
→ `current` observer → new editor. Article 03 explains the controls and boundaries.

The generated `call-network.json` records pkgnet's package-local static network,
source hashes and explicitly reviewed bridge edges. It is not a multi-repository
complete call graph. Use the query/check script described in the documentation
workflow before relying on it; missing edges are not proof of missing calls.
