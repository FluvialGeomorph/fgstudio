# Repaint completed discovery after creation or mode changes, without a request.
drainage_layers <- function(map, state, target = "boundary") {
  for (g in c(unname(drainage_groups), "Located stream", "Selected location")) map <- leaflet::clearGroup(map, g)
  if (is.null(state)) return(map)
  colors <- c(upstream = "#3182bd", downstream = "#de2d26")
  for (key in names(colors)) {
    # Selectable candidate polygons/lines are painted by their own modules.
    if (target == "stream") next
    x <- state$result$layers[[key]]
    if (is.null(x)) next
    map <- leaflet::addPolylines(map, data = x, group = drainage_groups[[key]], color = colors[[key]],
      options = leaflet::pathOptions(interactive = FALSE))
  }
  located <- state$located
  if (!is.null(located$flowline)) map <- leaflet::addPolylines(map, data = located$flowline,
    group = "Located stream", color = "#d95f02", weight = 6, options = leaflet::pathOptions(interactive = FALSE))
  if (!is.null(located$snapped_point)) map <- leaflet::addCircleMarkers(map, data = located$snapped_point,
    group = "Located stream", color = "#d95f02", radius = 7, options = leaflet::pathOptions(interactive = FALSE))
  if (!is.null(state$clicked)) map <- leaflet::addCircleMarkers(map, data = state$clicked,
    group = "Selected location", color = "#222222", radius = 6, options = leaflet::pathOptions(interactive = FALSE))
  map
}

# Available overlays only, including unchecked overlays so users can restore them.
context_layer_groups <- function(mode, target, boundary = FALSE, saved_streams = FALSE,
                                 state = NULL, polygons = NULL, polygon_preview = NULL,
                                 channels = NULL, stream_preview = NULL) {
  groups <- c(character(), if (boundary) "boundary", if (saved_streams) "Saved Streams")
  if (!identical(mode, "explore")) return(groups)
  groups <- c("NHDPlusV2 reference channels", groups,
    if (!is.null(state$clicked)) "Selected location",
    if (!is.null(state$located)) "Located stream")
  if (identical(target, "stream")) {
    c(groups, if (!is.null(channels) && nrow(channels)) "Stream candidates",
      if (!is.null(stream_preview)) "Stream preview",
      if (isTRUE(stream_preview$clipped)) "Unclipped buffer")
  } else {
    keys <- c("upstream", "downstream")
    found <- vapply(keys, function(k) !is.null(state$result$layers[[k]]) && nrow(state$result$layers[[k]]) > 0L, logical(1))
    c(groups, unname(drainage_groups[keys[found]]),
      if (!is.null(polygons) && nrow(polygons)) "Boundary candidates",
      if (!is.null(polygon_preview)) "Boundary preview")
  }
}
