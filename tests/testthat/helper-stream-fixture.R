stream_test_context <- function() {
  line <- sf::st_sf(nhdplus_comid = c("101", "102"), gnis_name = c("Creek", "Creek"),
    geometry = sf::st_sfc(sf::st_linestring(rbind(c(-90,40),c(-90,40.01))),
      sf::st_linestring(rbind(c(-90,40.01),c(-90,40.02))), crs=4326))
  list(layers=list(upstream=line, downstream=line[1,]),
    location=list(comid="101"), retrieved_at="Test UTC",
    status=data.frame(layer=c("upstream","downstream"), status="available", outcome="available"))
}
stream_test_parent <- function() sf::st_sf(geometry=sf::st_sfc(sf::st_polygon(list(
  rbind(c(-90.1,39.9),c(-89.9,39.9),c(-89.9,40.1),c(-90.1,40.1),c(-90.1,39.9)))),crs=4326))
