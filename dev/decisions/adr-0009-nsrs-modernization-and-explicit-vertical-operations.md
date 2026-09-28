# ADR 0009: NSRS modernization and explicit elevation operations

Status: owner direction accepted, 2026-09-20; implementation incremental.
Extends ADR 0008 and the guided CRS discovery design. This record changes no
runtime, schema, source data or installed geospatial libraries.

## Context and authority

The owner requires all CRS handling to prepare for NOAA/NGS NSRS modernization:
NATRF2022 for applicable North American plate studies, NAPGD2022 for geopotential
reference, and SPCS2022 for State Plane coordinates. Historic project analysis
used UTM and State Plane. The owner reports that vertical reference was retained
in metadata and elevation-unit handling/conversion was performed manually by
USACE survey/geospatial analysts because implicit transformations were not trusted.
This is project practice, not a finding about all vendor capabilities.

NGS's May 28, 2026 bulletin describes the foundational definitions as stable for
implementation planning and integration before official modernized NSRS release.
Definition availability, official release status, catalog registration, installed
software support and a qualified transformation are different facts. Recheck
current authoritative status when implementing each operation; do not infer
operational readiness from a name, an EPSG entry or the label "2022".

## Decision

1. Continue sf/terra with PROJ/GDAL for open-source coordinate operations and GEOS
   for geometry. Qualify the actual installed stack and required resources; open
   source alone is not evidence that an operation is accurate or supported.
2. Keep analysis horizontal coordinates projected and planar. NATRF2022 is a
   reference frame, SPCS2022 supplies projected systems/zones, and NAPGD2022 is a
   geopotential reference. These must not be collapsed into a single datum label.
   Offer applicable UTM/State Plane systems and identify modernization status;
   preserve legacy NAD83/NAVD88 source declarations instead of relabeling data.
3. EPSG is the preferred user-facing authority where registered and locally
   supported. Persist the resolved definition and provenance. Do not invent EPSG
   codes or silently substitute NAD83, WGS84, another realization or another zone
   when a requested modernized system is unavailable. A bounded advanced route
   can accept authoritative definitions only after explicit qualification.
4. Design for horizontal frame/realization, projected CRS/zone and axis units;
   coordinate epoch where applicable; vertical datum/realization, height type,
   elevation units; geoid/deformation/transformation model identities and versions
   where applicable. Keep unknown/not applicable distinct. Do not derive coordinate
   epoch from the Survey Event month, file timestamp, or "2022" system name.
   Frame reference epoch, coordinate epoch and acquisition date are separate.
5. Separate four operations in UI and provenance: metadata assignment/correction,
   exact unit conversion, coordinate/datum transformation, and raster resampling.
   Assigning NAPGD2022 metadata does not convert NAVD88 or ellipsoidal heights.
   Metres-to-feet conversion does not change a vertical datum. A horizontal unit
   selection must not imply an elevation unit or change elevation values.
6. No hidden/on-the-fly vertical datum changes or elevation-unit conversions.
   Preserve original samples and declarations. Horizontal-only raster processing
   must explicitly prevent unintended compound-CRS vertical corrections and test
   that contract, while accounting separately for planned interpolation effects.
   Retain full source compound CRS evidence even when constructing a horizontal-only
   processing definition; do not erase vertical information to suppress operations.
7. Any future implemented vertical operation is an explicit analyst-directed,
   reviewable step. Record source/target references and epochs, method/pipeline,
   area of applicability, accuracy evidence, resource versions/checksums, exact
   conversion factors, software/database versions, actor and input/output hashes.
   Block missing necessary evidence, unavailable required grids or unqualified
   operations. Do not silently fall back to a ballpark or lower-quality operation.
   Compare qualified transforms against applicable NGS tools/control examples.
8. Treat manual/external analyst conversions as real processing history. Preserve
   available evidence without assuming missing details. Prevent double conversion;
   distinguish provider-original elevations from already converted inputs.
9. Explicitly distinguish metres, international feet and legacy U.S. survey feet.
   SPCS2022 uses the international foot when feet are used. Preserve legacy foot
   definitions; deprecation does not authorize reinterpreting historic values.

## Transformation selection: owner direction, 2026-09-28

Selecting destination reference systems is not selecting a transformation. Present
feasible candidate horizontal and vertical datum transformations and require the
analyst to select the operation before it is used. Do not silently select the
first, highest-ranked or sole candidate. The selection and exact executed operation
are mandatory provenance. Candidate review and durable selection are implemented
as planning under Survey Events. Selected-pipeline DEM execution remains
unimplemented; plans do not enable it. Candidate discovery and local persistence
are specified in `dev/schemas/terrain-transform-plan.md`.

- Discover candidates for each distinct source-to-target reference pair and the
  analysis area, using known coordinate epochs and installed resources. Resolve
  missing reference/epoch evidence where required to determine feasibility.
  Files sharing operation requirements may share a choice; do not repeat the
  same decision for every tile.
