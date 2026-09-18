# Convert the browser's GeoJSON payload, not file paths or user-supplied CRS.
drawn_boundary <- function(collection) {
  if (!is.list(collection) || !identical(collection$type, "FeatureCollection") ||
      length(collection$features) != 1L)
    stop("Draw one polygon to define the Study Area.", call. = FALSE)
  geometry <- collection$features[[1]]$geometry
  if (!identical(geometry$type, "Polygon") || !length(geometry$coordinates))
    stop("The boundary must be a polygon.", call. = FALSE)
  rings <- lapply(geometry$coordinates, function(ring) {
    if (length(ring) < 4L || length(ring) > 5000L)
      stop("Use a closed polygon with 3 to 4,999 vertices.", call. = FALSE)
    points <- lapply(ring, function(point) {
      point <- unlist(point, use.names = FALSE)
      if (!is.numeric(point) || length(point) != 2L || any(!is.finite(point)) ||
          abs(point[1]) > 180 || abs(point[2]) > 90)
        stop("The drawing contains invalid longitude/latitude coordinates.", call. = FALSE)
      point
    })
    xy <- do.call(rbind, points)
    if (!identical(unname(xy[1, ]), unname(xy[nrow(xy), ])))
      stop("Finish the polygon by clicking its first point.", call. = FALSE)
    xy
  })
  boundary <- sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(rings), crs = 4326))
  if (!isTRUE(sf::st_is_valid(boundary)) || sf::st_is_empty(boundary))
    stop("The boundary is invalid. Check for crossing edges or overlapping vertices and redraw.", call. = FALSE)
  boundary
}

mod_boundary_ui <- function(id, exploration_only = FALSE, selection_draft = NULL, study = NULL) {
  ns <- shiny::NS(id)
  bslib::card(
    bslib::card_header(if (exploration_only) "Explore before defining your study" else
      if (isTRUE(study$boundary)) "2. Study Area, Streams and Reaches" else "2. Define your Study Area"),
    shiny::radioButtons(ns("selection_target"), "Working on",
      choices = if (exploration_only) c("Study Area" = "boundary") else
        c("View" = "view", "Study Area" = "boundary", "Streams" = "stream", "Reaches" = "reach"),
      selected = boundary_initial_target(study, exploration_only, selection_draft), inline = TRUE),
    shiny::conditionalPanel("input.selection_target === 'boundary'", ns = ns,
      shiny::radioButtons(ns("boundary_method"), "Boundary method",
        choices = if (exploration_only) c("Select watersheds" = "explore") else
          c("Select watersheds" = "explore", "Draw / edit polygon" = "draw"),
        selected = if (boundary_initial_mode(study, exploration_only, selection_draft) == "draw") "draw" else "explore", inline = TRUE)),
    # Internal compatibility input for the map helpers; the task selector is the UI.
    shiny::div(style = "display:none;", shiny::radioButtons(ns("map_mode"), NULL,
      choices = c("view", "draw", "explore", "reach"), selected = boundary_initial_mode(study, exploration_only, selection_draft))),
    shiny::uiOutput(ns("task_status")),
    bslib::layout_columns(col_widths = bslib::breakpoints(sm = c(12, 12), lg = c(8, 4)),
      bslib::card(full_screen = TRUE, height = "72vh", min_height = "360px",
        bslib::card_body(class = "p-0", leaflet::leafletOutput(ns("map"), height = "100%")),
        bslib::card_footer(
          shiny::conditionalPanel("input.map_mode === 'explore'", ns = ns,
            shiny::uiOutput(ns("reference_status"))))),
      shiny::div(
        shiny::conditionalPanel("input.map_mode === 'view'", ns = ns,
          compact_table(data.frame(Item = c("Boundary", "Next", "Editing rule"),
            Status = c("Saved; click a Stream or Reach for details (use layers to reveal overlapping features)", "Choose Study Area, Streams or Reaches to edit", "Must retain all saved Stream and Reach areas")))),
        shiny::conditionalPanel("input.map_mode === 'draw'", ns = ns,
          compact_table(data.frame(Step = c("Draw / edit", "Store"),
            Action = c("Finish the polygon with the map toolbar", "Select Save boundary below"))),
          shiny::uiOutput(ns("status")),
          shiny::actionButton(ns("save"), "Save boundary", class = "btn-primary"),
          shiny::p(class = "small text-body-secondary", "Changes remain a draft until saved.")),
        shiny::conditionalPanel("input.map_mode === 'explore'", ns = ns, drainage_explorer_ui(ns, selection_draft)),
        shiny::conditionalPanel("input.selection_target === 'reach'", ns = ns,
          reach_selection_ui(ns, study, selection_draft$reach))))
  )
}

