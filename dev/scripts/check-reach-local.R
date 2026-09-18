# Read-only compatibility check against retained local studies. Never saves Reaches.
.libPaths(c(normalizePath("dev/local-library"), .libPaths()))
pkgload::load_all(".", quiet = TRUE)
args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) args[1] else ".local-data"
stopifnot(dir.exists(root))
files <- list.files(root, full.names = TRUE, recursive = TRUE)
before <- tools::md5sum(files)
store <- local_study_store(root)
checked <- 0L
merges <- 0L
ordered <- 0L; unresolved <- 0L
for (key in unname(store$catalog()$choices)) {
  study <- store$read(key)
  if (!inherits(study$stream_inventory, "sf")) next
  for (id in study$stream_inventory$stream_id) {
    source <- store$stream_segments(key, id, study$path)
    ordered <- ordered + sum(source$ordering$order_status == "ordered")
    unresolved <- unresolved + sum(source$ordering$order_status != "ordered")
    saved <- unique(source$reach_mappings$reach_id)
    if (length(saved) >= 2L) {
      view <- store$preview_reach_merge(key, saved[1:2], saved[1], study$path)
      stopifnot(identical(view$retain_reach_id, saved[1]),
        view$distance_m == source$distance_m)
      merges <- merges + 1L
    }
    available <- setdiff(source$lines$selection_id, source$assigned_selection_ids)
    if (length(available)) {
      view <- store$preview_reach(key, id, available[1], study$path)
      stopifnot(view$distance_m == source$distance_m,
        isTRUE(sf::st_crs(view$area) == sf::st_crs(source$lines)))
      checked <- checked + 1L
    }
  }
}
stopifnot(identical(files, list.files(root, full.names = TRUE, recursive = TRUE)),
  identical(before, tools::md5sum(files)))
cat("Read-only Reach previews verified for", checked, "saved Streams; study files unchanged.\n")
cat("Read-only saved-Reach merge previews verified for", merges, "Streams.\n")
cat("Retained candidate order:", ordered, "ordered;", unresolved, "unresolved.\n")
