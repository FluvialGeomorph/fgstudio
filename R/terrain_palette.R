# Matches fluvgeo::get_terrain_leaflet(), low to high elevation.
terrain_palette <- function(n=256L) grDevices::colorRampPalette(c(
  "cadetblue2","khaki1","chartreuse4","goldenrod1",
  "orangered4","saddlebrown","gray70","white"))(n)
