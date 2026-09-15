drainage_groups <- c(huc12 = "HUC12", basin = "Upstream basin", upstream = "Upstream channels", downstream = "Downstream path")

drainage_explorer_ui <- function(ns) {
  shiny::tagList(
    shiny::p("Click near a channel, then Snap to stream. Review the orange channel and snapped point before retrieving its drainage context."),
    shiny::actionButton(ns("locate_stream"), "Snap to stream", class = "btn-primary"),
    shiny::uiOutput(ns("drainage_status")),
    shiny::uiOutput(ns("drainage_failure")),
    shiny::uiOutput(ns("drainage_location")),
    shiny::numericInput(ns("navigation_km"), "Upstream / downstream search distance (km)", value = 50, min = 1, max = 200),
    shiny::actionButton(ns("get_drainage"), "Explore this stream", class = "btn-primary"),
    shiny::actionButton(ns("cancel_drainage"), "Cancel request"),
    shiny::uiOutput(ns("drainage_results")),
    shiny::p(class = "small text-body-secondary", "Exploration only: nothing is saved or assigned to a Study Area, Stream or Reach. Coordinates go to public USGS services. Use only locations appropriate for public services. Requests can be cancelled; each request has a two-minute limit."))
}

launch_drainage_job <- function(operation, argument, distance = 50) {
  callr::r_bg(drainage_request, args = list(operation = operation, argument = argument, distance = distance),
    libpath = .libPaths(), stdout = NULL, stderr = NULL,
    user_profile = FALSE, system_profile = FALSE, supervise = TRUE)
}

