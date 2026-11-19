# Cross-section qualification, performance and retained evidence

Status: method-v11 geometric baseline accepted by the owner on 2026-11-19 as
an "80% solution," sufficiently performant and good for now. The increment is
closed. The [feature baseline](../features/cross-section-layout.md) owns design
intent, defaults, constraints and parked options; the
[draft schema](../schemas/cross-section-drafts.md) owns persistence. This record
holds compact measurements and limitations, not a sequence of instructions to
resume earlier experiments. Hydraulic acceptance remains separate.

## Repeatable audit

From the fgstudio root, use the workstation Rscript and isolated development
library:

```text
Rscript dev/scripts/audit-cross-sections.R STORE STUDY_KEY EVENT_ID OUTPUT [REACH_ID ...]
```

Without Reach IDs the maintained audit inventories saved Stream/Reach inputs and
REM readiness. Optional Reach IDs run layouts and record timings, geometry RDS
and Rprof under the explicit OUTPUT directory. It never publishes drafts or
changes source data. Prepare missing REMs through the app. Real Study inputs are
opt-in qualification evidence, not automatic test fixtures. Ordinary regression
tests remain in tests/testthat in the owning package.

Separate cold input opening, REM preparation, inundation, polygon-centerline
construction, layout/review and saved-draft reopening. Record method, cache state,
settings, section count and diagnostic completeness. Partial profiles are not
full completion times; indeterminate progress is not a percentage estimate.

## Accepted current qualification

Spencer Study, December 2019 Event; accepted 103/109 ft levels, 20 m spacing and
other feature defaults. Measurements used Windows R 4.6.0, fluvgeo development
9074 and sf/GEOS 3.14.1, GDAL 3.12.1, PROJ 9.7.1. They are workstation evidence,
not performance guarantees for different geometry or hardware.

| Method-v11 Reach | Sections | Incomplete floodplain legs | Section/channel/floodplain contacts | Removed channel lobes | Cached-region layout including review |
| --- | ---: | ---: | --- | ---: | ---: |
| Mainstem R1 | 84 | 0 | 0 / 0 / 0 | 19 | 25.03 s |
| Mainstem R2 | 310 | 0 | 0 / 0 / 0 | 60 | 199.53 s |

Both have zero actual bank/outer-order conflicts and self-crossings, and less
than 1 mm outside-footprint length. Every previously complete baseline leg is
preserved. R2's four prior incomplete legs (84 and 267-269) are complete. Its
channel search uses 18 nodes, rotating 268 by 7.5 degrees and 269 by 5 degrees.
All saved Flowline station measures are unchanged. The channel, raw source,
cleanup reference, regions and centerlines match the retained preparation
artifacts exactly. Direction, coverage and hydraulic review remain distinct
from these geometry checks.

R2 improves 17 of 19 bend families in 138 route trials; its isolated final bend
pass took 31.92 s. R1 improves two families in ten trials. R2 uses 179 added
floodplain vertices and R1 two; these permit contained deformation and useful
endpoint distribution without imposing bends on feasible straight legs. R2's
full layout is about 6% slower than v10's 188.50 s while resolving its four
incomplete legs and three channel-contact flags. V10 R1 took 19.64 s.

Shared mesh edges, boundary clearance and point/triangle attachments are reused;
obstacle contacts are recalculated for each proposal. Valid incumbent paths are
reused as deformation guides. Matching saved drafts and analytical/display REMs
reopen without geometry regeneration. Loading feedback paints before slow work;
its 650 ms continuous-busy fallback avoids short-poll flicker and layout shifts.

All 11 saved Reaches have matching Flowline Points and prepared REMs. Additional
historical method-v8 qualification is retained for mainstem R3 (297 sections,
zero contacts, five incomplete legs) and east tributary R1 (189 sections, zero
contacts, two incomplete legs). Those are distinct Reach baselines, not current
v11 qualifications. Other-Reach testing is available through the ordinary app;
it is not a blocker to this accepted increment or an R1-only product restriction.

## R2 sinuosity investigation

The accepted pruning recipe uses the raw polygon channel medial route and
boundary-distance discs, a native shallow-depth screen, single-attachment tests
and one removal overlay. It preserves the reference and other original banks.
Large arms at 253/19-20, hooked arms at 246, stubby arms at 130/109 and the narrow
obstruction at 133 are the owner's representative review cases. All have
complete legs without contact/order flags in the accepted result. Removed areas
remain available to LOB/ROB routing; the three removed patches near 109-114 total
29.342 square metres and XS 109 already traverses 2.584 m within them.

Cleanup-only measurements reuse the saved raw medial reference; they exclude
constructing its skeleton and exclude section layout:

| Input | Time | Reviewed / removed lobes |
| --- | ---: | ---: |
| R1 | 1.12 s | 64 / 19 |
| R2 | 3.37 s | 142 / 60 |
| Two translated R2 copies | 8.44 s | 284 / 120 |
| Four translated R2 copies | 25.59 s | 568 / 240 |

These are finite translated-copy stress checks, not additional natural reaches
or evidence of linear scaling. Normal processing is Reach-scoped. Retain the
accepted pruning balance; a routing limitation is not a reason to weaken it.

## Remaining tight bends and endpoint distribution

