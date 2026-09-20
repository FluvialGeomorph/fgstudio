# Run independently of the analyst app. Fail if tests leak a mocked backend.
# Require all JavaScript contracts in the maintainer workflow. No network or installs.
if (!nzchar(Sys.which("node"))) stop("Install Node.js and add it to PATH before running maintainer checks.")
Sys.setenv(FGSTUDIO_REQUIRE_NODE = "true")
.libPaths(c(normalizePath("dev/local-library"),.libPaths()))
pkgload::load_all(".",quiet=TRUE)
before <- fluvgeo::check_study_area_containment
cancel_before <- fluvgeo::cancel_stream_dem_download
results <- testthat::test_local(".",reporter="summary",stop_on_failure=TRUE)
stopifnot(identical(before,fluvgeo::check_study_area_containment))
stopifnot(identical(cancel_before,fluvgeo::cancel_stream_dem_download))
cat("Backend containment and download cancellation functions unchanged after the full test suite.\n")
cat("Assertions passed:",sum(as.data.frame(results)$passed),"\n")
