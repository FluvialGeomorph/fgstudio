# Cross-section performance and real-data qualification

## Repeatable audit

From the fgstudio root, use the workstation Rscript and isolated development
library. The ordinary package tests remain the regression suite; this opt-in
audit reads an explicitly selected local Study, never automated fixtures.

```text
Rscript dev/scripts/audit-cross-sections.R STORE STUDY_KEY EVENT_ID OUTPUT [REACH_ID ...]
```

Without Reach IDs the script enumerates every saved Stream/Reach, checks saved
Flowline Points and exact-input analytical/display REM readiness, and writes
`reaches.csv` plus an input-loading Rprof. Optional Reach IDs calculate the
accepted default layout, write stage timings, geometry RDS and a standard Rprof
under OUTPUT, without publishing drafts or modifying source data. Prepare missing
REMs through the app first. Inspect profiles with `summaryRprof()`.

Separate cold input loading, REM preparation, inundation, polygon-centerline
construction, layout/deconfliction and saved-draft reopening. Report cache state,
section count, remaining diagnostic contacts and profiler overhead. A partial
profiling window is not a full completion time. First-time work can take minutes;
matching saved drafts bypass geometry generation.

## Measured evidence, 2026-11-18

Local Spencer Study, December 2019 Event; Windows R 4.6.0, fluvgeo development
9074, sf/GEOS 3.14.1/GDAL 3.12.1/PROJ 9.7.1; accepted defaults and unchanged
source inputs. Timings are workstation observations, not performance guarantees.
This table records method v8; method v9 qualification appears below.

| Operation | Observation | Conditions |
| --- | --- | --- |
| Cold saved-input opening | 10.06 s | About 78% of sampled time in Flowline Points validation; this blocks the R session while running |
| R2 inundation polygons | 1.61 s | Prepared analytical REM; 6,195 m Reach |
| Prior R2 layout hot spot | About 90% sampled time in repeated CRS parsing | 60 s profiling window, cached polygon centerlines; not a completion time |
| Optimized R1 layout | 19.83 s versus prior 260.73 s, about 13 times faster | Same source geometry, defaults and cached polygon-centerline artifacts |
| Optimized R2 layout | 92.47 s | Full profiled layout, cached polygon centerlines; 310 sections, 3 contact flags, no missing channel crossings |
| Mainstem R3 first layout | 1.05 s inundation + 68.67 s centerlines + 130.42 s layout | Prepared REM; 5,946 m Reach; 297 sections, zero contacts and missing channel crossings |
| East tributary R1 first layout | 0.72 s inundation + 49.66 s centerlines + 49.19 s layout | Prepared REM; 3,783 m Reach; 189 sections, zero contacts and missing channel crossings |

R1 section WKB is byte-identical before/after optimization. SF diagnostics match
at tolerance 1e-12; CRS, source centerline WKB and boundary-anchor measure units
are unchanged. Focused backend geometry, ordering, channel solver, routing and
legacy-validator tests pass. Remaining R2 contacts are review evidence; these
results do not establish hydraulic acceptance across other Reaches.

All 11 saved Reaches (five mainstem and three on each tributary) have matching
saved Flowline Points and valid analytical/display REM preparations. Full layout
qualification covers mainstem R1/R2/R3 and east tributary R1. There is no R1-only
controller restriction. Mainstem R3 and east tributary R1 each complete without
contacts or missing channel crossings. The tributary reports two unreachable
graph-route warnings during alternatives testing; the final layout remains
available with explicit per-section diagnostics. Other Reach layouts still need
analyst testing. Newly calculated results are local review drafts, not accepted
hydraulic products.

| Reach | Sections | Sections with contacts | Incomplete floodplain legs | Component centerlines unavailable |
| --- | ---: | ---: | ---: | ---: |
| Mainstem R1, accepted baseline | 84 | 0 | 0 | 0 |
| Mainstem R2 | 310 | 3 | 17 | 12 |
| Mainstem R3 | 297 | 0 | 5 | 4 |
| East tributary R1 | 189 | 0 | 2 | 3 |

