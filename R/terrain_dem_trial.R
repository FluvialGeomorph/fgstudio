# Opt-in real-window producer with cached or Study-owned output. The developer
# supplies the small fixture; saved editions explicitly retain Reach-portion scope.
terrain_dem_trial_recipe <- function(trial) {
  paths <- c(trial$sources, trial$mask_file, trial$context_path, trial$group_path)
  info <- file.info(paths)
  if (anyNA(info$size)) stop("A saved trial input is unavailable.")
  list(version = 1L, backend = as.character(utils::packageVersion("fluvgeo")),
    paths = paths, size = info$size, modified = as.numeric(info$mtime),
    overlap = trial$unmasked_result$overlap, units = "international_foot")
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
      file.path(directory, "mosaic.tif"), trial$unmasked_result$overlap)
    trial$masked_result <- fluvgeo::mask_terrain_mosaic(trial$unmasked_result$path,
      trial$mask_file, file.path(directory, "masked.tif"))
    trial$result <- fluvgeo::terrain_to_international_feet(trial$masked_result$path,
      file.path(directory, "dem-international-feet.tif"))
    trial$stage <- "international_feet"
    trial$seconds <- proc.time()[["elapsed"]] - started
    trial
  }, args = list(trial = trial, directory = directory, cached = cached), libpath = .libPaths(),
    stdout = NULL, stderr = NULL, poll_connection = FALSE,
    user_profile = FALSE, system_profile = FALSE, supervise = TRUE)
}

terrain_dem_trial_job <- function(input, output, session, initial, context, current,
                                  launch = launch_terrain_dem_trial, store = NULL) {
  value <- shiny::reactiveVal(initial)
  busy <- shiny::reactiveVal(FALSE)
  notice <- shiny::reactiveVal(NULL)
  job <- NULL; directory <- NULL; recipe <- NULL; target <- NULL
  enabled <- isTRUE(getOption("fgstudio.dem_trial", FALSE))
  cache <- getOption("fgstudio.dem_trial_cache")
  binding <- NULL
  durable <- !is.null(store)
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
    if (!matching()) { notice("Select the saved 2019-12 trial Event. Edited inputs need a refreshed development fixture."); return() }
    tryCatch({
      if (is.null(cache) || !dir.exists(cache)) stop("The development DEM cache is unavailable.")
      recipe <<- terrain_dem_trial_recipe(initial)
      if (durable) {
        binding <<- store$dem_request(initial$key,initial$group_id,context()$path,context()$group_path)
        saved <- store$find_dem(binding,recipe)
        if (!is.null(saved)) { value(saved); notice("Saved DEM ready. No raster processing needed."); return() }
      }
      key <- as.character(openssl::sha256(serialize(recipe, NULL)))
      target <<- file.path(cache, paste0(key, ".rds"))
      if (file.exists(target)) {
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
      notice("Building the small Reach DEM: mosaic, saved mask, then international feet.")
    }, error = function(e) { stop_job(); notice(paste("DEM could not be built.", conditionMessage(e))) })
  }
  poll <- function() {
    if (is.null(job) || job$is_alive()) return()
    tryCatch({
      completed <- job$get_result()
      if (!matching() || !identical(recipe, terrain_dem_trial_recipe(initial)))
        stop("Saved inputs changed; the earlier result was not retained.")
      if (durable) {
        completed <- store$publish_dem(binding,recipe,directory,completed)
        directory <<- NULL; job <<- NULL; busy(FALSE); value(completed)
        notice("DEM saved with this Survey Event. Ready to reopen or download.")
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
  shiny::observeEvent(list(context(), current()$key), start(), ignoreNULL = FALSE)
  shiny::observe({ if (busy()) { shiny::invalidateLater(500, session); poll() } })
  shiny::observeEvent(input$cancel_dem, { stop_job(); notice("DEM preparation cancelled. Completed results are retained.") }, ignoreInit = TRUE)
  shiny::observeEvent(input$resume_dem, start(), ignoreInit = TRUE)
  output$job_status <- shiny::renderUI({
    if (!enabled) return(NULL)
    shiny::tagList(shiny::div(role = "status", notice()),
      if (busy()) shiny::actionButton(session$ns("cancel_dem"), "Cancel", class = "btn-outline-secondary btn-sm") else
        if (is.null(value()) && matching()) shiny::actionButton(session$ns("resume_dem"), "Retry DEM", class = "btn-outline-secondary btn-sm"))
  })
  session$onSessionEnded(function() try(stop_job(), silent = TRUE))
  list(value = value, busy = busy, poll = poll, notice = notice)
}