# Each opened revision gets an isolated editor. Inactive editors cannot save.
mod_boundary_server <- function(id, study, store, is_active, on_saved, search = search_places,
                                exploration_only = FALSE, launch = launch_drainage_job, selection_draft = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    candidate <- shiny::reactiveVal(NULL)
    dirty <- shiny::reactiveVal(FALSE)
    task_status <- shiny::reactiveVal(NULL)
    rejected_task <- FALSE
    status <- shiny::reactiveVal("No unsaved boundary. Draw a polygon or edit the displayed boundary.")
    searching <- shiny::observeEvent(input$map_place_query, {
      if (!is_active()) return()
      query <- input$map_place_query
      if (!is.list(query) || length(query$token) != 1L || !is.numeric(query$token) ||
          !is.finite(query$token)) return()
      rows <- list()
      error <- NULL
      tryCatch({
        found <- search(query$text)
        rows <- lapply(seq_len(nrow(found)), function(i) as.list(found[i, ]))
        if (!length(rows)) error <- "No places found. Add a town or state."
      }, error = function(e) error <<- conditionMessage(e))
      leaflet::invokeMethod(leaflet::leafletProxy("map", session = session), NULL,
        "fgPlaceResults", query$token, rows, error)
    }, ignoreInit = TRUE)
    output$map <- leaflet::renderLeaflet({
      map <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) |>
        leaflet::addTiles(options = leaflet::tileOptions(noWrap = TRUE))
      if (!is.null(study$boundary_sf)) {
        shape <- sf::st_transform(study$boundary_sf, 4326)
        box <- sf::st_bbox(shape)
        map <- map |> leaflet::addPolygons(data = shape, group = "boundary", color = "#245c4f",
          weight = 3, fillOpacity = 0.15) |>
          leaflet::fitBounds(box[[1]], box[[2]], box[[3]], box[[4]])
      } else map <- leaflet::setView(map, lng = -98, lat = 39, zoom = 4)
      initial_mode <- boundary_initial_mode(study, exploration_only, selection_draft)
      if (identical(initial_mode, "draw")) map <- boundary_draw_toolbar(map)
      map <- saved_feature_layers(map, study, identical(initial_mode, "view"))
      if (identical(initial_mode, "explore")) map <- drainage_layers(map, selection_draft$exploration)
      b <- selection_draft$bounds
      if (valid_map_bounds(b)) map <- leaflet::fitBounds(map, b$west, b$south, b$east, b$north)
      map <- add_network_reference(map, enabled = identical(initial_mode, "explore"))
      add_place_search(map)
    })
    exploring <- drainage_explorer(input, output, session, function() is_active() && !dirty(), launch,
      polygon_controls = list(huc12 = shiny::uiOutput(session$ns("select_huc12")),
        basin = shiny::uiOutput(session$ns("select_basin")),
        upstream = shiny::uiOutput(session$ns("select_upstream")),
        downstream = shiny::uiOutput(session$ns("select_downstream"))), draft = selection_draft$exploration,
      stream_pending = function() stream_selection$has_pending() || selection$has_pending())
    identifying <- shiny::observeEvent(input$map_mode, {
      if (is_active()) saved_feature_layers(leaflet::leafletProxy("map", session = session),
        study, identical(input$map_mode, "view"))
    }, ignoreInit = TRUE)
    feature_focus <- lapply(c("reach_parent", "split_reach", "merge_keep"), function(field) {
      shiny::observeEvent(input[[field]], {
        if (!is_active() || !identical(input$selection_target, "reach")) return()
        if (field == "split_reach" && !identical(input$reach_operation, "split")) return()
        if (field == "merge_keep" && !identical(input$reach_operation, "merge")) return()
        focus_saved_feature(leaflet::leafletProxy("map", session = session),
          saved_feature_shape(study, if (field == "reach_parent") "stream" else "reach", input[[field]]))
      }, priority = -5)
    })
    selection <- polygon_selection(input, output, session, exploring, study, store,
      function() is_active() && !dirty(), on_saved, selection_draft)
    stream_selection <- stream_selection_server(input, output, session, exploring, study, store,
      function() is_active() && !dirty() && !selection$has_pending(), on_saved, selection_draft$stream)
    reach_selection <- reach_selection_server(input, output, session, study, store,
      function() is_active() && !dirty() && !selection$has_pending() && !stream_selection$has_pending(),
      on_saved, selection_draft$reach)
    reach_merge <- reach_merge_server(input, output, session, study, store, reach_selection$source,
      function() is_active() && !dirty() && !selection$has_pending() && !stream_selection$has_pending(), on_saved)
    reach_split <- reach_split_server(input,output,session,study,store,reach_selection$source,
      function() is_active() && !dirty() && !selection$has_pending() && !stream_selection$has_pending(),on_saved)
    reach_action <- shiny::observeEvent(input$reach_operation, {
      if (!identical(input$reach_operation, "new") && reach_selection$has_pending()) {
        shiny::updateRadioButtons(session, "reach_operation", selected = "new")
        task_status("Save or Clear the selected segments before combining saved Reaches.")
      } else if (!identical(input$reach_operation, "merge") && reach_merge$has_pending()) {
        shiny::updateRadioButtons(session, "reach_operation", selected = "merge")
        task_status("Save or Clear the combination before defining another Reach.")
      } else if (!identical(input$reach_operation,"split") && reach_split$has_pending()) {
        shiny::updateRadioButtons(session,"reach_operation",selected="split")
        task_status("Save or Clear the split before changing actions.")
      }
    }, ignoreInit = TRUE)
    discovery_painting <- shiny::observe({
      if (!is_active()) return()
      state <- list(clicked = exploring$clicked(), located = exploring$located(), result = exploring$result())
      drainage_layers(leaflet::leafletProxy("map", session = session),
        if (identical(input$map_mode, "explore")) state else NULL,
        target = if (identical(input$selection_target, "stream")) "stream" else "boundary")
    })
    layer_groups <- shiny::reactive(c(context_layer_groups(input$map_mode, input$selection_target,
      boundary = isTRUE(study$boundary) || !is.null(candidate()), saved_streams = inherits(study$stream_inventory, "sf"),
      state = list(clicked = exploring$clicked(), located = exploring$located(), result = exploring$result()),
      polygons = selection$pool(), polygon_preview = selection$preview(),
      channels = stream_selection$pool(), stream_preview = stream_selection$preview()),
      if (inherits(study$reach_inventory, "sf")) "Saved Reaches",
      if (identical(input$selection_target, "reach") && !isTRUE(input$reach_operation %in% c("merge","split")) && !is.null(reach_selection$source())) "Reach candidates",
      if (identical(input$selection_target, "reach") && !isTRUE(input$reach_operation %in% c("merge","split")) && !is.null(reach_selection$preview())) "Reach preview",
      if (identical(input$selection_target, "reach") && identical(input$reach_operation, "merge") &&
          !is.null(study$reach_inventory) && any(study$reach_inventory$stream_id %in% input$reach_parent)) "Reach merge candidates",
      if (identical(input$selection_target, "reach") && identical(input$reach_operation, "merge") && !is.null(reach_merge$preview())) "Reach merge preview",
      if (identical(input$selection_target,"reach") && identical(input$reach_operation,"split") && !is.null(input$split_reach) && nzchar(input$split_reach)) "Reach split line",
      if (identical(input$selection_target,"reach") && identical(input$reach_operation,"split") && !is.null(reach_split$preview())) "Reach split preview"))
    layer_control <- shiny::observeEvent(layer_groups(), {
      map <- leaflet::leafletProxy("map", session = session) |> leaflet::removeLayersControl()
      if (length(layer_groups())) leaflet::addLayersControl(map, overlayGroups = layer_groups(),
        options = leaflet::layersControlOptions(collapsed = TRUE))
    }, ignoreNULL = FALSE, priority = -10)
    initialized <- shiny::observeEvent(input$map_mode, {
      if (!is.null(selection_draft$polygon_action)) shiny::updateRadioButtons(session,
        "polygon_action", selected = selection_draft$polygon_action)
      else if (length(selection_draft$selected)) shiny::updateRadioButtons(session, "polygon_action", selected = "select")
      if (!is.null(selection_draft$distance)) shiny::updateNumericInput(session, "navigation_km", value = selection_draft$distance)
    }, once = TRUE)
    target_change <- shiny::observeEvent(list(input$selection_target, input$boundary_method), {
      if (!is_active() || is.null(input$selection_target)) return()
      # Keep a rejection visible when the browser applies our corrective choice.
      if (rejected_task) rejected_task <<- FALSE else task_status(NULL)
      requested <- if (input$selection_target == "view") "view" else
        if (input$selection_target == "reach") "reach" else
        if (input$selection_target == "stream") "explore" else
          if (identical(input$boundary_method, "draw")) "draw" else "explore"
      if (dirty() && requested != "draw") {
        rejected_task <<- TRUE
        shiny::updateRadioButtons(session, "selection_target", selected = "boundary")
        shiny::updateRadioButtons(session, "boundary_method", selected = "draw")
        task_status("Finish and save the boundary drawing before switching tasks.")
        return()
      }
      if (input$selection_target == "reach" && (selection$has_pending() || stream_selection$has_pending())) {
        rejected_task <<- TRUE
        shiny::updateRadioButtons(session, "selection_target", selected = if (selection$has_pending()) "boundary" else "stream")
        task_status("Save or clear the current geometry selection before defining Reaches.")
        return()
      }
      if (input$selection_target != "reach" && (reach_selection$has_pending() || reach_merge$has_pending() || reach_split$has_pending())) {
        rejected_task <<- TRUE
        shiny::updateRadioButtons(session, "selection_target", selected = "reach")
        task_status("Save or Clear the selected Reach before switching tasks.")
        return()
      }
      if (identical(input$selection_target, "stream") && selection$has_pending()) {
        rejected_task <<- TRUE
        shiny::updateRadioButtons(session, "selection_target", selected = "boundary")
        task_status("Save or clear the selected Study Area polygons before defining Streams.")
        return()
      }
      if (requested == "draw" && selection$has_pending()) {
        rejected_task <<- TRUE
        shiny::updateRadioButtons(session, "boundary_method", selected = "explore")
        task_status("Save or clear selected polygons before drawing a different boundary.")
        return()
      }
      shiny::updateRadioButtons(session, "map_mode", selected = requested)
      if (input$selection_target == "stream") shiny::updateRadioButtons(session,
        "stream_action", selected = if (is.null(stream_selection$pool())) "point" else "select")
    })
    output$task_status <- shiny::renderUI({
      if (!is.null(task_status())) shiny::div(class = "alert alert-warning py-1", role = "status", task_status())
    })
    output$workflow_next <- shiny::renderUI({
      stream <- identical(input$selection_target, "stream")
      step <- if (stream && !isTRUE(study$boundary)) "Choose Study Area and save its boundary first." else
        if (stream && !is.null(stream_selection$pool()) && identical(input$stream_action, "select")) {
          if (!length(stream_selection$selected())) "Check channel segments (or click their lines), or click an empty map location to find more channels." else
            if (is.null(input$buffer_distance) || !is.finite(input$buffer_distance) || input$buffer_distance <= 0 ||
                (is.null(input$stream_existing) && (is.null(input$stream_name) || !nzchar(trimws(input$stream_name)))))
              "Enter the Stream name and buffer distance on EACH side." else
                if (is.null(stream_selection$preview())) "Select Preview Stream and review the gold area." else
                  if (stream_selection$preview()$containment != "inside") "Preview failed containment verification. Revise the geometry and preview again; save is blocked." else
                    if (isTRUE(stream_selection$preview()$clipped)) "Review the clipped gold area; Save Stream, or enlarge the Study Area if needed." else "Select Save Stream."
        } else if (!stream && identical(input$polygon_action, "select")) "Check watershed polygons, then Preview boundary and Save." else
          if (is.null(exploring$clicked())) "Click near a blue channel on the map, then select Snap to stream." else
            if (is.null(exploring$located())) "Select Snap to stream for the black point on the map." else
              "Review the orange channel, then select Explore this stream to load selectable features."
      compact_table(data.frame(`Working on` = if (stream) "Stream" else "Study Area",
        `Do next` = step, check.names = FALSE))
    })
    changing_mode <- shiny::observeEvent(input$map_mode, {
      if (!is_active()) return()
      if (identical(input$map_mode, "draw") && selection$has_pending()) {
        shiny::updateRadioButtons(session, "map_mode", selected = "explore")
        selection$status("Save or clear selected polygons before drawing a different boundary.")
        return()
      }
      if (identical(input$map_mode, "explore") && dirty()) {
        shiny::updateRadioButtons(session, "map_mode", selected = "draw")
        status("Save your boundary changes first, or reopen the study to discard them before exploring.")
        return()
      }
      leaflet::invokeMethod(leaflet::leafletProxy("map", session = session), NULL,
        "fgReferenceMode", identical(input$map_mode, "explore"))
      map <- leaflet.extras::removeDrawToolbar(leaflet::leafletProxy("map", session = session))
      if (identical(input$map_mode, "draw") && !exploration_only) boundary_draw_toolbar(map)
    }, ignoreInit = TRUE)
    drawing <- shiny::observeEvent(input$map_draw_all_features, {
      if (!is_active() || exploration_only || isTRUE(input$map_mode %in% c("explore", "view", "reach"))) return()
      dirty(TRUE)
      candidate(NULL)
      tryCatch({
        candidate(drawn_boundary(input$map_draw_all_features))
        status("Unsaved boundary ready for review. Select Save boundary to retain it.")
      }, error = function(e) status(conditionMessage(e)))
    }, ignoreInit = TRUE)
    starting <- shiny::observeEvent(list(input$map_draw_start, input$map_draw_editstart,
        input$map_draw_deletestart), {
      if (!is_active() || exploration_only || isTRUE(input$map_mode %in% c("explore", "view", "reach"))) return()
      dirty(TRUE)
      candidate(NULL)
      status("Drawing changes are in progress. Finish the drawing or use the map toolbar's Save control before saving the boundary.")
    }, ignoreInit = TRUE, priority = 10)
    saving <- shiny::observeEvent(input$save, {
      if (!is_active() || exploration_only || isTRUE(input$map_mode %in% c("explore", "view", "reach"))) return()
      if (is.null(candidate())) {
        status("Draw or finish editing a valid polygon before saving. The saved boundary has not changed.")
        return()
      }
      tryCatch({
        result <- store$save_boundary(study$key, candidate(), study$path)
        candidate(NULL)
        dirty(FALSE)
        on_saved(result)
      }, error = function(e) {
        status(paste("Boundary not saved.", conditionMessage(e)))
        message("fgstudio boundary save failed [", class(e)[[1]], "]")
      })
    }, ignoreInit = TRUE)
    output$status <- shiny::renderUI(shiny::p(role = "status", status()))
    output$reference_status <- shiny::renderUI({
      state <- input$map_reference_state
      text <- if (identical(state, "visible")) "Blue lines: NHDPlusV2 reference channels. Click near one to snap. Tiles are display guidance, not surveyed geometry." else
        if (identical(state, "hidden")) "Reference channels are hidden. Turn on NHDPlusV2 reference channels in the map layer control." else
        if (identical(state, "error")) "Some reference tiles failed to load. A blank map is not evidence of no streams; pan or toggle the layer to retry." else
          "Zoom in to show the NHDPlusV2 reference channels before choosing a point."
      shiny::p(class = "small text-body-secondary mb-0", role = "status", text)
    })
    list(focus_feature = function(shape) {
        if (is_active()) focus_saved_feature(leaflet::leafletProxy("map", session = session), shape)
      }, has_unsaved = function() shiny::isolate(dirty()) || selection$has_pending() || stream_selection$has_pending() || reach_selection$has_pending() || reach_merge$has_pending() || reach_split$has_pending(),
      selection_state = function() shiny::isolate(c(selection$state(), list(
        exploration = exploring$state(), bounds = if (valid_map_bounds(input$map_bounds)) input$map_bounds else selection_draft$bounds,
        map_mode = input$map_mode, target = input$selection_target, polygon_action = input$polygon_action,
        distance = input$navigation_km, stream = stream_selection$state(), reach = reach_selection$state()))), destroy = function() {
      drawing$destroy(); starting$destroy(); saving$destroy()
      searching$destroy()
      changing_mode$destroy(); exploring$destroy(); selection$destroy(); stream_selection$destroy()
      reach_selection$destroy()
      reach_merge$destroy(); reach_split$destroy(); reach_action$destroy()
      initialized$destroy(); target_change$destroy()
      discovery_painting$destroy(); layer_control$destroy()
      identifying$destroy(); lapply(feature_focus, function(observer) observer$destroy())
    })
  })
}