These counts describe different diagnostics: no missing channel crossing or
contact does not imply complete overbank direction/coverage. The three new
results are saved with diagnostics for continued analyst testing. R3 was selected
and reopened in the fresh whole-app preview; its 297-section summary and remaining
five incomplete legs match the native audit output. Initial input progress and
client-side busy feedback through synchronous map/draft reopening were verified.
The fallback has a 650 ms continuous-busy delay and a reserved status slot;
brief poll responses do not flash a second message or change the map position.
Map reopening can still block interaction briefly; phase feedback is not a
percentage-complete estimate.

The accepted R1 baseline has 84 sections, no section contacts or incomplete
overbank segments, and no bank-order review problems. Sections 1–10 are
channel-only; four sections (2, 3, 6, 7) exceed the provisional 15-degree channel
review threshold. Sections 19/30 retain perpendicular channel segments and LOB
35–39 retain complete ordered routes. The current saved draft is the regression
reference; the optional outlet PNG is a visual aid, not a second authoritative
dataset. The representative legacy CC_R15 xs_100_100 dataset has 13 rows and
legitimate two-vertex geometry and remains part of compatibility evidence.

Repeated sampling, distance and predicate calls were reparsing the same projected
CRS. After input CRS validation and metre-to-native-unit conversion, the backend
now uses coordinate-preserving CRS-free working copies for planar operations,
then restores the original CRS and units on outputs. It never transforms the
scientific coordinates or mutates source artifacts. The method/schema remain
unchanged because the accepted output is unchanged.

The app shares matching already-validated Flowline Points within an exact
session/context/Event/revision, defers cold opening until the status has painted,
and shows an indeterminate progress indicator above the map. The background
worker reports inundation, centerline and deconfliction phases and returns stage
timings. Source changes invalidate reuse; publication rechecks exact input hashes.
Recreating Flowline Points invalidates an open layout through its saved revision,
even when the selected Stream/Reach and Hydro/Flowline revision stay unchanged.
Cold polygon-centerline construction and actual GEOS layout remain material costs.

## Data retention and verification boundary

Nine obsolete automatic draft revisions (methods preceding the accepted method,
zero edited sections) were removed from the active Study through the Windows
Recycle Bin: 18,982,912 bytes. Both accepted method-v8 R1 draft GeoPackages were retained
with unchanged SHA-256 hashes. Upstream Study/Event, DEM/Hydro, Flowlines, Flowline
Points and current analytical/display REM assets were retained. The ignored audit
output holds the explicit cleanup manifest and retained-baseline hashes. Another
61 superseded developer artifacts, including a generated package-check directory,
were recycled (19,016,891 bytes). The completed handoff and obsolete hardcoded
exploration script were retired after adapting their useful content into the
feature, schema, developer article and audit route. Recycling removes active
workspace clutter while keeping recovery available; it does not reclaim disk
space until the Recycle Bin is emptied.

Synthetic geometry/persistence fixtures and representative legacy cross sections
remain useful and are retained. Superseded developer probes and generated checks
can be recycled after their evidence is captured here; `.local-data` must never
be repurposed as an automated fixture store. The old R1/R3-only exploration
script is replaced by the explicit all-Reach audit entry point above.

Package-wide R CMD check remains blocked by existing undeclared package
dependencies: namespace imports hydrogeofetch, leafem, raster,
rmarkdown, stars, terrainr, testthat and tmap. DESCRIPTION and
NAMESPACE are unchanged by this work. Focused tests and documentation verification
must be reported separately from that package-wide limitation.

Focused backend constructor/review/order/channel/routing/legacy-validator tests,
app cross-section interaction/preparation/store tests, and adjacent Flowline
Points/Study-module checks passed. Loading regressions cover exact-key reuse,
changed saved-point revisions, cancelled loads, Reach selection and stdout phase
delivery. The documentation site validated 781 local links across 24 pages and
22 article exports; all four affected backend Rd files passed checkRd. Existing
host locale and R-binary-version warnings remain.

## R2 sinuosity investigation

Current qualification uses method v10. The feature baseline and draft schema
own its exact policies; these measurements do not establish universal hydraulic
or tributary classification defaults. Raw Study, terrain, Flowline, Flowline
Points and REM inputs remain unchanged.

