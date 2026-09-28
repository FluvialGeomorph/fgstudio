# Opt-in real-window producer with cached or Study-owned output. The developer
# supplies the small fixture; saved editions explicitly retain Reach-portion scope.
terrain_dem_trial_recipe <- function(trial) {
  paths <- c(trial$sources, trial$mask_file, trial$context_path, trial$group_path,
    unique(trial$source_selection$selection_path))
  info <- file.info(paths)
  if (anyNA(info$size)) stop("A saved trial input is unavailable.")
  list(version = 3L, backend = as.character(utils::packageVersion("fluvgeo")),
    paths = paths, size = info$size, modified = as.numeric(info$mtime),
    overlap = trial$unmasked_result$overlap, source_extent = trial$source_extent,
    source_selection = trial$source_selection, scope = trial$scope, reach_id = trial$reach$reach_id,
    stream_id = trial$stream_id,
    units = "international_foot", resampling = "bilinear", grid_handling = "ordered_source_grid_runs")
}

# Editions from the completed aligned workflow remain valid for identical saved
# inputs. Match that exact legacy recipe; changed grids/selections cannot reuse it.
terrain_dem_legacy_recipe <- function(recipe) {
  recipe$version <- 1L
  recipe$backend <- as.character(package_version("2026.09.24.9057"))
  recipe$resampling <- NULL
  recipe$grid_handling <- NULL
  recipe
}

terrain_dem_single_grid_recipe <- function(recipe) {
  recipe$version <- 2L
  recipe$backend <- as.character(package_version("2026.09.28.9058"))
  recipe$grid_handling <- NULL
  recipe
}

terrain_dem_mixed_grid_recipe <- function(recipe,backend="2026.09.28.9059") {
  recipe$version <- 3L
  recipe$backend <- as.character(package_version(backend))
  recipe
}

launch_terrain_dem_trial <- function(trial, directory, cached = NULL) {
  callr::r_bg(function(trial, directory, cached) {
    owner_file <- file.path(directory,"owner.json")
    if (file.exists(owner_file)) {
      owner <- jsonlite::read_json(owner_file,simplifyVector=TRUE)
      owner$worker_pid <- Sys.getpid()
      jsonlite::write_json(owner,owner_file,auto_unbox=TRUE,null="null")
    }
    if (!is.null(cached)) {
      destination <- file.path(directory,"dem-international-feet.tif")
      if (!file.copy(cached$result$path,destination,overwrite=FALSE)) stop("Could not stage completed DEM.")
      x <- terra::rast(cached$result$path); y <- terra::rast(destination)
      if (!terra::compareGeom(x,y) || !identical(terra::datatype(x),terra::datatype(y)) ||
          !identical(terra::units(x),terra::units(y)) ||
          file.info(cached$result$path)$size != file.info(destination)$size) stop("Staged DEM verification failed.")
      cached$result$path <- destination
      return(cached)
    }
    started <- proc.time()[["elapsed"]]
    trial$unmasked_result <- fluvgeo::mosaic_terrain_tiles(trial$sources,
      file.path(directory, "mosaic.tif"), trial$unmasked_result$overlap,
      extent = trial$source_extent, template = trial$mask_file)
    trial$masked_result <- fluvgeo::mask_terrain_mosaic(trial$unmasked_result$path,
      trial$mask_file, file.path(directory, "masked.tif"))
    trial$result <- fluvgeo::terrain_to_international_feet(trial$masked_result$path,
      file.path(directory, "dem-international-feet.tif"))
    if (isTRUE(trial$scope %in% c("reach","stream")) &&
        !terra::compareGeom(terra::rast(trial$result$path),terra::rast(trial$mask_file),
          crs=FALSE,stopOnError=FALSE))
      stop("Source coverage does not span the saved analysis grid. The DEM was not published.")
    trial$stage <- "international_feet"
    trial$seconds <- proc.time()[["elapsed"]] - started
    trial
  }, args = list(trial = trial, directory = directory, cached = cached), libpath = .libPaths(),
    stdout = NULL, stderr = NULL, poll_connection = FALSE,
    user_profile = FALSE, system_profile = FALSE, supervise = TRUE)
}

