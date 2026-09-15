# Opt-in public-service smoke test, run from fgstudio. No user study access.
.libPaths(c(normalizePath("dev/local-library"), .libPaths()))
pkgload::load_all(".", quiet = TRUE)
point <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(-89.35306, 43.08451)), crs = 4326))
collect <- function(job) {
  on.exit(if (job$is_alive()) job$kill(), add = TRUE)
  job$wait(120000)
  if (job$is_alive()) stop("Public-service smoke test exceeded 120 seconds.")
  job$get_result()
}
# Invalid input fails locally; verify diagnostic fields survive the process boundary.
failure <- tryCatch(collect(launch_drainage_job("locate", NULL)), error = identity)
stopifnot(inherits(failure$parent, "fgstudio_drainage_error"),
  identical(failure$parent$code, "unresolved"),
  nzchar(failure$parent$details))
cat("Worker error details retained across process boundary.\n")
location <- collect(launch_drainage_job("locate", point))
cat("Located COMID", location$comid, "at", round(location$snap_distance_m, 2), "metres.\n")
result <- collect(launch_drainage_job("context", location, 30))
print(result$status)
if (any(result$status$status != "available"))
  stop("Some candidate layers were unavailable; inspect service status before attributing a regression.")
# Verify the same process control used by the Cancel button, without another request.
job <- callr::r_bg(function() Sys.sleep(120), stdout = NULL, stderr = NULL,
  user_profile = FALSE, system_profile = FALSE, supervise = TRUE)
stopifnot(job$is_alive())
job$kill(); job$wait(5000)
stopifnot(!job$is_alive())
cat("Worker cancellation verified. No project records read or written.\n")
