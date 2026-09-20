# Opt-in live public-service and saved-evidence check. No active user data access.
.libPaths(c(normalizePath("dev/local-library"), .libPaths()))
pkgload::load_all(".", quiet = TRUE)
collect <- function(job) {
  on.exit(if (job$is_alive()) job$kill(), add = TRUE)
  job$wait(120000)
  if (job$is_alive()) stop("Public-service request timed out.")
  job$get_result()
}
point <- sf::st_sf(geometry=sf::st_sfc(sf::st_point(c(-89.35306,43.08451)),crs=4326))
location <- collect(launch_drainage_job("locate",point))
context <- collect(launch_drainage_job("context",location,30))
sources <- polygon_candidates(context)
if (is.null(sources) || !all(c("huc12","basin") %in% sources$source_type))
  stop("Both live polygon types are required for this test; inspect service outcomes.")
preview <- fluvgeo::combine_study_area_polygons(sources)
root <- tempfile("polygon-selection-", tmpdir="dev/check-output")
store <- local_study_store(root)
study <- store$create("Public Madison polygon-selection test")
saved <- store$save_selected_boundary(study$key,sources,study$path,"Live test, not a user study.")
stopifnot(saved$boundary, identical(study$study_id,saved$study_id),
  lengths(sf::st_equals(saved$boundary_sf,preview$boundary)) == 1L)
cat("Live HUC12 and basin combined and saved;",preview$polygon_parts,"polygon parts.\n")
cat("Verified test evidence retained under",root,"\n")
