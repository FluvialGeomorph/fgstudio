# Query from fgstudio root. Read-only; refuses stale snapshots.
source("dev/scripts/code-map-utils.R")
map <- jsonlite::read_json("dev/architecture/call-network.json")
if (!code_map_fresh(map)) stop("Code map is stale. Review changes and rebuild documentation first.")
args <- commandArgs(trailingOnly = TRUE)
if (!length(args) || identical(args, "--check")) {
  cat("Code map source hashes are current; graph completeness is not implied.\n")
} else {
  if (length(args) != 1L) stop("Supply one package-qualified symbol or --check.")
  edges <- code_map_neighborhood(map, args[[1]])
  cat(jsonlite::toJSON(list(symbol = args[[1]], relationships = edges,
    note = "Empty results mean not indexed, not no callers."), pretty = TRUE, auto_unbox = TRUE), "\n")
}
