# Cross-section layout exploration

Status: owner-authorized implementation in progress. A session-only
inundation-review tab has been reviewed by the owner; cross-section layout, editing and
persistence are not yet implemented.

## Intended workflow

Use reviewed Flowlines, Flowline Points and terrain from the selected Survey
Event. The analyst identifies a channel by interactively flooding an REM, then
adjusts a flood-prone elevation initially estimated as twice the selected
channel depth. The initial estimate doubles depth above the REM reference, not
the numeric REM elevation: the existing `fluvgeo::detrend()` adds 100. The
channel elevation must always be strictly less than the floodplain elevation;
enforce this at the UI and computation boundaries. `ohwm2` initializes its
channel slider at 103 with an REM baseline of 100 and a 0.1 step, then clamps
the value to the selected cross section's observed range. This is an initial
3 ft depth in its existing feet-based workflow, not a terrain-derived estimate.
Record the reference and vertical units. The two elevations are adjustable, and the
resulting polygons and flow paths must be visible for review.
For layout, ignore interior holes in the channel and flood-prone polygons so
the outer extents govern coverage; preserve the original inundation evidence.
Do not join disconnected components merely to fill holes.

Use `ohwm2`'s interactive flooding as the interaction reference: separate
channel and floodplain sliders update map overlays via throttled values, cache
polygons by elevation, and debounce slower analytics. FG Studio must use its
own background-worker, stale-result and file-backed raster conventions for
large study data. Keep both elevations valid throughout interaction; use a
3 ft initial channel depth for this feet-based workflow and initialize the
floodplain depth to twice that value, while allowing analyst adjustment.
`fluvgeo::water_surface_extents()` provides unsimplified paired original and
hole-filled footprints and enforces elevation order. `cross_section_review.R`
uses it in background jobs with saved Reach Flowline, Flowline Points and Hydro
DEM inputs; the current temporary REM uses the existing detrend function and
a 150 m buffer. It does not generate or save cross sections. Slider changes
are debounced, and stale workers are cancelled; scalable caching, persistence,
extent selection and end-to-end validation remain open. A whole-app Spencer R1
preview confirmed the default map, recomputation after changing the channel
slider, and rejection of channel elevations at or above the floodplain level.
The owner found the current performance acceptable for further prototyping;
initial full-Reach REM preparation is still noticeable and broader performance
has not been qualified. The current 150 m buffer can truncate
floodplain evidence and is disclosed in the review. It must not be treated as
an adequate universal analysis extent.

The analyst supplies longitudinal cross-section spacing. A candidate section
has four vertices in left-to-right downstream order: left outer endpoint, left
bank, right bank, right outer endpoint. Channel orientation is estimated from
the channel and directed flowline; investigate a bounded shortest channel
crossing rather than assuming raw flowline normals are robust. Estimate each
overbank's flow path using its own flood-prone corridor centerline. Smooth and
bridge paths through thin or absent side polygons using neighboring evidence;
show inferred gaps and unresolved cases. Perpendicular overbank legs use those
estimated directions. Avoid touching or crossing other sections, but report
when satisfying that condition leaves inadequate coverage. The output is an
editable candidate, not a guarantee of hydraulic-model compliance.

### Layout and flow direction requirements

- Generate positions from the directed, measured Flowline and the analyst's
  longitudinal spacing. Measures increase upstream from the appropriate outlet;
  clarify placement origin, endpoints, Reach boundaries and measure units in
  the implementation. Forced locations at junctions, structures or slope breaks
  are a possible later extension, not a prerequisite for the current MVP.
- For downstream tangent `(dx, dy)`, left and right normals are `(-dy, dx)`
  and `(dy, -dx)`. A left-to-right candidate should satisfy the downstream
  cross-product orientation check. Handle degenerate tangents explicitly.
- For the middle segment, the owner proposed a line through the sample point
  adjusted near perpendicular to minimize the channel crossing distance.
  Its exact search bounds, polygon-crossing selection and tie-breaking are
  open design work. Simple raw Flowline perpendiculars can be noisy; smoothing
  trades noise reduction against loss of real bends. Avoid claiming an
  unvalidated angle is the primary flow direction.
- Derive left and right overbank flow-path estimates separately from the
  respective flood-prone side geometry, using its centerline as the proposed
  direction proxy. Very thin or absent side polygons are common: estimate a
  smooth path through those locations from surrounding evidence, flag inferred
  portions, and define behavior when evidence is unavailable. A polygon is not
  itself a hydraulic flow model. The actual straight leg is perpendicular to
  the estimated local side path and extends toward the relevant outer extent.
- Candidate cut lines must neither intersect nor touch other cut lines. Detect
  all pairs, including nonadjacent lines. Resolve conflicts without silently
  sacrificing floodplain representation; quantify altered coverage and return
  an actionable unresolved result where constraints cannot all be satisfied.
  Trimming or spatial partitioning were candidate approaches, not approved
  algorithms. Never assume the existing experimental shortener is acceptable.
- Number for review downstream to upstream and provide resequencing after
  additions, deletions or changes. `Seq` is a mutable legacy order, not durable
  identity. Preserve an old-to-new mapping where downstream references need it;
  exact stable identity and FGDB publication binding remain unresolved.

