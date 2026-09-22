# Stream-scoped source DEM file discovery

## Current remediation (9047 / fluvgeo 9052)

Source DEM discovery reads all catalog pages. Download size and healthy-transfer
duration caps are removed, including legacy request restrictions. Connection/idle
recovery and cancellation remain. Saved availability is read across attempt history
independently of selection refresh; each preview retains its receipt's attempt.
Explicit refreshed selections can reuse matching verified source bytes.

Focused backend discovery/download tests passed, including the local HTTP transfer
fixture; the directory-symlink case remains skipped on this account. App download,
file-selection and inspection tests passed. Only the isolated development backend
was installed. See article 06 and the current checkpoint for preview verification.
The real app saved-history worker passed against an existing synthetic local tile;
a live DEM query through a worker returned COMPLETE using the saved synthetic
public fixture. Preview 9047 runs on port 8782, leaving the old browser session
untouched. Interactive visual acceptance remains owner review.
Earlier verification below is historical and does not reinstate retired limits.

## Source download increment (9028 / fluvgeo 9038)

The owner approved the [download design](dem-download-proposal.md). Download saved
files revalidates current study/source/selection evidence and acquires originals
under the study's `source-dem` folder. Sequential transfers have connection/idle recovery,
per-file outcomes and immutable provenance receipts. Cancel stops and joins the
worker before cleaning its incomplete files. Completed assets survive failure,
cancel and explicit retries. Retry rehashes compatible sources before reuse;
reopening checks local integrity in a background worker. RECORDED fallback states
explicitly distinguish a saved receipt from a newly checked checksum.

HTTP/catalog lengths, TIFF signatures and SHA-256 verify transferred bytes.
Scientific suitability and Survey Event creation remain future capabilities.
The exact backend schema is `fluvgeo/dev/schemas/stream-dem-downloads.md`.
Only Studio's isolated development library adopts the backend update.
Refreshed metadata must be saved again even when tile IDs are unchanged; the
download start guard cannot substitute an earlier selection snapshot for the
inventory currently shown in review.

### Verification, 2026-09-19

- Backend: 74 focused assertions passed, including real loopback HTTP streaming,
  byte limits, cancellation, idle/file timeouts, receipt failures, corrupt-asset
  reuse, relocation and unknown-size handling. One directory-symlink test skipped
  because this Windows account cannot create those links.
- App: full suite passed 629 assertions with restored containment/cancellation
  bindings. After adding the outer eight-hour watchdog, the final focused suite
  passed 62 assertions and again confirmed cancellation bindings were restored.
  Existing sf/shiny/testthat R 4.6.1 build warnings occur under runtime R 4.6.0.
- Live qualification: a fresh app worker downloaded one 10,295,641-byte public
  USGS source for a synthetic Omaha Stream. HTTP/catalog lengths matched, TIFF
  signature and SHA-256 checks passed, and a second attempt reused the rehashed
  local asset. Evidence is under ignored
  `dev/check-output/dem-live-39e84d9d32d7`. No analyst study was opened or mutated
  by this qualification, and no analyst-selected tiles were downloaded.
- App package check completed with tests (624 assertions at that earlier
  refinement) and vignettes, zero errors and a non-ASCII source warning. Subsequent
  controller refinements are covered by the full/focused runs above; touched
  download source strings now use portable Unicode escapes.
- Backend build/limited package check completed with one existing non-ASCII
  warning and two notes about existing undeclared methods/global bindings. The
  strict check initially stopped on unavailable optional fluvgeodata/gt; the
  limited rerun used `_R_CHECK_FORCE_SUGGESTS_=false`, `--no-tests --no-examples
  --no-manual`. The legacy full suite was deliberately not run: several report
  tests delete/rewrite files under HOME, outside temporary test directories.
  The build also reported existing R >=4.1 syntax in unrelated source files.
- Final pkgdown rebuild succeeded. Navigation: 58 nodes, 72 static edges and 14
  reviewed bridges; source freshness and bridge checks passed. The expected local
  site diagnostic about an unset public URL remains. Article 06 and README contain
  the implemented download workflow and refreshed-inventory guard.
- The identified older preview was stopped and `run-dev.ps1` launched a fresh
  hidden R process. HTTP 200 on port 8780 and the Download saved files/Cancel
  download controls were verified. Browser interaction/owner UI acceptance is
  still distinct from these automated checks.

No commits, pushes or shared-library upgrades were performed.

