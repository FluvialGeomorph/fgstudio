# R package development

## Trigger and evidence

Read this workflow before changing R package code, dependencies, tests,
documentation, build/check tooling or development automation. Inspect the relevant
`DESCRIPTION`, `NAMESPACE`, `R/`, `tests/testthat/`, roxygen/`man/`,
`README.md` or `README.Rmd`, vignettes and pkgdown configuration.

## Choose the standard facility first

| Task | Usual entry point |
| --- | --- |
| Load development code | `devtools::load_all()` or `pkgload::load_all()` |
| Test behavior | `devtools::test()` or `testthat::test_local()` |
| Generate function documentation | `devtools::document()` or `roxygen2::roxygenise()` |
| Build/check the package | `devtools::check()` or standard `R CMD build` / `R CMD check` |
| Build the documentation site | `pkgdown::build_site()` |

Before adding or retaining a wrapper, inspect the existing tool's supported
options. Use metadata and configuration when they meet the need. Custom code must
address a demonstrated gap; record the standard facility considered, the gap and
when the workaround can be removed in a short code comment or existing workflow.
A script's existence or successful execution is not justification for keeping it.
Keep installation and workstation setup explicit and independently usable.

## Placement and verification

- Keep installed behavior in `R/`; regression assertions and controlled fixtures
  in the standard package test workflow. Use temporary outputs and scoped cleanup.
- Evaluate explicit opt-in conditions for live integration tests. Do not use real
  analyst data as automatic fixtures. Retain separate diagnostics only where
  their inputs or execution requirements warrant it.
- `dev/` may hold necessary developer tools; it must not become a parallel test
  suite or a replacement package-management interface. Do not add frameworks or
  dependencies solely to reorganize existing scripts.
- Keep implementation, exports, help, examples and tests aligned. Run focused
  tests first, then broader checks proportionate to the change; do not rebuild
  every artifact for dev-only prose edits.

## Completion

Review the diff for duplicate responsibilities, implicit side effects and
superseded wrappers. Update the existing workflow to describe the current
procedure, removing conflicting instructions. Verify that the AGENTS route and
this workflow suffice to choose the normal commands without reading a dated
report. Report relevant verification and remaining exceptions in the response;
do not create a routine completion narrative. Review generated changes separately.

## FG Studio execution constraints

- Owner requirement: every app-development turn must end with a reviewable UI
  update in a fresh local preview and precise directions to the changed controls.
  Keep increments small enough for owner feedback before proceeding. Do not build
  a backlog of backend functionality without UI review; if a backend-only step is
  necessary, clarify the intended reviewable outcome with the owner first.

- Scientific methods and their tests belong to fluvgeo. Use the existing isolated
  `dev/local-library` for app development; never replace the shared backend as a
  side effect of checking. In a fresh R session from this repository, select it
  with `.libPaths(c(normalizePath("dev/local-library", mustWork = TRUE), .libPaths()))`.
- Resolve R and Pandoc using the workspace workstation instructions. Keep the
  analyst preview in a separate R process. Within Shiny `testServer`, scope backend
  doubles with `with_mocked_bindings()` and verify restoration.
- JavaScript contracts run through `test-javascript.R`; use Node.js 18+ on PATH
  and `FGSTUDIO_REQUIRE_NODE=true` for complete maintainer checks. Without Node,
  ordinary package tests explicitly skip those contracts. The app needs no Node.
- The current scripts inventory is `dev/scripts/README.md`. Existing wrappers are
  legacy execution aids under review, not a requirement to create more wrappers.
  A Windows processx pipe issue motivated direct R CMD invocation; recheck that
  limitation before retaining its workaround. Rechecked 2026-09-20:
  `devtools::check(document=FALSE, manual=FALSE, cran=FALSE)` still fails creating
  a processx write pipe (Windows error 5); direct `R CMD build/check` remains the
  workstation fallback. For sandboxed vignette/site builds, set `R_CACHE_ROOTPATH`
  to an existing writable directory under `dev/check-output`; flow/styler otherwise
  attempts to write the per-user R cache outside the workspace.
  Start the local analyst preview with worker-process permission: a sandboxed
  Windows preview can serve pages yet fail to create processx supervisor pipes
  when a user starts background preflight, download or mask work.
  Keep live/local diagnostics opt-in.
- Follow `developer-documentation.md` when capabilities or call paths change.
  Code-map experiments are optional for routine package development.
