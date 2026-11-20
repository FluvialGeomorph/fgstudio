# XS 268: Study Area linear-reference stay-or-go analysis

Status: owner/team two-method direction accepted, 2026-11-19. RAS-style cross
sections use bankfull centerline linear referencing for all new work/rework;
simple (straight-ish) cross sections retain Flowline referencing as the legacy
backward-compatible method. FGDB must distinguish both. Exact schema and producer
implementation remain unfinished. Start each continuation at
[project-plan.md](project-plan.md#near-term-decision-gate-the-xs-268-issue).
Method v11 is accepted and closed. This analysis authorizes no geometry
optimization, reference migration, project reprocessing or production changes.

## Accepted direction and practical feasibility

The adopted direction is recorded in
[FGDB ADR-0027](../../../FGDB/dev/decisions/adr-0027-two-cross-section-methods-and-reference-families.md).
Use the [implementation plan](cross-section-implementation-plan.md) for current
work order and acceptance; this assessment retains rationale and evidence.

The two-method plan is practically feasible. The
[FGDB cross-section contract](../../../FGDB/dev/schemas/cross-section-feature-contract.md#accepted-two-method-direction)
owns the accepted method/reference pairings and proposed minimum metadata.
Existing dataset roles, scientific-method contracts, accepted editions and
reference-frame identities supply most of the needed organizational model.
Generalizing the Flowline-only reference bindings and implementing centerline
stationing/calibration remain substantive work; this is not solved by adding a
method-name column alone.

Use distinct method-family metadata and exact algorithm versions, linked to the
actual reference geometry edition, frame/base/calibration and provenance. Separate
dataset roles allow both methods in one Survey Event without one overwriting the
other. Keep historical measures intact; common-axis comparisons need an explicit
reviewed mapping. Rework produces RAS-style output without implying that every
historical product must be reprocessed. The RAS-style name does not establish
hydraulic acceptance. Existing accepted v11 geometry uses Flowline stations and
must retain that truthful transitional provenance until the new binding exists.

## Scientific objective and intended benefits

Owner clarification on 2026-11-19: the primary scientific goal is to isolate
stream morphological change over time in response to infrastructure and landscape
change. Flowline remains an essential input to REM creation. The selected change
is to derive an additional **bankfull channel centerline** and use it for linear
referencing; both geometries coexist. Flowline can ideally approximate the
thalweg/low-flow centerline, whereas the bankfull centerline represents the
channel at a broader morphological scale. These are distinct scientific roles.

The intended benefits, articulated by the owner, are:

- reduce station displacement caused by event-to-event variation in the
  low-flow path, its length and flight-day water conditions;
- reference observations to bankfull channel form, which is expected to change
  less frequently than the low-flow path and better express the higher-power
  fluvial processes of interest;
- retain explicit base-event selection and comparison-event calibration, while
  seeking fewer calibration distortions, anomalous correspondences and manual
  exceptions;
- relate longitudinal sampling more directly to bankfull channel geometry,
  including the spacing mismatch exposed by XS 268; and
- retain both scales of evidence so real low-flow-path change and bankfull
  channel change can be studied without treating every path-length difference
  as a change in observation location.

These are the scientific rationale and testable expected benefits, not measured
performance claims. Genuine bankfull migration, cutoffs and length change must
remain observable; calibration should not erase the morphological signal. Preserve
uncalibrated geometry/lengths alongside calibrated positions for both families.

The source limitation is material: ordinary topographic LiDAR does not establish
a submerged thalweg. Instrument wavelength matters as well as clarity/depth:
[USGS distinguishes near-infrared topographic LiDAR from water-penetrating green topobathymetric LiDAR](https://www.usgs.gov/3d-elevation-program/inland-bathymetry).
Shallow clear water alone does not establish bed detection by a topographic
sensor. A derived Flowline follows the supplied DEM's representation of the
channel, which may reflect flight-day water surface or processing/interpolation;
it is not automatically a measured thalweg or a reliable water-surface survey.
This qualifies the measurement claim without changing the owner's rationale.

The current REM-threshold channel polygon is a candidate representation of
bankfull extent, not independently established bankfull truth. Adoption needs a
documented bankfull interpretation and evidence of consistent delineation across
events. The current polygon's Flowline/REM dependency does not invalidate its
use as a higher-level reference; it identifies provenance and sensitivity to test.

## Decision and consequences

Implement the accepted two-method direction through FGDB contracts that accommodate
both Flowline- and bankfull-centerline-based frames, retaining Flowline in the
processing chain. RAS-style is selected for new work/rework; bankfull delineation
and calibration qualification remain implementation requirements. Preserve historical Flowline-referenced projects in
their original frames; convert or additionally position selected observations
only where a scientific comparison requires it.

Coexistence removes universal historical conversion as an adoption prerequisite.
The accepted direction is not a claim that centerlines already reduce variance.
Method v11 remains closed, and no code or production stationing is changed by
this decision record.

## Primary finding: coexistence in FGDB

**Yes, both can coexist in one FGDB design without compulsory historical
reprocessing. The existing contracts need an explicit additive extension.**
Three different capabilities must be distinguished:

| Capability | Requirement | Historical work |
|---|---|---|
| Store/query each project in its native reference | Record exact frame, reference family, base realization, mouth, topology, units, calibration and evidence status. | Bind and validate surviving historical evidence; no centerline conversion merely to load it. |
| Display different projects together or compare metrics independent of longitudinal position | Retain project/frame labels and method compatibility; do not imply equal stations denote equal places. | No coordinate conversion unless the particular analysis needs it. |
| Compare old and new observations at common longitudinal locations | Explicitly select a common frame and use accepted additional positions/calibrations or a reviewed frame mapping. Check spatial coverage and comparability of sampled transects separately. | Selected correspondence/calibration and affected output review; regenerate geometry/terrain products only if the analysis requires resampling. |

The existing model already allows configuration 1:N frames, each with its own
mouth, base selections and calibrations. Derived Dataset Editions already identify
scientific method and schema contracts. Those mechanisms support heterogeneity;
they do not yet implement centerline stationing. Current accepted ADR-0013/0014
and draft base-selection/calibration foreign keys explicitly require Flowlines.
An extra `reference_type` flag alone would leave those relationships incorrect.

### Proposed additive logical design, for review

Keep Study Area → Stream → Reach → Survey Event ownership. Retain Flowline and
add a separately identified bankfull centerline dataset/feature role with exact
edition and source-bankfull-polygon lineage. Do not relabel existing Flowlines
or use their identity for a second, simultaneously existing geometry.

Introduce a typed **reference alignment** abstraction solely in the data model:
one edition-qualified reference path of family `FLOWLINE` or
`BANKFULL_CENTERLINE`. Each alignment must resolve to exactly one real source
geometry realization with enforced ownership and referential integrity. A common
parent with constrained subtype relations is one option; exact tables and
physical bindings remain a review choice. This is not a proposed analyst-facing
term. Preserve existing Flowline relationships through compatible bindings.

Generalize frame base selections and comparison calibrations to those alignments.
Pin exact geometry editions as well as stable feature IDs so a later accepted
geometry edition cannot silently change an existing frame. Initially propose
one declared reference family per frame, with one selected base realization per
Reach; the schema should not imply that one frame has two competing definitions
of the same coordinate. Mouth, Reach intervals, confluence continuity, monotonic
upstream kilometers and explicit base selection apply to both families.

Separate the Cross Section's geometry/derivation lineage from its longitudinal
positions. Its original Flowline link remains useful provenance even when a
centerline provides stationing. A proposed `cross_section_position` association
can retain one position per section per frame, with Reach assignment, applicable
base/comparison calibration, position method, quality and units. Adding a second
position neither creates a second physical transect nor changes its stable
identity. The draft kernel's direct Flowline ownership of Cross Section needs
review at this boundary; final Cross Section identity remains unresolved.

Inherited attributes can keep shared types, units, direction and definitions
where their roles agree: Reach label, kilometer endpoint measures, coordinates,
uncalibrated measures and calibration difference. Centerline receives its own
identity, geometry-family discriminator, polygon lineage and method evidence.
Same-shaped attributes do not make the coordinate values interchangeable.
Established Flowline/Flowline Points outputs retain their original meanings.
Specify a separate centerline profile or explicit frame-qualified view; do not
silently put centerline stationing into a legacy Flowline-profile export.

### Worked coexistence example

A historical project retains frame F, based on its selected Flowline and original
mouth/calibration. A newer project uses frame C, based on its selected bankfull
centerline. FGDB can hold both, including old sections whose only accepted
position is in F and new sections whose accepted position is in C. Different
projects/Streams do not need a spatial crosswalk just to coexist.

For an overlapping Reach with old and new events, comparison can deliberately
adopt C as the analysis frame. Keep each old section's position in F. Where
geometry and controls support it, add an accepted position in C by locating that
existing transect against the selected centerline realization and applying the
declared calibration, or by a reviewed F-to-C mapping. Historical bankfull
polygons/centerlines need not be reconstructed solely to position an existing
historical section in C. They are needed if the question is historical bankfull
centerline change or a centerline-to-centerline event calibration requiring them.

Multiple/no intersections, changed topology and uncertain correspondence require
explicit dispositions. Matching stations do not prove that differently located
transects sampled the same material or are otherwise scientifically comparable.
A query requiring a common longitudinal axis must request a target frame and
reject or explicitly exclude observations without an accepted mapping. Native
separate-frame queries remain usable. Same-origin kilometer values are not enough.

## Evidence and limits

- **Verified maintained XS evidence:** the
  [performance audit](../performance/cross-sections.md#remaining-tight-bends-and-endpoint-distribution)
  reports retained v10 R2 stations at 5330/5350/5370 m, whose channel sections
  intersected the polygon centerline at successive gaps of 17.727 and 3.468 m.
  Labels are at bank midpoints. These are retained v10 comparison measurements,
  not new measurements of v11 and not a portfolio-wide error estimate.
- **Verified legacy producer:**
  [`_05a_Flowline.py`](../../../FluvialGeomorph-toolbox/tools/_05a_Flowline.py)
  dissolves reviewed network segments by `ReachName` and smooths with PAEK.
  [`_06_FlowlinePoints.py`](../../../FluvialGeomorph-toolbox/tools/_06_FlowlinePoints.py)
  sets kilometer `from_measure` from the mouth offset, sets `to_measure` to
  offset plus Flowline length in kilometers, builds a two-field route, and
  optionally calibrates comparison routes using point controls. It preserves
  uncalibrated measures and the signed calibration difference.
- **Verified dictionary:**
  [`data_dictionary.csv`](../../../FG-Tech-Manual/data_dictionary.csv)
  describes kilometer Flowline endpoints and XS `km_to_mouth`. Its `POINT_M`
  descriptions vary by entity; a common field name is not a universal unit or
  distance definition. The
  [compatibility profile](../../../FGDB/dev/schemas/legacy-derived-feature-compatibility.md)
  resolves the ArcPy-replacement Flowline Points kilometer contract separately
  from existing R clients' local projected-unit behavior.
- **Verified current implementation:**
  [`cross_section_preparation.R`](../../R/cross_section_preparation.R)
  prepares an REM with `fluvgeo::detrend(dem, line, points, ...)`, then thresholds
  it through `water_surface_extents()`. That function retains components
  intersecting the Flowline; region preparation derives/prunes centerlines.
  Thus the available polygon centerline is not independent channel evidence.
  Flowline remains the upstream construction input under the owner's clarified
  scope. Centerline referencing adds a later workflow role.
- **Verified consumers:**
  [`cross_section.R`](../../../fluvgeo/R/cross_section.R) converts declared
  Flowline Point units to XS `km_to_mouth`;
  [`cross_section_points.R`](../../../fluvgeo/R/cross_section_points.R)
  carries that value while constructing separate within-section `POINT_M`;
  [`compare_xs_long_profile.R`](../../../fluvgeo/R/compare_xs_long_profile.R)
  groups by `Seq` and `km_to_mouth` across surveys;
  [`compare_long_profile.R`](../../../fluvgeo/R/compare_long_profile.R) and
  [`xs_metric_plot.R`](../../../fluvgeo/R/xs_metric_plot.R) plot longitudinal
  measures. Legacy
  [`_13a_XSResequence.py`](../../../FluvialGeomorph-toolbox/tools/_13a_XSResequence.py)
  resequences by ascending `POINT_M`. These dependencies make migration more
  than a map-label change. This is a sampled dependency review, not a complete
  audit of reports, exports, customers or external scripts.

Sources were inspected in the working trees: fgstudio HEAD `c89b08b`, fluvgeo
`9f16cc02`, toolbox `1e96199`, FGDB `b772fab`. FGDB had existing staged/unstaged
design changes, including the longitudinal contract and compatibility artifacts;
their draft/accepted status is taken from each document, not inferred from Git.
The initial assessment edited no sibling repository. The revised assessment
adds a clearly proposed coexistence route in FGDB's owning longitudinal contract;
it does not amend accepted ADRs or implement the proposed relations.

### Read-only historical sample

On 2026-11-19, `sf::st_layers()` inspected the local
`FG-filedata/FileGDB/Collections/FluvialGeomorph` directory. Its 16 `.gdb`
directories comprise the Copperas Creek Stream geodatabase and R01–R15 Reach
geodatabases. The Stream geodatabase contains `stream_network` and `flowline`.
All 15 Reach geodatabases contain `flowline`, `flowline_points` and four layers
whose names begin `xs_` (these include derived products, not four layouts).
An NWO_Papillion directory also exists, but this scan found no `.gdb` there.
This is available local coverage, not an inventory of the historical portfolio.

`st_read()` read only the first three rows of selected R15 layers. R15 contains
one Flowline, 1316 Flowline Points, 13 `xs_100_100` sections, 424 section points
and 13 rows each of L1/L2 dimension products. Its Flowline interval is
45.6648–46.92673 km. Sample XS `Seq` 465–467 have equal `POINT_M` and
`km_to_mouth` values 45.7144, 45.8151 and 45.9149; their `to_measure` values
31.83451, 35.77539 and 40.88923 are a separate section measure, not kilometer
distance to mouth. The sample confirms existing linked products and differing
field meanings, not successful calibration, topology or migration validation.
No dataset was changed. R completed with workstation locale and sf build-version
warnings; these reads are not numerical equivalence tests.

## Scientific comparison

| Criterion | Retain selected base Flowlines | Migrate to polygon channel centerlines |
|---|---|---|
| Coordinate meaning | Preserves the selected base path's distance to the common mouth; does not assert a surveyed thalweg. | Defines distance along a derived geometric channel middle; requires an explicit channel definition and a selected base realization. |
| XS 268 | Preserves established stations but does not make spacing uniform on the polygon centerline. | May make initial spacing more uniform on that centerline; does not prove hydraulic adequacy or remove bend crowding. |
| Temporal interpretation | Comparison events calibrate to one declared base; a new base creates another frame. | Must also calibrate to a frozen base. Replacing the centerline each event would mix coordinate change with observed change. |
| Reproducibility | Requires exact network/path, smoothing, Reach division, mouth, offsets and calibration evidence. | Requires those topology/origin controls plus REM/channel thresholds, polygon pruning, component selection, skeleton routing, densification and smoothing versions. |
| Stability | Event/flow-dependent low-flow-path lengths can introduce coordinate noise; calibration attempts to reconcile it. | Expected to reduce low-flow-scale noise and calibration anomalies by referencing bankfull form. This benefit and boundary/threshold/pruning sensitivity remain unmeasured. |
| Network continuity | Current connected-study implementation propagates parent confluence offsets; FGDB acceptance still requires governed QA. | Reach-local centerlines do not automatically join at shared endpoints or tributaries. Gaps, alternate skeleton branches and confluence correspondences require explicit review. |
| Historical comparability | Can preserve validated historical stationing and report axes. | Can coexist with original historical frames. Correspondence is required only for analyses needing a common position; equal numeric stations cannot establish matching places or identities. |

The hydraulic distinction matters: USACE describes section orientation relative
to anticipated flow and channel/overbank paths, while treating river-station
labels separately from physical inter-section reach lengths. A polygon middle
is not thereby validated as a center-of-mass flow path. This is an inference for
FG Studio from the
[HEC-RAS Cross Section Geometry reference](https://www.hec.usace.army.mil/confluence/rasdocs/ras1dtechref/6.3/basic-data-requirements/geometric-data/cross-section-geometry)
and [Cross Section Data manual](https://www.hec.usace.army.mil/confluence/rasdocs/rasum/6.4/entering-and-editing-geometric-data/cross-section-data),
accessed 2026-11-19; it is not hydraulic validation of method v11. FG station
fields retain their established distance meaning even though HEC-RAS permits
arbitrary ordered station labels.

Changing a distance denominator can change slope, length-normalized summaries
and sampling weights. Moving the sampled path can also change sampled terrain
elevation and an REM. Keeping old section geometry and attaching an alternative
coordinate is therefore a different scientific operation from laying out new
sections or deriving a new elevation profile. These effects must be isolated
before attributing improvement to the reference choice.

## Historical effort and what FGDB already requires

The table below estimates additional work **if historical reference conversion
is selected**, not a prerequisite for adopting centerlines in newer projects.
Native-frame coexistence requires evidence binding/validation and the additive
schema/tooling work, not this conversion for every project. Positioning existing
sections in a selected common frame may also avoid reconstructing each event's
historical bankfull polygon, as described above.

[Accepted ADR-0017](../../../FGDB/dev/decisions/adr-0017-network-automation-and-legacy-reconstruction.md)
separates extraction, reviewed reconstruction and loading. Retained networks may
be imported; surviving Flowlines may support an explicitly labeled reconstructed
observation without re-smoothing; qualified legacy loading can retain missing
network status. The
[longitudinal contract](../../../FGDB/dev/schemas/longitudinal-reference-model.md#legacy-migration-states)
permits `VALIDATED_LEGACY`, `RECOMPUTED`, `UNVERIFIED` and `NOT_AVAILABLE`.
Consequently, FGDB work requires evidence and validation, not universal
terrain-to-report regeneration. The local Copperas sample is evidence against
assuming that every project must rebuild a missing network.

| Historical evidence cohort | Cost with Flowline retention | Additional cost for centerline migration |
|---|---|---|
| Network, Flowlines, measures and controls retained | Inventory, bind identities/frame, validate topology/units/calibration; preserve passing values. | Recover or derive versioned channel polygons/centerlines, establish correspondences, rebuild confluence measures and validate affected consumers. |
| Flowlines retained, original network missing | Review reconstruction only where needed; record reconstructed lineage and uncertainty. | Same reconstruction review plus centerline evidence recovery and calibration; retained Flowlines alone cannot recover historical channel boundaries. |
| Measures survive but origin/base/controls are incomplete | Retain source values as unverified until evidence suffices; selectively recompute only from accepted inputs. | Resolve the same evidence gaps plus the new frame; projecting to a new line does not validate the old values. |
| Adequate geometry/terrain absent | Qualified missing evidence may limit queries/publication. | Historical equivalence may be unrecoverable; modern terrain cannot silently stand in for an earlier event. |

Separate three work packages when estimating costs: FGDB metadata/topology
binding common to both choices; migration-only centerline and crosswalk work;
and optional/new scientific products. A coordinate-only conversion of fixed
features may need revised axes, associations and reports without rebuilding
DEMs. Moving sampling paths/sections requires new sampled elevations, affected
REM/geometry products and dependent metrics/reports, as demonstrated by their
actual dependencies. Unaffected source terrain need not be regenerated merely
because stationing changes.

No defensible person-day or portfolio total is available yet. Estimate separately
for native coexistence, selected common-frame comparisons and optional full
historical rederivation. Estimate by
cohort using project/event/Reach counts, missing-input frequency, timed analyst
exception review, computation, report regeneration and independent QA. Include
shared tool/adapter development and deployment/training costs separately.
Sample straightforward, bend-dominated, tributary and multi-event cases before
extrapolating; the local single-project scan cannot supply those rates.

## Compatibility and migration options

The original [ADR-0013](../../../FGDB/dev/decisions/adr-0013-project-longitudinal-reference-frame.md)
and [ADR-0014](../../../FGDB/dev/decisions/adr-0014-versioned-synthetic-network-and-base-event-calibration.md)
realized stationing with explicit base-event Flowlines. ADR-0027 extends the
accepted direction to bankfull centerlines for RAS-style sections. The current draft
longitudinal schema binds `reference_base_flowline` and `flowline_calibration`
to that model. Centerline referencing is therefore not a transparent parameter
change. It requires reviewed FGDB semantics and physical bindings. Owner direction
is that Flowline and bankfull centerline coexist as distinct geometries. The
typed alignment proposal above accommodates both without reclassifying Flowline.

1. **Continue current referencing:** validate and bind historical frames; retain current coordinate
   semantics and accepted geometry. Lowest demonstrated additional burden, but
   preserves XS 268's unequal centerline spacing and known reference limitations.
2. **Prospective coexistence and versioned qualification (selected direction):** preserve old frames and outputs; create a
   separately identified candidate centerline frame and additive correspondence
   records. Supports paired evaluation and reversible default selection, with
   added storage, UI/query and maintenance complexity. Qualify future bankfull
   referencing without requiring retrospective adoption. Implementation follows
   the authorized two-method implementation plan; historical conversion remains
   selective rather than an automatic side effect.
3. **Migrate after qualification:** publish a reviewed new frame and explicitly
   select it as the operational default for an agreed project/event scope.
   Recalibrate selected comparisons and regenerate only dependency-affected
   outputs. Keep reproducible access to valid prior analyses under an approved
   retention policy. A prospective-only adoption still needs legacy interoperability.

For options 2–3, a proposed crosswalk must identify both frame versions, Stream,
Reach, source/target geometry editions, feature or control identities, paired
measures and units, method/version, residuals, ambiguity and acceptance status.
Use controlled along-path correspondences with endpoint, confluence and interior
controls as needed. Nearest-point projection or a global length ratio cannot be
assumed valid in tight bends, cutoffs, branches or changed topology. Allow
unmapped/split/merged correspondences with explicit disposition. Validate
monotonicity, continuity and inverse error only where a one-to-one mapping is
scientifically defensible. A crosswalk does not create missing historical truth.

Preserve legacy layer names and field names/types/units/meaning, including
`from_measure`, `to_measure`, `POINT_M`, `POINT_M_uncalibrated`,
`calibration_diff` and `km_to_mouth` under their applicable entity/profile.
Do not write new centerline distances into old-frame values or reinterpret
within-section measures. `Seq`, station and map labels are not governed feature
identity. Alternative frames need explicit selection in queries and exports;
unqualified mixed-frame reports must fail validation. Draft cross-section
identity and enterprise physical bindings remain unresolved.

## Qualification evidence

The next session starts at the project plan and implementation plan, with FGDB's
contracts alongside the relevant source. Use this assessment for rationale and
qualification evidence. The adoption gate is resolved; optional XS shape
optimization remains parked.

Implementing the accepted direction requires the following planning and qualification:

1. Use the owner's established objective: isolate morphological change over time
   in response to infrastructure and landscape change, reducing low-flow-path
   coordinate noise while preserving real bankfull change. Define
   acceptable station displacement, calibration residuals and report effects
   before evaluating candidate results; do not invent tolerances after seeing them.
2. Inventory representative historical projects by the evidence cohorts above,
   including multi-event controls, source DEM/REM/polygon availability, network
   topology, report dependencies and retention obligations. Confirm the intended
   portfolio with the owner; do not infer completeness from this workstation.
3. Specify a read-only paired comparison using frozen saved geometries. Isolate
   coordinate reassignment from section/path resampling. Measure station drift,
   local spacing, length/slope effects, ambiguous mappings and confluence/Reach
   continuity across ordinary and tight bends, tributaries and eligible events.
   Record sensitivity to declared channel/pruning/route versions. Do not create
   synthetic base/comparison events in the single-event Spencer study.
4. Time representative coexistence binding and selected cross-frame calibration,
   exception review and affected downstream work. Price full historical
   rederivation separately as an optional scenario. Compare incremental costs
   with common FGDB work; identify irrecoverable cases and coverage limitations.
5. Reconcile the accepted two-method decision with FGDB ownership/version and
   compatibility rules, including exact schema/ADR amendments, producer contracts,
   role/identity behavior and query/export validation. No migration follows
   automatically from this document; do not reopen the adoption decision by default.

Adoption evidence should test the expected reduction in station displacement,
calibration distortion and analyst exceptions across eligible events, without
suppressing true bankfull change. Reliable network correspondence, reproducible
bankfull delineation and affordable coexistence/common-frame comparison are the
relevant gates. Universal historical rederivation is not an adoption condition.
