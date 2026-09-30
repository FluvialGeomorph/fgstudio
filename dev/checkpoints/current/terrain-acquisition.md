# Terrain workflow: next-session handoff

Updated 2026-09-30. FG Studio 0.0.0.9080 / isolated fluvgeo 2026.09.29.9066.
The local Hydro Modify increment is complete. **Synthetic stream extraction is
the owner-selected next feature; it is not implemented yet.**

## Start here

Read workspace and repository `AGENTS.md`, then:

1. [Project plan](../../goals/project-plan.md): next integrated outcome and scope.
2. [Hydro Modify developer article](../../../vignettes/dev-15-hydro-modify.Rmd)
   and [storage crosswalk](../../../vignettes/storage-model.Rmd): existing inputs,
   workers, saved editions and the local-versus-FGDB boundary.
3. [R spatial workflow](../../workflows/r-spatial.md), followed by the legacy
   contributing-area and network tools named in the project plan.

Use [agent routes](../../architecture/agent-routes.md) for targeted source/tests;
do not reconstruct previous sessions or load every terrain diagnostic.
Work in the existing saved checkout: fgstudio and sibling fluvgeo have uncommitted
implementation changes, including new files. A clean checkout would omit them.
Inspect current Git evidence and preserve those changes before any Git action.

## Current capability and constraints

- Survey Events assemble immutable Stream DEM editions with same-horizontal-CRS
  bilinear resampling, mixed source cell sizes/alignment and ordered source
  priority. Outputs use the Event grid and international-foot elevations.
- Datum candidate review saves explicit analyst selections only when a datum
  change requires a choice. Selected-pipeline DEM execution is still deferred;
  a saved plan must never be represented as an executed operation.
- Hydro Modify opens with the first saved Survey Event, preserves an explicit
  valid selection and shows its date. Streams have extent-based map views,
  shared terrain colors, elevation/hillshade opacity controls and imagery,
  street and OpenTopoMap basemaps.
- Cutlines can be drawn/edited/deleted and reopen from immutable GeoPackage
  revisions. Apply runs in the background and saves a derived GeoTIFF with
  source edition, drawing revision, hashes, methods and coordinate provenance.
- The accepted hydro method uses touched cells, first-drawn priority on shared
  cells and each cutline zone's minimum elevation, without widening. Source
  grid, CRS, units and NoData remain intact. NoData-only lines are explicitly
  omitted; valid lines can proceed.
- Keep drawings pinned to their displayed source edition, even when a newer
  equivalent DEM exists. Never queue a Cutlines-group clear alongside map-widget
  replacement: a late proxy message can erase the restored drawing display.
- Initial display reuses existing pyramids or prepares a bounded window with
  `build_cache=FALSE`; the Event context prewarms the display worker. Do not
  reintroduce a full-raster pyramid build into the first-view critical path.

## Next integrated action

Review the legacy scientific method, resolve consequential method/threshold-unit
choices, then deliver contributing area, analyst-controlled threshold, network
preview and persisted vector/provenance output from an exact prepared DEM edition.
Use saved Hydro DEMs where available. Backend, app, persistence, error handling
and focused verification belong to this feature, not separate "proceed" handoffs.
See the project plan for acceptance scope. Do not resume optional hydro polish or
unrelated transform qualification by default.

## Retained review context

Primary whole-app preview:
http://127.0.0.1:8801/?study=85fbe60be7c1f957bf3d5f3e9e41f401

This is Spencer Creek, Survey Event 2019-12. The last read-only inspection found
27 saved cutlines: Mainstem 8, east tributary 12, west tributary 7. Reuse the saved
Study and DEMs; do not recreate drawings or publish diagnostic outputs into it.
Data are under `.local-data/<study-key>/`; `hydro-modify` holds drawings/results,
`event-dems/editions` holds raw editions and `terrain-display` holds display caches.

Verify the preview is running; processes need not survive a new session. The
ignored launcher `dev/check-output/run-whole-app-preview.R` uses the isolated
`dev/local-library`. Follow workstation routing and never replace shared fluvgeo.
Use small real DEM windows for development; full Stream runs need a specific
integration question. Review changes in the whole app with normal navigation.

Focused backend/module/storage/publication checks and saved-drawing restoration
checks passed in the preceding increment. The owner confirmed drawing behavior
and improved display performance. Agent browser automation timed out, so those
checks do not establish agent-performed visual interaction coverage. No full
credential-dependent backend suite is claimed.

## Deferred, not the next task

Cross-CRS selected-pipeline execution, vertical datum shifts and portable FGDB
Reach/Event bindings remain open. Local Hydro DEM production does not complete
that governed delivery contract. [Mosaic design](../../features/dem-mosaic-design.md),
[DEM edition schema](../../schemas/survey-event-dem.md) and
[transform-plan schema](../../schemas/terrain-transform-plan.md) retain the scope.
Bounded execution tests in fluvgeo remain qualification evidence, not app support.
No commit, deployment or data retirement is implied by this handoff.
