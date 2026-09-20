test_that("map search JavaScript handles responses, cancellation and safe labels", {
  map <- add_place_search(leaflet::leaflet())
  options <- map$x$calls[[1]]$args[[1]]
  run_javascript_contract("map-search", list(
    snippets = unname(lapply(options[c("sourceData", "formatData", "filterData", "buildTip")], as.character)),
    hook = as.character(map$jsHooks$render[[1]]$code)))
})

test_that("network JavaScript isolates maps, gates tiles and disposes events", {
  asset <- system.file("www", "network-reference.js", package = "fgstudio", mustWork = TRUE)
  run_javascript_contract("network-reference", list(hook = paste(readLines(asset), collapse = "\n")))
})

test_that("CRS dropdown JavaScript handles viewport, scroll and cleanup", {
  options <- crs_selectize_options()
  run_javascript_contract("crs-dropdown",
    lapply(options[c("onInitialize", "onDropdownOpen", "onLoad")], as.character))
})
