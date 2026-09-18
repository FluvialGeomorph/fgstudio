# Hierarchy names and downstream-to-upstream candidate order

## Saved-feature usability (9022)

The owner accepted saved-Reach splitting. View mode now labels saved Streams
and Reaches and provides click popups with name, type, parent context and ID
(plus Reach count for Streams). Use the layer control to reveal overlapping
features. Editing modes leave saved context noninteractive so identification
cannot consume discovery, segment-selection or split-point clicks.

Parent Stream, Reach-to-split, combination-identity and rename selections zoom
to the saved feature. Names-only records have no geometry to zoom to. Rename
choices sort alphabetically, case-insensitively. Per owner clarification,
Reach labels use **Stream / Reach**, sorting first by Stream name and then by
Reach name so identically named Reaches remain grouped under their Streams.
This display order does not
change downstream-to-upstream candidate ordering or stationing.

The saved inventory lists Streams with their nested Reaches and area status,
including Streams with no Reaches yet. These are presentation changes only;
saved data, identities, provenance and backend contracts are unchanged.

Verification (2026-09-17): 9022 package check **OK**, 535 assertions passed;
two existing sf/Shiny build-version warnings remain. Tests cover escaped popup
content, context-only layers remaining noninteractive during edits, alphabetic
choices, nested inventory, CRS-aware zoom and dropdown events across Add, Split
and Combine. Context validation passed. Browser usability review remains with
the owner; tests did not modify saved analyst data.

9020 / fluvgeo 9031 adds Rename Stream and Rename Reach links beside the study
title. A modal selects the existing identity and pre-fills its name. Explicit
save changes one display-name field in a new revision. Blank names, same-parent
duplicates and stale revisions are rejected; an unchanged name is a no-op in
the adapter. Pending map/selection work blocks opening or saving the rename.

Geometry, CRS, IDs, parent links, Survey Events and provenance files are retained.
Historical labels in source evidence stay historical; matching uses identity and
geometry, not display names. Names do not assign stationing or number records.

Both upstream and downstream reference query lists now use whole-network
downstream-to-upstream order. Reach candidates use original Stream evidence
before clipping to establish their order. Existing origin-based backend callers
keep their previous behavior; the app opts into whole-network ordering with a
NULL origin. sfnetworks supplies endpoint topology and igraph supplies reverse
topological order; digitized downstream NHDPlus reference direction is assumed.
No mainstem choice, snapping, reversal or topology repair is introduced.
Branches have stable tie-breaks, not a single scientific stationing route.
Unsupported geometry/cycles remain explicitly unresolved, never ordered by
COMID magnitude and presented as hydrologically sequenced.

The owner also requested custom segmentation. [ADR 0005](../decisions/adr-0005-custom-segment-editing.md)
selects both pre-assembly and post-assembly editing through one piece model.
It was not available in 9020; saved-Reach splitting shipped in 9021 and was
accepted by the owner. Pre-assembly and Stream cuts remain future work.

Only the isolated FG Studio backend is upgraded. ArcGIS, QGIS, ohwm2 and
Enterprise behavior are unchanged. Tests use temporary stores; retained user
studies are inspected read-only, never automatically renamed or renumbered.

## Verification (2026-09-17)

FG Studio 9020 package check: **OK**, 491 assertions passed, with the existing
sf/Shiny build-version warnings (installed 4.6.1 builds, runtime 4.6.0).
Backend ordering checks: 19 assertions passed, including branches, row shuffles
and projection changes. Rename tests verify whole-context preservation including
Survey Events, while app tests cover geometry/evidence preservation, duplicates,
staleness, modal submission and rename-then-merge compatibility.
Read-only checks ordered all 16 retained segments (zero unresolved), previewed
saved-Reach merges in all three Streams and confirmed unchanged study-file hashes.
Both repository context checks passed. The owner subsequently accepted Rename
and saved-Reach Split. Full fluvgeo package checks were not rerun.

The 535-assertion package check above predates the Stream-first rename sorting
correction. That correction passed the focused saved-feature-display suite
(30 assertions, including repeated Reach names across Streams); a new full
package check was not run for it. On 2026-09-18 the owner described the app as
very functional and requested this documentation review. That is overall user
feedback, not separate sign-off of every popup/zoom edge case.
