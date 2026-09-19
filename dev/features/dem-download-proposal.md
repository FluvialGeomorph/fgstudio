# Source DEM download increment

Status: owner approved this proposal on 2026-09-19; implemented in fgstudio 9028
and fluvgeo 9038. Verification evidence is recorded in `stream-dem-files.md`.
The exact backend contract is `fluvgeo/dev/schemas/stream-dem-downloads.md`.
See ADR 0007 for accepted scientific boundaries.

## User workflow

Within DEM files, save tile choices, review the destination and reported size,
then explicitly select Download saved files. Download only the selected IDs in
that immutable selection snapshot. Unsaved checkbox changes, empty selections,
stale context/source evidence or unsaved DEM product intent block start with an
actionable message. PARTIAL discovery remains visible and does not imply complete
coverage. Unknown resolution remains unknown; retain the existing coarse-resolution
warning without presenting any acquired file as suitable terrain.

Show the current file, bytes received, completed/total files, and Cancel download.
Show percentages only when a usable transfer length is available. A compact
per-file table distinguishes downloaded, reused, failed, cancelled and not started.
An explicit subsequent start retries unsuccessful files; it does not automatically
retry forever. Changing study, Stream, collection or context revision cancels the
active job. Session closure also cancels it. Completed assets remain available.

## Local destination

Use the configured local study directory, with a study-owned `source-dem/`
subdirectory. This is a local-preview storage choice, not an Enterprise layout.
The UI displays the resolved destination before start. No folder picker or second
storage root in this increment. The owner approved this storage choice.

Separate completed assets, attempt records and incomplete transfers. Generate
internal paths from application-controlled identities; preserve the provider's
filename as evidence rather than using it as a trusted path. Record relative paths
so moving the whole study folder preserves its links. Verify resolved destinations
remain inside the study-owned directory, including any existing link/junction.

Each completed file has a byte-derived SHA-256 identity. Reuse within this study
only when a completed record matches the saved source evidence and local bytes
still match the recorded length and hash. Reuse is an offline integrity claim,
not proof that the remote provider has not revised the object. No cross-study
cache, automatic eviction or deletion of earlier assets. Changed source evidence
requires a new attempt and retains the earlier source-to-content association.

## Transfer and verification

Use one background worker and sequential files. Configurable ceilings:
10 GiB per file, 50 GiB per attempt, 30 seconds to connect, 120 seconds without
progress, two hours per file and eight hours per attempt. Reject known over-limit
plans before starting; enforce byte limits during transfer when size is unknown
or reported incorrectly. Surface limits in download details. A limit failure
preserves completed files and reports the remaining work explicitly.

Accept only HTTPS object URLs under the supported public USGS source-directory
prefix validated against the saved collection. Reject userinfo, ambiguous paths
and unsupported hosts. Do not follow redirects automatically; report a redirect
as unsupported in this first adapter. Provider metadata must not expand the allowed
destination or source scope. Implementation must verify the transport library's
timeout, streaming and cancellation behavior with focused tests.

Write to a unique incomplete file on the destination volume. Require successful
HTTP transfer, a nonempty body and agreement with a valid HTTP Content-Length when
present. Require agreement with the saved catalog size when known; a mismatch is
a verification failure requiring review/refreshed discovery, not silent acceptance
of revised bytes. Missing lengths are explicitly recorded. Reject obvious error
payloads and require a supported TIFF/BigTIFF signature for this initial GeoTIFF
adapter; archives and other formats return unsupported.

Calculate SHA-256 from the completed local bytes. A local hash establishes content
identity and supports later corruption checks; it does not authenticate the
provider's content. Record a provider checksum only when actually supplied with
a known algorithm; do not interpret an ETag as a checksum. These checks do not
prove full raster readability, coverage, resolution, datum or scientific suitability.

Publish without replacing existing files, only after verification. Persist a
completion receipt after asset publication; expose a file as downloaded only when
both asset and receipt validate. A crash between those steps may leave an orphan
asset, which must not be inferred to be a registered download. Keep progress separate
from immutable completion evidence. On cancellation, stop the worker and close file
handles before cleaning that attempt's incomplete files. After a crash, report
interrupted attempts; incomplete files never count as completed assets. Do not
delete unrelated files or perform an automatic broad cleanup.

## Evidence and ownership

Retain the exact selection snapshot reference and checksum, context revision,
Stream and Survey Collection identities, source file ID, original URL and metadata
evidence, requested/reported sizes, observed bytes, HTTP outcome, relevant response
headers, UTC attempt times, local relative path, SHA-256, verification results and
per-file outcome/reason. Prior receipts and selection snapshots remain immutable.
Do not log credentials or unrestricted request/response headers.

FG Studio owns destination selection, current-state guards, job lifecycle and UI.
Reusable transfer validation and receipt read/write logic belong in fluvgeo, with
explicit destination arguments and no Shiny dependency. The exact APIs and
versioned receipt schema are in `fluvgeo/dev/schemas/stream-dem-downloads.md`.
Adoption remains through Studio's isolated backend library.

## Implementation acceptance checks

Use temporary synthetic study folders and deterministic transport fixtures for
successful transfer, HTTP/error-body failure, truncated/oversized data, missing
lengths, checksum reuse/corruption, unsupported URL/format/redirect, cancellation,
worker interruption, partial success, disk/write failure, collision and publication
failure. Verify stale selections and context switches cannot register a result
against a newer study state. Test explicit retry and offline reopening.

Update article 06 and agent routes with the implemented worker/store/backend paths,
then rebuild documentation and run proportionate package checks. Start the analyst
preview in a fresh R process. Any live transfer qualification uses a small synthetic
case explicitly separated from the owner's saved selections. Existing study tiles
are downloaded only through the owner's explicit start action in the app.

This increment ends at original source files and verified transfer receipts.
Raster inspection, terrain processing and Survey Event assignment remain the
subsequent owner-reviewed steps described in ADR 0007.
