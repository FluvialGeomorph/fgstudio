# Keep provider attribution and overzoom the last available tiles for DEM inspection.
# OpenTopoMap is the project-wide default; callers may still expose the other
# groups in their layer controls.
add_opentopomap <- function(map,pane="tilePane") {
  leaflet::addProviderTiles(map,"OpenTopoMap",group="OpenTopoMap",
    options=leaflet::providerTileOptions(maxNativeZoom=17,maxZoom=23,noWrap=TRUE,pane=pane)) |>
    leaflet::hideGroup("Street map") |>
    leaflet::hideGroup("Imagery")
}
