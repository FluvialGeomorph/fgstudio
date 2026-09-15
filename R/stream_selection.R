channel_candidates <- function(context) {
  rows <- list()
  for (key in c("upstream", "downstream")) {
    shape <- context$layers[[key]]
    if (is.null(shape) || !nrow(shape)) next
    inventory <- drainage_feature_inventory(shape, key, context$location$comid)
    for (i in seq_len(nrow(inventory))) {
      item <- inventory[i, ]; if (is.na(item$source_id)) next
      rows[[length(rows) + 1L]] <- sf::st_sf(candidate_key = paste0("c", item$source_id),
        source_id = item$source_id, name = item$name, direction = key,
        retrieved_at = as.character(context$retrieved_at), source_description = "USGS NLDI NHDPlusV2 flowline",
        geometry = sf::st_geometry(sf::st_transform(shape[item$feature_row, ], 4326)))
    }
  }
  if (!length(rows)) return(NULL)
  x <- do.call(rbind, rows)
  for (id in unique(x$candidate_key)) x$direction[x$candidate_key == id] <-
    paste(unique(x$direction[x$candidate_key == id]), collapse = ",")
  x[!duplicated(x$candidate_key), ]
}

stream_selection_ui <- function(ns) {
  shiny::tagList(
    shiny::uiOutput(ns("stream_identity")),
    bslib::layout_columns(col_widths = c(7, 5),
      shiny::numericInput(ns("buffer_distance"), "Buffer on EACH side", value = NA_real_, min = .01),
      shiny::selectInput(ns("buffer_unit"), "Unit", c("Metres" = "m", "Feet (international)" = "ft"))),
    shiny::uiOutput(ns("stream_summary")),
    shiny::div(class = "d-flex gap-2 flex-wrap mb-1",
      shiny::actionButton(ns("preview_stream"), "Preview Stream", class = "btn-outline-primary btn-sm"),
      shiny::actionButton(ns("clear_stream"), "Clear lines", class = "btn-outline-secondary btn-sm"),
      shiny::actionButton(ns("save_stream"), "Save Stream", class = "btn-primary btn-sm")),
    shiny::uiOutput(ns("stream_status")),
    shiny::tags$details(class = "small", shiny::tags$summary("Buffer method and rationale"),
      compact_table(data.frame(Item = c("Width", "Method", "Meaning"), Detail = c(
        "Distance on each side; total corridor is approximately twice this distance",
        "Clip lines to Study Area, buffer in a local metre-based CRS, then clip the buffer",
        "User-defined analysis extent; not a floodplain delineation or topology repair"))),
      shiny::textInput(ns("stream_rationale"), "Why these lines and this width? (optional)")))
}

