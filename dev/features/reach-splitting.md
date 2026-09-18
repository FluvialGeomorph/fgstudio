# Split an existing Reach (9021 / fluvgeo 9032)

Owner approved ADR 0005 and requested the concrete Reaches action sequence:
**Add new**, **Split existing**, **Combine existing**. Add new's name input now
precedes guidance and the scrollable segment list. When all segments are already
assigned, creating another Reach requires Split existing, not assigning a segment
twice. Rename and Combine remain separate supported actions.

## Analyst workflow

1. Reaches -> parent Stream -> Split existing -> choose the saved Reach.
2. Enter the new Reach name. Choose whether the existing identity stays on the
   downstream (default) or upstream portion.
3. Click on/near that Reach's blue line. Local sf/GEOS projection snaps within
   200 m; no NLDI request is needed. Review the black cut point, gold downstream
   and teal upstream portions, their lengths and inherited buffer width.
4. Save split. The same Stream now contains two named Reaches. Previous revisions
   remain intact. A later split or combination uses the retained piece records.

Changing Reach/parent clears the cut. Changing retained side invalidates preview;
Preview split recomputes it. Saving recomputes from the current context. Pending
cuts guard task/mode/name changes; stale revisions fail closed. An inactive editor
cannot save after another revision has replaced it. No user study is automatically
split or renamed during testing.

## Boundaries

This is post-assembly Reach splitting, not yet pre-assembly or Stream cutting.
Requires a connected, unbranched, directed and non-self-crossing channel. Ambiguous
branches, disconnected parts, endpoints and distant clicks produce guidance, not
guessed geometry. Survey Events on the selected Reach and linked terrain/network
records require separate reconciliation; none are duplicated or arbitrarily moved.

The backend uses sf projection/interpolation and lwgeom substring in the saved
metric Stream CRS; Leaflet's Web Mercator display is never the processing frame.
Cut positions within 1 cm of a piece endpoint use that existing junction, avoiding
numerical remnants; this is not a scientific minimum Reach length. Both portions
are rebuffered at the inherited width and clipped to the Stream. Adjacent buffers
may overlap. Source intervals and list positions are not stationing.

## Persistence and compatibility

See [piece evidence schema](../../../fluvgeo/dev/schemas/reach-pieces.md).
Original COMID and local selection/piece identity are separate fields. The first
split publishes one Stream-wide piece inventory, assignment state and Reach-area
snapshot. Subsequent Add/Combine/Split writes a new snapshot with a hash-linked
prior-evidence reference. Old contexts and original evidence are untouched.
Piece editing requires fluvgeo >=9032; do not use an older segment editor on a
piece-enabled context. Generic current context geometry remains readable; no
production ArcGIS, QGIS, ohwm2 or Enterprise deployment is performed.

Backend tests cover repeated split/add/combine, interval/identity preservation,
length conservation, containment, inherited feet, dependent-event refusal and
unchanged prior files. App tests cover mode labels, visible name placement,
map-click preview, retained-side invalidation and explicit save. These are not
a substitute for owner browser acceptance.

## Verification, 2026-09-17

FG Studio 9021 package check **OK**, 507 app assertions passed; existing sf/Shiny
build-version warnings remain (4.6.1-built packages on runtime 4.6.0). The full
runtime-isolation check also passed. All nine retained user Reaches passed
read-only midpoint split previews; before/after file hashes confirmed no study
changes. Both repository context validators passed. The computer-use visual
check could not proceed because desktop approval timed out. The owner subsequently
reported that split functionality works great; this is direct user acceptance,
not automated browser verification. Full fluvgeo
package checks were not rerun; focused backend suites cover this increment.
