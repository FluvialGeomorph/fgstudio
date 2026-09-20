# Build the backend into an isolated app-development library, never a shared one.
lib <- file.path(getwd(), "dev", "local-library")
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
backend <- normalizePath("../fluvgeo", winslash = "/", mustWork = TRUE)
status <- system2(file.path(R.home("bin"), "R.exe"),
  c("CMD", "INSTALL", "--no-multiarch", paste0("--library=", shQuote(lib)), shQuote(backend)))
if (status != 0L) stop("Backend installation failed.")
.libPaths(c(lib, .libPaths()))
devtools::document(".")
source("dev/scripts/check-tests.R")
pkgload::load_all("../reproducibleai", quiet = TRUE)
print(reproducibleai::validate_agentic_context(".", strict = TRUE))