- Present operation name and authority/code where available, source and target
  references, area of use, stated accuracy (explicitly unknown when unspecified),
  required grids/models and availability, epoch requirements, and horizontal and
  vertical effects. Show unavailable operations separately with their reasons.
  Execution support is part of feasibility, not merely catalog presence.
- Start with no transformation selected. Require an explicit choice even when
  only one feasible candidate exists. A recommendation is not a selection.
  Never silently substitute another operation when the selected one is unavailable.
- Explain horizontal and vertical effects separately. A candidate may be a
  concatenated operation affecting both; preserve its complete ordered pipeline.
  Do not imply arbitrary horizontal and vertical choices can safely be combined.
  Distinguish reprojection, datum transformation, elevation-unit conversion and
  raster interpolation in the processing record.
- Persist operation name/identifiers and executable pipeline, source/target
  definitions, area and accuracy evidence, coordinate epochs, required resource
  identities/versions/checksums, software and coordinate database versions, input
  bindings, and selection time/actor when known. Retain the candidate evidence
  presented at selection. Link the executed operation record to every resulting
  DEM edition; CRS names or an EPSG pair alone are insufficient provenance.
- Revalidate saved selections when bound inputs, references, area, epochs or
  resources change. Require a new choice if the old one no longer applies; retain
  earlier choices and DEM histories. Execute the saved pipeline instead of
  asking the library to select another operation during processing.
- When no datum change is needed, state and record that explicitly. Identity,
  projection-only processing and exact unit conversion must not be described as
  datum transformations. Do not invent a transform choice solely to create a
  confirmation step.

## Consequences and next slice

The owner requires the transformation interface only when a datum choice is
needed. Matching horizontal and vertical datums, including different projections
or units, do not prompt for a datum operation. Distinct realizations remain
distinct. The app checks automatically and displays only pairs requiring review;
unresolved references must not silently be treated as matching.

Backend implementation 9048 qualifies a bounded static same-geodetic-reference
horizontal raster path: retain compound source evidence, pass a separate 2D
processing definition and exact grid-free pipeline, explicitly disable vertical
shifting, and verify the selected output precision. Owner correction in 9049 makes
Float32 storage the default, independent of Float64 working precision; Float64
storage is explicit opt-in. The installed GDAL control converts synthetic
US-survey-foot heights to metres without these guards; the guarded path preserves
them. This enables no app mosaic action or vertical/datum/epoch operation. Source
reference reconciliation, projection suitability and scientific acceptance remain
separate. See sibling fluvgeo's `dev/schemas/horizontal-terrain-warp.md` and the
human developer article 13 for qualification scope and tests.

Implementation 9035/9044 records vertical target metadata in context schema 7:
exact resolved definition or explicitly unresolved/local/unknown declaration,
height type, independent target elevation unit, coordinate epoch/status/evidence,
frame epoch and intended model identity/version/reference. Dynamic vertical and
3D geographic definitions may be saved as metadata only. This does not lift the
horizontal active-CRS guard or qualify vertical/epoch processing. Source records
and historic conversion evidence are retained without new interpretations.

Owner refinement (9034): CRS choice requires no manual Recorded by or Why fields.
Record automatic validation/catalog evidence and the user-triggered action without
inventing a personal identity. This does not eliminate scientific source-reference
evidence or explicit processing provenance. Vertical/epoch storage recommendations
are in `../features/vertical-reference-design.md`; metadata recording must remain
distinct from enabling an epoch-dependent coordinate operation.

The guided picker must expose frame/realization, units, area of use and installed
support, with links to authoritative NGS modernization resources as well as
SpatialReference.org. A name match is not a qualified operation. Legacy sources
remain usable through supported, explicit workflows; no bulk migration is implied.

The context records horizontal/vertical definitions and vertical epoch/planning metadata. This does not qualify epoch-dependent operations or complete NSRS modernization. Implementation scope is maintained in the reference feature records.

Follow sibling FGDB ADR-0026 for vertical-reference recovery and preservation.
No FGDB schema changes or production upgrades are authorized by this design record.
Maintain the established Event grid/mask rules independently of datum migration.

## Primary references (checked 2026-09-20)



- [NGS implementation-planning bulletin, May 28, 2026](https://content.govdelivery.com/accounts/USNOAANOS/bulletins/4193400)
- [NGS modernization progress](https://www.ngs.noaa.gov/datums/newdatums/TrackOurProgress.shtml)
- [NGS modernization FAQ](https://www.ngs.noaa.gov/datums/newdatums/FAQNewDatums.shtml)
- [NGS SPCS2022 guidance and units](https://beta.ngs.noaa.gov/SPCS/learn-more.html)
- [PROJ time-dependent transformations](https://proj.org/en/stable/operations/time_dependent_transformations.html)
- [PROJ operation options and required-grid behavior](https://proj.org/en/stable/development/reference/functions.html)

The cited latest PROJ documentation does not establish the capabilities of the
installed sf/terra bindings. Test each binding and operation before enabling it.

Float32 is the default DEM storage type; Float64 is explicit opt-in. GDAL manages working precision. The explicit vertical-operation decision applies independently of storage precision.
