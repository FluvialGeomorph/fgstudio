# Project plan

## Goal

Let a browser user define a study and progress to desktop-equivalent L1 analysis
with less installation and conceptual overhead. Work backward from the L1 Report;
reuse fluvgeo, identify actual gaps and design QGIS views alongside the new UI.

## Current slice

9011 implemented the owner's requested Stream-selection step: select discovered
channel lines, supply a name and per-side buffer distance/unit, preview, save,
and repeat for another Stream. Shared fluvgeo methods own buffering, containment,
identities and evidence publication. See [the feature record](../features/drainage-exploration.md).

9012 responds to owner feedback on that slice: use one View/Study Area/Streams
selector, context-sensitive Do next guidance, automatic line-selection mode after
retrieval, and Workspace - New instead of a separate Start another study action.
Remove non-decision-oriented record/map disclosures from the working screen while
retaining their data and README guidance. No new backend method or schema change.

9013 adds visible service activity, task-aware layer controls and the owner's
revised Stream rule: selected lines must be covered by the Study Area, but buffer
overflow is automatically clipped and disclosed in the preview and saved evidence.

9014 follows owner review: checking a new candidate focuses the map on that
feature. Fix false clipped-area rejection at slanted boundary intersections in
the shared backend; keep strict flowline coverage and real outside-area rejection.

9015 corrects a test double leaking into the analyst runtime. The app must start
in a fresh R process, never the process that ran its tests. Verify test cleanup
and the real backend before asking the owner to retry the Stream workflow.

## Next

9016 owner correction: clip selected flowlines to the Study Area first, then
buffer and clip the area. Replace the earlier strict-line rejection rule.
Geospatial topology must use mature CRS-aware R GIS tools, not raw coordinate
tests. Preview discloses retained channel length; original selections and
processed lines are separate evidence. See the current Stream-selection contract.

Owner review: choose Streams, follow Do next from empty discovery to a saved Stream.
Confirm that the active task and Workspace - New behavior are clear.
Review a boundary-coincident Stream: preview the clipped buffer, then save.
Confirm service activity and the available-layer menu. Try editing the parent
after saving a Stream. Pending Stream choices survive a parent revision but
require a new preview against its changed boundary.

After owner review, design nested Reach selection using retained Stream lines.
Editing/removing saved spatial Streams, mixed names-only/spatial inventories,
cross-Stream overlap rules and network acceptance remain future increments.
Do not automatically advance into terrain or L1 processing. The app is local-only;
Enterprise support remains a goal.

Existing active studies are retained. The earlier owner-authorized retirement
of four test studies remains recoverable under dev/check-output; it is not a
standing instruction to clear new studies.
