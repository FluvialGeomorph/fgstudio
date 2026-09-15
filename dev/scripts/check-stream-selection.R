.libPaths(c(normalizePath("dev/local-library"), .libPaths()))
pkgload::load_all(".", quiet=TRUE)
testthat::test_local(".", stop_on_failure=TRUE)
