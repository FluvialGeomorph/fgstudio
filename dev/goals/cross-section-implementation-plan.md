# Implement the two cross-section methods

Status: implementation plan, 2026-11-19. The owner authorizes moving forward with
the accepted two-method direction. The present deliverable is the decision,
storage analysis and executable sequence below; code implementation is unfinished.
Start sessions at [project-plan.md](project-plan.md). The governing decision is
[FGDB ADR-0027](../../../FGDB/dev/decisions/adr-0027-two-cross-section-methods-and-reference-families.md).
The [reference analysis](xs-268-reference-analysis.md) retains scientific rationale
and inspected historical evidence; it is not a pending adoption gate.

## Outcome and boundaries

Produce RAS-style sections stationed on the bankfull channel centerline for new
work/rework. Preserve and support simple legacy sections stationed on Flowline,
including an open-source replacement of ArcPy layout. Both remain distinguishable
in saved outputs and eventual FGDB ingestion. Flowline still creates the REM.

Retain accepted v11 routing and v10 pruning; change their reference inputs and
necessary integration, not their geometric objectives or optional refinements.
Retain existing saved studies/drafts. No automatic archival relabeling, bulk rerun,
customer deployment or production ArcPy replacement follows from this plan.
RAS-style is not a hydraulic certification or a promise of HEC-RAS export.

## Source findings that determine the sequence

- `fluvgeo/R/cross_section_layout.R` currently samples `flowline` beginning at
  half-spacing and derives polygon-centerline direction separately. Passing a
  centerline in place of that argument everywhere would also change preparation,
  artifact matching and routing associations. Separate construction Flowline
  from reference geometry explicitly; do not perform a global argument rename.
- `fgstudio/R/cross_section_preparation.R` creates footprints/region assets
  before layout; `cross_section_store.R` binds schema 9 and
  `polygon-centerline-v11`. New reference semantics need a new method/schema
  fingerprint, while unchanged upstream DEM/REM assets remain reusable.
- `fluvgeo::cross_section()` takes already supplied transects, attaches nearest
  Flowline Point attributes and enriches downstream fields. It is not a port of
  `_11_XSLayout.py`, and a centerline-aware route-position operation must not
  inherit its implicit nearest-sampled-point behavior accidentally.
- `_11_XSLayout.py` splits a dissolved Flowline at requested distances or existing
  vertices, centers a transect at each split piece's along-line midpoint and
  derives perpendicular direction from that piece's endpoints. Width is one-side
  length in separately declared units. Its bearing construction uses ArcPy
  geodesic operations; exact open replacement equivalence is not established.
- The ArcPy layout stage emits only `ReachName`, short `Seq`, double endpoint
  coordinates and line geometry under `xs_<spacing>_<width>` naming. Later
  watershed/river-position/section-point stages add more fields. The manual's
  combined dictionary must not turn those into fictitious layout-stage outputs.
  Retained R15 data confirms later-stage products and a section-length versus
  dictionary-unit conflict; resolve that profile before claiming later-stage
  export compatibility.

Source paths below are repository-relative unless a sibling is named. These
findings describe inspected working-tree behavior, not approved new API names.

## Storage recommendation

