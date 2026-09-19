# Metadata only; synthetic public Omaha polygon. No user study data or raster IO.
.libPaths(c(normalizePath("dev/local-library"),.libPaths()))
pkgload::load_all("../fluvgeo",quiet=TRUE)
b <- sf::st_sf(study_area_id="synthetic-area",geometry=sf::st_as_sfc(sf::st_bbox(
  c(xmin=-96.10,ymin=41.335,xmax=-96.09,ymax=41.34),crs=4326)))
d <- fluvgeo::discover_survey_collections(b)
c <- d$records[d$records$catalog=="USGS 3DEP",]
if(!nrow(c)) stop("No USGS fixture collection returned; inspect service outcomes.")
s <- sf::st_sf(stream_id="synthetic-stream",geometry=sf::st_geometry(b))
r <- fluvgeo::discover_stream_dem_files(s,c[1,])
print(r[c("outcome","message","retrieved_at")])
print(sf::st_drop_geometry(r$files)[c("file_id","title","size_bytes","pixel_size_m")],row.names=FALSE)
stopifnot(r$outcome=="COMPLETE",nrow(r$files)>0L,all(lengths(sf::st_intersects(r$files,s))>0L))
cat("Live metadata-only Stream DEM file check passed. No rasters downloaded.\n")
