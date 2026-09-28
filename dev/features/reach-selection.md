# Reaches from saved Stream segments

After a split, Add/Combine operate on local selection/piece IDs using
[versioned evidence](../../../fluvgeo/dev/schemas/reach-pieces.md); the whole-segment
note mappings described below remain the compatibility path for unsplit contexts.

The workflow implements [ADR 0004](../decisions/adr-0004-multi-segment-reach-selection.md):
choose Reaches in the existing map, choose a saved Stream, check one or more
retained NHDPlus segments, review/edit the name, preview, then explicitly save.
Repeat without reopening. All checked segments create one Reach. The separate
Combine existing handles already-saved identities. The
[Split existing action](reach-splitting.md) adds reviewed saved-Reach cuts.
Map clicks toggle checkboxes. Selection changes invalidate preview and preserve
the typed name. Selected segment and preview-part counts are shown; disconnected
polygon parts remain visible, not silently connected.

The buffer distance and units are read-only inherited settings. fluvgeo
reuses the parent's retained processing CRS, GEOS buffer parameters and clipped
line evidence, then clips the Reach area to its parent Stream. Overlap at segment
ends is retained, not converted to non-overlapping partitions. Purple polygons
are saved Reaches; gold is the current preview. Assigned segments remain grey on
the map but are omitted from the available selection list.

## Storage and safety

Combine saved Reaches selects at least two same-Stream records and one retained
identity. Preview counts retired identities and reassigned Survey Events. Save
recomputes the combined inherited buffer and changes only the chosen Reach
inventory and retired event-parent references. Earlier snapshots and source
files are untouched. The latest explicit `Reach merge` note supersedes that
identity's former source mapping; this supports repeated merges. Exact Reach
evidence hashes and current areas are verified first. Linked network/terrain
manifests block merging until separately reconciled. Modes protect pending
selections and use separate inputs, previews and save actions.

The shared backend reads the exact Stream evidence filename/checksum from the
existing context note convention; it does not scan for orphan candidates or
contact USGS. Missing, changed, ambiguous or unsupported evidence blocks the
operation. This is a compatibility reader for the existing note-based links,
not a new normalized provenance schema.

Save recomputes geometry and verifies containment. Duplicate source assignment
within a Stream and duplicate Reach names are refused. New local Reach UUIDs
remain separate from COMIDs. Existing records and earlier revisions survive.
Reach source mappings and SHA256-linked `reach-selection-<uuid>.gpkg` evidence
(`retained_line`, `reach_area`) are added to the new revision's notes.
Evidence is written first; a later failure may leave unreferenced evidence.

The app checks the current revision before preview/save, validates selection
against server-held sources, protects pending geometry when switching tasks,
and retains the parent Stream after saving. Unsaved previews are never reused
across revisions. Explicit reopen clears transient work as in the existing app.

## Verification and boundaries

Backend tests cover inherited international feet, boundary-coincident segments,
unchanged Streams, containment, repeated saves, duplicates and changed evidence.
App tests cover map selection, consecutive saves, task guards and stale revisions.
`dev/scripts/check-reach-local.R` performs read-only previews of retained local
Streams and compares file hashes before/after; it never publishes Reaches.

Only FG Studio's isolated backend is upgraded. Existing ArcGIS/QGIS clients,
ohwm2, terrain processing, arbitrary Reach geometry editing/deletion and Enterprise loading remain
unchanged. No complete drainage-network or scientific segmentation acceptance
is inferred from a successful save.
