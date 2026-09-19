# Source after installing the exact fgstudio snapshot into the documentation library.
source("dev/scripts/code-map-utils.R")
reporter <- pkgnet::FunctionReporter$new()
reporter$set_package("fgstudio")
raw_nodes <- as.data.frame(reporter$nodes)
raw_edges <- as.data.frame(reporter$edges)
stopifnot(all(c("SOURCE", "TARGET") %in% names(raw_edges)))
rfiles <- list.files("R", pattern = "\\.R$", full.names = TRUE)
nodes <- lapply(seq_len(nrow(raw_nodes)), function(i) {
  name <- raw_nodes$node[i]
  hits <- lapply(rfiles, function(f) grep(paste0(name, " <- function"),
    readLines(f, warn = FALSE), fixed = TRUE))
  j <- which(lengths(hits) > 0L)
  list(id = paste0("fgstudio::", name), exported = raw_nodes$isExported[i],
    locations = unlist(lapply(j, function(k) lapply(hits[[k]], function(line)
      list(file = rfiles[k], line = line))), recursive = FALSE))
})
edges <- lapply(seq_len(nrow(raw_edges)), function(i) list(
  from = paste0("fgstudio::", raw_edges$SOURCE[i]),
  to = paste0("fgstudio::", raw_edges$TARGET[i]),
  kind = "static-dependency", evidence = "pkgnet-FunctionReporter"))
bridges <- jsonlite::read_json("dev/architecture/reviewed-call-bridges.json")$edges
bridges <- lapply(bridges, code_map_bridge)
inputs <- lapply(code_map_inputs(), function(f) list(file = f, sha256 = code_map_hash(f)))
map <- list(schema_version = 1L, package = "fgstudio",
  package_version = as.character(packageVersion("fgstudio")),
  generator = list(pkgnet = as.character(packageVersion("pkgnet")),
    flow = as.character(packageVersion("flow"))),
  scope = "Package-local static dependencies plus reviewed navigation bridges; not a complete runtime or multi-repo graph",
  inputs = inputs, nodes = nodes, edges = c(edges, bridges),
  evaluation = list(static_nodes = nrow(raw_nodes), static_edges = nrow(raw_edges),
    reviewed_bridges = length(bridges),
    storage_closure_detected = any(grepl("split_reach", raw_nodes$node, fixed = TRUE)),
    limitations = c("List-held adapter closures and indirect writer dispatch require reviewed bridges",
      "Shiny registration is not chronological execution", "Backend internals and Python/QGIS graphs not indexed")))
jsonlite::write_json(map, "dev/architecture/call-network.json", pretty = TRUE,
  auto_unbox = TRUE, null = "null")
stopifnot(code_map_fresh(jsonlite::read_json("dev/architecture/call-network.json")))
cat("pkgnet: ", nrow(raw_nodes), " nodes, ", nrow(raw_edges), " static edges; ",
    length(bridges), " separately labelled reviewed bridges.\n", sep = "")
