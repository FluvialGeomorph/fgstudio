# Import the package providing the bundled renderer (an asset-only dependency).
#' @import leafem
NULL

# Display-only tile transport: no Features query, spatial analysis or study write.
add_network_reference <- function(map, enabled = FALSE) {
  bundle <- system.file("htmlwidgets/lib/protomaps", package = "leafem", mustWork = TRUE)
  map$dependencies <- c(map$dependencies, list(htmltools::htmlDependency(
    "fgstudio-protomaps", "1", src = bundle, script = "protomaps.min.js")))
  script <- system.file("www/network-reference.js", package = "fgstudio", mustWork = TRUE)
  htmlwidgets::onRender(map, paste(readLines(script, warn = FALSE), collapse = "\n"),
    data = list(enabled = enabled,
      url = paste0("https://api.water.usgs.gov/fabric/pygeoapi/collections/nhdflowline_network/",
        "tiles/WebMercatorQuad/{z}/{y}/{x}?f=mvt")))
}

# Self-contained because this function is serialized to the isolated callr worker.
# Keep remote warnings as evidence when the upstream client returns NULL.
drainage_request <- function(operation, argument, distance = 50) {
  warnings <- character()
  tryCatch(withCallingHandlers({
    if (operation == "locate") fluvgeo::locate_drainage_stream(argument)
    else fluvgeo::get_drainage_context(argument, distance)
  }, warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  }), error = function(e) {
    evidence <- paste(c(conditionMessage(e), warnings), collapse = "\n")
    # Classify only explicit transport evidence, never infer an outage from NULL.
    transport <- grepl("HTTP [45][0-9][0-9]|[Tt]imed? ?out|[Cc]ould not resolve|[Ff]ailed to connect|[Cc]onnection", evidence)
    too_far <- grepl("No stream snap within 200 metres", conditionMessage(e), fixed = TRUE)
    code <- if (transport) "service_unavailable" else if (too_far) "outside_snap_distance" else "unresolved"
    message <- if (transport) {
      "USGS request failed (service or connection problem). Your selected point is retained; try Snap to stream again without moving it."
    } else if (too_far) {
      "The returned stream location was beyond 200 m. Click closer to the blue NHDPlusV2 reference channel."
    } else {
      "The request could not resolve a usable stream or response. This does not establish that your click was too far away. Retry the same point or review the request details."
    }
    stop(errorCondition(message, class = "fgstudio_drainage_error", code = code, details = evidence))
  })
}
