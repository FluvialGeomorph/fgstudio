# Focus newly checked features only. Deselecting or synchronizing checkbox
# lists must not move the map. Padding retains nearby spatial context.
focus_checked_features <- function(map, pool, previous, selected) {
  added <- setdiff(selected, previous)
  if (!length(added) || is.null(pool)) return(map)
  features <- pool[pool$candidate_key %in% added, ]
  if (!nrow(features)) return(map)
  b <- sf::st_bbox(sf::st_transform(features, 4326))
  leaflet::fitBounds(map, b[[1]], b[[2]], b[[3]], b[[4]],
    options = list(maxZoom = 16, padding = c(35, 35)))
}