| Case | Method v9 baseline | Method v10 |
| --- | --- | --- |
| R2 | 310 sections; 5 incomplete floodplain legs; 3 sections with channel contacts; 16 removed lobes | 310 sections; 4 incomplete legs; the same 3 channel-contact flags; 60 removed lobes |
| R1 regression | 84 sections; no incomplete legs or contacts; 4 removed lobes | 84 sections; no incomplete legs or contacts; 19 removed lobes |
| XS 195-201 and 270-276 | Complete, nonintersecting ordered legs after the earlier geodesic/group extension | Complete, nonintersecting ordered legs retained |

The earlier method-v8 baseline had 17 incomplete R2 legs. It rejected XS 270
LOB and XS 196/199 ROB before routing because their component centerlines were
not visible through straight contained connectors. Contained geodesic association
and local group repair remain part of the current method. Existing R1/v9 saved
revisions remain separate immutable references.

The owner's further pruning examples are the large arms at XS 253 and 19-20,
hooked arms near 246, stubby arms near 130/109 and the narrow obstruction at 133.
Native comparison figures show the revised channel against the previous mask;
removed areas remain in the total floodplain and become LOB/ROB. Tests include
hooked/stubby/narrow arms, preservation of a broad bank expansion and a winding
constant-width mainstem, projected-foot units and unchanged source banks.

The refinement replaces the tangent-advance rejection and repeated whole-channel
mouth splits with depth-screened, single-attachment envelope pruning. A native
overlay discards shallow boundary chips before per-lobe evaluation. The raw
channel polygon medial route remains the reference; the Flowline selects its
longitudinal route without supplying cleanup geometry. No recursive pruning or
additional skeleton pass is introduced by the stronger pruning rules.

A downstream extraction failure exposed a separate anchor-selection weakness:
one R2 floodplain polygon's global anchor landed on a detached 1.35 m skeleton
fragment instead of its roughly 494 m main component. A failed path now retries
within the connected skeleton component with the greatest longitudinal span,
without joining fragments. The recovered R2 route spans 99.76% of the original
longitudinal node range. Its skeleton/raw/smoothed WKB was independently rebuilt
through the constructor and matches the retained recovered geometry. Region
diagnostics carry the fallback and its measured span fraction.

R1 XS 38 exposed an ordered target whose straight direction was 30.16 degrees
against the 30-degree bound. One optional, genuine bend with a clamped initial
direction resolves it without changing banks/targets or relaxing the bound.
Feasible straight legs acquire no mandatory bend. The final full-layout runs
include this repair and retain the original bank/order/contact checks.

### Computational cost

An isolated cleanup rerun reuses the saved raw-channel medial reference. It
includes envelope construction, screening, candidate review, removal and topology
guards; it excludes constructing that initial skeleton/reference and excludes
cross-section layout. On this workstation, v9 took 10.86 s for R2 (16 removed
lobes). Current v10 takes 3.37 s (142 reviewed, 60 removed); R1 takes 1.12 s
(64 reviewed, 19 removed). The one-copy prepared-channel WKB matches the native
constructor output exactly. Each raw source has one channel component and one
retained reference route.

| Combined R2 geometry copies | Cleanup time | Reviewed / removed |
| --- | --- | --- |
| 1 | 3.37 s | 142 / 60 |
| 2 | 8.44 s | 284 / 120 |
| 4 | 25.59 s | 568 / 240 |

Copies are rigid translations of R2, not additional natural reaches or full
layout runs. Growth is faster than linear; these results do not prove unlimited
or linear scaling for a very long continuous reach. Normal app processing stays
Reach-scoped and reuses matching prepared artifacts. Changing only XS spacing
or tangent distance does not require rebuilding the regional geometry.

With prepared artifacts, the final v10 full layouts took 188.50 s for R2 and
19.64 s for R1, versus v9's 206.50 s and 21.84 s. Geometry changes between methods,
so this is a workflow comparison rather than a pure same-output optimization
benchmark. The earlier v9 full regional preparation took 137.94/29.10 s for
R2/R1. A preliminary v10 preparation measured 132.37 s for R2 before the connected-
route retry was added; full preparation was not retimed after that small fallback.
Saved matching drafts bypass regeneration and retain the existing REM assets.

