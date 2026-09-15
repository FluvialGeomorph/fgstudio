# One-time package scaffold; run from the fgstudio repository root.
authors <- gsub("\n", "\n    ", read.dcf("../fluvgeo/DESCRIPTION")[1, "Authors@R"])
usethis::create_package(normalizePath(".", winslash = "/"), open = FALSE, fields = list(
  Title = "FluvialGeomorph Studio",
  Version = "0.0.0.9000",
  `Authors@R` = authors,
  Description = paste("A browser workspace for defining FluvialGeomorph studies.",
    "Provides a modular Shiny interface to shared fluvgeo capabilities,",
    "beginning with durable local Study Area drafts."),
  License = "CC0",
  URL = "https://github.com/FluvialGeomorph/fgstudio",
  BugReports = "https://github.com/FluvialGeomorph/fgstudio/issues"
))
usethis::use_testthat(edition = 3)
usethis::use_package("shiny", min_version = "1.8.1")
usethis::use_package("bslib", min_version = "0.9.0")
if (!requireNamespace("fluvgeo", quietly = TRUE)) pkgload::load_all("../fluvgeo", quiet = TRUE)
usethis::use_package("fluvgeo", min_version = "2026.09.13.9018")
usethis::use_package("openssl")
usethis::use_package("withr", type = "Suggests")
usethis::use_package("pkgload", type = "Suggests")
usethis::use_build_ignore(c("dev", "AGENTS.md", "app.R", ".local-data", "LICENSE"))
usethis::use_git_ignore(c(".local-data/", "dev/local-library/", "dev/check-output/",
  "*.Rcheck/", "*.tar.gz", ".Rhistory", ".RData", ".Renviron"))
