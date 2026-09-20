# Checkpoint: Source DEM detail inspection

- Updated: 2026-09-19
- Status: implementation and qualification complete; ready for owner UI review

## Owner direction and implementation

Latest increment: fgstudio 9031 / fluvgeo 9041, **Inspect selected area**. Brush a
rectangle to read a finer source pixel window, repeat for native data, and use
**Preview elevations** to reset. Unique brush IDs prevent stale selections from
being reused; windows retain source row/column offsets. Read the current feature
section and article 07 before the older overview/metadata handoff below.

The owner accepted metadata inspection and requested the next step. Current
fgstudio 9030 / fluvgeo 9040 add **Preview elevations**: a bounded source-grid
colour overview with explicit sampling, units and missing-data limits. It uses
the same receipt binding, worker cancellation and stale-result isolation. Read
`dev/features/dem-inspection.md`, article 07 and sibling
`fluvgeo/dev/schemas/stream-dem-inspection.md` for this latest increment.
Earlier metadata qualification below remains historical.

The owner approved the study-local download design with "Proceed as proposed."
FG Studio 0.0.0.9028 and fluvgeo 2026.09.19.9038 implement explicit acquisition of
saved source DEM choices. Study-local `source-dem` storage keeps original files,
immutable selection copies and transfer receipts, SHA-256 identities and failures.
Transfers are sequential and bounded. Reopening verifies local checksums in a
background worker; explicit retries reuse only matching, rehashed source assets.

Start requires the current saved inventory and checked IDs. Refreshing metadata
requires saving again even if IDs did not change. Scope changes stop and join the
worker before incomplete-file cleanup; delayed results cannot attach to another
study or selection. Downloaded does not mean scientifically suitable terrain.

Download work is committed at fgstudio cf47b8b / fluvgeo a378771; both main working
trees were clean when the owner directed the next step. The new 9029 / 9039
metadata-inspection increment is uncommitted. See `dev/features/dem-inspection.md`
and article 07 for current behavior and qualification. No commits, pushes,
shared-library upgrades or production-client changes were performed.
The prior preparation-only handoff is [archived](../archive/terrain-acquisition-before-downloads-2026-09-19.md).

## Read to continue

- `dev/features/stream-dem-files.md`: current behavior and verification evidence.
- `dev/features/dem-download-proposal.md`: owner-approved scope and limits.
- `vignettes/dev-06-stream-dem-files.Rmd` and `dev/architecture/agent-routes.md`:
  paired human and agent call-flow navigation.
- Sibling `fluvgeo/dev/schemas/stream-dem-downloads.md`: exact receipt/API contract.
- `dev/decisions/adr-0007-iterative-terrain-acquisition.md`: scientific boundaries.

## Runtime and data preservation

Current 9031 preview restarted in a fresh hidden process and returned HTTP 200 at
http://127.0.0.1:8780/. Logs: `dev/check-output/preview-detail.stdout.log` and
`.stderr.log`. Final evidence: 673 full app assertions, 73 backend assertions
(one existing symlink skip), real worker/native-detail image qualification,
developer site/code-map checks, and app/backend package checks with no errors.
Existing warnings/notes and legacy backend exclusions are in the feature record.
The detail control appears after an elevation preview; browser owner acceptance
is not claimed. All three inspection increments remain uncommitted.

Latest 9030 preview restarted and verified HTTP 200 at http://127.0.0.1:8780/,
including **Preview elevations**, inspect and cancel controls. Logs:
`dev/check-output/preview-elevation.stdout.log` and `.stderr.log`. Final checks:
662 app assertions, 64 backend download/preview assertions (one existing symlink
skip), real-worker rendering and visual PNG inspection, documentation/code map,
and app/backend package checks with no errors and only existing warnings/notes.
The previous metadata increment's details below are historical evidence.

Current 9029 preview restarted in a fresh hidden process and verified HTTP 200 at
http://127.0.0.1:8780/ with inspection/start/cancel controls. Logs:
`dev/check-output/preview-inspection.stdout.log` and `.stderr.log`. Current checks:
647 full app assertions before final inspector refinements, 20 final focused app
assertions, 103 focused backend assertions, real-worker/UI-render qualification,
all seven vignettes and local developer site/code-map build. Package checks have
no errors; existing warnings/notes and excluded legacy checks are recorded in
`dev/features/dem-inspection.md`. Browser owner acceptance remains unclaimed.

Fresh preview verified at http://127.0.0.1:8780/ with HTTP 200 and the download
controls present. Final evidence: 74 backend assertions; 629 full app assertions
before the outer-watchdog addition and 62 final focused assertions afterward;
one 10.3 MB synthetic USGS transfer plus checksum reuse. See the feature record
for package-check warnings, unavailable optional dependencies and test limits.

Use `dev/scripts/run-dev.ps1` in a fresh R process, with Studio's isolated
`dev/local-library`. Verify port 8780/process ownership before restarting.
Preserve all `.local-data` studies and selection revisions. No analyst source
tiles are downloaded automatically; the owner must select Download saved files.
The opt-in live qualification script uses a separate synthetic Omaha AOI and
caps its one source tile at 16 MiB under ignored `dev/check-output`.

## Next owner review

Review **Inspect selected area** after drawing a rectangle on an elevation view.
Repeat for native data and use **Preview elevations** to reset. This source-grid
detail complements metadata evidence; georeferenced review, complete-source
readability, ground-resolution qualification, processing review and acceptance
rationale remain subsequent work. Temporary display windows do not implement
analytical mosaicking/reprojection/clipping, suitability acceptance or Event creation.

High-resolution AOI remains the saved Stream polygon. One future Stream Survey
Event may draw on several Survey Collections. Reach derivatives, physical Reach
DEM persistence and Stream/Event linkage remain design questions. Study Area
mid-resolution terrain and point-cloud processing remain future scopes.
