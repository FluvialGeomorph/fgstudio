# Opt-in public Madison geometry check; never opens active .local-data.
.libPaths(c(normalizePath("dev/local-library"), .libPaths()))
pkgload::load_all(".",quiet=TRUE)
collect <- function(job) {
  on.exit(if (job$is_alive()) job$kill(),add=TRUE)
  job$wait(120000)
  if (job$is_alive()) stop("Public-service request timed out.")
  job$get_result()
}
point <- sf::st_sf(geometry=sf::st_sfc(sf::st_point(c(-89.35306,43.08451)),crs=4326))
location <- collect(launch_drainage_job("locate",point))
context <- collect(launch_drainage_job("context",location,30))
polygons <- polygon_candidates(context)
lines <- channel_candidates(context)
stopifnot(!is.null(polygons),!is.null(lines))
parent <- fluvgeo::combine_study_area_polygons(polygons)$boundary
# Test fixture selection only: choose a returned line whose 100 m corridor fits.
# This is not an automated recommendation of a user's Stream membership/width.
chosen <- NULL
for (i in seq_len(min(30L,nrow(lines)))) {
  preview <- fluvgeo::preview_stream_corridor(lines[i,],100)
  child <- sf::st_sf(stream_name="Test",geometry=sf::st_geometry(preview$area))
  if (fluvgeo::check_study_area_containment(parent,child)$status == "inside") {
    chosen <- lines[i,]; break
  }
}
if (is.null(chosen)) stop("No contained test corridor among first 30 candidates; inspect returned geography.")
root <- tempfile("stream-selection-",tmpdir="dev/check-output")
store <- local_study_store(root)
study <- store$create("Public Madison Stream test")
study <- store$save_selected_boundary(study$key,polygons,study$path,"Public test, not a user study")
saved <- store$save_stream(study$key,chosen,"Test channel",100,"m","Public test, not analyst intent",study$path)
stopifnot(saved$streams==1L,identical(study$study_id,saved$study_id),
  fluvgeo::check_study_area_containment(saved$boundary_sf,saved$stream_inventory)$status=="inside")
saveRDS(context,file.path(root,"public-drainage-context.rds"))
cat("Saved/reopened contained Stream",chosen$source_id,"from",nrow(lines),"candidates.\n")
cat("Test evidence:",root,"\n")
