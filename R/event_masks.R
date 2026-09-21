launch_event_masks <- function(request,directory) {
  callr::r_bg(function(request,directory) do.call(fluvgeo::write_event_masks,c(request,list(directory=directory))),
    args=list(request=request,directory=directory),libpath=.libPaths(),stdout=NULL,stderr=NULL,
    poll_connection=FALSE,user_profile=FALSE,system_profile=FALSE,supervise=TRUE)
}

event_masks_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(shiny::tags$summary("Analysis masks"),
    shiny::p("Create One/NoData masks for the Study Area, one Stream and its Reaches using the saved Event spacing. Masks define the analysis domain; they do not indicate DEM coverage."),
    shiny::p(class="small","Cell centers exactly on polygon or hole edges are excluded. Narrow polygons may have no included centers. This release limits a family to 50 million cells and 65,536 columns."),
    shiny::selectInput(ns("stream"),"Stream to mask",choices=character()),
    shiny::actionButton(ns("run"),"Create mask family",class="btn-outline-primary btn-sm"),
    shiny::actionButton(ns("cancel"),"Cancel masks",class="btn-outline-secondary btn-sm"),
    shiny::uiOutput(ns("status")),shiny::uiOutput(ns("result")))
}

event_masks_server <- function(id,context,store,pending,launch=launch_event_masks,clock=Sys.time) {
  shiny::moduleServer(id,function(input,output,session) {
    result <- shiny::reactiveVal(NULL); busy <- shiny::reactiveVal(FALSE)
    message <- shiny::reactiveVal("Choose a saved Event group and Stream.")
    job <- NULL; request <- NULL; directory <- NULL; started <- NULL; owner <- NULL
    stop_job <- function() {
      if(!is.null(job) && job$is_alive()) {job$kill();job$wait(timeout=2000)}
      if(!is.null(job) && job$is_alive()) stop("Mask worker has not stopped.")
      job <<- NULL; busy(FALSE)
    }
    make_request <- function() {
      x <- context()
      if(is.null(x) || length(input$stream)!=1L || !input$stream %in% x$streams$stream_id)
        stop("Choose a saved Event group and one of its Streams.")
      store$mask_request(x$key,x$group_id,input$stream,x$path,x$selection,x$group_path)
    }
    reset <- function() {
      result(NULL)
      tryCatch({stop_job();message("Ready to create masks from saved settings.")},error=function(e) message(conditionMessage(e)))
    }
    shiny::observeEvent(context(),{
      reset(); x <- context(); s <- if(is.null(x)) NULL else x$streams
      shiny::updateSelectInput(session,"stream",choices=stats::setNames(as.character(s$stream_id),s$stream_name))
    },ignoreNULL=FALSE,priority=100)
    shiny::observeEvent(input$stream,reset(),ignoreNULL=FALSE,priority=90)
    shiny::observeEvent(input$run,{
      if(busy()) {message("Wait for the mask worker or cancel it.");return()}
      result(NULL)
      tryCatch({
        if(pending()) stop("Save or cancel pending Event and acquisition edits first.")
        request <<- make_request(); owner <<- context(); directory <<- store$prepare_masks(owner$key)
        started <<- clock();job <<- launch(request,directory);busy(TRUE)
        message("Creating and verifying masks. Prior editions are retained.")
      },error=function(e) message(conditionMessage(e)))
    },ignoreInit=TRUE)
    poll <- function() {
      if(is.null(job)) return()
      if(pending() || as.numeric(difftime(clock(),started,units="secs"))>1800) {
        tryCatch({stop_job();message("Mask setup changed or processing timed out. No edition published.")},
          error=function(e) message(conditionMessage(e)));return()
      }
      if(job$is_alive()) return()
      tryCatch({
        if(!identical(request,make_request())) stop("Saved mask setup changed.")
        manifest <- job$get_result()
        result(store$publish_masks(owner$key,owner$group_id,request,directory,manifest))
        message("Verified mask edition saved. DEM mosaics remain a separate step.")
      },error=function(e) {result(NULL);message(paste("Masks not published:",conditionMessage(e)))})
      job <<- NULL;busy(FALSE)
    }
    shiny::observe({if(busy()) {shiny::invalidateLater(500,session);poll()}})
    shiny::observeEvent(input$cancel,{
      tryCatch({stop_job();message("Mask worker cancelled. Prior editions remain available.")},error=function(e) message(conditionMessage(e)))
    },ignoreInit=TRUE)
    output$status <- shiny::renderUI(shiny::div(role="status",message(),if(busy()) shiny::tags$progress(style="width:100%")))
    output$result <- shiny::renderUI({
      r <- result();if(is.null(r)) return(NULL)
      shiny::tagList(shiny::p(paste("Saved edition:",r$path)),
        compact_table(do.call(rbind,lapply(r$manifest$products,function(p) data.frame(
          Level=p$level,Cells=p$plan$cells,Included=p$valid_cells,File=p$file)))),
        shiny::p("Zero included cells means no cell centers passed the polygon and parent tests. NoData gaps in future DEMs will remain NoData."))
    })
    session$onSessionEnded(function() try(stop_job(),silent=TRUE))
    list(result=result,busy=busy,poll=poll,message=message)
  })
}
