# R package development

## Applicable evidence

- Package metadata and dependencies: `DESCRIPTION`
- Exported interface: `NAMESPACE`, roxygen source, and generated `man/`
- Implementation: `R/`
- Behavioral verification: `tests/testthat/`
- User guidance: `README.Rmd`, vignettes, and pkgdown configuration

## Procedure

1. Inspect `DESCRIPTION`, `NAMESPACE`, relevant R functions, tests, and documentation.
2. Keep exported behavior, roxygen comments, generated help, examples, and tests aligned.
3. Prefer deterministic functions with structured return values for automation.
4. Run focused `testthat` tests, regenerate documentation when needed, then run package-level checks.
5. Review generated-file changes separately from hand-authored source changes.

Keep test execution and the analyst preview in different R processes. Start the
preview with `dev/scripts/run-dev.ps1`, not by sourcing the app after a test suite.
Inside Shiny `testServer` evaluation, use `with_mocked_bindings()` for explicit
mock scope; do not assume `local_mocked_bindings()` will clean up on leaving that
evaluation environment. Run `check-runtime-isolation.R` to verify restoration.

For map-search JavaScript changes, also run `node dev/scripts/check-map-search.cjs`
from the repository root. This is a pure contract test, not browser acceptance.

For the NHDPlusV2 tile adapter also run `node dev/scripts/check-network-reference.cjs`.
It covers zoom/mode gating, per-map state and pointer/event isolation without a
remote dependency. Public-service verification remains an opt-in smoke test.
