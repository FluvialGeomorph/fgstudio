# Saved DEM review; the Survey Event queue coordinates production work.
launch_terrain_mosaic_trial <- function(sources, filename, overlap) {
  callr::r_bg(function(sources, filename, overlap) {
    fluvgeo::mosaic_terrain_tiles(sources, filename, overlap)
  }, args = list(sources = sources, filename = filename, overlap = overlap),
  libpath = .libPaths(), stdout = NULL, stderr = NULL, poll_connection = FALSE,
  user_profile = FALSE, system_profile = FALSE, supervise = TRUE)
}

launch_terrain_mask_trial <- function(source, mask, filename) {
  callr::r_bg(function(source, mask, filename) {
    fluvgeo::mask_terrain_mosaic(source, mask, filename)
  }, args = list(source = source, mask = mask, filename = filename),
  libpath = .libPaths(), stdout = NULL, stderr = NULL, poll_connection = FALSE,
  user_profile = FALSE, system_profile = FALSE, supervise = TRUE)
}

launch_terrain_feet_trial <- function(source, filename) {
  callr::r_bg(function(source, filename) {
    fluvgeo::terrain_to_international_feet(source, filename)
  }, args = list(source = source, filename = filename),
  libpath = .libPaths(), stdout = NULL, stderr = NULL, poll_connection = FALSE,
  user_profile = FALSE, system_profile = FALSE, supervise = TRUE)
}

terrain_mosaic_trial_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::div(class = "pt-3",
    shiny::uiOutput(ns("job_status")),
    shiny::uiOutput(ns("summary")),
    shiny::conditionalPanel("output.has_dem === 'true'",ns=ns,
      shiny::plotOutput(ns("map"), height = "480px"),
      shiny::p(class = "small", "Orange: saved analysis boundary. Dashed line: source tile boundary. White: NoData."), shiny::uiOutput(ns("details"))))
}

