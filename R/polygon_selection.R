# Normalize only server-returned polygons, never browser-supplied geometry.
polygon_candidates <- function(context) {
  rows <- list()
  for (key in c("huc12", "basin")) {
    shape <- context$layers[[key]]
    if (is.null(shape) || !nrow(shape)) next
    inventory <- drainage_feature_inventory(shape, key, context$location$comid)
    for (i in seq_len(nrow(inventory))) {
      item <- inventory[i, ]
      geometry <- sf::st_geometry(shape[item$feature_row, ])
      source_id <- if (key == "basin") paste0("origin COMID ", context$location$comid) else item$source_id
      if (is.na(source_id)) source_id <- paste0("geometry SHA256 ",
        as.character(openssl::sha256(sf::st_as_binary(geometry)[[1]])))
      token <- paste0("p", as.character(openssl::sha256(charToRaw(paste(key, source_id)))))
      rows[[length(rows) + 1L]] <- sf::st_sf(candidate_key = token, source_type = key,
        source_id = as.character(source_id), name = item$name,
        retrieved_at = as.character(context$retrieved_at),
        source_description = if (key == "huc12") "USGS WBD 2025 HUC12" else
          "NLDI/NHDPlusV2 simplified upstream catchments; not split at clicked point",
        geometry = geometry)
    }
  }
  if (length(rows)) do.call(rbind, rows) else NULL
}

polygon_selection_ui <- function(ns) {
  shiny::tagList(
    shiny::uiOutput(ns("selection_summary")),
    shiny::div(class = "d-flex gap-2 flex-wrap mb-1",
      shiny::actionButton(ns("preview_selection"), "Preview boundary", class = "btn-outline-primary btn-sm"),
      shiny::actionButton(ns("undo_selection"), "Undo", class = "btn-outline-secondary btn-sm"),
      shiny::actionButton(ns("clear_selection"), "Clear selection", class = "btn-outline-secondary btn-sm")),
    shiny::tags$details(class = "small mb-1", shiny::tags$summary("Boundary rationale (optional)"),
      shiny::textInput(ns("selection_rationale"), "Why this extent?")),
    shiny::actionButton(ns("save_selection"), "Save reviewed Study Area boundary", class = "btn-primary btn-sm"),
    shiny::uiOutput(ns("selection_status")))
}

