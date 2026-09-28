# Guided CRS discovery

The normal CRS picker reads the installed PROJ catalog locally through sf/GDAL.
SpatialReference.org is a reference/exploration link, not the candidate-search
service. External URL parameters are website details, not a versioned API.
The required catalog layout is checked; no remote query selects the analysis CRS.

## Picker contract

Owner requirement, 2026-09-20: apply
[ADR 0009](../decisions/adr-0009-nsrs-modernization-and-explicit-vertical-operations.md)
throughout this design. Prepare for NATRF2022, NAPGD2022 and SPCS2022, retaining
frame/realization, applicable coordinate epochs, height type and exact units.
Expose definition versus installed-operation support and provide NGS references.
No hidden vertical conversions; catalog membership is not operational qualification.

The searchable pick list defaults to
non-deprecated EPSG projected 2D systems whose recorded area-of-use bounds contain
the complete transformed Study Area bounds. Label area-of-use evidence as a coarse
screen, not proof of acceptable distortion. Handle dateline/zone boundaries
explicitly and do not silently select a zone from the centroid alone.

Show name, EPSG code, datum realization, linear unit, projection method and area
of use. Offer name/code search and unit filters. Present appropriate State Plane
and UTM candidates without guessing the analyst's datum or measurement convention.
Do not recommend EPSG:3857 for engineering measurements simply because it is
projected. A user must still choose the desired system.

The picker offers Study Area exploration and selected-CRS reference links.
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

The saved definition supplies Event grid construction. Projected-2D
validation remains mandatory. Epoch-dependent horizontal choices are currently
explore-only, including advanced WKT. Separate vertical target epoch/model
metadata is persisted in schema 7; it does not qualify coordinate operations.

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