terrain_mosaic_trial_server <- function(id, current, event_context = function() NULL, store = NULL,
                                      request_ready = function() TRUE, target_stream = NULL, process = TRUE) {
  path <- getOption("fgstudio.mosaic_trial")
  shiny::moduleServer(id, function(input, output, session) {
    initial <- if (process && !is.null(path)) readRDS(path) else NULL
    reach_id <- getOption("fgstudio.dem_reach")
    stream_id <- if(is.null(target_stream)) getOption("fgstudio.dem_stream") else target_stream
    factory <- if(process && (!is.null(reach_id) || !is.null(stream_id))) function()
      terrain_dem_request(store,current(),event_context(),reach_id,stream_id=stream_id) else NULL
    task <- if (!is.null(initial) || !is.null(factory)) terrain_dem_trial_job(input, output, session, initial, event_context, current, store=store,request_factory=factory,request_ready=request_ready) else list(value=function() NULL)
    saved <- shiny::reactive({
      ctx <- event_context()
      if (is.null(store) || is.null(current()) || is.null(ctx)) return(NULL)
      binding <- store$dem_request(current()$key,ctx$group_id,ctx$path,ctx$group_path)
      result <- if(is.null(target_stream)) store$find_dem(binding) else
        store$find_dem(binding,stream_id=target_stream,scope="stream")
      if (isTRUE(result$use_saved_sources)) {
        selected <- terrain_dem_sources(store, current()$key, ctx$group_id,
          if(is.null(result$stream_id)) result$reach$stream_id else result$stream_id, ctx$path, ctx$group_path)
        if (!identical(selected, result$source_selection)) return(NULL)
      }
      result
    })
    displayed <- shiny::reactive({
      pending_result <- task$value()
      if (!is.null(pending_result$saved_dem)) return(pending_result)
      if (!is.null(saved())) return(saved())
      pending_result
    })
    matching_study <- shiny::reactive(!is.null(current()) && (is.null(initial) ||
      !is.null(saved()) || identical(current()$key, initial$key)))
    matching_event <- shiny::reactive(!is.null(saved()) || is.null(initial$group_id) ||
      (!is.null(event_context()) && identical(event_context()$group_id, initial$group_id)))
    output$summary <- shiny::renderUI({
      shiny::req(matching_study())
      if (!matching_event()) return(shiny::p(paste("Select Survey Event", initial$event_label,
        "to view its small Reach mosaic trial.")))
      trial <- displayed()
      if (is.null(trial)) return(shiny::p("No DEM has been saved for these Survey Event settings."))
      full_reach <- identical(trial$saved_dem$scope,"reach") || identical(trial$scope,"reach")
      full_stream <- identical(trial$saved_dem$scope,"stream") || identical(trial$scope,"stream")
      shiny::tagList(
        if(!full_stream && !full_reach) shiny::p(
          if(identical(trial$level,"Stream")) "Preview: Stream portion" else "Preview: portion of Reach"),
        shiny::p(class = "mb-0",
          if (identical(trial$stage, "international_feet")) "Elevation: NAVD88 international feet." else
            paste("Source elevation unit:", trial$source_unit)),
        if (identical(trial$stage, "reach_masked")) shiny::p(class = "text-warning",
          "Unit conversion is pending; this preview retains source elevations."))
    })
    output$details <- shiny::renderUI({
      shiny::req(matching_study(), matching_event())
      trial <- displayed(); shiny::req(trial)
      item <- function(label, value) shiny::tagList(
        shiny::tags$dt(class = "col-sm-3", label),
        shiny::tags$dd(class = "col-sm-9", value))
      shiny::tags$details(class = "mt-2",
        shiny::tags$summary(class = "fw-semibold", "DEM details"),
        shiny::div(class = "mt-3",
          shiny::tags$dl(class = "row small mb-0",
            item("Grid dimensions", paste(paste(format(trial$result$dimensions[1:2], big.mark = ",", trim = TRUE), collapse = " x "), "(rows x columns)")),
            item("Cell spacing", paste(paste(trial$result$resolution, collapse = " x "),
              if(is.null(trial$horizontal_unit)) "metre" else trial$horizontal_unit)),
            if(!is.null(trial$unmasked_result$source_resolution)) item("Source cell spacing",
              paste(paste(trial$unmasked_result$source_resolution, collapse = " x "),
                if(is.null(trial$horizontal_unit)) "metre" else trial$horizontal_unit)),
            if(!is.null(trial$unmasked_result$source_resolutions)) item("Source cell spacing",
              paste(paste(vapply(trial$unmasked_result$source_resolutions,function(x)
                paste(x,collapse=" x "),character(1)),collapse="; "),
                if(is.null(trial$horizontal_unit)) "metre" else trial$horizontal_unit)),
            item("Resampling", if(identical(trial$unmasked_result$resampling,"bilinear"))
              if(isTRUE(trial$unmasked_result$mixed_source_grids))
                "Bilinear interpolation from differing source grids to the Event cell size." else
                "Bilinear interpolation to the Event cell size." else "None; source cells already aligned with the Event grid."),
            item("Storage", paste(trial$result$datatype, "GeoTIFF", if(!is.null(trial$saved_dem)) "in the Study folder")),
            item("Sources", if(!is.null(trial$source_selection)) paste(nrow(trial$source_selection),
              "DEM files selected automatically from saved Survey Event and Stream assignments.") else paste(length(trial$sources), "source DEM files")),
            item("Processing", if(!is.null(trial$result$method)) trial$result$method else
              "Processing method was not recorded by this producer."),
            item("Processing time", sprintf("%.2f seconds", trial$seconds))),
          terrain_dem_provenance_ui(trial)))
    })
    output$map <- shiny::renderPlot({
      shiny::req(matching_study(), matching_event())
      trial <- displayed(); shiny::req(trial)
      draw_terrain_mosaic_trial(trial)
    })
    output$has_dem <- shiny::renderText(if (matching_study() && matching_event() && !is.null(displayed())) "true" else "false")
    shiny::outputOptions(output,"has_dem",suspendWhenHidden=FALSE)
  })
}

draw_terrain_mosaic_trial <- function(trial) {
  r <- terra::rast(trial$result$path)
  if (terra::ncell(r) > 250000) r <- terra::spatSample(r, 250000, method = "regular", as.raster = TRUE)
  terra::plot(r, col = grDevices::hcl.colors(80, "Terrain"), axes = TRUE,
              main = if (identical(trial$stage, "international_feet")) paste(if(identical(trial$level,"Stream")) "Stream" else "Reach","DEM (international feet)") else if (identical(trial$stage, "reach_masked")) "Reach DEM preview (source metres)" else "Mosaicked elevation (source metres)")
  boundary <- sf::st_transform(if(is.null(trial$boundary)) trial$reach else trial$boundary,terra::crs(r))
  graphics::plot(sf::st_geometry(boundary), add = TRUE, border = "#e68a00", lwd = 2)
  for (p in trial$sources) {
    e <- as.vector(terra::ext(terra::rast(p)))
    graphics::rect(e[1], e[3], e[2], e[4], lty = 2)
  }
}
