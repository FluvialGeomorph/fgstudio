# Study Area definition

A Study Area has a stable identity, required name, optional Purpose and a revisable
boundary. Workspace New starts a transient definition; Open selects a saved
Study. Explicit reopening clears transient edits without deleting saved data.

Boundaries can be drawn or adopted from reviewed watershed candidates. Saving
calls fluvgeo's context revision writer and preserves prior snapshots. Geometry
must be valid, nonempty, CRS-labelled and compatible with existing child areas.
Polygon import is not implemented. Boundary selection does not choose an analysis
CRS or qualify terrain.

Edit name and Edit purpose publish metadata revisions. Cancel or unchanged values
do not write. Purpose is stored independently of provenance notes; older drafts
use creation notes until an explicit Purpose is saved. Pending boundary work is
protected from accidental discard during metadata edits.

The map's compact Photon/OpenStreetMap search navigates to places without changing
geometry. Failures leave manual navigation available. Source and public-service
disclosure belong to the analyst guide.

Ownership: `R/mod_study.R`, `R/mod_boundary.R`, `R/map_search.R`, the local store
and fluvgeo context writers. Article 02 describes lifecycle; article 03 describes
candidate adoption. Tests cover revision round trips, stale/pending edits, boundary
validation, search-result handling and identity preservation. The exact boundary
contract is `dev/schemas/boundary-selection.md`.
