# Cross-section layout exploration

Status: owner-authorized exploration; geometry and UI are not yet implemented.

## Intended workflow

Use reviewed Flowlines, Flowline Points and terrain from the selected Survey
Event. The analyst identifies a channel by interactively flooding an REM, then
adjusts a flood-prone elevation initially estimated as twice the selected
channel depth. The initial estimate doubles depth above the REM reference, not
the numeric REM elevation: the existing `fluvgeo::detrend()` adds 100. Record
the reference and vertical units. The two elevations are adjustable, and the
resulting polygons and flow paths must be visible for review.

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

## Evidence and next work

- `fluvgeo::water_surface_poly()` selects inundated components intersecting
  the flowline, then simplifies by one coordinate unit. Check narrow-corridor
  effects and nested polygon topology before relying on its boundaries.
- The saved Spencer study has Flowline and Flowline Points candidates and
  Hydro DEMs; no saved REM was found in its local study directory. Evaluate
  generating an REM from those inputs and its unit/extent requirements.
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
