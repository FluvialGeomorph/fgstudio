# Resume: Qualified source operations and Stream DEM mosaics

## Current state

Event setup, read-only grid/source preflight and hierarchical One/NoData masks
are implemented in FG Studio 0.0.0.9039 / fluvgeo 2026.09.21.9047.
Next: qualify horizontal-only source operations, then implement cancellable
Stream/Event DEM assembly with saved source order and mask application.
Both repositories contain uncommitted changes. Refresh Git evidence before work.
Only the app's isolated backend library was upgraded. The analyst preview was not
inspected or restarted and may still run older code. No analyst study was used.

## Implemented behavior

- Study hierarchy, collection selection, original DEM acquisition, immutable
  receipts and tile inspection are available. No further tile preview work is requested.
- Horizontal CRS and structured vertical target/epoch specification are saved;
  no vertical operation or elevation-unit conversion is enabled.
- Immutable acquisition groups retain explicit collections/Streams, acquisition
  year/month precision, rationale, optional existing Reach Event links and required
  cell size. Reach-owned FGDB Event identities are unchanged.
- Preflight validates current group/source evidence and receipts and reports grid
  estimates and source unit/alignment issues. PASS is metadata screening, never
  execution approval, coverage acceptance or a reusable receipt check.
- Analysis masks explicitly create a Study Area/selected Stream/Reach family.
  Shared zero-anchor grids use the saved Event spacing. Centers strictly inside
  polygons are included; exact exterior/hole boundary centers are excluded.
  Child masks intersect parent NoData. Missing Reach polygons block the family;
  a Stream with no Reaches produces two masks. Narrow polygons can be all NoData.
- The backend writes compressed Byte masks in bounded blocks, checks resources,
  reopens and verifies output, and writes the manifest last. The app rechecks
  current revisions/hashes and publishes staging by rename to a new edition.
  Cancellation/failure leaves staging unpublished and previous editions intact.

## Limits and next implementation boundary

Read the R-development workflow, mosaic feature, ADR 0008 and ADR 0009. Follow
sibling fluvgeo AGENTS.md and backend assessment before scientific changes.
Source vertical/epoch reconciliation, pixel readability, operation qualification,
valid-data coverage and Float64 mosaic execution remain unresolved. Revalidate
all source selections/receipts/hashes at execution; never use preflight PASS as
approval. Preserve interpolation halos and apply masks after source assembly.
Keep first/last valid overlap order explicit. Preserve zero, negative, fractional
and Float64 values; do not silently perform vertical corrections or unit changes.

Masks currently admit 50 million total cells per family, at most 65,536 columns,
and require four uncompressed payloads plus 256 MiB of available disk. This is
not a space reservation or large-study performance qualification. Editions are
saved under event-masks/editions; failed staging remains for diagnosis. The UI
shows the newly saved path/counts but has no persisted edition browser yet.
Backend read_event_masks() verifies saved editions; later processing must also
bind them to current settings. Equal-size Events share boundaries; different-size
Events need explicit alignment for raster arithmetic.

Preserve all .local-data studies and original assets. No FGDB migration, production
backend upgrade, commit, deployment or preview restart has been performed.

## Evidence and routes

Focused backend checks passed 94 assertions (34 mask, 38 preflight, 22 grouping).
The full app suite passed 821 assertions with zero failures/skips; existing sf/Shiny build-version
warnings remain. Full legacy backend reporting is outside this bounded check
because optional gt is unavailable and some legacy scripts write outside temporary
fixtures. Source build/check retained the single existing non-ASCII warning. Site/map checks passed, including 357 local links. Detailed evidence is in the mosaic feature.

- dev/features/dem-mosaic-design.md: owner requirements and current verification.
- dev/decisions/adr-0008-study-analysis-crs-and-terrain-masks.md: grid/mask rules.
- dev/decisions/adr-0009-nsrs-modernization-and-explicit-vertical-operations.md:
  source/reference/epoch and explicit-operation boundaries.
- R/event_masks.R, R/study_store.R, tests/testthat/test-event-masks.R and
  vignettes/dev-12-event-masks.Rmd: worker, publication and human developer route.
- Sibling fluvgeo R/event_masks.R, tests/testthat/test_event_masks.R and
  dev/schemas/event-masks.md: scientific mask contract and verification.
- R/stream_dem_preflight.R and sibling fluvgeo R/preflight_stream_dem.R:
  current source screening; shared group validation and grid planner.
- dev/architecture/agent-routes.md: concise paired navigation for related work.
