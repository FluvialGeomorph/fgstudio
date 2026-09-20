# ADR 0008: Study Area analysis CRS and terrain masks

Status: owner requirements accepted and clarified, 2026-09-19. CRS selection
implemented; Event grid and mosaicking remain pending.

## Context

The owner accepted tile inspection and supplied raster hygiene requirements for
analysis DEM creation. Downstream raster math needs an explicit analysis frame
and NoData domain, while source tiles can have different CRSs and resolutions.

## Decision

- Require an analyst-defined planar horizontal CRS for each Study Area, shared
  by all analysis, using sf and terra with the open-source geospatial stack.
- Group Survey Collections by acquisition time for Survey Events, using the
  same-calendar-month convention and retained metadata. Preserve unknown date
  components; ambiguous membership requires evidence review.
- Produce one DEM per Stream/Event from all included tiles, with first/last
  overlap precedence and floating-point elevations. Owner clarification supersedes
  the original source-cell-size retention rule: require one analyst-selected output
  cell size per Event, which can differ from its source resolutions.
- Establish Study Area/Event One/NoData masks and derive Stream/Reach masks to
  enforce CRS, resolution, alignment and domain. Stream DEM cells outside their
  mask are NoData. Retain high-resolution data along the corridor.
- Snap products to one Study Area grid anchor. All rasters in an Event share cell
  boundaries, as do different Events with the same output cell size. Events may
  have different cell sizes; those boundaries need not coincide.
- Link local acquisition/product grouping explicitly to FGDB Reach-owned Survey
  Events. Reprocessing creates a product revision, not a new acquisition.

## Consequences

The earlier design-only restriction to compatible source grids is superseded;
horizontal reprojection/alignment belongs in this increment. Detailed defaults,
questions and qualification requirements are maintained in
[the mosaic design](../features/dem-mosaic-design.md), with proposed defaults
distinguished from owner requirements.

This extends ADR 0007's Stream-first, multiple-Collection design. It does not
authorize implicit vertical transformations, arbitrary resolution changes,
scientific acceptance of every source or production deployment.
