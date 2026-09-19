# Checkpoint: Source DEM download review

- Updated: 2026-09-19
- Status: implementation and qualification complete; ready for owner UI review

## Owner direction and implementation

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

Current work is uncommitted on main in both repositories. Initial resumed HEADs
were fgstudio 04d5b89 and fluvgeo 9de01fa, with clean working trees. No commits,
pushes, shared-library upgrades or production-client changes were performed.
The prior preparation-only handoff is [archived](../archive/terrain-acquisition-before-downloads-2026-09-19.md).

## Read to continue

- `dev/features/stream-dem-files.md`: current behavior and verification evidence.
- `dev/features/dem-download-proposal.md`: owner-approved scope and limits.
- `vignettes/dev-06-stream-dem-files.Rmd` and `dev/architecture/agent-routes.md`:
  paired human and agent call-flow navigation.
- Sibling `fluvgeo/dev/schemas/stream-dem-downloads.md`: exact receipt/API contract.
- `dev/decisions/adr-0007-iterative-terrain-acquisition.md`: scientific boundaries.

## Runtime and data preservation

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

Review the working download UI with saved choices. Any refinements remain within
source acquisition unless separately directed. The subsequent terrain inspection
step needs its own bounded design: raster readability, actual resolution, source
CRS/vertical evidence, visual/processing review and acceptance rationale. No
mosaicking, reprojection, clipping, suitability acceptance or Survey Event creation
has been implemented or implied by downloading.

High-resolution AOI remains the saved Stream polygon. One future Stream Survey
Event may draw on several Survey Collections. Reach derivatives, physical Reach
DEM persistence and Stream/Event linkage remain design questions. Study Area
mid-resolution terrain and point-cloud processing remain future scopes.
