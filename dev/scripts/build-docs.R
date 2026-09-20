# Run from fgstudio in a fresh R process, not the analyst preview.
stopifnot(read.dcf("DESCRIPTION")[1, "Package"] == "fgstudio")
.libPaths(c(normalizePath("dev/local-library", mustWork = TRUE), .libPaths()))
required <- c("pkgdown", "flow", "pkgnet", "knitr", "rmarkdown")
for (p in required) if (!requireNamespace(p, quietly = TRUE)) stop("Install development dependency: ", p)
# Article workers and pkgnet need an installed snapshot, not pkgload's namespace.
# Install only the app into a documentation-only library; never replace fluvgeo.
doclib <- file.path(getwd(), "dev/check-output/doc-library")
dir.create(doclib, recursive = TRUE, showWarnings = FALSE)
old_libs <- Sys.getenv("R_LIBS")
Sys.setenv(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
status <- system2(file.path(R.home("bin"), "R.exe"), c("CMD", "INSTALL",
  "--no-multiarch", "--no-test-load", paste0("--library=", shQuote(doclib)), "."))
Sys.setenv(R_LIBS = old_libs)
if (status != 0L) stop("Documentation snapshot installation failed.")
.libPaths(c(doclib, .libPaths()))
source("dev/scripts/build-code-map.R")
source("dev/scripts/check-code-map.R")
# Keep one landing-page source. GitHub needs vignette source links; the built
# site needs article HTML links. pkgdown/index.md is disposable generated input.
dir.create("pkgdown", showWarnings = FALSE)
home <- readLines("README.md", warn = FALSE, encoding = "UTF-8")
home <- gsub("\\]\\(vignettes/([^)]*)\\.Rmd\\)", "](articles/\\1.html)", home)
writeLines(c("<!-- Generated from README.md by dev/scripts/build-docs.R; do not edit. -->",home),
  "pkgdown/index.md",useBytes=TRUE)
pkgdown::build_site(".", devel = FALSE, new_process = FALSE, install = FALSE,
  preview = FALSE, quiet = FALSE)
source("dev/scripts/check-docs.R")
cat("Local site: ", normalizePath("docs/index.html", winslash = "/"), "\n", sep = "")
