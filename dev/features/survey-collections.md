# Survey Collections

A Survey Collection is a reported lidar acquisition candidate, distinct from an
FGDB Collection and from a Reach-owned Survey Event. Discovery queries the saved
Study Area against supported USGS 3DEP and NOAA USIEI catalogs, retaining provider
IDs, acquisition/date evidence, status, links, footprints and retrieval provenance.
Catalog coverage and cross-listing reconciliation remain adapter limitations.

Selection records acquisition intent, including unresolved provider availability.
DEM and POINT_CLOUD plans retain product-specific evidence; general access links
are not promoted to product-specific availability. Point-cloud processing remains
outside the implemented terrain pipeline. Source acquisition targets Streams;
catalog discovery targets the Study Area.

Discovery and planning share a map with inspected/included/custom visibility and
explicit zoom targets. Visibility does not alter saved selection. Failed queries
are distinguished from zero results; selected records absent from refreshed
results retain their evidence.

Saving writes an immutable Survey selection GeoPackage with query geometry,
reviewed records, selected flags, product plan and metadata. Changed boundaries
or stale revisions block publication. Older snapshots without a plan reopen with
an empty plan. Deselecting a Collection updates the new snapshot only.

Article 05 owns UI and call paths. Source files, inspection and Survey Event DEM
assembly are subsequent implemented capabilities. ADR 0007 owns acquisition
scope; fluvgeo owns catalog/persistence methods. Tests cover query failures,
metadata preservation, product distinctions, revision binding and reopening.
