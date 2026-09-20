# Verification evidence: 2026-09-20

Historical results for the initial testing cleanup at fgstudio 0.0.0.9036.
These results establish tested behavior, not the necessity of retained tooling.

- Source and installed-package suites: 759 passing assertions, including three
  JavaScript contracts; installed-package run had zero skips. Backend containment
  and cancellation bindings were restored after the source suite.
- Missing-Node and deliberately broken callback probes confirmed skip/error
  handling and propagation of Node failures into testthat.
- R CMD check: no errors; one existing non-ASCII warning in
  `R/mod_survey_collections.R`. Eleven vignettes built and rebuilt.
- Documentation build: 264 local links/anchors across 13 pages and navigation/text
  exports for eleven articles passed. No browser acceptance was performed.

This record contains no standing development instructions.