stream_selection_server <- function(input, output, session, exploration, study, store,
                                    is_active, on_saved, draft = NULL) {
  pool <- shiny::reactiveVal(draft$pool)
  selected <- shiny::reactiveVal(if (is.null(draft$selected)) character() else draft$selected)
  preview <- shiny::reactiveVal(NULL)
  status <- shiny::reactiveVal("Choose lines from the upstream/downstream lists; enter a name and buffer distance.")
  alive <- TRUE
  saved_once <- FALSE
  active <- function() alive && is_active() && identical(input$map_mode, "explore")
  enabled <- function() active() && identical(input$selection_target, "stream")
  change <- function(keys) {
    keys <- sort(unique(keys))
    if (!identical(keys, sort(selected()))) { selected(keys); preview(NULL) }
  }
  collecting <- shiny::observeEvent(exploration$result(), {
    if (!alive) return()
    incoming <- channel_candidates(exploration$result())
    if (is.null(incoming)) return()
    old <- pool()
    if (!is.null(old)) {
      for (id in intersect(old$candidate_key, incoming$candidate_key)) {
        j <- match(id, old$candidate_key); k <- match(id, incoming$candidate_key)
        old$direction[j] <- paste(unique(c(strsplit(old$direction[j], ",")[[1]], strsplit(incoming$direction[k], ",")[[1]])), collapse = ",")
      }
      incoming <- incoming[!incoming$candidate_key %in% old$candidate_key, ]
    }
    if (nrow(incoming) + (if (is.null(old)) 0L else nrow(old)) > 2000L) {
      status("2,000 candidate limit reached. Reopen the study to start a fresh search."); return()
    }
    pool(if (is.null(old)) incoming else rbind(old, incoming))
    if (identical(input$selection_target, "stream"))
      shiny::updateRadioButtons(session, "stream_action", selected = "select")
  }, ignoreNULL = TRUE)
  choices <- lapply(c("upstream", "downstream"), function(key) {
    output[[paste0("select_", key)]] <- shiny::renderUI({
      x <- pool(); rows <- if (is.null(x)) NULL else x[grepl(key, x$direction), ]
      count <- if (is.null(rows)) 0L else nrow(rows)
      latest <- exploration$result()$status
      row <- if (is.null(latest)) NULL else latest[latest$layer == key, , drop = FALSE]
      state <- if (is.null(row) || !nrow(row)) "Not queried" else
        if (row$status[[1]] == "available") "Returned" else
          switch(if ("outcome" %in% names(row)) row$outcome[[1]] else "unresolved", service_unavailable = "Request failed", no_features = "No matches", "Unresolved")
      shiny::tags$details(class = "border rounded px-2 py-1 mb-1",
        open = if (identical(input$selection_target, "stream") && identical(input$stream_action, "select") && count) NA else NULL,
        shiny::tags$summary(shiny::strong(drainage_groups[[key]]), paste0(" (", count, ") - ", state)),
        if (count) shiny::div(style = "max-height:14rem; overflow-y:auto; overflow-wrap:anywhere;",
          if (identical(input$selection_target, "stream") && identical(input$stream_action, "select"))
            shiny::checkboxGroupInput(session$ns(paste0("lines_", key)), NULL,
              choices = stats::setNames(rows$candidate_key, paste(rows$name, rows$source_id, sep = " - ")),
              selected = shiny::isolate(intersect(selected(), rows$candidate_key))) else
            shiny::tags$ul(class = "small ps-3", lapply(seq_len(count), function(i)
              shiny::tags$li(paste(rows$name[i], rows$source_id[i], sep = " - "))))))
    })
    shiny::observeEvent(input[[paste0("lines_", key)]], {
      if (!enabled() || !identical(input$stream_action, "select")) return()
      x <- pool(); if (is.null(x)) return()
      valid <- x$candidate_key[grepl(key, x$direction)]
      keys <- input[[paste0("lines_", key)]]
      if (!all(keys %in% valid)) { status("Unrecognized line selection; nothing changed."); return() }
      focus_checked_features(leaflet::leafletProxy("map", session = session), x, selected(), keys)
      change(c(setdiff(selected(), valid), keys))
    }, ignoreInit = TRUE, ignoreNULL = TRUE)
  })
  syncing <- shiny::observeEvent(selected(), {
    x <- pool(); if (is.null(x)) return()
    for (key in c("upstream", "downstream")) shiny::updateCheckboxGroupInput(session,
      paste0("lines_", key), selected = intersect(selected(), x$candidate_key[grepl(key, x$direction)]))
  }, ignoreNULL = FALSE)
  clicking <- shiny::observeEvent(input$map_shape_click, {
    if (!enabled() || !identical(input$stream_action, "select")) return()
    id <- input$map_shape_click$id
    if (is.null(id) || length(id) != 1L || !id %in% pool()$candidate_key) return()
    change(if (id %in% selected()) setdiff(selected(), id) else c(selected(), id))
  }, ignoreInit = TRUE)
  clear <- shiny::observeEvent(input$clear_stream, { if (enabled()) change(character()) }, ignoreInit = TRUE)
  parameters <- shiny::observeEvent(list(input$buffer_distance, input$buffer_unit, input$stream_name, input$stream_existing), preview(NULL), ignoreInit = TRUE)
  output$stream_identity <- shiny::renderUI({
    old <- study$stream_inventory
    if (!is.null(old) && !inherits(old, "sf")) shiny::selectInput(session$ns("stream_existing"),
      "Assign area to saved Stream", stats::setNames(old$stream_id, old$stream_name)) else
      shiny::textInput(session$ns("stream_name"), "Stream name", value = if (is.null(draft$name)) "" else draft$name)
  })
  restored <- shiny::observeEvent(input$selection_target, {
    if (!is.null(draft$distance)) shiny::updateNumericInput(session, "buffer_distance", value = draft$distance)
    if (!is.null(draft$unit)) shiny::updateSelectInput(session, "buffer_unit", selected = draft$unit)
    if (length(draft$selected)) shiny::updateRadioButtons(session, "stream_action", selected = "select")
    if (!is.null(draft$rationale)) shiny::updateTextInput(session, "stream_rationale", value = draft$rationale)
  }, once = TRUE)
  previewing <- shiny::observeEvent(input$preview_stream, {
    if (!enabled()) return()
    preview(NULL)
    tryCatch({
      if (!isTRUE(study$boundary)) stop("Save a Study Area boundary first; discovery and choices will be kept.")
      if (!length(selected())) stop("Select at least one channel line.")
      x <- pool(); value <- fluvgeo::preview_stream_corridor(x[x$candidate_key %in% selected(), ], input$buffer_distance, input$buffer_unit,
        boundary = study$boundary_sf)
      value$containment <- fluvgeo::check_study_area_containment(study$boundary_sf,
        sf::st_sf(stream_name = "Candidate", geometry = sf::st_geometry(value$area)))$status[[1]]
      preview(value)
      b <- sf::st_bbox(sf::st_transform(value$area, 4326))
      leaflet::fitBounds(leaflet::leafletProxy("map", session = session), b[[1]], b[[2]], b[[3]], b[[4]])
      status(if (value$containment != "inside") "Preview failed containment verification; save is blocked. Revise the selection or Study Area and preview again." else
        if (isTRUE(value$line_clipped) || isTRUE(value$clipped)) "Lines and buffer clipped to the Study Area. Review the retained gold line and area, then Save Stream. Enlarge the Study Area if more channel or floodplain is needed." else
        "Review the gold area, then Save Stream.")
    }, error = function(e) status(conditionMessage(e)))
  }, ignoreInit = TRUE)
  saving <- shiny::observeEvent(input$save_stream, {
    if (!enabled() || saved_once) return()
    tryCatch({
      view <- preview()
      if (is.null(view)) stop("Preview the current lines and buffer before saving.")
      if (view$containment != "inside") stop("Clipped geometry could not be verified inside the Study Area; save is blocked.")
      old <- study$stream_inventory
      id <- if (!is.null(old) && !inherits(old, "sf")) input$stream_existing else NULL
      name <- if (!is.null(id)) old$stream_name[match(id, old$stream_id)] else input$stream_name
      rationale <- paste("User reviewed selected NHDPlusV2 lines and their buffered analysis extent in FG Studio.",
        if (is.null(input$stream_rationale)) "" else input$stream_rationale)
      x <- pool()
      saved <- store$save_stream(study$key, x[x$candidate_key %in% selected(), ], name,
        input$buffer_distance, input$buffer_unit, rationale, study$path, id)
      change(character()); preview(NULL)
      saved_once <<- TRUE
      shiny::updateTextInput(session, "stream_name", value = "")
      on_saved(saved)
    }, error = function(e) status(paste("Stream not saved:", conditionMessage(e))))
  }, ignoreInit = TRUE)
  painting <- shiny::observe({
    x <- pool(); keys <- selected(); value <- preview()
    m <- leaflet::leafletProxy("map", session = session) |>
      leaflet::clearGroup("Stream candidates") |> leaflet::clearGroup("Stream preview") |> leaflet::clearGroup("Unclipped buffer")
    if (!enabled()) return()
    if (!is.null(x)) m <- leaflet::addPolylines(m, data = x, layerId = x$candidate_key,
      group = "Stream candidates", color = ifelse(x$candidate_key %in% keys,
        if (is.null(value)) "#e6a500" else "#777777", "#3182bd"),
      weight = ifelse(x$candidate_key %in% keys & is.null(value), 6, 3), label = paste(x$name, x$source_id),
      options = leaflet::pathOptions(interactive = identical(input$stream_action, "select"), bubblingMouseEvents = FALSE))
    if (!is.null(value)) {
      if (isTRUE(value$clipped)) m <- leaflet::addPolygons(m, data = sf::st_transform(value$unclipped_area,4326), group = "Unclipped buffer",
        color = "#666666", dashArray = "5,5", fill = FALSE, options = leaflet::pathOptions(interactive = FALSE))
      m <- leaflet::addPolylines(m, data = sf::st_transform(value$clipped_lines,4326), group = "Stream preview",
        color = "#e6a500", weight = 8, options = leaflet::pathOptions(interactive = FALSE))
      leaflet::addPolygons(m, data = sf::st_transform(value$area,4326), group = "Stream preview",
        color = "#e6a500", fillOpacity = .2, options = leaflet::pathOptions(interactive = FALSE))
    }
  })
  output$stream_summary <- shiny::renderUI({
    value <- preview()
    compact_table(data.frame(Item = c("Selected lines", "Lines retained", "Channel length retained", "Buffer parts", "Inside Study Area", "Buffer clipping"),
      Value = c(length(selected()), if (is.null(value)) "Preview required" else paste(value$retained_features,"of",value$selected_features),
        if (is.null(value)) "Preview required" else paste0(format(round(sum(value$line_lengths$retained_m),1),big.mark=",")," m of ",
          format(round(sum(value$line_lengths$original_m),1),big.mark=",")," m"),
        if (is.null(value)) "Preview required" else value$polygon_parts,
        if (is.null(value)) "Not checked" else value$containment,
        if (is.null(value)) "Not checked" else if (isTRUE(value$clipped))
          paste0(format(round(value$removed_area_m2), big.mark = ","), " m\u00b2 removed; dashed outline = original buffer") else "Not needed")))
  })
  output$stream_status <- shiny::renderUI(shiny::p(class = "small my-1", role = "status", status()))
  list(pool = pool, selected = selected, preview = preview, status = status,
    has_pending = function() shiny::isolate(length(selected()) > 0L),
    state = function() shiny::isolate(list(pool = pool(), selected = selected(), name = if (saved_once) "" else input$stream_name,
      distance = input$buffer_distance, unit = input$buffer_unit, rationale = input$stream_rationale)),
    destroy = function() {
      alive <<- FALSE
      for (o in c(list(collecting, syncing, clicking, clear, parameters, restored, previewing, saving, painting), choices)) o$destroy()
    })
}