terrain_dem_trial_job <- function(input, output, session, initial, context, current,
                                  launch = launch_terrain_dem_trial, store = NULL, request_factory = NULL,
                                  request_ready = function() TRUE) {
  value <- shiny::reactiveVal(initial)
  busy <- shiny::reactiveVal(FALSE)
  notice <- shiny::reactiveVal(NULL)
  job <- NULL; directory <- NULL; recipe <- NULL; target <- NULL
  enabled <- isTRUE(getOption("fgstudio.dem_trial", FALSE)) || !is.null(request_factory)
  cache <- getOption("fgstudio.dem_trial_cache")
  binding <- NULL
  durable <- !is.null(store)
  resolve_sources <- function() {
    if (!isTRUE(initial$use_saved_sources)) return(initial)
    if (is.null(store)) stop("Saved-source processing requires the Study store.")
    resolved <- initial
    resolved$source_selection <- terrain_dem_sources(store, initial$key, initial$group_id,
      if(is.null(initial$stream_id)) initial$reach$stream_id else initial$stream_id, context()$path, context()$group_path)
    resolved$sources <- unique(resolved$source_selection$path)
    resolved
  }
  matching <- function() {
    ctx <- context()
    !is.null(ctx) && !is.null(current()) &&
      identical(current()$key, initial$key) && identical(ctx$group_id, initial$group_id) &&
      identical(normalizePath(ctx$path, winslash = "/", mustWork = FALSE),
                normalizePath(initial$context_path, winslash = "/", mustWork = FALSE)) &&
      identical(normalizePath(ctx$group_path, winslash = "/", mustWork = FALSE),
                normalizePath(initial$group_path, winslash = "/", mustWork = FALSE))
  }
  stop_job <- function() {
    if (!is.null(job)) {
      if (job$is_alive()) { job$kill(); job$wait(timeout = 2000) }
      if (job$is_alive()) stop("DEM worker has not stopped.")
      job <<- NULL
    }
    busy(FALSE)
    # Only this session's unique, unpublished job directory is removed.
    if (!is.null(directory)) {
      if (durable) store$discard_dem(initial$key,directory) else unlink(directory, recursive = TRUE)
    }
    directory <<- NULL
  }
  start <- function() {
    stop_job()
    if (!enabled) return()
    value(NULL)
    tryCatch({
      if (!request_ready()) { notice(NULL); return() }
      if (!is.null(request_factory)) initial <<- request_factory()
      if (is.null(initial)) { notice(NULL); return() }
      if (!matching()) { notice("Waiting for matching saved Survey Event settings."); return() }
      cache_available <- !is.null(cache) && dir.exists(cache)
      if (!durable && !cache_available) stop("The development DEM cache is unavailable.")
      initial <<- resolve_sources()
      recipe <<- terrain_dem_trial_recipe(initial)
      if (durable) {
        binding <<- store$dem_request(initial$key,initial$group_id,context()$path,context()$group_path)
        saved <- store$find_dem(binding,recipe)
        for(backend in c("2026.09.28.9060","2026.09.28.9059"))
          if(is.null(saved)) saved <- store$find_dem(binding,terrain_dem_mixed_grid_recipe(recipe,backend))
        if (is.null(saved)) saved <- store$find_dem(binding,terrain_dem_single_grid_recipe(recipe))
        if (is.null(saved)) saved <- store$find_dem(binding,terrain_dem_legacy_recipe(recipe))
        if (!is.null(saved)) { value(saved); notice("Saved DEM ready. No raster processing needed."); return() }
      }
      key <- as.character(openssl::sha256(serialize(recipe, NULL)))
      target <<- if(cache_available) file.path(cache, paste0(key, ".rds")) else NULL
      if (!is.null(target) && file.exists(target)) {
        saved <- readRDS(target)
        if (identical(saved$recipe, recipe) && file.exists(saved$trial$result$path)) {
          if (durable) {
            directory <<- store$prepare_dem(initial$key)
            job <<- launch(initial,directory,cached=saved$trial); busy(TRUE)
            notice("Saving the completed Reach portion DEM with this Survey Event.")
          } else { value(saved$trial); notice("DEM ready. Reused the completed small Reach result.") }
          return()
        }
      }
      if (durable) directory <<- store$prepare_dem(initial$key) else {
        directory <<- tempfile("dem-job-", tmpdir = cache); dir.create(directory)
      }
      job <<- launch(initial, directory); busy(TRUE)
      notice("Building the DEM from saved sources and the Event grid, then converting to international feet.")
    }, error = function(e) { stop_job(); notice(paste("DEM could not be built.", conditionMessage(e))) })
  }
  poll <- function() {
    if (is.null(job) || job$is_alive()) return()
    tryCatch({
      completed <- job$get_result()
      if (!matching() || !identical(recipe, terrain_dem_trial_recipe(resolve_sources())))
        stop("Saved inputs changed; the earlier result was not retained.")
      if (durable) {
        completed <- store$publish_dem(binding,recipe,directory,completed)
        directory <<- NULL; job <<- NULL; busy(FALSE); value(completed)
        notice("Development DEM saved with this Survey Event. Ready to review.")
        return()
      }
      temporary <- tempfile("result-", tmpdir = cache)
      on.exit(unlink(temporary), add = TRUE)
      saveRDS(list(recipe = recipe, trial = completed), temporary)
      if (!file.rename(temporary, target)) stop("Could not retain the completed DEM result.")
      directory <<- NULL; job <<- NULL; busy(FALSE); value(completed)
      notice("DEM ready. Mosaic, masking and international-foot conversion completed.")
    }, error = function(e) { stop_job(); notice(paste("DEM could not be built.", conditionMessage(e))) })
  }
  shiny::observeEvent(list(context(), current()$key, request_ready()), start(), ignoreNULL = FALSE)
  shiny::observe({ if (busy()) { shiny::invalidateLater(500, session); poll() } })
  shiny::observeEvent(input$cancel_dem, { stop_job(); notice("DEM preparation cancelled. Completed results are retained.") }, ignoreInit = TRUE)
  shiny::observeEvent(input$resume_dem, start(), ignoreInit = TRUE)
  output$job_status <- shiny::renderUI({
    if (!enabled) return(NULL)
    shiny::tagList(shiny::div(role = "status", notice()),
      if (busy()) shiny::actionButton(session$ns("cancel_dem"), "Cancel", class = "btn-outline-secondary btn-sm") else
        if (is.null(value()) && matching() && is.character(notice()) &&
            any(startsWith(notice(),c("DEM could not be built.","DEM preparation cancelled."))))
          shiny::actionButton(session$ns("resume_dem"), "Retry DEM", class = "btn-outline-secondary btn-sm"))
  })
  session$onSessionEnded(function() try(stop_job(), silent = TRUE))
  list(value = value, busy = busy, poll = poll, notice = notice)
}
