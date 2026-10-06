# Legacy-derived feature compatibility

## Trigger

Use this workflow before FG Studio development creates, changes, persists, or
exports a vector dataset historically produced by a `FluvialGeomorph-toolbox`
ArcPy tool.

## Ecosystem purpose

`FluvialGeomorph-toolbox` supplies the legacy production behavior and output
contracts. `fluvgeo` owns reusable open-source replacement functions. FG Studio
is the implementation-first workflow used to prove that those functions support
a viable end-to-end analyst workflow. FGDB owns the eventual governed roll-up,
enterprise relationships, and delivery contracts.

This is a bidirectional design loop. Accepted FGDB domain and compatibility
invariants constrain implementation, while concrete FG Studio development is
expected to reveal GeoPackage representation, interoperability, persistence,
and workflow requirements that a design-only pass could not specify reliably.
Those findings must be reconciled into the owning FGDB contract. A draft FGDB
physical schema is not presumed complete, and an app-local convenience does not
become FGDB authority merely because it works.

Open-source replacement improves method logic, integrity checks, automation,
defaults, portability, and robustness without casually changing the datasets
that historical projects and downstream tools already understand.

## Required evidence before implementation

Inspect all applicable evidence rather than relying on one description:

1. the original ArcPy producer in `FluvialGeomorph-toolbox`;
2. `FG-Tech-Manual/data_dictionary.csv` and the tool parameter documentation;
3. representative retained legacy datasets, including version differences;
4. current `fluvgeo` constructors, `check_*` functions, package data, and tests;
5. downstream consumers in `fluvgeo`, `ohwm2`, reports, and desktop tooling; and
6. the FGDB legacy-derived-feature compatibility profile and relevant canonical
   feature/reference-frame contracts.

Record conflicts rather than silently choosing one source. An ambiguity that can
change field meaning, units, geometry, or downstream behavior requires owner
review before implementation.

## Compatibility invariant

The produced feature class or GeoPackage layer retains its established name and
all established field names, capitalization, types, units, and meanings. New
fields may be added. Existing fields may not be removed, renamed, repurposed, or
assigned different units without an explicit reviewed migration decision.

Platform-managed fields such as `OBJECTID`, `Shape`, and `Shape_Length` need not
be fabricated as scientific identifiers by a non-Esri driver. The portable
binding must nevertheless retain equivalent geometry and must not treat those
fields as durable relationships. When an Esri-compatible export is produced,
its driver supplies the applicable managed fields.

A normalized FGDB base table may differ internally. That enterprise choice does
not weaken the output contract for `fluvgeo`, FG Studio local products, legacy-
project refreshes, or compatibility exports/views.

## Implementation and verification gate

Before considering the feature complete:

- state the legacy feature class and exact output profile being implemented;
- keep reusable construction and validation in `fluvgeo`;
- make FG Studio call the explicit compatibility profile rather than infer units;
- strengthen or add a `check_*` validator for required fields, types, geometry,
  units/measure relationships, null behavior, and ordering invariants;
- test the constructor and validator against representative legacy fixtures and
  deliberate renamed, removed, mistyped, or unit-changed fields;
- inspect downstream consumers for assumptions that differ from the ArcPy
  contract and preserve them through an explicit mode or migration path;
- update the FGDB compatibility profile, FG Studio storage crosswalk, workflow
  article, agent route, `fluvgeo` schema/help, and release notes as applicable;
  and
- report unresolved differences as compatibility gaps, not as completed
  replacements.

When implementation supplies new interoperability evidence, update or propose a
change to the narrowest FGDB schema/decision and label its status accurately.
Do not wait until enterprise implementation to record a requirement already
demonstrated by the grounded workflow.

## Current route

The initial concrete contract is
`../../../FGDB/dev/schemas/legacy-derived-feature-compatibility.md`. It currently
covers `flowline` and `flowline_points`; extend it before implementing another
legacy-derived feature family.
