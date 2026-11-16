# Cross-section implementation handoff

## Outcome and authority

Continue the owner-authorized cross-section workflow, including reusable
`fluvgeo` methods and FG Studio interactive review, editing and persistence as
needed for a usable outcome. Work independently through routine intermediate
steps; the owner explicitly requested larger cohesive steps and no repeated
handoffs for ordinary progress. The standing requirements, prototype findings,
and open scientific choices are in [cross-section layout](../../features/cross-section-layout.md)
and [project plan](../../goals/project-plan.md). Read the workspace and each
relevant repository's `AGENTS.md`, workstation notes and the matching workflows.

## Current implementation

- `fluvgeo/R/water_surface_extents.R` exposes paired, strictly ordered REM
  thresholds and unsimplified flowline-connected original and hole-filled outer
  polygons. Its help, tests, namespace and project schema are in the checkout.
  This is inundation preparation, not a legacy cross-section producer.
- `fgstudio/R/cross_section_review.R`, mounted by `mod_study.R`, presents linked
  Event/Stream/Reach controls, 103/106 ft initial REM sliders and interactive
  map overlays using session-temporary background REM and footprint jobs.
  Inputs are saved Flowlines, Flowline Points and Hydro DEMs. The current 150 m
  REM buffer may clip the floodplain. No layout, editing, resequencing, or
  durable outputs exist. See [developer article 18](../../../vignettes/dev-18-cross-section-review.Rmd)
  and the [analyst guide](../../../vignettes/guide-study-workflow.Rmd).
- The owner approved the UI's appearance and found its current performance
  acceptable for further prototyping, not a general large-data qualification.
  Full-app Spencer R1 preview exercised slider updates and invalid-level
  feedback. The preview process may not remain running across sessions.
- The saved Spencer study and its Event/Flowline/Flowline Points/Hydro DEMs are
  under `fgstudio/.local-data`; resolve them through the app store and saved
  lineage, not a hard-coded study in production code. Local study data prep and
  exploratory scripts belong in `fgstudio`; reusable scientific methods belong
  in `fluvgeo`. The owner expressly rejected fgstudio-specific scripts/data in
  `fluvgeo`. The diagnostic is `fgstudio/dev/scripts/explore-spencer-cross-section-inputs.R`.

## Next integrated work

1. Develop usable direction and geometry methods in `fluvgeo`, exercised via
   the existing interactive FG Studio workflow and real Spencer R1 and R3
   contexts. The owner wants to review the map interactively rather than a
   sequence of fixed figures. Preserve analyst control of both REM elevations.
2. Address absent/narrow overbank support and abrupt path-direction changes;
   the experimental R1 sections 9–11 are wrong. Their collisions are all on
   right legs, but the old experiment shortened both sides. Do not promote that
   diagnostic shortener into production. Account for collision and loss of
   floodplain coverage separately, and allow manual correction of candidates.
3. Before implementing a historical vector output, extend the FGDB legacy
   compatibility profile and inspect ArcPy producer/resequencer, Technical
   Manual, representative legacy data, validators and all downstream consumers.
   Preserve established names/types/units/meaning and geometry conventions;
   distinguish legacy output from unresolved normalized FGDB schema. Identity
   must not silently default to `Seq` or a platform object ID.
4. Integrate the complete app workflow, temporary versus saved data boundaries,
   stale-input invalidation, documentation, tests and a fresh whole-app preview.
   Qualify representative large-data execution without inventing data-size or
   raster-extent restrictions. Reconcile verified GeoPackage requirements to
   FGDB as they emerge.

## Verification and working tree

The prior focused `fluvgeo` inundation tests passed; the isolated FG Studio
library was updated for the preview. The documentation site built with pkgdown
and 782 local links passed its check. These checks do not establish completed
cross-section geometry or full app release readiness. The previous session left
uncommitted feature code and documentation in both repositories; `fluvgeo` also
had unrelated pre-existing Hydro DEM display changes in `DESCRIPTION`,
`NAMESPACE`, `NEWS.md`, code, help and tests. Inspect exact status and diffs,
preserve all unrelated changes, and do not reset or overwrite them. FGDB also
had pre-existing uncommitted work. No commit or deployment was made.
