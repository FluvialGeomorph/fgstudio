# Flowline Points capability qualification and FG Studio integration

- Status: current/base-event creation implemented and verified; comparison-event calibration deferred
- Updated: 2026-10-06
- Workflow position: after saved Flowline and before Features, REM, and Cross
  Sections
- Legacy producer: `FluvialGeomorph-toolbox/tools/_06_FlowlinePoints.py`
- Governing compatibility profile:
  `FGDB/dev/schemas/legacy-derived-feature-compatibility.md`

## Outcome

Qualify and adapt the existing `fluvgeo::flowline_points()` capability for the
complete FG workflow, then integrate it with every exact saved FG Studio
Flowline revision and Hydro DEM in the selected Survey Event. Points follow
each Flowline upstream from one Study Area outlet, carry a shared kilometer
station across connected Streams and ordered Reaches, and sample terrain
elevation. The app saves and reopens the Study-wide result with enough input,
parameter, topology, unit, and method evidence to detect stale candidates.

This continues the refactoring pattern already proven by `ohwm2`. To deploy the
Shiny workflow quickly and dogfood the existing `fluvgeo` analyses, `ohwm2`
asked the user to digitize a Flowline manually. It then drove development and use
of `fluvgeo::flowline_points()` and its downstream analysis chain. FG Studio has
now closed that upstream gap by deriving and saving the Flowline automatically.
The remaining question is not whether Flowline Points can be created; it is
whether the existing implementation satisfies the legacy output contract and
every downstream function that consumes it.

The increment begins with the current/base-event case demonstrated by Spencer
Creek. It does not fabricate comparison-event calibration when the local study
contains only one event setting and no governed Reach-owned Survey Events.

## Why this is the next step

The User Manual places **Create Flowline Points** immediately after **Create
Flowline**. Flowline Points supply the terrain-sampled longitudinal profile and
stationing consumed by Features, cross sections, slope/sinuosity calculations,
and Level 1 reporting. The completed Flowline store already provides the exact
saved Reach lines and Hydro DEM revision required by this operation.

The existing `fluvgeo::flowline_points()` samples one arbitrary line and is used
by `ohwm2`. The current `fluvgeo::reach_flowline_points()` wrapper extends that
capability to continuous kilometer stationing across ordered saved Reaches
without changing the existing API default. The next work begins with a gap audit
covering the legacy producer and all downstream consumers, then makes only the
adaptations demonstrated to be necessary for the shared contract, persistence,
application review, and calibration workflow.

## Capability-gap review result

The implementation traced and tested the actual contracts used by:

- `ohwm2` and its current arbitrary, manually drawn Flowline workflow;
- `fluvgeo::detrend()` and REM creation;
- `fluvgeo::cross_section()` and `cross_section_points()`;
- slope, sinuosity, gradient, and Level 1 dimension calculations;
- longitudinal profile comparison and both Level 1 report variants;
- Features and other consumers of `km_to_mouth` or `POINT_M`; and
- the legacy Flowline Points producer, User Manual, Technical Manual data
  dictionary, retained FileGDB examples, and FGDB reference-frame contracts.

The audit found two intentional measure profiles. Existing `ohwm2` calls
`flowline_points()` with an unlabeled `POINT_M` in metres; that default remains
unchanged. Legacy ArcPy outputs and the report/profile consumers use kilometer
`POINT_M`. FG Studio therefore calls the ordered-Reach wrapper, which explicitly
creates the kilometer profile and declares its units. `cross_section()` now
honors an explicit `POINT_M_units` value while retaining metres when the field is
absent, so both paths remain compatible. `detrend()` is unit-neutral for this
purpose because it uses the point coordinates and elevations.

The legacy producer always created `POINT_M_uncalibrated` and
`calibration_diff`, including for an uncalibrated run. Those fields were the
material backend gap. They are now present and checked along with
`km_to_mouth`; no legacy field was renamed or removed. Shared Reach endpoints
remain duplicated by ownership with the same measure. Validation tolerates only
machine-precision roundoff at that equality, not a meaningful reversal.

## Legacy procedure and streamlined replacement

| Historical analyst action | Replacement behavior |
| --- | --- |
| Browse to a feature dataset, Flowline, and `dem_hydro`. | Use the selected saved Flowline candidate and its fingerprinted Hydro DEM automatically. |
| Enter `km_to_mouth` manually for every Stream/Reach. | Identify the one outlet Stream from Stream corridors, assign it zero, and derive each tributary offset from its confluence on the downstream Flowline. Do not expose a routine offset field. |
| Enter station distance in feature-class units. | Default FG Studio to `1 m`, record the physical unit explicitly, and show one optional advanced override; never reinterpret map units silently. |
| Run the newest survey first. | For the first local slice, create uncalibrated current/base-event points. In the multi-event workflow, suggest the latest eligible validated event as the base but store the explicit resolved event and Flowline identities. |
| Browse to calibration points and choose `ReachName`, `POINT_M`, and a search radius for each older survey. | Resolve the selected base-event points, identities, measure field, and tolerance from saved context. Ask only for the scientifically meaningful base/comparison selection; fail on ambiguous correspondence. |
| Manually ensure endpoints are snapped or receive an empty result. | Validate adjacent Reach endpoints, coverage, order, direction, CRS, and DEM extent before calculation and return an actionable error. |
| Inspect a newly added feature class. | Review points over the Flowline/Hydro DEM and a longitudinal elevation profile, then save one immutable candidate. |

## Required output contract

The portable layer name remains `flowline_points`. The baseline output retains
the exact historical fields:

- `ReachName`
- `POINT_X`
- `POINT_Y`
- `POINT_M`
- `POINT_M_uncalibrated`
- `calibration_diff`
- `Z`

