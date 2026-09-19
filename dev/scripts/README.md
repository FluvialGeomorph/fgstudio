# Development scripts

- `check-dem-download-live.R`: opt-in acquisition of one reported <=16 MiB
  public USGS tile for a synthetic Omaha AOI, with worker/readback/reuse checks.
  Evidence is retained under ignored `dev/check-output`; never opens analyst studies.

- `check-stream-dem-files-live.R`: opt-in metadata-only public USGS test using a
  synthetic Stream polygon; no raster downloads or analyst-data writes.

Store maintained automation supporting development workflows here. Scripts should document inputs, outputs, dependencies, and safe execution expectations.

Run from the repository root:

- `check-survey-collections-live.R`: opt-in USGS/NOAA smoke query for a synthetic
  Omaha-area AOI and temporary GeoPackage round trip; never reads analyst studies.

- `build-docs.ps1`: resolve R/Pandoc, install an isolated documentation snapshot,
  build/check pkgnet navigation data, then render the local pkgdown site with flow
  widgets. No app data changes or hosted deployment.
- `query-code-map.R`: verify source freshness or print a symbol's direct indexed
  relationships; `check-code-map.R` also checks indirect bridges and stale rejection.

- `bootstrap.R`: initial usethis scaffold; already completed, not a routine launcher.
- `prepare-dev.R`: build the sibling backend into an isolated library, document,
  test and validate context. Re-running updates that development backend snapshot.
- `run-dev.ps1`: launch a fresh R process for the preview on loopback port 8780
  with `.local-data` storage, using `run-dev.R`. Never source the R launcher in a
  process previously used for tests.
- `check-runtime-isolation.R`: full offline suite plus verification that the real
  backend containment function is restored afterward. Run separately from the app.
- `check-reach-local.R`: read-only Reach previews for retained local Streams;
  optional first argument selects a local study-store folder (default `.local-data`).
  Checks file hashes before/after and never saves a Reach or queries USGS.
- `check-saved-boundary-corridor.R`: explicit saved-study key, public COMID,
  distance/unit and optional cached public sf RDS. Reads active data, reports
  original/retained channel length and tests backend plus Shiny preview/save/reopen
  only in separate output copies. Verifies the active study stays unchanged.
  Without a cache, makes one public NLDI feature request.
- `check-package.ps1`: Windows package build/check, with process-local locale
  corrections restored on exit. No remote deployment or global R installation.
- `check-stream-selection.R`: offline full app suite with the isolated backend;
  uses temporary test studies, never edits active `.local-data` records.
- `check-stream-services.R`: opt-in public USGS Madison geometry and Stream-save
  check in a fresh dev/check-output folder; never opens active studies.
- `check-reach-split-local.R`: read-only split previews against retained Reaches,
  with before/after file hashes; it does not publish splits or alter user records.