# Selection belongs to this study editor. Only this helper has the explicit
# selected-boundary writer; retrieval remains read-only.
polygon_selection <- function(input, output, session, exploration, study, store,
                              is_active, on_saved, draft = NULL) {
  pool <- shiny::reactiveVal(if (is.null(draft)) NULL else draft$pool)
  selected <- shiny::reactiveVal(if (is.null(draft)) character() else draft$selected)
  preview <- shiny::reactiveVal(NULL)
  status <- shiny::reactiveVal("Select HUC12s or an upstream basin, then preview their combined boundary.")
  previous <- character()
  alive <- TRUE
  enabled <- function() alive && is_active() && identical(input$map_mode, "explore") &&
    !identical(input$selection_target, "stream")
  change <- function(keys) {
    keys <- sort(unique(keys))
    if (identical(keys, sort(selected()))) return()
    previous <<- selected()
    selected(keys); preview(NULL)
    status("Selection changed. Preview before saving; no records changed.")
  }
  collecting <- shiny::observeEvent(exploration$result(), {
    if (!enabled()) return()
    incoming <- polygon_candidates(exploration$result())
    if (is.null(incoming)) return()
    old <- pool()
    if (!is.null(old)) incoming <- incoming[!incoming$candidate_key %in% old$candidate_key, ]
    if (!nrow(incoming)) return()
    if (nrow(incoming) + (if (is.null(old)) 0L else nrow(old)) > 200L) {
      status("Candidate limit reached (200). Reopen the study to start a fresh discovery session.")
      return()
    }
    pool(if (is.null(old)) incoming else rbind(old, incoming))
  }, ignoreNULL = TRUE)
  choices <- lapply(c("huc12", "basin"), function(key) {
    output[[paste0("select_", key)]] <- shiny::renderUI({
      x <- pool()
      rows <- if (is.null(x)) NULL else x[x$source_type == key, ]
      count <- if (is.null(rows)) 0L else nrow(rows)
      current <- exploration$result()
      outcome <- if (is.null(current)) NULL else current$status[current$status$layer == key, , drop = FALSE]
      detail <- if (is.null(outcome)) "Find watersheds to add candidates here." else
        if (outcome$status[[1]] == "available") "Candidates are retained across discovery clicks." else
          switch(if ("outcome" %in% names(outcome)) outcome$outcome[[1]] else "unresolved",
            service_unavailable = "Latest request failed: service or connection problem. Earlier candidates and choices remain.",
            no_features = "Latest request returned no matching polygons. Earlier candidates and choices remain.",
            "Latest response could not be interpreted; no matches versus request failure is unknown. Earlier candidates and choices remain.")
      shiny::tags$details(class = "border rounded px-2 py-1 mb-1",
        shiny::tags$summary(shiny::strong(drainage_groups[[key]]), paste0(" (", count, " candidates)")),
        shiny::p(class = "small my-1", detail),
        if (count) shiny::div(style = "max-height: 14rem; overflow-y: auto; overflow-wrap: anywhere;",
          if (identical(input$polygon_action, "select")) shiny::checkboxGroupInput(
            session$ns(paste0("chosen_", key)), NULL,
            choices = stats::setNames(rows$candidate_key, paste(rows$name, rows$source_id, sep = " - ")),
            selected = shiny::isolate(intersect(selected(), rows$candidate_key))) else
              shiny::tags$ul(class = "small ps-3", lapply(seq_len(count), function(i)
                shiny::tags$li(paste(rows$name[i], rows$source_id[i], sep = " - "))))))
    })
    shiny::observeEvent(input[[paste0("chosen_", key)]], {
      if (!enabled() || !identical(input$polygon_action, "select")) return()
      x <- pool(); if (is.null(x)) return()
      keys <- input[[paste0("chosen_", key)]]
      valid <- x$candidate_key[x$source_type == key]
      if (!all(keys %in% valid)) { status("Selection was not recognized; no records changed."); return() }
      focus_checked_features(leaflet::leafletProxy("map", session = session), x, selected(), keys)
      change(c(setdiff(selected(), valid), keys))
    }, ignoreNULL = TRUE, ignoreInit = TRUE)
  })
  synchronizing <- shiny::observeEvent(selected(), {
    x <- pool(); if (is.null(x)) return()
    for (key in c("huc12", "basin")) shiny::updateCheckboxGroupInput(session,
      paste0("chosen_", key), selected = intersect(selected(), x$candidate_key[x$source_type == key]))
  }, ignoreNULL = FALSE)
  clicking <- shiny::observeEvent(input$map_shape_click, {
    if (!enabled() || !identical(input$polygon_action, "select")) return()
    id <- input$map_shape_click$id
    if (is.null(id) || length(id) != 1L || !id %in% pool()$candidate_key) return()
    change(if (id %in% selected()) setdiff(selected(), id) else c(selected(), id))
  }, ignoreInit = TRUE)
  clearing <- shiny::observeEvent(input$clear_selection, { if (enabled()) change(character()) }, ignoreInit = TRUE)
  undoing <- shiny::observeEvent(input$undo_selection, { if (enabled()) change(previous) }, ignoreInit = TRUE)
  drawing <- shiny::observe({
    x <- pool(); keys <- selected(); view <- preview()
    active <- enabled()
    selectable <- identical(input$polygon_action, "select")
    m <- leaflet::leafletProxy("map", session = session) |>
      leaflet::clearGroup("Boundary candidates") |> leaflet::clearGroup("Boundary preview")
    if (!active) return()
    if (!is.null(x)) m <- leaflet::addPolygons(m, data = x, layerId = x$candidate_key,
      group = "Boundary candidates", color = ifelse(x$candidate_key %in% keys, "#e6a500", "#756bb1"),
      weight = ifelse(x$candidate_key %in% keys, 4, 2), fillOpacity = 0.08,
      label = paste(x$name, x$source_id, sep = " - "),
      options = leaflet::pathOptions(interactive = selectable, bubblingMouseEvents = FALSE))
    if (!is.null(view)) leaflet::addPolygons(m, data = view$boundary, group = "Boundary preview",
      color = "#e6a500", weight = 5, fillOpacity = 0.15,
      options = leaflet::pathOptions(interactive = FALSE))
  })
  previewing <- shiny::observeEvent(input$preview_selection, {
    if (!enabled()) return()
    preview(NULL)
    tryCatch({
      x <- pool(); if (!length(selected())) stop("Select at least one polygon first.")
      view <- fluvgeo::combine_study_area_polygons(x[x$candidate_key %in% selected(), ])
      preview(view)
      b <- sf::st_bbox(view$boundary)
      leaflet::fitBounds(leaflet::leafletProxy("map", session = session), b[[1]], b[[2]], b[[3]], b[[4]])
      status("Review the gold boundary, then save. Existing child areas must remain inside it.")
    }, error = function(e) status(conditionMessage(e)))
  }, ignoreInit = TRUE)
  saving <- shiny::observeEvent(input$save_selection, {
    if (!enabled()) return()
    if (is.null(study$key) || is.null(store)) {
      status("Create a Study Area in the New tab first. These choices will carry into it; preview again and save."); return()
    }
    if (is.null(preview())) { status("Preview the current selection before saving."); return() }
    tryCatch({
      x <- pool(); sources <- x[x$candidate_key %in% selected(), ]
      rationale <- if (is.null(input$selection_rationale)) "" else input$selection_rationale
      saved <- store$save_selected_boundary(study$key, sources, study$path, rationale)
      selected(character()); preview(NULL)
      on_saved(saved)
    }, error = function(e) status(paste("Boundary was not confirmed saved. Reopen the study to check its latest revision; earlier records are retained.", conditionMessage(e))))
  }, ignoreInit = TRUE)
  output$selection_summary <- shiny::renderUI(compact_table(data.frame(
    Selected = length(selected()), Parts = if (is.null(preview())) "Not previewed" else preview()$polygon_parts,
    Preview = if (is.null(preview())) "Required" else "Ready")))
  output$selection_status <- shiny::renderUI(shiny::p(class = "small my-1", role = "status", status()))
  list(state = function() shiny::isolate(list(pool = pool(), selected = selected())),
    has_pending = function() shiny::isolate(length(selected()) > 0L),
    selected = selected, preview = preview, pool = pool, status = status,
    destroy = function() {
      alive <<- FALSE
      for (o in c(list(collecting, clicking, clearing, undoing, synchronizing, drawing, previewing, saving), choices)) o$destroy()
    })
}
