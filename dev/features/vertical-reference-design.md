# Vertical reference and epoch specification

The Study Area vertical specification records a target reference and epoch evidence.
It is distinct from processing source elevations. ADR 0009 owns the scientific
requirements; the DEM pipeline's supported unit conversion is described separately.

## Reference specification

Analysis setup has Horizontal CRS and Vertical reference tabs. The latter provides
local area-screened vertical EPSG candidates, authoritative-definition entry,
ellipsoidal 3D definitions, declared/future names, local and unknown choices.
Height type, elevation unit, coordinate epoch/evidence and optional intended-model
metadata persist together. Unknown/local/declared entries retain an unqualified
status; dynamic resolved definitions remain metadata-only. Save requires a current
check and no pending geometry/acquisition edits. No Recorded by or Why fields.

One new immutable context stores vertical_reference plus paired descriptive
vertical/unit rows. Source assets, geometry and horizontal CRS are unchanged.
Later revisions retain the specification. Existing processing records block target
changes. Older contexts remain readable; older software rejects schema 7.
Exact contract: sibling fluvgeo/dev/schemas/study-vertical-reference.md.

Validation/save feedback is revision-bound and displayed beside the controls.
Reload restores saved definitions; unsaved inputs are discarded. Catalog dropdowns
use viewport-aware placement and bounded scrolling. Article 09 traces the editor
and tests; ADR 0009 owns reference and epoch requirements.

## Storage recommendation

Preserve source coordinates, raster samples, provider metadata and original
observations. Record actual references; never relabel NAD83/NAVD88 as 2022 systems
to express future intent. Keep a planned target separate from source declarations
and from the qualified active analysis reference.

For each source asset/layer and each derived product, retain structured fields:

| Information | Meaning |
|---|---|
| CRS authority/code and canonical WKT2 | Exact frame/realization, axes and units; optional equivalent PROJJSON |
| Coordinate epoch (decimal year) | Epoch at which these coordinates are valid, with evidence and known/unknown/not-applicable status |
| Frame reference epoch | Definition property, kept separate from coordinate epoch |
| Acquisition start/end and precision | Observation dates; never automatically substituted for coordinate epoch |
| Vertical reference and height type | Vertical CRS/datum/realization; orthometric, ellipsoidal, local, or unknown |
| Elevation unit and exact factor | Independent of horizontal units; distinguish metre, international foot and U.S. survey foot |
| Geoid/deformation model | Model name/version and source where actually used; not assumed from datum name |
| Original metadata and evidence | Provider declarations, documents/control and analyst corrections, with immutable source hashes |
| Processing history | Already-applied unit/datum operations, exact factors, source/target epochs, pipeline, grids/checksums, software/catalog versions and accuracy evidence |
| Capability/status | Declared/planned versus locally resolvable versus qualified for the specified operation |

Use nullable numeric epochs with explicit status. Never use zero, a system-name
year, the file timestamp or the Survey Event grouping month as an unknown epoch.
One dataset-level epoch applies only where all its coordinates share that epoch;
retain mixed source epochs separately rather than averaging into an Event value.
Do not guess a source coordinate epoch from EPSG:6344 or its NAD83(2011) name.

The app's context should remain the authoritative structured record, with export
metadata mirrored into formats only after round-trip tests through sf and terra.
GDAL supports GeoPackage epoch storage and GeoTIFF CoordinateEpochGeoKey, but
upstream capability does not establish preservation by the installed R workflow.
Test original -> read -> write -> reopen for CRS, epoch, units and unchanged samples.
WKT CRS alone is insufficient for dataset coordinate epoch; coordinate metadata
must associate the CRS with that epoch. Preserve authoritative definitions without
inventing EPSG codes for definitions absent from the local catalog.

## UI and scientific boundaries

The implemented Vertical reference tab sits alongside Horizontal CRS in Analysis
setup. Choose the intended vertical reference and elevation unit separately,
including explicit unknown/local choices. Reveal epoch/model fields only when
applicable, and keep technical details/sources in disclosure panels. Collect
scientific evidence from source metadata and explicit corrections, with automatic
recording of user-triggered actions; do not reinstate mandatory personal attribution
or a general-purpose Why field for choosing an analysis system.

The saved specification defines one Study Area target vertical reference and elevation unit for comparable
derived products, with source references retained per asset. A target epoch must
be explicit where the operation requires it; do not infer it from Event membership.

Distinguish saving a reference specification from altering data. Source evidence
belongs to source assets, and a Study Area target does not assert that all DEMs
already conform. Orthometric heights need a vertical CRS; ellipsoidal heights
belong to a 3D geodetic reference and must not be represented by a fabricated
standalone vertical EPSG code. Local/unknown references cannot silently pass
cross-source compatibility checks. Preserve legacy external/manual conversions.

Dynamic definitions can be recorded as source/planning metadata before an
operation is implemented. Enabling them as active analysis choices requires the
structured epoch contract and qualified processing support; the current saving
horizontal saving guard remains until that work is complete. Saving vertical
planning metadata is allowed without qualifying an operation. No vertical transformations are enabled
by this design. Epoch propagation also requires explicit scientific review for
historical terrain; it must not silently remove real geomorphic change.

## Primary guidance checked 2026-09-20

- [NGS preparation guidance](https://www.ngs.noaa.gov/datums/newdatums/GetPrepared.shtml): retain original observations and datum/epoch metadata; assess resurvey, readjustment or transformation against accuracy needs.
- [GDAL coordinate epochs](https://gdal.org/en/stable/user/coordinate_epoch.html): decimal-year coordinate epoch, distinction from observation epoch, dataset/layer limits and supported format encodings.
- [PROJJSON](https://proj.org/en/stable/specifications/projjson.html): standard CRS/operation definitions and CoordinateMetadata support; catalog support is not operation qualification.
- [EPSG:6344](https://spatialreference.org/ref/epsg/6344/): NAD83(2011) / UTM zone 15N, horizontal metre axes; no vertical reference is chosen by this code.