Use one standard `cross_section` polyline feature class with a descriptive
`cross_section_type` field/domain exposed to clients, plus edition-level method
contracts and frame-qualified reference relationships. Prefer named codes
`RAS_STYLE` and `SIMPLE_LEGACY` over a generic free-text `type`. Exact spelling
and physical duplication remain proposed in the
[owning FGDB storage analysis](../../../FGDB/dev/schemas/cross-section-feature-contract.md#storage-alternatives-and-recommended-binding).

Do not create a feature class per algorithm version. Keep one authoritative
family per dataset role/edition; a feature-level copy must be enforced equal or
derived in a view. Reference family and method family must be independently
identifiable and their allowed pairings validated. Preserve unknown/transitional
source records without falsely assigning either conforming family.

## Delivery sequence and acceptance

Each implementation increment includes backend, necessary app/storage integration,
focused verification and maintained documentation. Routine integration does not
require separate owner handoffs. Genuine scientific ambiguities are recorded for
review while independent work continues.

### 0. Record the direction — completed in this planning task

ADR-0027 records the accepted pairings, Flowline retention, compatibility and
rework rules. FGDB owns the decision; FG Studio routes to it. Detailed storage
and algorithm choices below remain unfinished rather than being labeled accepted.

### 1. Bind the minimum data/reference contract

Owners: FGDB contract; fluvgeo constructors/validators; FG Studio local adapter.

- Finalize method-family domain, separate dataset roles, section identity and
  rework correspondence, edition/provenance requirements and unknown-evidence
  behavior. Preserve Survey Event/Reach ownership and source labels.
- Define bankfull centerline identity, edition-qualified polygon lineage, and
  which channel path is the longitudinal reference. LOB/ROB centerlines remain
  geometric support, not alternative stationing routes. Specify path orientation,
  Reach endpoints and disconnected/branch/gap dispositions.
- Extend base/reference/calibration bindings to either geometry family with
  enforceable foreign keys, retaining legacy Flowline bindings. Separate
  derivation inputs from `cross_section_position`-style frame-qualified positions.
- Define local physical centerline distance, calibrated kilometer distance to
  mouth, within-section distance and their exact fields. Keep existing legacy
  field names/units/meanings; no implicit meters/kilometers conversion.
- Resolve spacing policy before implementation: proposed default retains physical
  20 m sampling and half-spacing offset, now along the event's selected centerline,
  then calibrates positions to the chosen base. Uniform spacing on that event
  geometry is not uniform spacing in a calibrated comparison frame. Fixed-base
  repeat-transect sampling is a different operation and must not be implied.
- Reconcile the kernel, feature catalog, longitudinal/centerline/cross-section
  contracts, compatibility profiles and local draft binding together. Register
  scientific method/schema versions; do not wait for a complete enterprise loader.

Acceptance: explicit contract examples for both families in the same Event,
unknown legacy evidence, immutable reference editions and prohibited mixed-family
claims. A developer can trace every displayed station to its source frame/geometry.

### 2. Deliver centerline-referenced RAS-style layout in FG Studio

Owners: fluvgeo scientific operations; FG Studio orchestration and persistence.

- Reuse the saved Flowline/Flowline Points → DEM/REM → channel polygon preparation
  chain. Persist/select the exact resulting bankfull-reference centerline and its
  polygon/recipe evidence. Label the current threshold-based bankfull interpretation
  accurately; do not claim independent hydraulic bankfull determination.
- Decouple layout station sampling from construction Flowline. Use centerline
  positions for centers, distances, sequence and station evidence. Retain accepted
  polygon-derived directions/deconfliction, modifying only associations required
  by the new reference. Keep old API defaults or provide an explicit new profile.
- Support current/base-event Reach stationing and connected-Study offsets through
  one outlet, shared Reach boundaries and tributary confluences. The reference
  geometry must be independent of XS spacing; never define it from the sections
  it will station. Fail clearly on unsupported or ambiguous topology.
- Update request/worker/cache keys, validators, GeoPackage tables, exact-lineage
  reopening and UI method/reference information together. New schema/method IDs
  must prevent old Flowline-stationed drafts being reused as centerline products.
  Preserve original draft files and reuse unchanged upstream assets safely.
- Make RAS-style the normal new-work path. Expose legacy compatibility in its
  appropriate context; do not present simple as an equivalent default for new work.

Acceptance: generate, inspect, save and reopen a centerline-referenced RAS-style
draft in the whole app. Cover an ordinary Reach, XS 268's tight-bend neighborhood
and a connected tributary case. Verify actual reference locations, upstream order,
units, confluence continuity, stale-input failures and old-draft preservation.
Record expected geometry changes caused by new anchors without optimizing shapes.
Refresh the app in a fresh R process and identify the changed controls.

### 3. Replace the simple legacy layout producer with open-source R

Owner: fluvgeo; FG Studio proves save/reopen and the compatibility path.

- Define an explicit simple-layout entry point/profile rather than changing
  `cross_section()`'s existing enrichment role. Reuse suitable existing line,
  stationing and validation primitives after inspecting their contracts.
- Implement both historical split modes, split-piece midpoint/chord direction,
  residual end pieces, one-side width and explicit CRS/width-unit conversion.
  Cover zero-length/duplicate vertices, axis-aligned segments, multipart inputs,
  direction and multiple Reach labels. Do not preserve accidental divide-by-zero
  defects or silently guess unsupported multipart/branch semantics.
- Qualify planar/geodesic construction differences against retained legacy
  geometry and declared tolerances; define any material departure as a reviewed
  method/profile difference. Match scientific intent and output contract without
  promising ArcPy vertex-for-vertex equivalence.
- Emit the defined layout-stage legacy profile and additive method/reference
  metadata. Preserve `xs_<spacing>_<width>` for compatibility export and original
  names as evidence; canonical local/FGDB delivery uses `cross_section` under the
  accepted naming migration. Enforce short-integer `Seq` range in that profile.
- Connect Flowline referencing and later-stage consumers explicitly; test
  `cross_section()`, `xs_upstream()`, `cross_section_points()`, resequencing and
  representative report inputs. Resolve rather than conceal the later-stage
  `POINT_M`/`to_measure` unit/profile conflicts before those exports are claimed.

Acceptance: no ArcPy runtime for the replaced layout operation; constructor and
validator tests cover both split modes, units, field/types, geometry and negative
cases, with retained Copperas fixtures and GeoPackage round trips. Old and new
method roles coexist without replacement. Only the demonstrated layout scope is
declared replaced. Keep production toolbox wrappers unchanged until separately
authorized and qualified; check source attribution before redistributing code.

### 4. Qualify multi-event centerline calibration and mixed-method comparisons

- Extend/reuse calibration primitives only after confirming their existing API
  and unit contracts. Preserve explicit base-event choice, controls, uncalibrated
  measures, adjustments, QA and exact geometry edition bindings.
- Use eligible real multi-event data; do not invent comparison events in the
  single-event Spencer study. Exercise lateral migration, changed lengths,
  cutoffs, ambiguous intersections and confluence shifts.
- Measure station displacement, residuals and manual exceptions relative to the
  existing Flowline approach using predeclared tolerances. Preserve real geometry
  change separately from calibrated reference positions.
- Add reviewed old-to-new position mappings where a common-axis query needs
  them. Preserve native historical positions. Reject/exclude unmapped observations
  explicitly; do not join on `Seq`, station or label alone.

Acceptance: reproducible base/comparison frame selection, documented calibration
QA, one native-frame historical query and one accepted common-frame comparison.
Mixed-method metric compatibility is declared separately from position mapping.
Full historical centerline reconstruction is required only by a specific analysis.

### 5. Verify delivery contracts and downstream adoption

- Verify shared-type constraints, Event/role/edition replacement, references,
  GeoPackage round trips and compatible legacy export. Exercise the FGDB ingestion
  contract with validation fixtures; do not claim a deployed loader or enterprise
  round-trip implementation before one exists. Test Enterprise bindings as that
  implementation becomes available.
- Assess fluvgeo reports, ohwm2, RegionalCurve, fluvgeodata, desktop and QGIS
  adapters for units, assumptions and release impact. Preserve existing defaults;
  no production client migration or deployment is automatic.
- Update package help/NEWS, FG Studio analyst guide, article 18, storage crosswalk,
  function/data mappings and agent routes as behavior changes. Keep tested source
  and owning FGDB contracts aligned; preserve GeoTIFF terrain deliverables.
- Run focused deterministic tests, required package checks and applicable client
  checks using workstation routing and the isolated backend library. Record
  service/platform limitations separately from deterministic failures. Review
  whole-app outcomes and representative runtime without reopening optimization.

Acceptance: both method families are distinguishable and reproducible end to end;
new/rework uses centerline; legacy remains usable; an export never silently
reinterprets reference semantics. List any unimplemented adapter or comparison
scope instead of declaring universal compatibility.

## Immediate next implementation action

Complete phase 1's minimum contract and carry it into phase 2's first usable
centerline-referenced save/reopen increment. Begin at `cross_section_layout.R`,
`cross_section_regions.R`, `cross_section_preparation.R`, `cross_section_store.R`
and their tests, with FGDB's reference and feature contracts alongside them.
Phase 3 can follow the shared contract independently of multi-event qualification;
phases 4–5 complete the wider scientific and delivery scope. The full initiative
is not complete when only a type field or a single-event geometry test passes.