boundary_initial_target <- function(study, exploration_only, draft) {
  if (exploration_only) return("boundary")
  if (identical(draft$target, "reach")) return("reach")
  if (boundary_initial_mode(study, exploration_only, draft) == "view") return("view")
  if (identical(draft$target, "stream")) "stream" else "boundary"
}

boundary_initial_mode <- function(study, exploration_only, draft) {
  if (exploration_only || length(draft$selected) || length(draft$stream$selected)) return("explore")
  if (!is.null(draft$map_mode) && draft$map_mode %in% c("view", "draw", "explore", "reach")) return(draft$map_mode)
  if (isTRUE(study$boundary)) "view" else "draw"
}

valid_map_bounds <- function(b) {
  fields <- c("west", "south", "east", "north")
  is.list(b) && all(fields %in% names(b)) && all(vapply(b[fields],
    function(x) is.numeric(x) && length(x) == 1L && is.finite(x), logical(1))) &&
    b$west < b$east && b$south < b$north && b$south >= -90 && b$north <= 90
}

boundary_draw_toolbar <- function(map) {
  leaflet.extras::addDrawToolbar(map, targetGroup = "boundary", singleFeature = TRUE,
    polylineOptions = FALSE, circleOptions = FALSE, rectangleOptions = FALSE,
    markerOptions = FALSE, circleMarkerOptions = FALSE,
    polygonOptions = leaflet.extras::drawPolygonOptions(),
    editOptions = leaflet.extras::editToolbarOptions(), drag = FALSE)
}
