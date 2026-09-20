# Development scripts and verification boundaries

`dev/` is excluded by `.Rbuildignore`. These scripts are maintained developer
tools and optional qualification, not an alternative to `tests/testthat/`.
Script-only assertions do **not** run in `R CMD check` unless a maintained runner
explicitly invokes them. JavaScript contracts now run through
`tests/testthat/test-javascript.R` using fixtures under that test tree.

## Maintained tooling

| Scripts | Purpose and execution boundary |
| --- | --- |
| `run-dev.ps1`, `run-dev.R` | Start the loopback preview in a fresh R process, using `.local-data`; never source in a process that ran mocked tests |
| `prepare-dev.R` | Install the sibling backend into the isolated development library, regenerate app documentation, run package tests and validate repository context; deliberately changes the development snapshot |
| `check-package.ps1` | Windows R/Pandoc/locale orchestration around standard package build and check |
| `check-tests.R` | Run the ordinary package suite and then check two backend functions for leaked mocks; adds a suite-level process check, not a replacement regression suite |
| `build-docs.ps1`, `build-docs.R`, `build-code-map.R` | Build isolated documentation, site navigation and source map; no study changes or publication |
| `code-map-utils.R`, `query-code-map.R`, `check-code-map.R` | Developer-only graph helpers, lookup/freshness and bridge checks; checked by the documentation build |
| `check-docs.R` | Local HTML link/anchor and article-export validation; called after the site build, no network |

## Optional live-service qualification

Run explicitly from the repository root with the isolated library. These use
public services and synthetic study areas; they do not open analyst studies.
Failures may reflect service availability and must not be presented as equivalent
to deterministic fixture-test failures. The behavior they exercise also needs
appropriate stable tests in the owning package.

- `check-drainage-services-live.R`, `check-stream-services-live.R` and
  `check-polygon-selection-live.R`: public drainage/geometry requests and bounded
  preparation checks.
- `check-survey-collections-live.R`: catalog queries and temporary persistence.
- `check-stream-dem-files-live.R`: metadata-only source DEM discovery.
- `check-dem-download-live.R`: one reported <=16 MiB public tile, with worker,
  readback and reuse checks. Outputs remain in ignored `dev/check-output`.

## Local-data diagnostics

These depend on existing files and are not suitable as automatic package tests.
Inspect their input/output contracts before running them; `.local-data` is not a
package fixture store.

- `check-reach-local.R`: read-only previews against a selected store (default
  `.local-data`), with before/after file hashes.
- `check-reach-split-local.R`: read-only previews against `.local-data`, with hashes.
- `check-saved-boundary-corridor.R`: explicit study key, public COMID, distance/unit
  and optional cached public sf RDS. Reads a real boundary; save/reopen checks use
  separate output copies. Makes a public request when no cache is supplied.
- `check-dem-inspection-local.R`: explicitly supplied existing download attempt;
  real worker and UI checks, optional preview PNGs in `dev/check-output`.

## Existing execution aids

Use the standard commands in [R package development](../workflows/r-package-development.md)
first. The following legacy wrappers remain available from the repository root
with the existing isolated backend library and Node.js 18 or newer on PATH;
their responsibilities still need review against standard facilities:

- `Rscript --vanilla dev/scripts/check-tests.R`: app package tests, JavaScript
  contracts and backend mock-restoration checks; no installation or network.
- `dev/scripts/check-package.ps1`: source build and R CMD check, including
  installed-package JavaScript contracts and vignettes.

Both runners require Node. Plain testthat/R CMD check explicitly skip the three
JavaScript contracts when Node is absent; automation should set
`FGSTUDIO_REQUIRE_NODE=true` to prohibit that skip. The app itself needs no Node.
See [package development](../workflows/r-package-development.md) for focused checks.

The duplicate `check-stream-selection.R`, workstation-specific `check-purpose.R`
and completed initial `bootstrap.R` were retired on 2026-09-20. Their history
remains in Git. `check-runtime-isolation.R` was renamed to `check-tests.R`;
`prepare-dev.R` now calls it after its explicitly requested backend installation.
No ordinary check installs the backend or runs the backend's legacy suite.

Ignored `dev/check-output` holds transient logs/artifacts, not the sole maintained
definition of required checks. Stable regressions belong in package tests.
