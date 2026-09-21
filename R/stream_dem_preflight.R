launch_stream_dem_preflight <- function(request) {
  callr::r_bg(function(request) do.call(fluvgeo::preflight_stream_dem,request),
    args=list(request=request),libpath=.libPaths(),stdout=NULL,stderr=NULL,
    poll_connection=FALSE,user_profile=FALSE,system_profile=FALSE,supervise=TRUE)
}

stream_dem_preflight_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(shiny::tags$summary("Grid and source preflight"),
    shiny::selectInput(ns("stream"),"Stream to check",choices=character()),
    shiny::actionButton(ns("run"),"Check grid and saved sources",class="btn-outline-primary btn-sm"),
    shiny::actionButton(ns("cancel"),"Cancel check",class="btn-outline-secondary btn-sm"),
    shiny::uiOutput(ns("status")),shiny::uiOutput(ns("result")))
}

stream_dem_preflight_server <- function(id,context,store,pending,launch=launch_stream_dem_preflight,clock=Sys.time) {
  shiny::moduleServer(id,function(input,output,session) {
    result <- shiny::reactiveVal(NULL); busy <- shiny::reactiveVal(FALSE)
    message <- shiny::reactiveVal("Select a saved Event group, then check one Stream.")
    job <- NULL; request <- NULL; started <- NULL
    stop_job <- function() {
      if(!is.null(job) && job$is_alive()) { job$kill(); job$wait(timeout=2000) }
      if(!is.null(job) && job$is_alive()) stop("Preflight worker has not stopped.")
      job <<- NULL; busy(FALSE)
    }
    make_request <- function() {
      x <- context()
      if(is.null(x) || length(input$stream)!=1L || !input$stream %in% x$streams$stream_id)
        stop("Choose a saved Event group and one of its Streams.")
      store$dem_preflight_request(x$key,x$group_id,input$stream,x$path,x$selection,x$group_path)
    }
    shiny::observeEvent(context(),{
      result(NULL)
      tryCatch({stop_job();message("Select a saved Event group, then check one Stream.")},error=function(e) message(conditionMessage(e)))
      x <- context(); streams <- if(is.null(x)) NULL else x$streams
      shiny::updateSelectInput(session,"stream",choices=stats::setNames(as.character(streams$stream_id),streams$stream_name))
    },ignoreNULL=FALSE,priority=100)
    shiny::observeEvent(input$stream,{
      result(NULL); tryCatch({stop_job();message("Run preflight for the selected Stream.")},error=function(e) message(conditionMessage(e)))
    },ignoreNULL=FALSE,priority=90)
    shiny::observeEvent(input$run,{
      if(busy()) { message("Wait for the current check or cancel it."); return() }
      result(NULL)
      tryCatch({
        if(pending()) stop("Save or cancel pending Event and acquisition edits first.")
        request <<- make_request(); started <<- clock()
        job <<- launch(request); busy(TRUE)
        message("Checking grid sizes and hashing original source files. No raster products are created.")
      },error=function(e) message(conditionMessage(e)))
    },ignoreInit=TRUE)
    poll <- function() {
      if(is.null(job)) return()
      same <- !pending()
      if(!same || as.numeric(difftime(clock(),started,units="secs"))>1800) {
        result(NULL); tryCatch({stop_job();message("Setup changed or check timed out. Run preflight again.")},
          error=function(e) message(conditionMessage(e))); return()
      }
      if(job$is_alive()) return()
      tryCatch({
        if(!identical(request,make_request())) stop("Saved source choices changed. Run preflight again.")
        result(job$get_result())
        message("Preflight completed. Review source issues and estimates; mosaic execution is not enabled.")
      },error=function(e) {result(NULL);message(paste("Preflight failed:",conditionMessage(e)))})
      job <<- NULL; busy(FALSE)
    }
    shiny::observe({ if(busy()) { shiny::invalidateLater(500,session); poll() } })
    shiny::observeEvent(input$cancel,{
      result(NULL); tryCatch({stop_job();message("Preflight cancelled. Saved settings and source files are unchanged.")},
        error=function(e) message(conditionMessage(e)))
    },ignoreInit=TRUE)
    output$status <- shiny::renderUI(shiny::div(role="status",message(),
      if(busy()) shiny::tags$progress(style="width:100%")))
    output$result <- shiny::renderUI({
      r <- result(); if(is.null(r)) return(NULL)
      # Recheck current saved revisions when the result is rendered. A later
      # processing worker must independently verify hashes again, never reuse PASS.
      if(!isTRUE(tryCatch(identical(request,make_request()),error=function(e) FALSE)))
        return(shiny::p("Saved source choices changed. Run preflight again."))
      sizes <- r$grids
      sizes$mask_GiB <- signif(sizes$mask_bytes/1024^3,4)
      sizes$DEM_GiB <- signif(sizes$float64_bytes/1024^3,4)
      shiny::tagList(shiny::p(paste("Grid/source metadata screen:",r$grid_source_screen,"at",r$checked_at)),
        shiny::p(paste("Output spacing:",r$grid$cell_size,r$grid$unit,"; shared anchor: (0, 0).")),
        compact_table(sizes[c("level","columns","rows","cells","mask_GiB","DEM_GiB")]),
        shiny::p(class="small","Uncompressed payload estimates, not disk-space approval. Grid envelopes are not masks or observed coverage."),
        compact_table(r$sources[c("collection","file_id","spacing_x","spacing_y","source_unit","metres_x","metres_y","alignment","grid_screen","issues","band_unit")]),
        lapply(r$notes,shiny::p),
        shiny::p(class="small","Source vertical references, epochs and prior conversions still require review. No implicit vertical or elevation-unit conversion is enabled."))
    })
    session$onSessionEnded(function() try(stop_job(),silent=TRUE))
    list(result=result,busy=busy,poll=poll,message=message)
  })
}
