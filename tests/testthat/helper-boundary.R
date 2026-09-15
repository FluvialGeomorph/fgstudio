draw_fixture <- function(points = list(c(-96, 41), c(-95.9, 41),
    c(-95.9, 41.1), c(-96, 41.1), c(-96, 41))) {
  list(type = "FeatureCollection", features = list(list(type = "Feature",
    properties = list(), geometry = list(type = "Polygon", coordinates = list(points)))))
}
