# Decisions

Use architectural decision records for consequential choices that should remain understandable after the implementation changes.

- Give each ADR a stable identifier.
- Record context, decision, consequences, and status.
- Supersede accepted ADRs with a new ADR instead of rewriting history.

## Current decisions

- [Independent local-first Studio](adr-0001-independent-local-first-studio.md).
- [Geospatial tools and boundary inputs](adr-0002-geospatial-tools-and-boundary-inputs.md).
- [Reach segments and inherited Stream buffers](adr-0003-reach-segments-and-inherited-buffers.md).
- [Multi-segment Reach selection](adr-0004-multi-segment-reach-selection.md): supersedes the one-segment restriction.
- [Custom segment editing](adr-0005-custom-segment-editing.md): shared piece model; saved-Reach splitting implemented, pre-assembly and Stream cuts remain future work.
