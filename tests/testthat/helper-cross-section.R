cross_section_review_fixture <- function() {
  line <- sf::st_sf(reach_id="r1",ReachName="R1",geometry=sf::st_sfc(
    sf::st_linestring(rbind(c(0,0),c(200,0))),crs=26915))
  channel <- sf::st_sf(geometry=sf::st_buffer(sf::st_geometry(line),5,endCapStyle="FLAT"))
  floodplain <- sf::st_sf(geometry=sf::st_buffer(sf::st_geometry(line),30,endCapStyle="FLAT"))
  list(layout=fluvgeo::cross_section_layout(line,channel,floodplain),
    footprints=list(channel_outer=channel,floodplain_outer=floodplain))
}