## Historical discovery/selection increment (through 9027)

Owner-directed next increment, 2026-09-19. From Survey Collections / DEM files,
choose a saved Stream polygon and an included collection with DEM in its plan.
Find source DEM files uses a cancellable worker and fixed public USGS metadata
endpoints. The shared map displays Stream AOI (green) and checked file bounds
(purple). Select all / Clear operates on the returned intersecting tiles. The
selected-tile table scrolls within 220 px; the checkbox list within 180 px.
Short labels and collapsed search details reduce vertical space.

Empty completed searches explicitly distinguish the selected Stream from the
broader Study Area. Owner screenshots confirmed expected IA Eastern 2019 results;
no collection-switching defect was established. The collapsible Download review
shows selected/returned counts, saved state, reported MB (a subtotal when sizes
are missing), unknown sizes, and unknown/coarser-than-1-m resolution. Partial
catalog results remain explicitly incomplete. This is preparation only, not a
transfer executor or suitability decision. Next: explicit cancellable acquisition
of saved file choices, preserving original files and provenance for inspection.

Backend ownership: fluvgeo::discover_stream_dem_files. USGS OPR / 1 m source
directory links supported; other links/providers explicitly UNSUPPORTED. Directory
matching is exact, not guessed from dates or names. sf intersects reported bounds
with the Stream. No raster data are read/downloaded or coverage percentages
computed. File size, pixel-size evidence, format and publication date are shown;
publication is not acquisition, and bounds are not valid-elevation footprints.
Resolution can remain unknown even when a file is listed.

Save file choices writes a new immutable GeoPackage per Stream/collection pair,
retaining all returned records, explicit selected IDs, Stream/collection evidence
and query status. Reopening the same context and source snapshot restores choices
offline. Stale context/file revisions, changed geometry/source evidence, or a DEM
collection not in the saved acquisition plan block saving. Refresh requires draft
choices to be saved first. Switching Stream/collection discards unsaved choices.
Historic PARTIAL results require a new complete search; Select all means all returned tiles, not guaranteed complete
coverage. No asset registration, download, mosaic, suitability decision
or Event creation is implied. Those are subsequent slices. Existing study files,
the production toolboxes, ohwm2 and shared libraries are unchanged.

Study Area DEM clarification is recorded in ADR 0007: future mid-resolution terrain
for watershed work is distinct from Stream high-resolution acquisition. No storage
or FGDB schema scaffolding for that future role is added now.

## Evidence

Owner accepted the empty-result/download-review changes and requested a new-chat
pause. The final documentation build succeeded (55 nodes, 69 static edges,
11 reviewed bridges); the restarted preview returned HTTP 200. Resume via
`dev/checkpoints/current/terrain-acquisition.md`. Download execution is not built.

Empty-result/download-review refinement: 25 focused backend and 30 focused app
assertions passed; two existing app dependency build-version warnings. Includes
zero selection, saved state, partial results, unknown sizes/resolution and coarse
tiles. No downloads, service changes or study-data mutations. Full suites were
not rerun for this presentation-only refinement.

Bulk selection / saved-choice increment: focused backend tests passed 23
assertions; focused Studio tests passed 21. Full Studio suite passed 591
assertions, zero failures and two existing package build-version warnings.
Synthetic tests cover bulk selection, immutable round trips, offline restoration
and stale-context/source/file guards. No live service requalification was needed
for these UI/persistence changes; no raster downloads or active-study mutations.
Developer documentation rebuilt successfully; generated map has 55 nodes,
69 static edges and 11 reviewed bridges. Freshness and bridge checks passed.

The preceding discovery increment was qualified as follows:

Focused backend tests: 17 assertions passed. Focused Studio tests: 8 new module
assertions and 33 Survey Collection assertions passed; existing shiny/sf R-build
warnings only. Full Studio suite: 578 assertions passed, zero failures, two
existing build-version warnings. Live synthetic public Omaha AOI resolved source file
62640657d34e85fa62bd0234, 10,295,641 reported bytes, pixel size unknown. A separate
synthetic location correctly returned a successful empty catalog result. No
raster downloaded; no active user studies touched. Full fluvgeo suite and R CMD
check have not been rerun. Interactive browser acceptance remains owner review.

Developer article 06 and agent routes updated; pkgdown rebuilt successfully.
Generated map: 55 nodes, 69 static edges and 10 reviewed bridges; freshness and
bridge checks passed. Existing missing public-site URL diagnostic remains.
