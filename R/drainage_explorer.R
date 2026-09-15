drainage_groups <- c(huc12 = "HUC12", basin = "Upstream basin", upstream = "Upstream channels", downstream = "Downstream path")

service_activity_ui <- function(operation, seconds = 0) {
  shiny::div(role = "status", `aria-live` = "polite",
    shiny::strong(if (operation == "locate") "USGS: snapping to stream" else "USGS: retrieving drainage features"),
    shiny::tags$progress(style = "display:block;width:100%;height:.6rem;", `aria-label` = "Service request in progress"),
    shiny::span(class = "small", paste0(seconds, " seconds elapsed. Waiting for service response; Cancel is available.")))
}

drainage_explorer_ui <- function(ns) {
  shiny::tagList(
    shiny::uiOutput(ns("workflow_next")),
    shiny::div(class = "d-flex gap-2 flex-wrap mb-1",
      shiny::actionButton(ns("locate_stream"), "Snap to stream", class = "btn-primary btn-sm"),
      shiny::actionButton(ns("get_drainage"), "Explore this stream", class = "btn-primary btn-sm"),
      shiny::actionButton(ns("cancel_drainage"), "Cancel", class = "btn-outline-secondary btn-sm")),
    shiny::uiOutput(ns("drainage_status")),
    shiny::uiOutput(ns("drainage_failure")),
    shiny::uiOutput(ns("drainage_location")),
    shiny::numericInput(ns("navigation_km"), "Channel search distance (km)", value = 50, min = 1, max = 200, width = "100%"),
    shiny::conditionalPanel("input.selection_target === 'boundary'", ns = ns,
      shiny::radioButtons(ns("polygon_action"), NULL,
        c("Find watersheds" = "point", "Select polygons" = "select"), inline = TRUE)),
    shiny::conditionalPanel("input.selection_target === 'stream'", ns = ns,
      shiny::radioButtons(ns("stream_action"), NULL,
        c("Find channels" = "point", "Select lines" = "select"), inline = TRUE)),
    shiny::uiOutput(ns("drainage_results")),
    shiny::conditionalPanel("input.selection_target === 'boundary'", ns = ns, polygon_selection_ui(ns)),
    shiny::conditionalPanel("input.selection_target === 'stream'", ns = ns, stream_selection_ui(ns)),
    shiny::p(class = "small text-body-secondary mb-0", "Public USGS queries: use public locations only."))
}

launch_drainage_job <- function(operation, argument, distance = 50) {
  callr::r_bg(drainage_request, args = list(operation = operation, argument = argument, distance = distance),
    libpath = .libPaths(), stdout = NULL, stderr = NULL,
    user_profile = FALSE, system_profile = FALSE, supervise = TRUE)
}

