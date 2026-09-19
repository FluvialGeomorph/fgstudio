# Deterministic development checks; no analyst data and no source mutation.
source("dev/scripts/code-map-utils.R")
map <- jsonlite::read_json("dev/architecture/call-network.json")
stopifnot(code_map_fresh(map))
bad <- map; bad$inputs[[1]]$sha256 <- "stale"
stopifnot(!code_map_fresh(bad))
bad <- map; bad$inputs <- bad$inputs[-1]
stopifnot(!code_map_fresh(bad))
split <- code_map_neighborhood(map, "fluvgeo::split_study_reach")
stopifnot(length(split) == 1L, split[[1]]$kind == "injected-writer",
  split[[1]]$evidence == "reviewed-source-bridge")
entry <- code_map_neighborhood(map, "fgstudio::fgstudio_app")
stopifnot(any(vapply(entry, function(x) x$to == "fgstudio::local_study_store", logical(1))))
stopifnot(length(code_map_neighborhood(map, "unindexed::unknown")) == 0L)
bridges <- jsonlite::read_json("dev/architecture/reviewed-call-bridges.json")$edges
invisible(lapply(bridges, code_map_bridge))
bad <- bridges[[1]]; bad$anchor <- "anchor deliberately absent"
stopifnot(inherits(try(code_map_bridge(bad), silent = TRUE), "try-error"))
cat("Code-map freshness, direct/indirect lookup and missing-anchor checks passed.\n")
