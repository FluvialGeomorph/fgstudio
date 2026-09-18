# Documentation reconciliation: local hierarchy milestone

## Scope and evidence

Documentation-only review requested after the owner described FG Studio as very
functional. Reviewed README, goals, architecture, feature records, ADRs and Stream
evidence contract against the current R modules, storage adapter, test sources,
retained package-check output and recent Git history. Read fluvgeo's piece schema
as the backend contract; no other repository or saved study was changed.

Verified repository baseline: HEAD `285cda7` ("config study area from nldi features")
plus substantial tracked and untracked working-tree additions. DESCRIPTION is
0.0.0.9022, requiring fluvgeo >=2026.09.17.9032. Accomplished below means implemented
in this working tree, not committed, released or deployed. This review did not
commit changes or independently repeat geospatial/browser qualification.

## Findings and corrections

| Drift found | Evidence and correction |
| --- | --- |
| Completed Reach work still listed as next | Reach modules and adapter expose Add/Combine/Split; project plan now separates accomplished work from unimplemented entry points |
| Two candidate-order definitions | `drainage_inventory.R` calls `order_drainage_flowlines` with NULL origin; README/schema now specify downstream-to-upstream order for both query lists |
| Whole-COMID assumptions presented as universal | fluvgeo piece schema and Reach selection use selection_id after splitting; ADRs and features distinguish legacy mappings from piece-enabled contexts |
| Removed controls and under-described storage | Current modules use Working on and Workspace - New; architecture no longer directs users to removed panels or describes storage as boundary-only |
| Repeated stale acceptance requests | Owner accepted creation/combination, Rename and Split; dated records retain original verification but no longer imply those trials must be repeated |
| Test results could imply newer coverage than performed | Full 9022 check predates the Stream-first rename correction; focused verification of that correction is recorded separately |

The large Study Area/drainage feature records retain dated implementation and
debugging evidence. Current-status introductions and the consolidated project
plan make their historical scope explicit, rather than erasing lessons or
creating another parallel roadmap.

## Evidence strength and remaining boundaries

- **Verified:** current implementation includes local hierarchy definition and
  editing; retained 9022 package check reports OK and 535 passed assertions, with
  two installed-package build-version warnings. The later rename correction
  passed 30 focused assertions. These results were not rerun for this doc-only pass.
- **Owner-reported:** the workflow is functional; Stream entry, Reach creation,
  combining, renaming and splitting received affirmative feedback. This is not
  a comprehensive automated browser test or production acceptance.
- **Inferred:** stale "next" statements resulted from increment records accumulating
  faster than current-status summaries were reconciled. No new scientific-method
  drift was established by this bounded documentation review.
- **Approved design, not delivered:** pre-assembly cuts and Stream splitting.
  Existing saved-Reach splitting does not imply these entry points are available.
- **Unknown/not qualified:** child reconciliation for blocked splits, general
  spatial edits, deployment-scale performance, multi-user safety, final Enterprise
  schema/authentication/transport. Survey Event/terrain/report/L1 app integration
  is future work even where backend tools already exist.

## Handoff

Review checks: strict reproducibleai context validation passed (only expected
repository-owned seed-customization warnings); local Markdown file-link checks
passed across 35 maintained documents; Git whitespace validation passed. External
web links and browser behavior were not retested. App code, package dependencies,
saved studies and running preview were left unchanged.

Use [the project plan](../goals/project-plan.md) for current scope and the next
owner decision; [README](../../README.md) for the analyst path; feature records
and schemas for exact safety and evidence boundaries. Review/commit the accumulated
implementation and documentation when the owner is ready. No next functional
slice is selected by this review, and no new geospatial tool is authorized here.