# Lives inside the boundary module so exploration and drawing share one map.
# No storage adapter is passed here: exploration cannot publish project records.
drainage_explorer <- function(input, output, session, is_active, launch = launch_drainage_job,
                             clock = Sys.time, polygon_controls = NULL, draft = NULL) {
  clicked <- shiny::reactiveVal(draft$clicked)
  located <- shiny::reactiveVal(draft$located)
  result <- shiny::reactiveVal(draft$result)
  status <- shiny::reactiveVal(if (is.null(draft$result)) "" else "Previous discovery retained.")
  failure <- shiny::reactiveVal(NULL)
  busy <- shiny::reactiveVal(NULL)
  elapsed <- shiny::reactiveVal(0L)
  notification_id <- session$ns("service_activity")
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
    busy(NULL)
    shiny::removeNotification(notification_id, session = session)
  }
  clear_layers <- function() {
    m <- proxy()
    for (g in unname(drainage_groups)) m <- leaflet::clearGroup(m, g)
  }
  choose <- function(x) {
    selecting <- if (identical(input$selection_target, "stream")) identical(input$stream_action, "select") else identical(input$polygon_action, "select")
    if (!enabled() || selecting || !is.list(x) || !is.numeric(x$lng) || !is.numeric(x$lat) ||
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
    status("Location selected.")
  }
  clicking <- shiny::observeEvent(input$map_click, choose(input$map_click), ignoreInit = TRUE)
  shape_clicking <- shiny::observeEvent(input$map_shape_click, choose(input$map_shape_click), ignoreInit = TRUE)
  start <- function(kind, arg, distance = 50) {
    cancel()
    failure(NULL)
    tryCatch({
      busy(kind); elapsed(0L)
      shiny::showNotification(service_activity_ui(kind), id = notification_id,
        duration = NULL, closeButton = FALSE, session = session)
      job <<- launch(kind, arg, distance)
      operation <<- kind
      started <<- clock()
      status(if (kind == "locate") "Finding a nearby stream..." else "Retrieving HUC12, upstream basin and channel layers...")
    }, error = function(e) {
      cancel()
      status("The service request could not start. Saved records are unchanged. Please retry.")
    })
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
      if (!is.null(job)) status("Request stopped when leaving discovery. Saved records are unchanged.")
      cancel()
      clear_layers()
      proxy() |> leaflet::clearGroup("Located stream") |> leaflet::clearGroup("Selected location")
      # Viewing/editing a saved boundary must not discard completed discovery.
    }
  }, ignoreInit = TRUE)
  poll <- function() {
    if (is.null(job)) return()
    if (!enabled()) { cancel(); return() }
    if (as.numeric(difftime(clock(), started, units = "secs")) > 120) {
      cancel(); status("The USGS request exceeded two minutes and was stopped. Your point is retained; retry the same point. This is not evidence that it was too far from a stream."); return()
    }
    seconds <- floor(as.numeric(difftime(clock(), started, units = "secs")))
    if (seconds != shiny::isolate(elapsed())) {
      elapsed(seconds)
      shiny::showNotification(service_activity_ui(operation, seconds), id = notification_id,
        duration = NULL, closeButton = FALSE, session = session)
    }
    if (job$is_alive()) return()
    done <- job; job <<- NULL
    cancel()
    tryCatch({
      value <- done$get_result()
      if (operation == "locate") {
        located(value)
        proxy() |> leaflet::addPolylines(data = value$flowline, group = "Located stream", color = "#d95f02", weight = 6,
          options = leaflet::pathOptions(interactive = FALSE)) |>
          leaflet::addCircleMarkers(data = value$snapped_point, group = "Located stream", radius = 7,
            color = "#d95f02", fillOpacity = 1, label = "Snapped stream location",
            options = leaflet::pathOptions(interactive = FALSE))
        status("Stream located; highlighted in orange.")
      } else {
        result(value)
        m <- proxy()
        # The context-aware map observer paints the available discovery layers.
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
        status(if (all(value$status$status == "available")) "Candidate features loaded. Nothing saved." else
          "Some requests were incomplete; see each feature list for its outcome.")
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
  output$drainage_status <- shiny::renderUI({
    if (!is.null(busy())) service_activity_ui(busy(), elapsed()) else
      shiny::p(class = "small mb-1", role = "status", status())
  })
  output$drainage_failure <- shiny::renderUI({
    x <- failure()
    if (!is.null(x)) shiny::tags$details(shiny::tags$summary("Last failed request details"),
      shiny::p(x$time), shiny::tags$pre(style = "white-space: pre-wrap; overflow-wrap: anywhere;", x$detail))
  })
  output$drainage_location <- shiny::renderUI({
    x <- located()
    if (!is.null(x)) compact_table(data.frame(`Located COMID` = x$comid,
      `Snap distance (m)` = round(x$snap_distance_m), check.names = FALSE))
  })
  output$drainage_results <- shiny::renderUI({
    x <- result()
    if (identical(input$selection_target, "stream") && !is.null(polygon_controls))
      shiny::tagList(shiny::tags$h4("Stream line candidates", class = "h6 mb-1"),
        polygon_controls[c("upstream", "downstream")]) else drainage_result_ui(x, polygon_controls)
  })
  destroy <- function() {
    alive <<- FALSE; cancel()
    for (o in list(clicking, shape_clicking, locating, fetching, cancelling, mode, polling)) o$destroy()
  }
  session$onSessionEnded(destroy)
  list(destroy = destroy, poll = poll, clicked = clicked, located = located, result = result, status = status, busy = busy,
    state = function() shiny::isolate(list(clicked = clicked(), located = located(), result = result())))
}
