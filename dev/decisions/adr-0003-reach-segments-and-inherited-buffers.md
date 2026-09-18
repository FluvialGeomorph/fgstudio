# ADR 0003: Reach segments and inherited Stream buffers

Status: Accepted.
The one-segment restriction is superseded by [ADR 0004](adr-0004-multi-segment-reach-selection.md).
The no-custom-splitting restriction is superseded by [ADR 0005](adr-0005-custom-segment-editing.md).
The decision text below retains its original 9018 scope; inherited buffers remain current.
Owner clarification: 2026-09-16.

Implementation: FG Studio 9018 / fluvgeo 9029; see
[Reach selection](../features/reach-selection.md) for behavior and verification.

## Context

The owner accepted the Stream-selection workflow. For the first Reach version,
NHDPlus flowline segment breaks match normal FG Reach segmentation well enough
to provide the owner's stated "90% solution." Arbitrary endpoint placement is
not needed for this increment.

## Decision

- One retained NHDPlus flowline segment represents one Reach beneath its saved
  parent Stream. Do not introduce manual splitting or multi-segment merging in
  this version.
- Reach extent polygons inherit the parent Stream's buffer distance, units and
  buffering method. This is inheritance, not merely an editable default; no
  independent Reach buffer-width input is offered.
- Reuse the Stream's retained line evidence and buffer metadata. Do not guess
  a width from its polygon or depend on another live discovery query.

## Consequences and implementation boundary

The intended interface is parent Stream selection, segment selection/naming,
preview and explicit save. Show inherited buffer settings as information rather
than another decision. Missing parent evidence or buffer metadata requires
recovery rather than invented values. Source COMIDs remain provenance, not FG
Reach identities.

Use existing CRS-aware backend methods. The proposed nested-area implementation
clips each buffered Reach to the parent Stream area and discloses clipping.
Equal-width buffers can overlap at adjacent segment ends; this decision does
not authorize manufacturing non-overlapping partitions or changing buffer-end
geometry to remove that overlap. Such partitioning would need a separate design
decision if required.

Custom endpoint placement and merged-segment Reaches remain future capabilities.
No existing study data or production toolbox behavior changes with this record.
