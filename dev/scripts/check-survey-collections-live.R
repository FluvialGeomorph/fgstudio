# Opt-in public catalog smoke check; synthetic Omaha-area AOI, no analyst data.
# Run from fgstudio with workstation Rscript. Creates only a temporary snapshot.
.libPaths(c(normalizePath("dev/local-library"),.libPaths()))
pkgload::load_all("../fluvgeo",quiet=TRUE)
b <- sf::st_sf(study_area_id="public-omaha-smoke",geometry=sf::st_sfc(sf::st_polygon(list(rbind(
  c(-96.1,41.25),c(-96.0,41.25),c(-96.0,41.35),c(-96.1,41.35),c(-96.1,41.25)))),crs=4326))
x <- fluvgeo::discover_survey_collections(b,max_records=100L)
print(x$searches[c("catalog","outcome","matched","returned","message")],row.names=FALSE)
print(sf::st_drop_geometry(x$records)[c("catalog","record_id","title","date_label","status","availability")],row.names=FALSE)
if(!nrow(x$records)) stop("No live records available for round-trip smoke check; inspect query outcomes.")
f <- tempfile(fileext=".gpkg")
print(fluvgeo::survey_collection_products(x)[c("candidate_key","product","dem_pixel_size_m","resolution_screen")],row.names=FALSE)
x$acquisition_plan <- data.frame(candidate_key=x$records$candidate_key[1],product="DEM")
fluvgeo::write_survey_collection_selection(x,x$records$candidate_key[1],f)
y <- fluvgeo::read_survey_collection_selection(f)
stopifnot(identical(y$selected,x$records$candidate_key[1]))
stopifnot(identical(as.data.frame(y$acquisition_plan),x$acquisition_plan))
unlink(f)
cat("Live discovery and temporary selection round trip passed; no study data changed.\n")
