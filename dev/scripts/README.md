# Development scripts

Store maintained automation supporting development workflows here. Scripts should document inputs, outputs, dependencies, and safe execution expectations.

Run from the repository root:

- `bootstrap.R`: initial usethis scaffold; already completed, not a routine launcher.
- `prepare-dev.R`: build the sibling backend into an isolated library, document,
  test and validate context. Re-running updates that development backend snapshot.
- `run-dev.ps1`: launch a fresh R process for the preview on loopback port 8780
  with `.local-data` storage, using `run-dev.R`. Never source the R launcher in a
  process previously used for tests.
- `check-runtime-isolation.R`: full offline suite plus verification that the real
  backend containment function is restored afterward. Run separately from the app.
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
