# Saved DEM review plus an opt-in real-window producer. Never auto-dispatches
# full Streams; current saved editions explicitly describe a Reach portion.
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
  bslib::card(
    bslib::card_header("DEM"),
    shiny::uiOutput(ns("job_status")),
    shiny::uiOutput(ns("summary")),
    shiny::uiOutput(ns("download_ui")),
    shiny::conditionalPanel("output.has_dem === 'true'",ns=ns,
      shiny::plotOutput(ns("map"), height = "480px"),
      shiny::p(class = "small", "Orange: saved Reach boundary. Dashed line: source tile boundary. White: NoData. This Reach portion is not a completed Stream DEM.")))
}

terrain_mosaic_trial_server <- function(id, current, event_context = function() NULL, store = NULL) {
  path <- getOption("fgstudio.mosaic_trial")
  shiny::moduleServer(id, function(input, output, session) {
    initial <- if (!is.null(path)) readRDS(path) else NULL
    task <- if (!is.null(initial)) terrain_dem_trial_job(input, output, session, initial, event_context, current, store=store) else list(value=function() NULL)
    saved <- shiny::reactive({
      ctx <- event_context()
      if (is.null(store) || is.null(current()) || is.null(ctx)) return(NULL)
      binding <- store$dem_request(current()$key,ctx$group_id,ctx$path,ctx$group_path)
      store$find_dem(binding)
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
      shiny::tagList(
      shiny::p(paste(trial$stream_name, "-", trial$reach$reach_name,
                     "(portion of Reach); two actual downloaded DEM windows.")),
      if (!is.null(trial$saved_dem)) shiny::p("Saved with this Survey Event - Reach portion. Full Stream coverage has not been built."),
      shiny::p(paste(paste(trial$result$dimensions[1:2], collapse = " x "),
                     "cells; 1 m source spacing; Float32;", trial$source_crs)),
      if (identical(trial$stage, "international_feet")) shiny::p(
        "Elevation: NAVD88 international feet (metres / 0.3048). Horizontal grid: unchanged, 1 metre. No resampling or datum transformation. Saved Reach mask retained.") else
        shiny::p(paste("Source elevation unit:", trial$source_unit,
                     "- no resampling or elevation conversion.")),
      if (identical(trial$stage, "reach_masked")) shiny::tagList(
        shiny::p("Saved Reach mask applied. Outside-Reach cells are NoData; retained elevations are unchanged. The existing Survey Event grid already matches the source grid."),
        shiny::p(paste("Preview: NAVD88 metres. Saved target:", trial$target_vertical$reference_name,
                       "(international feet). Unit conversion is pending; this is not target-unit terrain."))),
      shiny::p(sprintf("Recorded processing time: %.2f seconds. Source DEMs and saved Study/Event settings are unchanged.", trial$seconds)))
    })
    output$map <- shiny::renderPlot({
      shiny::req(matching_study(), matching_event())
      trial <- displayed(); shiny::req(trial)
      draw_terrain_mosaic_trial(trial)
    })
    output$download_ui <- shiny::renderUI({
      shiny::req(matching_study(),matching_event())
      trial <- displayed(); shiny::req(trial$saved_dem)
      shiny::downloadButton(session$ns("download_dem"),"Download DEM (GeoTIFF)")
    })
    output$has_dem <- shiny::renderText(if (matching_study() && matching_event() && !is.null(displayed())) "true" else "false")
    shiny::outputOptions(output,"has_dem",suspendWhenHidden=FALSE)
    output$download_dem <- shiny::downloadHandler(
      filename=function() paste0("DEM-",gsub("[^A-Za-z0-9_-]","_",displayed()$event_label),"-Reach-portion-international-feet.tif"),
      content=function(file) {
        shiny::req(matching_study(),matching_event())
        trial <- displayed(); shiny::req(trial$saved_dem)
        if (!file.copy(trial$result$path,file,overwrite=TRUE)) stop("Could not download the saved DEM.")
      },contentType="image/tiff")
  })
}

draw_terrain_mosaic_trial <- function(trial) {
  r <- terra::rast(trial$result$path)
  if (terra::ncell(r) > 250000) r <- terra::spatSample(r, 250000, method = "regular", as.raster = TRUE)
  terra::plot(r, col = grDevices::hcl.colors(80, "Terrain"), axes = TRUE,
              main = if (identical(trial$stage, "international_feet")) "Reach DEM (international feet)" else if (identical(trial$stage, "reach_masked")) "Reach DEM preview (source metres)" else "Mosaicked elevation (source metres)")
  graphics::plot(sf::st_geometry(trial$reach), add = TRUE, border = "#e68a00", lwd = 2)
  for (p in trial$sources) {
    e <- as.vector(terra::ext(terra::rast(p)))
    graphics::rect(e[1], e[3], e[2], e[4], lty = 2)
  }
}
