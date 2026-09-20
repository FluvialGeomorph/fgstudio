# Execute shipped callbacks with bounded Node fixtures, in source or installed checks.
run_javascript_contract <- function(name, payload) {
  node <- Sys.which("node")
  if (!nzchar(node)) {
    if (identical(Sys.getenv("FGSTUDIO_REQUIRE_NODE"), "true")) {
      stop("Node.js is required by FGSTUDIO_REQUIRE_NODE=true; install Node.js and add it to PATH.")
    }
    testthat::skip("Node.js unavailable; JavaScript contracts require Node.js on PATH")
  }
  input <- withr::local_tempfile(fileext = ".json")
  jsonlite::write_json(payload, input, auto_unbox = TRUE)
  script <- testthat::test_path("javascript", paste0(name, ".cjs"))
  output <- suppressWarnings(system2(node, shQuote(c(script, input)),
    stdout = TRUE, stderr = TRUE))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  testthat::expect_equal(status, 0L, info = paste(output, collapse = "\n"))
}
