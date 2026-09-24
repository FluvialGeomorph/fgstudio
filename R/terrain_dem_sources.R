# Resolve application selections and receipt-backed assets, without reading pixels.
# Scientific grid/reference compatibility remains the backend's responsibility.
terrain_dem_sources <- function(store, key, group_id, stream_id, context_path, group_path) {
  group <- store$acquisition_groups(key)$groups[[group_id]]
  if (is.null(group) || !stream_id %in% group$streams$stream_id)
    stop("The Stream is not assigned to this Survey Event. Review Event Settings.")
  request <- store$dem_preflight_request(key, group_id, stream_id, context_path,
    store$survey_collections(key)$path, group_path)
  rows <- lapply(seq_len(nrow(request$sources)), function(i) {
    entry <- request$sources[i, ]
    if (is.na(entry$selection_path) || is.na(entry$attempt))
      stop("Source DEM selections or acquisition records are missing. Open Collections > DEM files.")
    selected <- fluvgeo::read_stream_dem_selection(entry$selection_path)$selected
    if (!length(selected)) stop("No source DEM files are selected. Open Collections > DEM files.")
    history <- fluvgeo::read_stream_dem_download(entry$attempt, verify = FALSE)
    if (!identical(history$manifest$stream_id, stream_id) ||
        !identical(history$manifest$candidate_key, entry$candidate_key))
      stop("Source acquisition does not match this Stream and Survey Collection.")
    files <- history$files[match(selected, history$files$file_id), , drop = FALSE]
    if (anyNA(files$file_id) || any(!files$outcome %in% c("RECORDED", "DOWNLOADED", "REUSED")))
      stop("Selected source DEMs are unavailable. Open Collections > DEM files and acquire the missing files.")
    paths <- normalizePath(file.path(dirname(dirname(entry$attempt)), files$asset),
      winslash = "/", mustWork = TRUE)
    data.frame(candidate_key = entry$candidate_key, file_id = files$file_id,
      path = paths, selection_path = entry$selection_path, attempt = entry$attempt,
      stringsAsFactors = FALSE)
  })
  result <- do.call(rbind, rows)
  if (is.null(result) || !nrow(result)) stop("No Survey Collections supply this Event.")
  result
}
