# Study Area analysis CRS

Implemented in fgstudio 9036 / fluvgeo 9044. Analysis setup requires a saved
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

In 9036 both editor-local errors and revision-bound save confirmations appear
beside Check/Save. Reopening displays the saved identifier/WKT in authoritative
definition mode. Create/Open retain the opaque study key in the tab URL; reload
reads its latest saved revision with both references. No key means a fresh empty
session; New clears it. Unsaved edits/checks/previews are not restored. See
test-study-reload.R and the paired lifecycle article for the session boundary.

The 9034 refinement treats NULL hidden acquisition inputs as uninitialized, using
saved Collection selections and not marking saved DEM selections as changed.
Explicit empty selections still count as edits. The integrated reopen/save test
persists EPSG:6344 without visiting Survey Collections, retains their selections,
and verifies the original context hash. Units/search and filters use horizontal
rows; Check/Save are adjacent; secondary details and sources use disclosures.

Saved DEM attempts remain discoverable across metadata-only revisions when the
current Stream geometry, Collection evidence and latest saved selection still
match. Their original context revision remains provenance. No files are moved or
downloaded as a side effect of CRS selection.

Vertical target/epoch specification is implemented alongside this tab and precedes
Event membership, output cell size and shared grid anchor; see vertical-reference-design.md.
No masks, resampling or mosaic execution is exposed yet. Future processing must
require a valid saved CRS and the explicit Event cell size before execution.

Source: R/study_analysis_crs.R, R/mod_study.R, R/study_store.R; backend:
fluvgeo/R/study_analysis_crs.R. Tests: test-study-analysis-crs.R and
test-stream-dem-files.R; backend test_study_analysis_crs.R. Developer article 08
and the agent route are maintained together.

## Current save/reload verification (9036, 2026-09-20)

Full app suite: 756 assertions pass, including fresh-session reload with both
references and visible validation/save feedback. Backend-isolation checks pass.
Nine articles/site and code-map checks pass; the app package check has no errors
and the existing Survey Collections non-ASCII warning. See the
[documentation review](../governance/documentation-review-2026-09-20.md) for exact
scope, persistence findings and browser-verification limits. Earlier results below
are historical increments, not outstanding verification requests.

## Verification (2026-09-19)

- Backend: 21 new CRS assertions plus 106 context/reference regression assertions
  pass. One existing report test is skipped because optional gt is unavailable.
- App: full suite produced 688 passing assertions and one outdated download-error
  expectation after the added CRS revision. Corrected that expectation; all 39
  focused download assertions then passed. The 15 new CRS store/editor assertions
  passed in the full run. No runtime code changed after that run.
- All eight developer articles and the local pkgdown site rebuilt. Code map:
  65 nodes, 79 static edges, 18 reviewed bridges; freshness/anchor/lookup checks pass.
- Logs are retained locally under dev/check-output/crs-*. Existing R 4.6.1 package
  build warnings on the R 4.6.0 workstation are unchanged.
- Package builds/checks complete with no errors: app's existing non-ASCII warning;
  backend's existing non-ASCII warning and methods/global-binding notes. App tests
  ran separately; backend check excludes unsafe legacy tests/examples. Missing
  optional fluvgeodata/gt remain recorded limitations. No production install.

## Guided picker verification (2026-09-20)

The full app suite passes 702 assertions, including 28 CRS store/editor/picker
assertions. Backend-function isolation checks pass. Known workstation package
build-version warnings remain. A final catalog correction retains WGS84 datum
ensemble projections; all 39 focused backend assertions and 28 focused app
assertions pass against the final code and isolated installation. All eight
developer articles and the local site rebuilt. The map has 65 nodes, 80 static
edges and 18 reviewed bridges; freshness, anchor and lookup checks pass.
Detailed logs are under dev/check-output/picker-*.

Both package builds/checks finish without errors. App: one existing non-ASCII
warning. Backend: one existing non-ASCII warning and two existing dependency/
global-binding notes. App tests ran separately; backend package checking excludes
unsafe legacy tests/examples, with the focused CRS tests providing verification.

Fresh 9033 preview: HTTP 200 with picker and advanced controls present. Existing
browser tabs timed out during debugger synchronization; visual QA remains for
analyst review. Saved studies and source files were not edited by verification.

## Form and pending-state refinement (9034, 2026-09-20)

Full suite: 715 assertions pass; backend-function isolation checks pass. This
includes the EPSG:6344 integrated regression, hidden/uninitialized selections,
explicit deselection guards and saving without manual identity/rationale fields.
Known workstation R package build-version warnings remain. Backend code and its
isolated installation are unchanged (9043). Vertical/epoch specification is a
documented next-step contract, not a new transformation capability.

All eight developer articles/site and code-map checks pass (65 nodes, 80 static
edges, 18 bridges). Fresh 9034 preview responds HTTP 200 with compact filters,
background disclosure and neither removed record field. Browser automation still
times out attaching to the webview, so visual browser acceptance is not claimed.
Logs: dev/check-output/crs-refinement-*.

9034 source build and package check finish with no errors and the existing
non-ASCII warning in mod_survey_collections.R. Vignettes are included and rebuild
successfully; the full tests ran separately. No backend package change was needed.