The replacement also retains the established downstream-consumer field
`km_to_mouth`. `POINT_M`, `POINT_M_uncalibrated`, `calibration_diff`, and
`km_to_mouth` use kilometers in the FG Studio replacement profile. For an
uncalibrated base result, `POINT_M_uncalibrated` equals `POINT_M`,
`calibration_diff` is zero, and `km_to_mouth` equals `POINT_M`; these are the
same computations performed by the legacy producer, not placeholder values.

Additive fields may carry immutable Reach identity and order, explicit units,
point sequence, station interval, origin, input revision, method, and software
provenance. They do not replace the legacy fields. Existing `ohwm2` callers keep
the historical `fluvgeo::flowline_points()` metre profile unless they request
the replacement profile explicitly.

## Implemented current/base-event integration

The **Flowline Points** tab now opens the exact saved Reach Flowline revisions
and bound Hydro DEMs for every Stream in the Survey Event, defaults to one-metre
maximum spacing, and exposes spacing only as an advanced override. Stream tabs
change only the detailed map review; the graph and saved candidate always
include the entire Study Area network. Creation validates topology, direction,
CRS, coverage, finite elevations, legacy fields, units and continuous shared
stationing. Long work uses the standard progress cue.

`fluvgeo::study_area_flowline_points()` uses prior Stream Definition as the
topology authority. A Stream whose downstream endpoint lies in another Stream's
corridor is a tributary of that Stream; the sole endpoint that lies in no other
corridor is the Study outlet. The tributary endpoint is projected onto the
saved parent Flowline, and its `km_to_mouth` begins at that confluence measure.
Ambiguous parents, more or fewer than one outlet, cycles, and connection gaps
larger than two cell diagonals of the coarser participating Hydro DEM fail
closed. The connection layer records the chosen parent, confluence measure,
projection distance, tolerance, and outlet status.

Saving writes an immutable Study-scoped candidate directory containing
`flowline-points.gpkg`, `result.rds`, and `provenance.json`. Study-scoped storage
avoids Windows path-length failure from the already deep Hydro/network/Flowline
lineage; the input record still fingerprints the exact Study, Event, every
Hydro output and every Flowline GeoPackage and rejects stale reopening. The
GeoPackage retains the exact portable `flowline_points` layer and adds
`stream_connections` as topology/provenance evidence.

Real-data topology acceptance on the saved Spencer 2019-12 event produced:

| Stream | Reaches | Points at 1 m | Start measure | End measure | Connection gap |
| --- | ---: | ---: | ---: | ---: | ---: |
| Spencer Creek mainstem | 5 | 34,517 | 0.000 km | 20.935 km | outlet |
| east unnamed trib | 3 | 14,360 | 1.523 km | 10.111 km | 0.166 m |
| west unnamed trib | 3 | 11,870 | 7.726 km | 14.809 km | 1.910 m |

All 60,747 points are now one candidate and can be plotted together without
manually entering offsets. Generation took 13.72 seconds on the development
workstation. The two tributary connection gaps pass the 2.828 m limit for the
one-meter Spencer Hydro DEMs.

## Station interval

FG Studio uses a **1-meter default maximum spacing**. This replaces the User
Manual's routine one-foot entry with one clear physical-unit default suitable
for the new workflow. Retain existing Flowline vertices, record
`station_distance_m = 1`, and allow an optional advanced override when a study
requires it. Do not change `fluvgeo::flowline_points()` defaults or reinterpret
the units supplied by existing callers.

The Spencer verification confirms the chosen density and legacy profile on all
three Streams. The advanced override remains available for a study-specific
need; changing it does not calculate until the user creates a new candidate.

## Later slice: comparison-event calibration

Multi-event calibration belongs to this feature family but is not required to
prove the single-event Spencer result. When eligible Reach-owned Survey Events
exist, the user initiates creation of a longitudinal reference frame, reviews
the proposed base event, and selects comparison events. Loading a newer event
must not recalibrate existing data automatically.

The backend uses stable Reach and Flowline relationships rather than free-text
`ReachName` matching, establishes point-to-route correspondence within a
documented tolerance, preserves uncalibrated measures, calculates calibrated
`POINT_M` and `calibration_diff`, and reports residual/coverage evidence. A
missing, duplicated, out-of-order, or ambiguous match fails closed. The analyst
reviews staged profiles before a frame becomes accepted or operational; FG
Studio does not invent governed frame IDs for a local candidate.

## Integrity and acceptance checks

- exact layer/field names, numeric types, units, and null behavior;
- one point sequence per applicable Reach with stable identity and order;
- finite coordinates, measures, and DEM elevations;
- `POINT_X` and `POINT_Y` equal point geometry within precision tolerance;
- exactly one Study outlet at zero and nonnegative measures increasing upstream
  within each Stream;
- one unambiguous downstream parent per tributary, an acyclic connected graph,
  and raster-resolution-aware confluence connection tolerance;
- each tributary's minimum `km_to_mouth` equal to its parent-Flowline
  confluence measure;
- equal measure at the duplicated shared endpoint owned by adjacent Reaches;
- continuous Reach `from_measure`/`to_measure` agreement;
- exact uncalibrated field relationships for the base case;
- calibration coverage and residual checks for comparison events;
- immutable save/reopen and stale-input rejection; and
- unchanged behavior for existing arbitrary Flowline/`ohwm2` callers.

Use all three Spencer Streams for real-data acceptance. Small fixtures cover
failure modes but do not replace review of map alignment and longitudinal
profiles against the actual Hydro DEM.

## Deferred

- acceptance or publication of an FGDB longitudinal reference frame;
- comparison-event calibration until multiple governed events are available;
- manual point editing;
- Features, REM, Cross Sections, or report integration; and
- desktop/QGIS cutover of the legacy tool.
