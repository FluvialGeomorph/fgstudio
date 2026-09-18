# ADR 0005: One segment model, editing before or after assembly

Status: Owner approved, 2026-09-17. First implementation: 9021 saved-Reach splitting.
Owner requested support for custom Stream/Reach segmentation, preferring both
entry points unless provenance or management problems prevent it. Supersedes
the earlier no-custom-splitting scope restriction, not the inherited buffer rule.

## Choice and alternatives

| Workflow | Advantage | Cost |
| --- | --- | --- |
| Split source candidates, then assemble | Choose precise endpoints early; no saved child records to reconcile | Users must foresee boundaries before assembling the project |
| Assemble, then split/reassemble | Edit a recognizable named Stream or Reach with full project context | Must preserve identities/history and review effects on children and surveys |
| Both, with one shared piece model (selected) | Supports exploratory and corrective work without forcing a restart | Requires explicit piece lineage and assignment records before either editor is released |

No fundamental provenance obstacle requires choosing only one workflow.
The two entry points should call the same fluvgeo operations, not maintain two
geometrically different splitting implementations. Original NHDPlus features
remain immutable reference data; local pieces are never represented as new COMIDs.

## Constraints at design entry (before 9021)

Stream evidence retains original and clipped lines; Reach assignments currently
use a whole numeric source_id/COMID. Reader validation and duplicate-assignment
rules assume one whole feature per source ID. Note-based mappings therefore
cannot faithfully distinguish two pieces of the same source. Simply copying a
COMID onto split features would break both uniqueness and assignment semantics.
Saved contexts have stable Study Area/Stream/Reach IDs and immutable revisions.
Saved-Reach merges already demonstrate reviewed identity retention and event
parent reassignment; a split has a different one-to-many ambiguity.

## Accepted piece contract

The saved-Reach implementation is now documented in the
[piece schema](../../../fluvgeo/dev/schemas/reach-pieces.md). The before-assembly
and Stream-editing entry points below remain approved design, not delivered UI.

- Distinguish three objects: immutable source segment, locally editable line
  piece, and named Stream/Reach with its buffered extent. Splitting a piece alone
  does not automatically split a named record or reassign Survey Events.
- Give each piece an independent ID, with source COMID, retained source geometry
  hash/version and parent-piece lineage. Keep cut point, snapped location,
  processing CRS, operation parameters and revision. Retain source-relative
  intervals only against the exact directed source geometry, not floating
  percentages of a later merged or simplified line. They are not FG stations.
- Store ordered piece-to-Stream and piece-to-Reach assignments. Old whole-COMID
  evidence must remain readable; migration to piece records is explicit and
  non-destructive. Do not rewrite existing evidence during read/open.
- Before assembly: select a source, place a cut on the map, snap to that selected
  line, preview both pieces, then choose pieces using the existing checkboxes.
- After assembly: open the saved Stream/Reach, refine its constituent pieces,
  initially retain their assignments, then explicitly repartition/reassemble.
  Preview retained/new identities, geometry and affected child records before save.
- Stream width and method remain inherited by Reach extents. Regenerate buffers
  from pieces and clip to the appropriate parent; do not slice the old corridor
  polygon as a substitute for line-based construction.
- Never duplicate or arbitrarily assign Survey Events when a Reach is divided.
  Existing children spanning a proposed split need analyst reconciliation;
  referenced terrain/network/analysis products must not be silently invalidated.
- Repeated cuts must preserve coverage, direction, lineage and non-overlapping
  source intervals; reject endpoint/zero-length cuts and ambiguous selected
  multipart branches. No invented gap fillers or geographic raw-coordinate cuts.

## Tooling and next increment

9021 implements the owner's requested post-assembly entry point first: Add new,
Split existing, Combine existing. Choose an existing Reach, click its line,
review the snapped cut and two buffered portions, name the new Reach, save.
The downstream portion retains the original identity by default; the analyst
can choose upstream instead. An unbranched connected Reach without dependent
Survey Events/network/terrain references is the current supported boundary.
Source pieces, assignments and cut lineage now have versioned evidence; original
whole-COMID contexts remain read-only until an explicit split save.
Pre-assembly candidate cutting, Stream splitting and child/event reconciliation
remain later entry points to this design, not implemented by this increment.

Use mature CRS-aware sf/lwgeom or sfnetworks operations in fluvgeo, with Leaflet
only supplying a user-selected location and explicit source identity.
Official tools reviewed: [sfnetworks blending](https://luukvdmeer.github.io/sfnetworks/reference/st_network_blend.html)
and [lwgeom splitting](https://r-spatial.github.io/lwgeom/reference/st_split.html).
[lwgeom line substrings](https://r-spatial.github.io/lwgeom/reference/st_linesubstring.html)
warn that substring interpolation is not geodesic: preserve the established
regional metric processing contract and qualify numerical behavior explicitly.
These functions provide geometry operations, not project lineage or event policy.

Implementation sequence clarification (2026-09-18): the owner requested and
accepted saved-Reach splitting first. The earlier suggestion to start with an
unassigned segment is superseded. Pre-assembly cuts and Stream splitting remain
future entry points; their implementation order needs the owner's next decision.
Exact UI for child/event reconciliation and final FGDB transport remain unknown.
Renaming and list-order changes are the independently testable 9020 increment.
