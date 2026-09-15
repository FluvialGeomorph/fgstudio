# Run from the fgstudio root in a FRESH R process (run-dev.ps1).
# Never source this script in an R process used for tests or mocked bindings.
# No changes to shared/production libraries.
if (!file.exists("DESCRIPTION") || read.dcf("DESCRIPTION")[1, "Package"] != "fgstudio")
  stop("Run this script from the fgstudio repository root.")
lib <- normalizePath("dev/local-library", winslash = "/", mustWork = TRUE)
.libPaths(c(lib, .libPaths()))
pkgload::load_all(".", quiet = TRUE)
fgstudio::run_app(data_dir = ".local-data", port = 8780, launch.browser = FALSE)