# Lives inside the boundary module so exploration and drawing share one map.
# No storage adapter is passed here: exploration cannot publish project records.
drainage_explorer <- function(input, output, session, is_active, launch = launch_drainage_job,
                             clock = Sys.time) {
  clicked <- shiny::reactiveVal(NULL)
  located <- shiny::reactiveVal(NULL)
  result <- shiny::reactiveVal(NULL)
  status <- shiny::reactiveVal("Select a location on the map to begin.")
  failure <- shiny::reactiveVal(NULL)
  job <- NULL
  operation <- NULL
  started <- NULL
  alive <- TRUE
  proxy <- function() leaflet::leafletProxy("map", session = session)
  enabled <- function() alive && is_active() && identical(input$map_mode, "explore")
  cancel <- function() {
    if (!is.null(job)) {
      try(job$kill(), silent = TRUE)
      job <<- NULL
    }
  }
  clear_layers <- function() {
    m <- proxy()
    for (g in unname(drainage_groups)) m <- leaflet::clearGroup(m, g)
  }
  choose <- function(x) {
    if (!enabled() || !is.list(x) || !is.numeric(x$lng) || !is.numeric(x$lat) ||
        length(x$lng) != 1L || length(x$lat) != 1L ||
        !is.finite(x$lng) || !is.finite(x$lat) || abs(x$lng) > 180 || abs(x$lat) > 90) return()
    cancel(); clear_layers()
    located(NULL); result(NULL)
    failure(NULL)
    clicked(sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(x$lng, x$lat)), crs = 4326)))
    proxy() |> leaflet::clearGroup("Located stream") |> leaflet::clearGroup("Selected location") |>
      leaflet::addCircleMarkers(lng = x$lng, lat = x$lat, group = "Selected location", radius = 6,
        color = "#222222", fillOpacity = 1, label = "Your clicked point",
        options = leaflet::pathOptions(interactive = FALSE))
    status("Location selected. Snap to stream to identify the nearest mapped channel within 200 m.")
  }
  clicking <- shiny::observeEvent(input$map_click, choose(input$map_click), ignoreInit = TRUE)
  shape_clicking <- shiny::observeEvent(input$map_shape_click, choose(input$map_shape_click), ignoreInit = TRUE)
  start <- function(kind, arg, distance = 50) {
    cancel()
    failure(NULL)
    tryCatch({
      job <<- launch(kind, arg, distance)
      operation <<- kind
      started <<- clock()
      status(if (kind == "locate") "Finding a nearby stream..." else "Retrieving HUC12, upstream basin and channel layers...")
    }, error = function(e) status("The service request could not start. Saved records are unchanged. Please retry."))
  }
  locating <- shiny::observeEvent(input$locate_stream, {
    if (!enabled()) return()
    if (is.null(clicked())) { status("Click near the intended channel first."); return() }
    located(NULL); result(NULL); clear_layers()
    proxy() |> leaflet::clearGroup("Located stream")
    start("locate", clicked())
  }, ignoreInit = TRUE)
  fetching <- shiny::observeEvent(input$get_drainage, {
    if (!enabled()) return()
    if (is.null(located())) { status("Snap to a stream and review the highlighted channel first."); return() }
    d <- input$navigation_km
    if (!is.numeric(d) || length(d) != 1L || !is.finite(d) || d < 1 || d > 200) {
      status("Choose a search distance between 1 and 200 km."); return()
    }
    result(NULL); clear_layers()
    start("context", located(), d)
  }, ignoreInit = TRUE)
  cancelling <- shiny::observeEvent(input$cancel_drainage, {
    if (!enabled()) return()
    cancel()
    status("Request cancelled. Saved project records are unchanged.")
  }, ignoreInit = TRUE)
  mode <- shiny::observeEvent(input$map_mode, {
    if (!identical(input$map_mode, "explore")) {
      cancel()
      clear_layers()
      proxy() |> leaflet::clearGroup("Located stream") |> leaflet::clearGroup("Selected location")
      clicked(NULL); located(NULL); result(NULL)
      failure(NULL)
      status("Select a location on the map to begin.")
    }
  }, ignoreInit = TRUE)
  poll <- function() {
    if (is.null(job)) return()
    if (!enabled()) { cancel(); return() }
    if (as.numeric(difftime(clock(), started, units = "secs")) > 120) {
      cancel(); status("The USGS request exceeded two minutes and was stopped. Your point is retained; retry the same point. This is not evidence that it was too far from a stream."); return()
    }
    if (job$is_alive()) return()
    done <- job; job <<- NULL
    tryCatch({
      value <- done$get_result()
      if (operation == "locate") {
        located(value)
        proxy() |> leaflet::addPolylines(data = value$flowline, group = "Located stream", color = "#d95f02", weight = 6,
          options = leaflet::pathOptions(interactive = FALSE)) |>
          leaflet::addCircleMarkers(data = value$snapped_point, group = "Located stream", radius = 7,
            color = "#d95f02", fillOpacity = 1, label = "Snapped stream location",
            options = leaflet::pathOptions(interactive = FALSE))
        status("Review the orange channel. If it is the intended stream, select Explore this stream; otherwise click again.")
      } else {
        result(value)
        colors <- c(huc12 = "#756bb1", basin = "#31a354", upstream = "#3182bd", downstream = "#de2d26")
        m <- proxy()
        for (key in names(drainage_groups)) {
          shape <- value$layers[[key]]
          if (is.null(shape)) next
          if (key %in% c("huc12", "basin")) {
            m <- leaflet::addPolygons(m, data = shape, group = drainage_groups[[key]], color = colors[[key]],
              weight = 2, fillOpacity = 0.08, options = leaflet::pathOptions(interactive = FALSE))
          } else m <- leaflet::addPolylines(m, data = shape, group = drainage_groups[[key]],
            color = colors[[key]], weight = 3, options = leaflet::pathOptions(interactive = FALSE))
        }
        # Keep the reviewed location prominent; never replace the drawing group.
        m <- leaflet::clearGroup(m, "Located stream") |>
          leaflet::addPolylines(data = value$location$flowline, group = "Located stream", color = "#d95f02", weight = 6,
            options = leaflet::pathOptions(interactive = FALSE)) |>
          leaflet::addCircleMarkers(data = value$location$snapped_point, group = "Located stream", radius = 7,
            color = "#d95f02", fillOpacity = 1, options = leaflet::pathOptions(interactive = FALSE))
        area <- value$layers$basin
        if (is.null(area)) area <- value$layers$huc12
        if (!is.null(area)) {
          b <- sf::st_bbox(area)
          leaflet::fitBounds(m, b[[1]], b[[2]], b[[3]], b[[4]])
        }
        status("Candidate layers are ready to compare. Toggle layers using the map control; no project records were changed.")
      }
    }, error = function(e) {
      # callr's wrapper message includes no useful UI detail; the parent is the backend error.
      cause <- if (!is.null(e$parent)) e$parent else e
      detail <- conditionMessage(cause)
      failure(list(time = format(Sys.time(), tz = "UTC", usetz = TRUE),
        detail = if (is.null(cause$details)) detail else cause$details))
      status(paste("Request unsuccessful:", detail, "Saved records are unchanged."))
    })
  }
  polling <- shiny::observe({ shiny::invalidateLater(500, session); poll() })
  output$drainage_status <- shiny::renderUI(shiny::p(role = "status", status()))
  output$drainage_failure <- shiny::renderUI({
    x <- failure()
    if (!is.null(x)) shiny::tags$details(shiny::tags$summary("Last failed request details"),
      shiny::p(x$time), shiny::tags$pre(style = "white-space: pre-wrap; overflow-wrap: anywhere;", x$detail))
  })
  output$drainage_location <- shiny::renderUI({
    x <- located()
    if (!is.null(x)) shiny::p(sprintf("Mapped stream ID %s; snap distance %.0f m. Orange marks the service's stream location; black marks your click.", x$comid, x$snap_distance_m))
  })
  output$drainage_results <- shiny::renderUI({
    x <- result()
    if (is.null(x)) return(NULL)
    questions <- c(huc12 = "Would this named hydrologic unit be a useful Study Area or Stream area?",
      basin = "Does this upstream drainage area match the scope of your question?",
      upstream = "Which upstream channels belong in your study?", downstream = "How far downstream does the study need to extend?")
    shiny::tagList(shiny::tags$h4("Use these candidates to frame your study", class = "h6"),
      shiny::tags$ul(lapply(names(drainage_groups), function(key) {
        row <- x$status[x$status$layer == key, ]
        shiny::tags$li(shiny::strong(paste0(drainage_groups[[key]], ": ")),
          if (row$status == "available") paste(row$features, "reference features.", questions[[key]]) else
            "Unavailable for this request; this does not establish that no coverage exists.")
      })),
      if (!is.null(x$layers$huc12)) {
        h <- sf::st_drop_geometry(x$layers$huc12)
        fields <- intersect(c("huc12", "name", "name_huc12", "hutype"), names(h))
        if (length(fields)) shiny::p(paste(apply(as.data.frame(h[fields]), 1, paste, collapse = " - "), collapse = "; "))
      },
      shiny::p(sprintf("HUC12: WBD 2025 at the snapped point. Basin: simplified NHDPlusV2 catchments, not an exact pour-point delineation. Both channel searches are limited to %g km; a complete upstream network is not guaranteed.", x$distance_km)),
      shiny::p("These alternatives support your next decision; adopting or combining them into saved Study Area/Stream geometry is the next design step."),
      shiny::tags$details(shiny::tags$summary("Source and request details"),
        shiny::p("Retrieved: ", x$retrieved_at),
        shiny::p(paste(x$sources, collapse = "; ")),
        shiny::tags$ul(lapply(seq_len(nrow(x$status)), function(i) shiny::tags$li(
          drainage_groups[[x$status$layer[i]]], ": ", x$status$detail[i])))))
  })
  destroy <- function() {
    alive <<- FALSE; cancel()
    for (o in list(clicking, shape_clicking, locating, fetching, cancelling, mode, polling)) o$destroy()
  }
  session$onSessionEnded(destroy)
  list(destroy = destroy, poll = poll, clicked = clicked, located = located, result = result, status = status)
}
