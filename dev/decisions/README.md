# Decisions

Use architectural decision records for consequential choices that should remain understandable after the implementation changes.

- Give each ADR a stable identifier.
- Record context, decision, consequences, and status.
- Supersede accepted ADRs with a new ADR instead of rewriting history.

## Current decisions

- [NSRS modernization and explicit elevation operations](adr-0009-nsrs-modernization-and-explicit-vertical-operations.md): modernization readiness, epochs, exact units and analyst-controlled vertical changes.

- [Study Area analysis CRS and terrain masks](adr-0008-study-analysis-crs-and-terrain-masks.md): CRS selection implemented; Event output cell size, snapping and hierarchical masks specified for subsequent implementation.

- [Iterative terrain acquisition](adr-0007-iterative-terrain-acquisition.md): shared coverage map, resolution versus suitability, and multiple source collections per Survey Event.

- [Dual-mode developer documentation](adr-0006-dual-mode-developer-documentation.md): human maintainability and agent navigation evolve together; pkgdown is the documentation surface.

- [Independent local-first Studio](adr-0001-independent-local-first-studio.md).
- [Geospatial tools and boundary inputs](adr-0002-geospatial-tools-and-boundary-inputs.md).
- [Reach segments and inherited Stream buffers](adr-0003-reach-segments-and-inherited-buffers.md).
- [Multi-segment Reach selection](adr-0004-multi-segment-reach-selection.md): supersedes the one-segment restriction.
- [Custom segment editing](adr-0005-custom-segment-editing.md): shared piece model; saved-Reach splitting implemented, pre-assembly and Stream cuts remain future work.
