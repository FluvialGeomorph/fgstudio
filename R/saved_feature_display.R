# Presentation uses saved identities; no geometry or hierarchy is changed.
saved_feature_choices <- function(study, level) {
  x <- study[[paste0(level, "_inventory")]]
  if (is.null(x) || !nrow(x)) return(character())
  names <- x[[paste0(level, "_name")]]
  labels <- names
  parent <- rep("", length(names))
  if (level == "reach") {
    parent <- study$stream_inventory$stream_name[
      match(x$stream_id, study$stream_inventory$stream_id)]
    labels <- paste(parent, names, sep = " / ")
  }
  i <- order(tolower(parent), tolower(names), x[[paste0(level, "_id")]])
  stats::setNames(x[[paste0(level, "_id")]][i], labels[i])
}

saved_feature_shape <- function(study, level, id) {
  x <- study[[paste0(level, "_inventory")]]
  if (!inherits(x, "sf") || length(id) != 1L || is.na(id)) return(NULL)
  x[x[[paste0(level, "_id")]] %in% id, ]
}

focus_saved_feature <- function(map, shape) {
  if (!inherits(shape, "sf") || !nrow(shape) || all(sf::st_is_empty(shape))) return(map)
  b <- sf::st_bbox(sf::st_transform(shape, 4326))
  leaflet::fitBounds(map, b[[1]], b[[2]], b[[3]], b[[4]],
    options = list(maxZoom = 16, padding = c(35, 35)))
}

saved_feature_popup <- function(study, level, i) {
  x <- study[[paste0(level, "_inventory")]]
  fields <- c(Type = if (level == "stream") "Stream" else "Reach",
    Name = x[[paste0(level, "_name")]][i], `Study Area` = study$name)
  if (level == "reach") fields <- c(fields, Stream = study$stream_inventory$stream_name[
    match(x$stream_id[i], study$stream_inventory$stream_id)]) else
      fields <- c(fields, Reaches = sum(study$reach_inventory$stream_id %in% x$stream_id[i]))
  fields <- c(fields, ID = x[[paste0(level, "_id")]][i])
  as.character(htmltools::tags$table(class = "table table-sm mb-0",
    lapply(seq_along(fields), function(j) htmltools::tags$tr(
      htmltools::tags$th(names(fields)[j]), htmltools::tags$td(unname(fields[j]))))))
}

saved_feature_layers <- function(map, study, identify = FALSE) {
  for (level in c("stream", "reach")) {
    group <- if (level == "stream") "Saved Streams" else "Saved Reaches"
    map <- leaflet::clearGroup(map, group)
    x <- study[[paste0(level, "_inventory")]]
    if (!inherits(x, "sf") || !nrow(x)) next
    map <- leaflet::addPolygons(map, data = sf::st_transform(x, 4326), group = group,
      layerId = paste0("saved-", level, "-", x[[paste0(level, "_id")]]),
      color = if (level == "stream") "#00796b" else "#6a51a3", weight = 2,
      fillOpacity = .12, label = if (identify) x[[paste0(level, "_name")]] else NULL,
      labelOptions = leaflet::labelOptions(noHide = TRUE, direction = "center"),
      popup = if (identify) vapply(seq_len(nrow(x)), function(i)
        saved_feature_popup(study, level, i), character(1)) else NULL,
      options = leaflet::pathOptions(interactive = identify, bubblingMouseEvents = FALSE))
  }
  map
}

saved_hierarchy_inventory <- function(study) {
  streams <- study$stream_inventory
  if (is.null(streams) || !nrow(streams)) return(NULL)
  reaches <- study$reach_inventory
  rows <- lapply(order(tolower(streams$stream_name)), function(i) {
    r <- if (!is.null(reaches)) reaches[reaches$stream_id %in% streams$stream_id[i], ] else NULL
    if (!is.null(r) && nrow(r)) r <- r[order(tolower(r$reach_name)), ]
    data.frame(Stream = streams$stream_name[i],
      `Stream area` = if (inherits(streams, "sf")) "Recorded" else "Not defined",
      Reach = if (!is.null(r) && nrow(r)) r$reach_name else "Not yet defined",
      `Reach area` = if (!is.null(r) && nrow(r)) {
        if (inherits(r, "sf")) "Recorded" else "Not defined"
      } else "", check.names = FALSE)
  })
  do.call(rbind, rows)
}
