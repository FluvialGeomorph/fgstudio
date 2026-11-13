#!/usr/bin/env Rscript

# Capture the stable, top-level FG Studio workflow for the pkgdown guide.
#
# Start a development preview with a complete saved study, then run:
# Rscript --vanilla dev/scripts/capture-doc-screenshots.R \
#   "http://127.0.0.1:8780/?study=<study-key>"

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1L || !nzchar(args[[1L]])) {
  stop(
    "Supply the URL of a running FG Studio preview with a complete saved study.",
    call. = FALSE
  )
}

if (!requireNamespace("chromote", quietly = TRUE)) {
  stop(
    "Install the suggested chromote package to regenerate documentation screenshots.",
    call. = FALSE
  )
}

preview_url <- args[[1L]]
output_dir <- file.path("vignettes", "figures", "study-workflow")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

steps <- data.frame(
  tab = c(
    "Overview",
    "Study Structure",
    "Collections",
    "Analysis CRS",
    "Survey Events",
    "Hydro Modify",
    "Flowline",
    "Flowline Points"
  ),
  file = sprintf("%02d-%s.png", 1:8, c(
    "overview",
    "study-structure",
    "collections",
    "analysis-crs",
    "survey-events",
    "hydro-modify",
    "flowline",
    "flowline-points"
  )),
  ready = c(
    "Review this Study",
    "Saved Streams and Reaches",
    "Selected Survey Collections",
    "Use an authoritative definition",
    "Elevation:",
    "Saved candidate:",
    "Reach Flowlines are saved automatically",
    "Saved Flowline Points are ready"
  ),
  stringsAsFactors = FALSE
)

js_string <- function(value) {
  jsonlite::toJSON(value, auto_unbox = TRUE)
}

session <- tryCatch(
  chromote::ChromoteSession$new(width = 1600L, height = 1000L),
  error = function(error) {
    stop(
      paste0(
        "Could not start the screenshot browser: ", conditionMessage(error),
        "\nClose managed/headless browser sessions and retry from a normal ",
        "developer terminal."
      ),
      call. = FALSE
    )
  }
)
on.exit(session$close(), add = TRUE)

evaluate <- function(expression) {
  result <- session$Runtime$evaluate(
    expression = expression,
    returnByValue = TRUE,
    awaitPromise = TRUE
  )
  if (!is.null(result$exceptionDetails)) {
    stop("Browser evaluation failed while capturing documentation.", call. = FALSE)
  }
  result$result$value
}

wait_until <- function(predicate, timeout = 45, interval = 0.25) {
  started <- Sys.time()
  repeat {
    if (isTRUE(evaluate(predicate))) {
      return(invisible(TRUE))
    }
    if (as.numeric(difftime(Sys.time(), started, units = "secs")) >= timeout) {
      stop("Timed out waiting for the requested app view.", call. = FALSE)
    }
    Sys.sleep(interval)
  }
}

session$Page$navigate(url = preview_url)
wait_until("document.readyState === 'complete'")
wait_until(
  paste0(
    "typeof Shiny !== 'undefined' && Shiny.shinyapp && ",
    "Shiny.shinyapp.$socket && Shiny.shinyapp.$socket.readyState === 1"
  )
)

for (index in seq_len(nrow(steps))) {
  tab_name <- steps$tab[[index]]
  tab_json <- js_string(tab_name)
  click_tab <- paste0(
    "(() => {",
    "const tabs = [...document.querySelectorAll('[role=tab]')];",
    "const tab = tabs.find(x => x.textContent.trim() === ", tab_json, ");",
    "if (!tab) return false; tab.click(); return true;",
    "})()"
  )
  if (!isTRUE(evaluate(click_tab))) {
    stop("Could not find the top-level tab: ", tab_name, call. = FALSE)
  }

  selected <- paste0(
    "[...document.querySelectorAll('[role=tab]')].some(x => ",
    "x.textContent.trim() === ", tab_json,
    " && x.getAttribute('aria-selected') === 'true')"
  )
  wait_until(selected)
  ready_text <- js_string(steps$ready[[index]])
  wait_until(paste0("document.body.innerText.includes(", ready_text, ")"))
  wait_until(
    "!document.documentElement.classList.contains('shiny-busy') && ",
    "![...document.querySelectorAll('.recalculating')].some(x => ",
    "x.offsetParent !== null) && ",
    "![...document.querySelectorAll('[role=progressbar]')].some(x => ",
    "x.offsetParent !== null)"
  )
  Sys.sleep(1.5)

  session$screenshot(
    filename = file.path(output_dir, steps$file[[index]]),
    selector = NULL,
    cliprect = "viewport",
    scale = 1,
    delay = 0
  )
  message(sprintf("Captured %d/8: %s", index, tab_name))
}

message("Documentation screenshots written to ", output_dir)
