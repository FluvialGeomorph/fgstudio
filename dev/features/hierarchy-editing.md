# Hierarchy names and downstream-to-upstream candidate order

## Saved-feature interaction

View mode labels saved Streams
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

The interface provides Rename Stream and Rename Reach links beside the study
title. A modal selects the existing identity and pre-fills its name. Explicit
save changes one display-name field in a new revision. Blank names, same-parent
duplicates and stale revisions are rejected; an unchanged name is a no-op in
the adapter. Pending map/selection work blocks opening or saving the rename.

Geometry, CRS, IDs, parent links, Survey Events and provenance files are retained.
Historical labels in source evidence stay historical; matching uses identity and
geometry, not display names. Names do not assign stationing or number records.

Both upstream and downstream reference query lists use whole-network
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
Saved-Reach splitting is implemented; pre-assembly and Stream cuts remain future work.

Only the isolated FG Studio backend is upgraded. ArcGIS, QGIS, ohwm2 and
Enterprise behavior are unchanged. Tests use temporary stores; retained user
studies are inspected read-only, never automatically renamed or renumbered.