The project deliberately targets four vertices for its MVP. Official HEC-RAS
guidance describes most cut lines as having at least four points and needing to
be perpendicular to anticipated channel and overbank flow; additional vertices
and other model inputs may be required. The owner accepts initial candidates
that may require manual editing. See [HEC-RAS Mapper cross sections](https://www.hec.usace.army.mil/confluence/rasdocs/rmum/6.4/geometry-data/cross-sections)
and [HEC-RAS cross-section geometry](https://www.hec.usace.army.mil/confluence/rasdocs/ras1dtechref/6.3/basic-data-requirements/geometric-data/cross-section-geometry).

## Evidence and next work

- `fluvgeo::water_surface_poly()` selects inundated components intersecting
  the flowline, then simplifies by one coordinate unit. On a 500 m Spencer R1
  diagnostic using 3/6 ft depths, independent simplification left 43.23 m²
  of channel outside the flood-prone polygon; the unsimplified extents had zero
  outside area. Check narrow-corridor effects and preserve nested topology
  before relying on its boundaries.
- The saved Spencer study has Flowline and Flowline Points candidates and
  Hydro DEMs; no saved REM was found in its local study directory. The bounded
  diagnostic `fgstudio/dev/scripts/explore-spencer-cross-section-inputs.R`
  generated an REM from those inputs using the existing detrend method. Its
  cross-valley slice-midpoint experiment found side evidence at 19 and 20 of
  22 sampled locations. Linear interpolation bridges internal missing points;
  neighboring estimated tangents support exploratory four-vertex candidates.
  These are not independently validated flow directions or production outputs.
  At 20 m sampling, 16 of 20 requested candidates were constructed, all 16
  passed the directional check, and one pair intersected. An experimental
  symmetric leg-shortening loop eliminated the collision but shortened four
  legs, one to 22.9% of its original length. Non-intersection alone is therefore
  insufficient evidence of useful floodplain coverage. Four missing candidates,
  boundary truncation, local channel orientation, and interpolation require
  further investigation. The inundation-review app now exists; no production
  cross-section solver exists.
  The 2/4 ft and 3/6 ft levels and the bounded window are diagnostic choices,
  not defaults. With 2/4 ft and holes filled, 17 of 20 candidates were
  constructed; three intersecting pairs were cleared by the experimental
  shortener, leaving at least 81% of each shortened leg. Retaining holes at
  the same levels produced 17 candidates and four intersecting pairs; the
  shortest retained fraction was 34.9%. At 3/6 ft with holes filled only 10
  candidates were constructed, and the shortest retained fraction was 22.9%.
  These observations concern one bounded window and depend on the provisional
  algorithm; they do not establish hydraulic accuracy or a universal depth.
  The owner observed that the resulting geometry is highly accurate relative
  to hand-drawn HEC-RAS sections. The numbered review keeps sampling numbers
  when a candidate fails: sections 1–3 are absent because the experimental
  left overbank endpoint could not be determined. Numbers increase upstream
  and are diagnostic labels, not persistent identity.
  The owner requested a 1.5 ft channel depth and more downstream context. The
  1.5/3 ft run produced 17 of 20 candidates, with three initial collisions;
  six legs were shortened and the least retained 72.9%. The existing 500 m
  window begins at the saved Study outlet (R1 measure zero), so the saved
  flowline itself contains no earlier downstream segment. A nearby retained
  source line ends about 17 m from that outlet; this does not establish a usable
  downstream continuation. The owner confirmed there is no opportunity to
  obtain additional downstream data for this example. Independently make path
  estimation handle missing corridor support and flag inferred directions and
  truncated coverage; do not silently fabricate a continuation.
  In R1 sections 9–11 the original three collisions are all right-overbank to
  right-overbank; the experimental resolver nevertheless shortens both sides
  of all three sections by 27.1%. The right-path sample shifts abruptly near
  section 9, and tangents from neighboring midpoints drive leg angles. The
  owner rejected these results; replace this conflict and angle behavior before
  presenting it as a candidate solution. A second exploratory site at the
  mouth of R3 includes 200 m of actual R2 downstream context and uses the same
  1.5/3 ft assumptions. It produced six of 21 candidates: thin or missing side
  support and endpoint failures require diagnosis; no intersections occurred
  among those six. The owner subsequently indicated an R3 channel depth near
  3 ft and floodplain depth around 6–10 ft are more suitable starting values;
  these are review guidance, not a universal rule. The owner also clarified that
  R1 is at the Mississippi confluence, where the 103 ft REM default is more
  appropriate than the earlier 101.5–102 ft trials. Interactive selection is
  required because values differ by Reach.
- A Copperas Creek legacy `xs_100_100` layer contains 34 sections, endpoint
  coordinates, `Seq`, `ReachName`, watershed area, `POINT_X`, `POINT_Y`,
  `POINT_M`, `Z`, `km_to_mouth`, measures, `loop`, and `bend`. Its processed
  kilometer `POINT_M` equals `km_to_mouth`. This is not evidence that every
  field is present immediately after layout. Inspect source types and other
  versions before defining the replacement profile.
- Before production output, extend the FGDB compatibility profile, preserving
  established names, field types, units, geometry and semantics. Retain a
  stable identity separately from mutable `Seq`; do not invent an FGDB binding.
- Validate the actual Spencer candidate visually, including bends, corridor
  pinch-outs, polygon gaps, and collision resolution. Exercise downstream
  cross-section processing and GeoPackage round trips. Update the app's
  function/data mappings and refresh the whole-app preview when implemented.

The corridor centerline is an estimate, not a measured flow direction. Establish
its algorithm, gap policy, smoothing scale, diagnostics and deterministic
tie-breaking from experiments before asserting scientific suitability. Avoid
promoting provisional app storage into the FGDB specification.