### Verification and limits

Native layouts have no self-crossings and less than 1 mm outside-floodplain
length. Remaining R2 incompleteness/contact flags stay explicit; this method
does not claim to solve every Study case. The retained CC_R15 xs_100_100 sample
still has 13 rows, integer Seq and double native-coordinate endpoint fields.
No established layout-stage field name, type, unit or meaning changes.

Channel-bank direction remains distinct from the outer endpoint chord of a
bent section. XS 198/199 illustrate why those diagnostics are separate;
`oriented` retains their established combined meaning. HEC-RAS's stationing
convention is relative to looking downstream
([HEC cross-section guidance](https://www.hec.usace.army.mil/confluence/rasdocs/ras1dtechref/6.3/basic-data-requirements/geometric-data/cross-section-geometry)).
Geometry and review diagnostics do not by themselves confer hydraulic acceptance.

Focused backend geometry/order/routing/region tests and all app cross-section
tests pass. Nonempty branch geometry, attachment_depth/cleanup_status and
continuity diagnostics survive GeoPackage save/reopen unchanged. All six named
pruning locations have complete legs and no contact/order flags; remaining
incomplete sections are 84 and 267-269. R2 uses 37 added floodplain vertices,
versus 79 in v9. Neither prepared channel adds holes to the raw outer footprint.
Accepted R1 and saved v9 GeoPackage hashes remain unchanged.

A fresh whole-app preview reopens both v10 drafts without layout recomputation.
R2 displays 60 removals, four incomplete legs, three channel-contact flags and
zero floodplain-contact flags; R1 displays zero incomplete legs/contacts.
Cleanup review layers render in the full-width, 650-pixel-high map, with the
idle loading fallback hidden. Four backend Rd files pass checkRd; the rebuilt
documentation validates 781 local links across 24 pages and 22 article exports.

## Remaining tight bends and endpoint distribution

### Diagnosed method-v10 limitations

Read-only comparison with retained v8/v9/v10 results established that the
267-269 channel contacts and reversed LOB bank order predated channel pruning.
The old channel-repair eligibility excluded mapped-overbank sections. XS 269's
ROB detour was identical in all three versions; its direct bank-to-target chord
had 8.069 m outside its component. Pruning was not the cause.

Method v10 sampled stations 267/268/269 at 5330/5350/5370 m on the saved Flowline,
while their channel segments crossed the polygon centerline at gaps of 17.727
and 3.468 m. Map numbers use bank midpoints, not the station points. The
[XS 268 decision gate](../goals/project-plan.md#near-term-decision-gate-the-xs-268-issue)
records the deferred system-wide Flowline-versus-centerline referencing question.
Current layout work preserves all existing station measures.

Outer-target ordering used an 8 mm numerical gap; angular refinement could
collapse a previously broader allocation against that gap. Subsequent group
routing kept targets fixed. Removed arms were available at 109-114: all
29.342 square metres belonged to its exact LOB routing component, and XS 109
already traversed 2.584 m inside those patches. That family had selected group
routes, but could not redistribute its frozen endpoints. Complete awkward legs
at 91-103 did not trigger the old failure/geodesic-only group repair.

### Method-v11 qualification

The current refactor extends station-preserving channel bank-order/contact
repair to sections with mapped overbanks before deriving their directions,
components and targets. It then jointly plans outer targets and routes in
bounded bend families, including already complete crowded or multi-bend legs.
Valid incumbent paths guide contained deformation toward new targets before
mesh reconstruction. Five target allocations and three routing priorities are
bounded alternatives; entire families must remain complete and nonintersecting.
The accepted method-v10 pruning recipe and its regional artifacts are unchanged.

R2 has 310 sections, zero incomplete floodplain legs and zero section/channel/
floodplain contacts. The four prior incomplete legs (84 and 267-269) are
complete. Channel repair uses 18 search nodes, rotating 268 by 7.5 degrees and
269 by 5 degrees while retaining their Flowline stations. Seventeen of 19
whole-bend families improve in 138 routing trials. R1 retains 84 complete
sections without contacts; two bend families improve.
R2 uses 179 added floodplain vertices, versus 37 in v10; R1 uses two. The
additional vertices allow contained path deformation and better endpoint
distribution. There is no mandatory bend on otherwise feasible straight legs.

| Family | v10 minimum outer-edge gap | v11 minimum gap | v10 / v11 outer-edge span |
| --- | --- | --- | --- |
| ROB 222-224 | 0.008 m | 4.707 m | 1.120 / 9.415 m |
| LOB 281-284 | 0.008 m | 2.370 m | 1.123 / 7.659 m |
| ROB 191-197 | 0.008 m | 9.622 m | 0.161 / 57.735 m |
| LOB 91-103 | 0.008 m | 2.382 m | 73.700 / 74.699 m |
| LOB 109-114 | 0.008 m | 0.008 m | 15.080 / 15.080 m |

These are arc distances along the actual outer edge, not hydraulic reach lengths
or universal minimums. The 281-284 fan is LOB in descending-bank labels. Group
planning can move neighboring targets too: the old fixed-neighbor interval of
17.633 m around ROB 191-197 was not a limit on the larger group's available
boundary. At 109-114, the bounded proposals do not yield a safe improvement, so
the existing valid family remains. This is a search limitation, not proof that
better geometry is impossible. No complete baseline leg is sacrificed.

Native verification checks all-pair separation, actual bank/outer order,
self-crossing, containment within 1 mm, unchanged station measures and exact
source/prepared channel, reference, region and centerline geometry. The retained
Copperas Creek xs_100_100 sample still has 13 rows, integer Seq and double
native-coordinate endpoint fields. No established field names, units or consumer
defaults change. Draft/input schema 9 is retained with method identity v11, so
older saved methods remain immutable evidence rather than being silently reused.

### Cost controls and verification route

An uncached exploratory trial was stopped after exceeding ten minutes without
publication; it is not a completed benchmark. Shared meshes now retain fixed
edge geometry, boundary-clearance values and exact point/triangle attachments.
Obstacle contacts are recomputed for every route. Using the original component
mesh avoids triangulating the tiny numerical containment margin. Reusing valid
paths reduces both reconstruction work and failed trials. The final isolated R2
bend pass takes 31.92 s, versus 59.03 s before adding incumbent guides and relaxed
allocations. The feature record owns the geometric defaults and hard constraints.

The final full cached-region layouts take 199.53 s for R2 and 25.03 s for R1,
including final review, versus v10's 188.50/19.64 s. R2 therefore adds about 6%
runtime while resolving the four incomplete legs and three channel contacts and
improving endpoint distribution in the named bend families. R1 improves two
families in ten route trials. These are workstation measurements with unchanged
source/pruning/centerline artifacts, not a guarantee for other reaches. Matching
saved drafts still bypass geometry generation; the REM and regional recipes are
unchanged.

Native probe scripts, profiles and before/after figures are ignored local outputs
under dev/check-output/cross-section-audit, not automatic real-Study fixtures.
Maintained regressions live in sibling test_cross_section_bend.R, channel/order/
mesh/layout/region tests, and the app's cross-section review/store/loading tests.
The new tests cover endpoint distribution, fixed banks/stations, projected-foot
units, current barriers, deterministic reuse and mapped-overbank channel repair.
Geometry and diagnostic checks do not confer hydraulic acceptance.

The isolated development backend installs successfully. Focused backend
constructor/order/channel/bend/mesh/region and legacy-validator suites and app
cross-section/loading/store, Flowline Points and Study-module suites pass.
New R1/R2 schema-9 GeoPackages reopen with identical geometry and typed method-v11
evidence. Every pre-existing cross-section GeoPackage retains its hash. A fresh
whole-app preview reopens both drafts and their precomputed REMs without layout
regeneration; R2 shows 310 candidates, zero incomplete legs and zero contacts,
with the idle loading indicator hidden. The copied legacy Centerline code,
shared backend installation and upstream source datasets are unchanged.
Standard source build succeeds. A packaging check with tests/vignettes/manual
disabled stops at the existing undeclared namespace dependencies listed above;
it does not provide a package-wide green result. Focused suites and the native
Study qualification are separate passing evidence. The source build also
reports the existing DESCRIPTION R-version floor being older than syntax already
used by the package; this refactor does not change dependency metadata.
