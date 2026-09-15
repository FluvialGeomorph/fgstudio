# Presentation only: keep every returned feature, even when names are repeated.
# Row is a session-local link to the source sf, not a new persistent identity.
drainage_feature_inventory <- function(shape, key, comid) {
  if (is.null(shape) || !nrow(shape)) return(data.frame())
  fields <- sf::st_drop_geometry(shape)
  pick <- function(candidates) {
    out <- rep(NA_character_, nrow(fields))
    for (candidate in candidates) {
      column <- match(candidate, tolower(names(fields)))
      if (is.na(column)) next
      value <- trimws(as.character(fields[[column]]))
      use <- is.na(out) & !is.na(value) & nzchar(value)
      out[use] <- value[use]
    }
    out
  }
  name <- pick(c("gnis_name", "name", "name_huc12", "gnisname"))
  id <- pick(if (key == "huc12") c("huc12", "identifier", "id") else
    c("comid", "nhdplus_comid", "nhdplusid", "identifier", "id"))
  fallback <- if (key == "basin") paste("Upstream basin of stream", comid) else
    if (key == "huc12") "HUC12 (name not supplied)" else "Channel (name not supplied)"
  name[is.na(name)] <- fallback
  label <- paste0(name, " - ", ifelse(is.na(id),
    paste("returned feature", seq_len(nrow(fields)), "(source ID not supplied)"), id))
  out <- data.frame(feature_row = seq_len(nrow(fields)), name = name, source_id = id, label = label)
  out[order(tolower(out$name), out$source_id, out$feature_row, na.last = TRUE), ]
}

drainage_result_ui <- function(x, polygon_controls = NULL) {
  if (is.null(x)) return(shiny::tagList(polygon_controls))
  questions <- c(huc12 = "Would this hydrologic unit be a useful Study Area or Stream area?",
    basin = "Does this drainage area match your study's scope?",
    upstream = "Which upstream channels belong in your study?",
    downstream = "How far downstream should your study extend?")
  shiny::tagList(
    shiny::tags$h4("Discovered features", class = "h6 mb-1"),
    lapply(names(drainage_groups), function(key) {
      if (!is.null(polygon_controls) && key %in% names(polygon_controls)) return(polygon_controls[[key]])
      row <- x$status[x$status$layer == key, , drop = FALSE]
      outcome <- if ("outcome" %in% names(row)) row$outcome[[1]] else
        if (row$status[[1]] == "available") "available" else "unresolved"
      available <- identical(outcome, "available")
      message <- switch(outcome,
        service_unavailable = "Request failed: service or connection problem. Retry Explore this stream; no-results was not established.",
        no_features = "No matching features returned for this query. This is not a timeout or proof of no coverage elsewhere.",
        unresolved = "Unavailable: response could not be interpreted. The client did not retain enough evidence to distinguish no results from a failed request.",
        "")
      inventory <- drainage_feature_inventory(x$layers[[key]], key, x$location$comid)
      shiny::tags$details(class = "fg-feature-list border rounded px-2 py-1 mb-1",
        shiny::tags$summary(shiny::strong(drainage_groups[[key]]),
          if (available) paste0(" (", nrow(inventory), ")") else
            paste0(" - ", switch(outcome, no_features = "No matches", service_unavailable = "Request failed", "Unresolved"))),
        shiny::p(class = "small my-1", if (available) questions[[key]] else message),
        if (nrow(inventory)) shiny::tags$ul(class = "small ps-3 mb-1",
          style = "max-height: 14rem; overflow-y: auto; overflow-wrap: anywhere;",
          lapply(seq_len(nrow(inventory)), function(i) shiny::tags$li(inventory$label[[i]]))))
    }),
    shiny::tags$details(class = "small mt-2", shiny::tags$summary("Sources, limits and request details"),
      compact_table(data.frame(Item = c("HUC12", "Basin", "Search limit", "Retrieved", "Sources"),
        Value = c("WBD 2025, at snapped point", "Simplified NHDPlusV2 catchments; not an exact pour-point delineation",
          paste(x$distance_km, "km per direction; not necessarily the full network"),
          x$retrieved_at, paste(x$sources, collapse = "; ")))),
      if (!is.null(x$name_lookup)) shiny::p(x$name_lookup$detail),
      compact_table(data.frame(Layer = unname(drainage_groups[x$status$layer]), Detail = x$status$detail))))
}
