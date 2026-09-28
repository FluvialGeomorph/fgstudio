# Study Area analysis CRS

 Analysis setup requires a saved
Study Area polygon and a projected 2D EPSG/WKT definition. Validation/catalog
evidence is recorded automatically, without personal identity or a Why field.
Check CRS resolves WKT/name/units with sf and tests
complete boundary transformation without ballpark operations. It does not certify
distortion or perform raster/vertical transformations.

The default searchable EPSG picker reads the installed PROJ catalog through sf,
screens the Study Area bounds, and displays datum/frame, units, projection, scope
and coverage. Full-bound engineering/topographic and UTM systems appear first;
explicit filters admit partial coverage and other mapping purposes. No default
CRS is chosen. SpatialReference.org links open the area explorer or selected
definition. Advanced EPSG/WKT entry remains available. Epoch-dependent frames
are exploration-only until coordinate-epoch processing is qualified; backend
validation also enforces this restriction. Picker saves record catalog version,
PROJ version, coverage and reference link alongside the validation result.

Save uses the existing immutable context revision mechanism and stores canonical
WKT in the horizontal analysis_reference component with PROJECT_RECORD basis.
Source geometry, originals, other reference components and old revisions persist.
Plain descriptive legacy notes are not treated as validated CRS definitions.
Reads revalidate the saved definition against the current boundary. Stale checked
definitions, changed study revisions and pending geometry/acquisition edits block
saving. The backend blocks changes when terrain_processing records exist; future
product persistence must maintain that dependency guard.

Both editor-local errors and revision-bound save confirmations appear
beside Check/Save. Reopening displays the saved identifier/WKT in authoritative
definition mode. Create/Open retain the opaque study key in the tab URL; reload
reads its latest saved revision with both references. No key means a fresh empty
session; New clears it. Unsaved edits/checks/previews are not restored. See
test-study-reload.R and the paired lifecycle article for the session boundary.

Hidden uninitialized acquisition controls use saved selections; an explicit empty
selection is an edit. Check/Save controls show revision-bound feedback.

Saved DEM attempts remain discoverable across metadata-only revisions when the
current Stream geometry, Collection evidence and latest saved selection still
match. Their original context revision remains provenance. No files are moved or
downloaded as a side effect of CRS selection.

Vertical target/epoch specification is implemented alongside this tab and precedes
Event membership, output cell size and shared grid anchor; see vertical-reference-design.md.
Automatic masks and aligned-grid Stream DEM processing use these references and
require a valid saved CRS and the explicit Event cell size before execution.

Source: R/study_analysis_crs.R, R/mod_study.R, R/study_store.R; backend:
fluvgeo/R/study_analysis_crs.R. Tests: test-study-analysis-crs.R and
test-stream-dem-files.R; backend test_study_analysis_crs.R. Developer article 08
and the agent route are maintained together.
