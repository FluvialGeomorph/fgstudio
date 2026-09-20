# Guided CRS discovery

Implemented guided picker in 9033/9043, 2026-09-20. The owner rejected a blank CRS text
box as the normal selection experience and asked about SpatialReference.org,
bounding-box filtering, planar engineering analysis and EPSG standardization.
The normal input is now a searchable local EPSG catalog with unit/coverage/scope
filters and reference links. See `study-analysis-crs.md` for verification and limits.
The research below records why local catalog access was chosen.

## Verified external capabilities

SpatialReference.org is maintained by the PROJ development team and publishes
CRS definitions generated from PROJ's database. Its Explorer filters on location,
name/code, type, authority and deprecated status. Definition pages expose area of
use, scope, method, axes/units and links to EPSG definitions. WKT2 and PROJJSON
are available as machine-readable per-CRS resources.

Read the live explorer.js and crslist.json on 2026-09-20. The implementation loads
the static JSON catalog and filters in the browser; no documented, supported
server-side bounding-box search API was found. The catalog contains authority,
code, name, type, deprecated status, area_of_use and projection method; it does
not include every datum/unit/scope field needed for final selection.

Explorer links support these observed parameters:

- authorities=EPSG
- activeTypes=PROJECTED_CRS
- allowDeprecated=false
- latlng=north,east,south,west (decimal latitude/longitude degrees)
- searchText for name/code filtering

These are observed website implementation details, not a versioned API contract.
Its geographic test is bounding-box INTERSECTION, not full Study Area containment.
Therefore a returned CRS can cover only part of the study. Do not treat the
website's result list as scientific approval or adequate full-area coverage.

## Picker contract

Owner requirement, 2026-09-20: apply
[ADR 0009](../decisions/adr-0009-nsrs-modernization-and-explicit-vertical-operations.md)
throughout this design. Prepare for NATRF2022, NAPGD2022 and SPCS2022, retaining
frame/realization, applicable coordinate epochs, height type and exact units.
Expose definition versus installed-operation support and provide NGS references.
No hidden vertical conversions; catalog membership is not operational qualification.

Replace the normal blank input with a searchable pick list. Default to
non-deprecated EPSG projected 2D systems whose recorded area-of-use bounds contain
the complete transformed Study Area bounds. Label area-of-use evidence as a coarse
screen, not proof of acceptable distortion. Handle dateline/zone boundaries
explicitly and do not silently select a zone from the centroid alone.

Show name, EPSG code, datum realization, linear unit, projection method and area
of use. Offer name/code search and unit filters. Present appropriate State Plane
and UTM candidates without guessing the analyst's datum or measurement convention.
Do not recommend EPSG:3857 for engineering measurements simply because it is
projected. A user must still choose the desired system.

Add both an Explore this Study Area link and a selected-CRS reference link.
Sending bounds occurs on the analyst's link click; candidate population need not
send study geometry to a remote service. Use local PROJ catalog access or a
validated cached public catalog for candidates, with sf/PROJ resolution and
existing transformation validation as the execution authority. Prefer local
database querying where feasible; do not assume sf exposes the entire PROJ C API.
Version and test any cached-catalog adapter and handle newer website codes absent
from the installed PROJ version without silently changing the runtime.

Recommend EPSG as the standard identifier for the normal workflow, while retaining
canonical WKT and relevant runtime/database provenance internally. EPSG-only is
not a universal CRS rule: legitimate custom/local engineering grids can lack a
code. An explicitly separate advanced exception can preserve WKT support; it
should not be the default analyst workflow. No global CRS should be chosen for
all studies, and horizontal EPSG codes do not choose the elevation datum.

This refinement precedes Event membership/cell-size controls. Projected-2D
validation remains mandatory. Epoch-dependent horizontal choices are currently
explore-only, including advanced WKT. Separate vertical target epoch/model
metadata is now persisted in schema 7; it does not qualify coordinate operations.

## Sources

- https://spatialreference.org/about.html
- https://spatialreference.org/explorer.html
- https://spatialreference.org/explorer.js (live implementation inspected)
- https://spatialreference.org/crslist.json (live schema inspected)
- https://spatialreference.org/ref/epsg/6492/ (example metadata page)
- https://proj.org/en/stable/apps/projinfo.html
- https://proj.org/en/stable/development/reference/functions.html

PROJ documents authority/type/bounding-box filtering for CRS database queries;
the implemented adapter reads the local SQLite catalog through sf/GDAL and checks
the required layout. No RSQLite dependency or remote search API is used.
