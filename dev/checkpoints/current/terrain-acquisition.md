# Terrain workflow remediation: current handoff

## Owner request and authorization

Continue through every implemented step 06–14, not just Source DEM files. The
owner has authorized independent remediation and does not need to send repeated
resume cues. Do not say work is continuing after ending a turn. Keep UI results
reviewable. Read dev/workflows/r-spatial.md and the repository workflows.

The owner permits deletion/recreation of app-generated products made with
superseded custom raster processing. Inventory found no such saved products:
34 mask rasters in six published Stream/Event outputs all record native terra rasterization
from backend 9051; 57 other rasters are downloaded original inputs. No raster
files were in staging. Nothing was deleted. Do not interpret original downloads
as app-generated derivatives to remove.

## Current source/runtime

FG Studio 0.0.0.9048; isolated fluvgeo 2026.09.22.9053. Changes are uncommitted.
The final preview runs at http://127.0.0.1:8784/ (exec session 65328), with Windows
worker permission. Earlier previews 8781/8782/8783 remain running; do not terminate
sessions with possible unsaved work. HTTP 200 and the new controls were checked.
Actual worker checks passed. Browser interaction has not been accepted visually.

Review Survey Collections → DEM files → View downloaded DEM. File selection
starts a preview; metadata appears in a collapsed section below it. Recheck file
integrity is optional. Review Define a Survey Event → Analysis masks for automatic
mask preparation and cached display. No preflight/source-review UI is mounted.

## Implemented and checked

- 06: complete discovery paging, uncapped healthy transfers, saved availability
  across refreshed choices; reopening metadata no longer rehashes every DEM.
- 07: one cold checksum, session metadata/display cache with change indicators,
  explicit refresh, automatic preview, no 30-minute cutoff.
- 08–10: explicit real-world CRS, structured vertical reference and Survey Event
  inputs retained; no speculative scientific defaults added.
- 11/14: internal screening and unmounted annotations remain optional backend
  evidence, never manual mask approval prerequisites. Misleading article fixed.
- 12: native terra mask operations; shared Study Area raster reuse; consolidated
  publication summary; no inverse-mask audit; lightweight reopening, worker
  display cache and stopped-job staging cleanup.
- 13: broken custom block dependency removed; native summaries; no cell/row/disk
  admission rules or forced working precision/memory. Affine source rotation and
  unequal spacing allowed. Explicit GDAL no-vertical-shift retained; Float32
  storage default. This primitive still has no app caller.

Affected backend and app tests passed. One small saved-mask reuse test exposed
list/numeric plan representation drift, which was fixed. Source cache tests prove
warm requests do not hash source bytes and explicit refresh does. Directory-
symlink test skips on this Windows account; package build-version warnings remain.

Actual worker diagnostics: 2000x2000 source preview cold/warm 10.21/9.18 seconds
including startup. Three real Stream mask grids at unchanged 1 m spacing included
8974x10688 cells; creation took 27.80/15.87/13.64 seconds and reopen about 10 seconds
per Stream. Sampled peak worker RSS was 1681/979/949 MiB. Diagnostic outputs lived
only in temporary directories, were removed, and saved input checksums matched.
Full scope matrix, measured evidence and source references are maintained in
`dev/features/terrain-gis-remediation.md`; use it rather than historical pass counts.

## Remaining work and scientific boundary

The F6/F7 engineering follow-ups are implemented: new mask outputs have geometry/
grid/recipe reuse keys; old outputs without keys retain exact-input compatibility.
Recorded abandoned staging is reclaimed only after both owning processes exit.
Normal failure/cancel/session-end cleanup remains. Unknown legacy staging is not
deleted based on age. Current tests verify cleanup, preservation of published
outputs and stable recipe identity across labels/dates, with cell-size changes
invalidating reuse. A ps helper-name error was caught in tests and replaced with
the installed ps_pids API. Do not claim concurrency or arbitrary-size certification.

The initial numeric grid alignment convention is not author-confirmed. (0,0)
means alignment inside the real-world CRS, not a substitute CRS. Legacy toolbox
steps snap to an input DEM. Do not silently move saved grids or label the specific
new cross-Event alignment convention approved. No new mosaic, vertical/datum
transformation, deployment or shared-library upgrade is authorized by this audit.

Preserve original DEMs and current inputs. There is no new approval needed for
independent engineering fixes. Keep schemas, relevant vignettes and agent routes
aligned; generated targeted help has been refreshed. Articles 07/12/13/14 rebuilt
and 431 local links passed. A bounded backend source-archive check completed with
zero errors, one existing non-ASCII warning and two notes covering dependency/
global-binding declarations. Legacy tests/examples and vignette/manual checks
were excluded. Set LC_ALL=C for checks: the host's unsupported C.UTF-8 startup
warnings contaminated the first metadata checks. An unused backend ps dependency
was removed from source after the check; the app declares its own ps dependency.
The final live worker also checked reservation ownership, display caching and
cleanup against saved masks without replacing them. Ignore old checkpoint constraints and
historical custom mask rules; this file replaces the contradictory old narrative.
