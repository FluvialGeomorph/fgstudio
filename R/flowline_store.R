# Immutable local Flowline candidate revisions. Governed FGDB publication is a
# later workflow boundary.
study_flowline_store <- function(context_path, hydro_read,
                                 stream_network_read) {
  file_hash <- function(path) {
    con <- file(path, "rb"); on.exit(close(con))
    unclass(as.character(openssl::sha256(con)))
  }
  object_hash <- function(x)
    unclass(as.character(openssl::sha256(serialize(x, NULL, version = 2))))
  network_file <- function(candidate) {
    path <- file.path(candidate$path, candidate$files$stream_network)
    if (!file.exists(path)) stop("The saved synthetic Stream Network is unavailable.")
    path
  }
  inputs <- function(record, candidate, selection, segments) {
    if (!file.exists(selection$path) || !file.exists(selection$group))
      stop("The saved Study or Survey Event revision is unavailable.")
    mappings <- segments$reach_mappings[, intersect(
      c("reach_id", "selection_id", "source_id"), names(segments$reach_mappings)),
      drop = FALSE]
    list(schema = "FGSTUDIO_FLOWLINE_INPUTS_1", key = selection$key,
      event = selection$event, stream = selection$stream,
      context_file = basename(selection$path), context_sha256 = file_hash(selection$path),
      event_file = basename(selection$group), event_sha256 = file_hash(selection$group),
      hydro_revision = record$id, hydro_sha256 = record$result$output_sha256,
      network_revision = basename(candidate$path),
      network_sha256 = file_hash(network_file(candidate)),
      reference_sha256 = segments$sha256,
      reach_mapping_sha256 = object_hash(mappings))
  }
  root <- function(candidate) {
    path <- file.path(candidate$path, "flowline")
    fs::dir_create(path); path
  }
  load_revision <- function(directory, result) {
    path <- file.path(directory, result$files$geopackage)
    if (!file.exists(path) || !identical(file_hash(path), result$files$sha256))
      stop("A saved Flowline candidate is incomplete or changed.")
    layers <- sf::st_layers(path)$name
    required <- c("raw_stream_flowline", "smoothed_stream_flowline",
      "reach_flowlines", "selected_network_segments")
    if (!all(required %in% layers))
      stop("A saved Flowline candidate is missing required layers.")
    result$path <- directory
    result$raw_flowline <- sf::st_read(path, layer = "raw_stream_flowline", quiet = TRUE)
    result$stream_flowline <- sf::st_read(path, layer = "smoothed_stream_flowline", quiet = TRUE)
    result$flowlines <- sf::st_read(path, layer = "reach_flowlines", quiet = TRUE)
    result$selected_segments <- sf::st_read(path, layer = "selected_network_segments", quiet = TRUE)
    result$boundaries <- if ("reach_boundaries" %in% layers)
      sf::st_read(path, layer = "reach_boundaries", quiet = TRUE) else
      sf::st_sf(downstream_reach_id=character(),upstream_reach_id=character(),
        geometry=sf::st_sfc(crs=sf::st_crs(result$flowlines)))
    result
  }
  read <- function(record, selection, segments, bandwidth = NULL) {
    candidate <- stream_network_read(record)
    if (is.null(candidate)) return(NULL)
    current_inputs <- inputs(record, candidate, selection, segments)
    directories <- list.dirs(root(candidate), recursive = FALSE, full.names = TRUE)
    directories <- directories[grepl("^[0-9a-f]{32}$", basename(directories))]
    directories <- directories[!file.exists(file.path(directories,"PENDING"))]
    directories <- directories[order(file.info(directories)$mtime, decreasing = TRUE)]
    for (directory in directories) {
      result <- tryCatch(readRDS(file.path(directory, "result.rds")),
        error = function(e) NULL)
      if (is.null(result) || !identical(result$inputs, current_inputs) ||
          (!is.null(bandwidth) && !identical(result$smoothing_bandwidth,
            as.numeric(bandwidth)))) next
      return(load_revision(directory, result))
    }
    NULL
  }
  publish <- function(record, selection, segments, bandwidth, raw_flowline,
                      stream_flowline, flowlines, boundaries,
                      selected_segments) {
    current <- hydro_read(record$key, record$event, record$stream, record$source)
    if (is.null(current) || is.null(current$result) ||
        !identical(current$id, record$id) ||
        !identical(context_path(record$key), selection$path))
      stop("Inputs changed; reopen the Flowline review before saving.")
    candidate <- stream_network_read(current)
    if (is.null(candidate)) stop("The saved Stream Network changed; reopen Flowline review.")
    fingerprint <- inputs(current, candidate, selection, segments)
    directory <- file.path(root(candidate),
      paste(format(openssl::rand_bytes(16)), collapse = ""))
    if (!dir.create(directory)) stop("Cannot prepare Flowline candidate storage.")
    pending <- file.path(directory,"PENDING")
    if(!file.create(pending)) stop("Cannot protect incomplete Flowline candidate storage.")
    complete <- FALSE
    on.exit(if (!complete && dir.exists(directory)) unlink(directory, recursive = TRUE),
      add = TRUE)
    path <- file.path(directory, "flowlines.gpkg")
    sf::st_write(raw_flowline, path, layer = "raw_stream_flowline", quiet = TRUE)
    sf::st_write(stream_flowline, path, layer = "smoothed_stream_flowline", quiet = TRUE)
    sf::st_write(flowlines, path, layer = "reach_flowlines", quiet = TRUE)
    sf::st_write(selected_segments, path, layer = "selected_network_segments", quiet = TRUE)
    if (nrow(boundaries))
      sf::st_write(boundaries, path, layer = "reach_boundaries", quiet = TRUE)
    result <- list(schema = "FGSTUDIO_FLOWLINE_CANDIDATE_1", inputs = fingerprint,
      smoothing_bandwidth = as.numeric(bandwidth), reach_count = nrow(flowlines),
      reach_ids = as.character(flowlines$reach_id),
      created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      files = list(geopackage = basename(path), sha256 = file_hash(path)))
    saveRDS(result, file.path(directory, "result.rds"))
    jsonlite::write_json(result, file.path(directory, "provenance.json"),
      auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA)
    if(unlink(pending) != 0L)
      stop("Could not publish the local Flowline candidate revision.")
    complete <- TRUE
    load_revision(directory, result)
  }
  list(flowline_read = read, flowline_publish = publish)
}
