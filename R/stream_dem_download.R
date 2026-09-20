launch_stream_dem_download_job <- function(attempt,verify_only=FALSE) {
  callr::r_bg(function(attempt,verify_only) {
    if(verify_only) fluvgeo::read_stream_dem_download(attempt) else fluvgeo::run_stream_dem_download(attempt)
  },args=list(attempt=attempt,verify_only=verify_only),libpath=.libPaths(),
  stdout=NULL,stderr=NULL,poll_connection=FALSE,user_profile=FALSE,system_profile=FALSE,supervise=TRUE)
}

stream_dem_download_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class="d-flex gap-2 mt-1",
      shiny::actionButton(ns("start"),"Download saved files",class="btn-primary btn-sm"),
      shiny::actionButton(ns("cancel"),"Cancel download",class="btn-outline-secondary btn-sm")),
    shiny::uiOutput(ns("destination")),shiny::uiOutput(ns("status")),shiny::uiOutput(ns("files")),
    stream_dem_inspection_ui(ns("inspection")))
}

stream_dem_download_server <- function(id,current,selection,scope,store,launch=launch_stream_dem_download_job,clock=Sys.time) {
  shiny::moduleServer(id,function(input,output,session) {
    state <- shiny::reactiveVal(NULL); message <- shiny::reactiveVal("")
    busy <- shiny::reactiveVal(FALSE); activity <- shiny::reactiveVal(NULL)
    job <- NULL; attempt <- NULL; verify_only <- FALSE; job_scope <- NULL; job_started <- NULL
    stop_job <- function() {
      if(!is.null(job)) {
        if(job$is_alive()) {job$kill();job$wait(timeout=2000)}
        if(job$is_alive()) stop("Download worker has not stopped; temporary files are retained.")
        if(!verify_only && !is.null(attempt)) fluvgeo::cancel_stream_dem_download(attempt)
      }
      job <<- NULL;busy(FALSE);activity(NULL)
      shiny::removeNotification(session$ns("activity"),session=session)
    }
    launch_job <- function(path,verify) {
      attempt <<- path;verify_only <<- verify
      job_scope <<- shiny::isolate(scope())
      job_started <<- clock()
      job <<- launch(path,verify_only=verify);busy(TRUE)
      message(if(verify) "Checking saved local source files\u2026" else "Downloading saved source files\u2026")
      shiny::showNotification(if(verify) "Checking local DEM integrity\u2026" else "Downloading source DEMs\u2026",
        id=session$ns("activity"),duration=NULL,session=session)
    }
    shiny::observeEvent(scope(),{
      tryCatch({
        state(NULL);activity(NULL);stop_job();attempt <<- NULL;message("")
        x <- current();s <- selection()
        if(!is.null(store) && !is.null(x) && !is.null(s$path) &&
            length(s$stream)==1L && length(s$collection)==1L) {
          path <- store$dem_download(x$key,s$stream,s$collection)
          if(!is.null(path)) launch_job(path,TRUE)
        }
      },error=function(e) message(conditionMessage(e)))
    },ignoreNULL=FALSE)
    shiny::observeEvent(input$start,{
      if(busy()) {message("Wait for the current operation or cancel it first.");return()}
      tryCatch({
        x <- current();s <- selection()
        if(is.null(store) || is.null(x) || is.null(s$path) || !length(s$draft) || !setequal(s$draft,s$ids))
          stop("Save the current nonempty file choices before downloading.")
        path <- store$prepare_dem_download(x$key,x$path,s$path,s$draft)
        state(NULL);activity(NULL);launch_job(path,FALSE)
      },error=function(e) message(paste("Download not started:",conditionMessage(e))))
    },ignoreInit=TRUE)
    poll <- function() {
      if(is.null(job)) return()
      # Bound startup and local verification too, beyond curl's transfer timers.
      if(as.numeric(difftime(clock(),job_started,units="secs"))>8*3600) {
        tryCatch({
          stop_job()
          if(identical(job_scope,shiny::isolate(scope())))
            state(fluvgeo::read_stream_dem_download(attempt,verify=FALSE)) else state(NULL)
          message("Operation timed out after eight hours. Completed receipts remain; start again to retry.")
        },error=function(e) message(conditionMessage(e)))
        return()
      }
      # If process termination was delayed, its eventual result still belongs
      # to the original scope. Never display it against the newly selected study.
      if(!identical(job_scope,shiny::isolate(scope()))) {
        state(NULL);activity(NULL)
        if(!job$is_alive()) tryCatch(stop_job(),error=function(e) message(conditionMessage(e)))
        return()
      }
      if(job$is_alive()) {
        if(!verify_only) activity(tryCatch(suppressWarnings(jsonlite::read_json(file.path(attempt,"progress.json"),simplifyVector=TRUE)),error=function(e) NULL))
        return()
      }
      tryCatch({
        result <- job$get_result();state(result)
        f <- result$files
        good <- sum(f$outcome %in% c("DOWNLOADED","REUSED"))
        message(paste(good,"/",nrow(f),"source files verified locally.",
          if(any(f$outcome %in% c("FAILED","UNAVAILABLE","INTERRUPTED","NOT_STARTED","CANCELLED")))
            "Review per-file outcomes; start again to retry." else "Terrain suitability remains unreviewed."))
      },error=function(e) {
        message(paste("Operation stopped:",conditionMessage(e),"Completed receipts are retained; start again to retry."))
        state(tryCatch(fluvgeo::read_stream_dem_download(attempt,verify=FALSE),error=function(e) NULL))
      })
      job <<- NULL;busy(FALSE);activity(NULL)
      shiny::removeNotification(session$ns("activity"),session=session)
    }
    shiny::observe({if(busy()) {shiny::invalidateLater(500,session);poll()}})
    shiny::observeEvent(input$cancel,{
      if(!busy()) return()
      tryCatch({
        stop_job()
        state(fluvgeo::read_stream_dem_download(attempt,verify=FALSE))
        message("Download/check cancelled. Completed receipts remain; recorded files will be rechecked before reuse.")
      },error=function(e) message(conditionMessage(e)))
    },ignoreInit=TRUE)
    output$destination <- shiny::renderUI({
      x <- current(); if(is.null(x) || is.null(store)) return(NULL)
      path <- tryCatch(store$dem_destination(x$key),error=function(e) conditionMessage(e))
      shiny::tags$details(shiny::tags$summary("Download location and limits"),
        shiny::p(class="small mb-1",style="overflow-wrap:anywhere",path),
        shiny::p(class="small mb-0","Original source files: 10 GiB per file, 50 GiB per attempt; one file at a time. Connection: 30 s; idle: 120 s; file: 2 h; attempt: 8 h. Start again retries unsuccessful files and rechecks completed files for reuse."))
    })
    output$status <- shiny::renderUI({
      p <- activity()
      shiny::div(role="status",message(),
        if(busy() && is.null(p)) shiny::tags$progress(style="width:100%"),
        if(!is.null(p)) shiny::tagList(
          shiny::p(class="small mb-1",paste(p$title,"\u2014",round(p$bytes/1e6,1),"MB received;",p$completed,"/",p$files,"complete")),
          if(!is.null(p$total_bytes) && is.finite(p$total_bytes) && p$total_bytes>0)
            shiny::tags$progress(value=p$bytes,max=p$total_bytes,style="width:100%") else shiny::tags$progress(style="width:100%")))
    })
    output$files <- shiny::renderUI({
      s <- state(); if(is.null(s)) return(NULL)
      shiny::div(style="max-height:220px;overflow:auto;",tabindex="0",role="region",`aria-label`="DEM download outcomes",
        compact_table(data.frame(File=s$files$title,Outcome=s$files$outcome,
          MB=round(s$files$bytes/1e6,1),Details=s$files$message)),
        if(any(s$files$outcome=="RECORDED")) shiny::p(class="small","RECORDED: receipt exists; checksum has not been rechecked in this view."))
    })
    inspection_context <- shiny::reactive({
      s <- state()
      if(busy() || is.null(s) || is.null(attempt)) return(NULL)
      files <- s$files[s$files$outcome %in% c("DOWNLOADED","REUSED","RECORDED"),c("file_id","title"),drop=FALSE]
      list(attempt=attempt,scope=scope(),files=files)
    })
    stream_dem_inspection_server("inspection",inspection_context)
    session$onSessionEnded(function() try(stop_job(),silent=TRUE))
    list(busy=busy,poll=poll,state=state)
  })
}
