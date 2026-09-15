# Run independently of the analyst app. Fail if tests leak a mocked backend.
.libPaths(c(normalizePath("dev/local-library"),.libPaths()))
pkgload::load_all(".",quiet=TRUE)
before <- fluvgeo::check_study_area_containment
testthat::test_local(".",reporter="summary",stop_on_failure=TRUE)
stopifnot(identical(before,fluvgeo::check_study_area_containment))
cat("Backend containment function unchanged after the full test suite.\n")