| Family | V10 minimum outer-edge gap | V11 minimum gap | V10 / v11 outer-edge span |
| --- | ---: | ---: | ---: |
| ROB 222-224 | 0.008 m | 4.707 m | 1.120 / 9.415 m |
| LOB 281-284 | 0.008 m | 2.370 m | 1.123 / 7.659 m |
| ROB 191-197 | 0.008 m | 9.622 m | 0.161 / 57.735 m |
| LOB 91-103 | 0.008 m | 2.382 m | 73.700 / 74.699 m |
| LOB 109-114 | 0.008 m | 0.008 m | 15.080 / 15.080 m |

These are arc distances along the actual outer edge, not hydraulic reach lengths
or universal minimums. The visible 281-284 cluster is LOB in descending-bank
labels. Moving neighboring targets together explains why ROB 191-197 can spread
beyond its old fixed-neighbor interval. LOB 109-114 remains valid but tightly
fanned: bounded alternatives do not improve the complete family safely. This
is an accepted current limitation, not proof of impossibility or selected work.

The reversed LOB banks/contacts at 267-269 predated pruning. V10 excluded sections
with mapped overbanks from channel repair, then held outer targets fixed during
route repair. V11 repairs channel anchors first and jointly plans difficult
endpoint/route families. The old 269 ROB detour's direct chord had 8.069 m outside
its component; the new bank/route planning resolves it.

The retained v10 R2 comparison also preserves the XS 268 example: Flowline
stations were 5330/5350/5370 m, while their channel segments crossed the separate
polygon centerline at gaps of 17.727 and 3.468 m. Map labels use bank midpoints.
The [XS 268 stay-or-go gate](../goals/project-plan.md#near-term-decision-gate-the-xs-268-issue)
requires a dedicated referencing decision before feature expansion. No reference
migration or historical reprocessing is authorized by current acceptance.

## Verification and compatibility boundary

The accepted implementation passed focused backend layout/order/channel/bend/
mesh/region and legacy-validator suites, plus app review/preparation/loading/
store, Flowline Points and Study-module suites. Tests cover deterministic
reconstruction, projected-foot units, changing barriers, fixed banks/stations,
legitimate absent overbanks and mixed-size GeoPackage round trips. Native
qualification independently checks containment, contacts, order and unchanged
preparation geometry. A fresh whole-app preview reopens accepted R1/R2 drafts
and REMs with their measured diagnostic counts and no regeneration.

The retained legacy CC_R15 xs_100_100 sample has 13 rows, integer Seq and double
native-coordinate endpoint fields. Existing names, types, units and meanings
are preserved under the owner-directed standard cross_section/table-metadata
binding. See the [FGDB compatibility contract](../../../FGDB/dev/schemas/legacy-derived-feature-compatibility.md)
for ArcPy/manual/sample/downstream evidence; this is not a claim of completed
legacy export or governed FGDB publication.

The isolated backend installs and the standard source build succeeds. Package
checking stops at pre-existing namespace dependencies absent from DESCRIPTION
Imports/Depends: hydrogeofetch, leafem, raster, rmarkdown, stars, terrainr,
testthat and tmap. The source build also reports an older declared R-version
floor than syntax already used in the package. No package-wide green result is
claimed. Dependency cleanup is separate from this accepted geometry increment.

## Retained data and lifecycle policy

The 2026-11-19 cleanup checks edits and hashes before retiring automatic drafts,
and uses the Windows Recycle Bin without emptying it. It removes five superseded,
unedited draft revisions (20,608,148 bytes) and 155 developer artifacts/trees
(39,612,533 bytes). Recycling removes active clutter; disk space is not reclaimed
until the Recycle Bin is emptied. The manifest and protected-input/retained-draft
hashes are under ignored dev/check-output/cross-section-cleanup.

Retained Study-local revision roles are:

| Revision | Purpose |
| --- | --- |
| 9a69296ba837053674defd79f24cca41 | Accepted v11 mainstem R1 |
| d7bdd7e5e2957de5d52d3697c3ba8275 | Accepted v11 mainstem R2 |
| cc3a3b2b344906dfa16a1cabda4c80f5 | V10 R2 before/after and XS 268 comparison |
| bfc11dcb7328e2e6527faed5f336cd85 | Earlier accepted R1 channel-only regression reference |
| fe167e185c43beebc587e12b2a489044 | Distinct mainstem R3 qualification baseline |
| 4005ede8ecbb5d043f14c2a18d8f11fa | Distinct east tributary R1 qualification baseline |

Every retained revision keeps its original bytes. All upstream Study/Event,
terrain/Hydro, Flowline/Flowline Points and preparation assets are protected;
none is an automatic fixture to purge. Scientific code, synthetic tests and
representative legacy data are retained. Further lifecycle cleanup requires
fresh evidence of supersession and edits; this is not permission to clear
studies or sources.

The curated ignored cross-section-audit folder retains final qualification/test/
publication/build logs, final bend profiles, pruning scale CSV, other-Reach
summary CSV, representative comparison figures and the accepted preview image.
One small pre-bend R2 v11 snapshot is retained for deliberate future solver
troubleshooting without repeating the expensive earlier stages. It is not an
app dependency, a required context source or a task to resume. The running
preview's launch script/logs and earlier cleanup manifests remain. Duplicate
layout/region/input RDS files, obsolete probes/publishers, failed or partial
trial logs, intermediate figures and generated package-check trees are retired.
