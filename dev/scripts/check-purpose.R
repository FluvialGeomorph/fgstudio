# Focused cross-repository verification; use only the isolated development library.
backend <- normalizePath("../fluvgeo", winslash = "/")
# Exported help was regenerated separately; avoid namespace-wide roxygen churn.
Sys.setlocale("LC_CTYPE", "English_United States.utf8")
.libPaths(c(.libPaths(), "C:/Users/R1Suser/AppData/Local/Programs/R/R-4.6.1/library"))
Sys.setenv(RSTUDIO_PANDOC = file.path(Sys.getenv("LOCALAPPDATA"),
  "Programs/Positron/resources/app/quarto/bin/tools"))
devtools::test(backend,
  filter = "study_context$|study_purpose|start_study_context|study_context_boundary",
  reporter = "summary", stop_on_failure = TRUE)
source("dev/scripts/prepare-dev.R")
