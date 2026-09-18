# ADR 0004: Multi-segment Reach creation and saved-Reach combinations

Status: Accepted, 2026-09-17. Supersedes ADR 0003's one-segment restriction only.
Later extension: ADR 0005 adds saved-Reach splitting and piece-level assignment.
Whole-COMID wording below describes the original 9019 representation; piece-enabled
contexts use the [versioned piece contract](../../../fluvgeo/dev/schemas/reach-pieces.md).

## Context and decision

The owner accepted the Reach UI and requested checkbox selection like Streams,
allowing several segment candidates to define one Reach. One or more retained
segments from one parent Stream now share one name and one new Reach identity.
Buffer distance, units, processing CRS and method remain inherited. No arbitrary
segment splitting is added.

## Consequences

Map clicks toggle the same checkbox selection. Changing selection invalidates
the preview without replacing a user-entered name. Preview combines the selected
segments' buffer and clips to the parent; disconnected polygon parts remain and
are disclosed, not bridged or silently repaired. No new connectivity acceptance
rule is inferred.

All COMIDs are retained in evidence and the Reach's note-based mapping; each is
unavailable for another new Reach in that Stream. Earlier single-segment mappings
remain readable. Counts distinguish assigned/available segments from Reaches.

The owner additionally requested combining already-saved Reaches. A separate
Combine saved Reaches action selects two or more Reaches under one Stream and
explicitly chooses a retained identity. Preview describes the combined area,
retired identities and Survey Event reassignment count. Save writes a new
revision; prior contexts/evidence remain intact. Survey Events keep their own
identities and attributes; only retired Reach parent references change.

Network or terrain-manifest links block this bounded merge until their references
can be reconciled. Changed/missing Reach source evidence or edited areas that
disagree with it also block merging, rather than silently reverting the geometry.
