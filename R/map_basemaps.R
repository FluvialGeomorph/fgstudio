# Keep provider attribution and overzoom the last available tiles for DEM inspection.
# OpenTopoMap is the project-wide default. Collection footprints deliberately
# use Street map so their colored outlines remain distinct from the basemap.
fg_leaflet <- function(max_zoom=23) {
  leaflet::leaflet(options=leaflet::leafletOptions(maxZoom=max_zoom,
    preferCanvas=TRUE))
}

add_opentopomap <- function(map,pane="tilePane",default="OpenTopoMap") {
  if(!default %in% c("OpenTopoMap","Street map"))
    stop("Basemap default must be OpenTopoMap or Street map.")
  map <- leaflet::addProviderTiles(map,"OpenTopoMap",group="OpenTopoMap",
    options=leaflet::providerTileOptions(maxNativeZoom=17,maxZoom=23,noWrap=TRUE,pane=pane)) |>
    leaflet::hideGroup("Imagery")
  if(identical(default,"Street map"))
    leaflet::hideGroup(map,"OpenTopoMap")
  else leaflet::hideGroup(map,"Street map")
}
