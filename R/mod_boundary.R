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

mod_boundary_ui <- function(id, exploration_only = FALSE) {
  ns <- shiny::NS(id)
  bslib::card(
    bslib::card_header(if (exploration_only) "Explore before defining your study" else "2. Explore or draw your Study Area"),
    shiny::radioButtons(ns("map_mode"), NULL,
      choices = if (exploration_only) c("Explore drainage" = "explore") else c("Draw boundary" = "draw", "Explore drainage" = "explore"),
      selected = if (exploration_only) "explore" else "draw", inline = TRUE),
    shiny::p("Use the magnifying glass to find a place, or zoom and pan the map."),
    leaflet::leafletOutput(ns("map"), height = "480px"),
    shiny::conditionalPanel("input.map_mode === 'explore'", ns = ns,
      shiny::uiOutput(ns("reference_status"))),
    shiny::conditionalPanel("input.map_mode === 'draw'", ns = ns,
    shiny::p("Select the polygon tool and click around the boundary; click the first point to finish. When editing, the toolbar Save finishes editing; Save boundary below stores it."),
    shiny::uiOutput(ns("status")),
    shiny::actionButton(ns("save"), "Save boundary", class = "btn-primary"),
    shiny::p(class = "small text-body-secondary",
      "Drawing, editing and removing shapes only change the candidate until you save. Previous saved revisions are retained.")),
    shiny::conditionalPanel("input.map_mode === 'explore'", ns = ns, drainage_explorer_ui(ns)),
    shiny::tags$details(shiny::tags$summary("Map and coordinate information"),
      shiny::p("The magnifying glass opens place search. Search text goes to Photon (OpenStreetMap data) after a pause in typing. Use public place names only. Selecting a match moves the map without changing your boundary."),
      shiny::p("Basemap tiles come from OpenStreetMap and require an internet connection. Tile requests reveal the viewed map area to the tile service; study names and drawn geometry are not uploaded to it."),
      shiny::p("Drawings are saved in WGS 84 longitude/latitude. This is not a choice of analysis CRS. Import and watershed selection will be added later."))
  )
}

# Each opened revision gets an isolated editor. Inactive editors cannot save.
mod_boundary_server <- function(id, study, store, is_active, on_saved, search = search_places,
                                exploration_only = FALSE, launch = launch_drainage_job) {
  shiny::moduleServer(id, function(input, output, session) {
    candidate <- shiny::reactiveVal(NULL)
    dirty <- shiny::reactiveVal(FALSE)
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
      if (!exploration_only) map <- boundary_draw_toolbar(map)
      map <- add_network_reference(map, enabled = exploration_only)
      map <- leaflet::addLayersControl(map, overlayGroups = c("NHDPlusV2 reference channels", "boundary", "Located stream", unname(drainage_groups)),
        options = leaflet::layersControlOptions(collapsed = FALSE))
      add_place_search(map)
    })
    exploring <- drainage_explorer(input, output, session, function() is_active() && !dirty(), launch)
    changing_mode <- shiny::observeEvent(input$map_mode, {
      if (!is_active()) return()
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
      if (!is_active() || exploration_only || identical(input$map_mode, "explore")) return()
      dirty(TRUE)
      candidate(NULL)
      tryCatch({
        candidate(drawn_boundary(input$map_draw_all_features))
        status("Unsaved boundary ready for review. Select Save boundary to retain it.")
      }, error = function(e) status(conditionMessage(e)))
    }, ignoreInit = TRUE)
    starting <- shiny::observeEvent(list(input$map_draw_start, input$map_draw_editstart,
        input$map_draw_deletestart), {
      if (!is_active() || exploration_only || identical(input$map_mode, "explore")) return()
      dirty(TRUE)
      candidate(NULL)
      status("Drawing changes are in progress. Finish the drawing or use the map toolbar's Save control before saving the boundary.")
    }, ignoreInit = TRUE, priority = 10)
    saving <- shiny::observeEvent(input$save, {
      if (!is_active() || exploration_only || identical(input$map_mode, "explore")) return()
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
        status("Boundary could not be saved. Reopen the study to check its latest revision before retrying. Earlier records were retained.")
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
      shiny::p(class = "small text-body-secondary", role = "status", text)
    })
    list(has_unsaved = function() shiny::isolate(dirty()), destroy = function() {
      drawing$destroy(); starting$destroy(); saving$destroy()
      searching$destroy()
      changing_mode$destroy(); exploring$destroy()
    })
  })
}

boundary_draw_toolbar <- function(map) {
  leaflet.extras::addDrawToolbar(map, targetGroup = "boundary", singleFeature = TRUE,
    polylineOptions = FALSE, circleOptions = FALSE, rectangleOptions = FALSE,
    markerOptions = FALSE, circleMarkerOptions = FALSE,
    polygonOptions = leaflet.extras::drawPolygonOptions(),
    editOptions = leaflet.extras::editToolbarOptions(), drag = FALSE)
}
