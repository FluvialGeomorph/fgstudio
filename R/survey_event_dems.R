survey_event_dems_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(
    bslib::card_header("DEMs"),
    bslib::card_body(class="pt-0",fillable=FALSE,
      shiny::div(shiny::uiOutput(ns("overview")),shiny::uiOutput(ns("queue_controls")),
        shiny::uiOutput(ns("streams")))))
}

survey_event_dems_server <- function(id,current,context,store,ready,launch=launch_terrain_dem_trial) {
  shiny::moduleServer(id,function(input,output,session) {
    active <- shiny::reactiveVal(NULL); attempted <- shiny::reactiveVal(NULL)
    states <- shiny::reactiveVal(list()); generation <- shiny::reactiveVal(0L)
    queue <- character(); registered <- character()
    job_context <- shiny::reactive({
      ctx <- context(); if(is.null(ctx) || is.null(active())) return(NULL)
      ctx$processing_stream <- active();ctx
    })
    factory <- function() {
      ctx <- job_context();if(is.null(ctx)) return(NULL)
      attempted(active())
      request <- terrain_dem_request(store,current(),ctx,stream_id=active())
      if(is.null(request)) stop("The saved analysis mask is unavailable. Review Study geometry and Event Settings.")
      request
    }
    task <- terrain_dem_trial_job(input,output,session,NULL,job_context,current,
      store=store,request_factory=factory,request_ready=ready,launch=launch)
    advance <- function() {
      next_id <- if(length(queue)) queue[1] else NULL
      queue <<- if(length(queue)) queue[-1] else character()
      active(next_id)
    }
    shiny::observeEvent(context(),{
      ctx <- context(); attempted(NULL)
      ids <- if(is.null(ctx)) character() else as.character(ctx$streams$stream_id)
      states(stats::setNames(lapply(ids,function(id) list(status="Waiting",message="")),ids))
      queue <<- ids;advance()
      for(sid in setdiff(ids,registered)) local({
        stream <- sid; child <- paste0("stream_",gsub("-","",stream))
        terrain_mosaic_trial_server(child,current,shiny::reactive({
          ctx <- context();generation()
          if(is.null(ctx) || !stream %in% ctx$streams$stream_id) return(NULL)
          ctx$dem_generation <- generation();ctx
        }),store=store,target_stream=stream,process=FALSE)
      })
      registered <<- union(registered,ids)
    },ignoreNULL=FALSE,priority=100)
    shiny::observe({
      sid <- active();if(is.null(sid) || !identical(attempted(),sid)) return()
      status <- states();if(is.null(status[[sid]])) return()
      if(task$busy()) {
        if(!identical(status[[sid]]$status,"Processing")) {
          status[[sid]] <- list(status="Processing",message="");states(status)
        }
        return()
      }
      result <- task$value();message <- task$notice()
      if(!is.null(result$saved_dem) && identical(result$stream_id,sid)) {
        status[[sid]] <- list(status="Ready",message="Saved GeoTIFF");states(status)
        generation(shiny::isolate(generation())+1L);advance()
      } else if(length(message)==1L && startsWith(message,"DEM could not be built.")) {
        status[[sid]] <- list(status="Needs attention",message=message);states(status);advance()
      } else if(length(message)==1L && startsWith(message,"DEM preparation cancelled.")) {
        for(id in c(sid,queue)) status[[id]] <- list(status="Paused",message="Completed DEMs are retained.")
        states(status);queue <<- character();active(NULL)
      }
    })
    shiny::observeEvent(input$retry_queue,{
      if(!is.null(active())) return()
      status <- states();queue <<- names(Filter(function(x) x$status %in% c("Needs attention","Paused"),status))
      for(id in queue) status[[id]] <- list(status="Waiting",message="")
      states(status);attempted(NULL);advance()
    },ignoreInit=TRUE)
    output$overview <- shiny::renderUI({
      ctx <- context();if(is.null(ctx)) return(shiny::p("Select a saved Survey Event to review its DEMs."))
      status <- states()
      shiny::tagList(lapply(seq_len(nrow(ctx$streams)),function(i) {
        sid <- ctx$streams$stream_id[i];s <- status[[sid]]
        if(is.null(s) || s$status %in% c("Waiting","Ready")) return(NULL)
        label <- if(identical(s$status,"Processing")) "Building DEM" else s$status
        shiny::div(class="mb-2",shiny::strong(paste(ctx$streams$stream_name[i],"-",label)),
          if(!is.null(s) && nzchar(s$message)) shiny::div(s$message))
      }))
    })
    output$queue_controls <- shiny::renderUI({
      if(task$busy()) return(shiny::actionButton(session$ns("cancel_dem"),"Pause DEM Processing",class="btn-outline-secondary btn-sm"))
      if(is.null(active()) && any(vapply(states(),function(s) s$status %in% c("Needs attention","Paused"),logical(1))))
        shiny::actionButton(session$ns("retry_queue"),"Resume Unfinished DEMs",class="btn-outline-secondary btn-sm")
    })
    output$streams <- shiny::renderUI({
      ctx <- context();if(is.null(ctx) || !nrow(ctx$streams)) return(NULL)
      panels <- lapply(seq_len(nrow(ctx$streams)),function(i)
        bslib::nav_panel(ctx$streams$stream_name[i],terrain_mosaic_trial_ui(session$ns(
          paste0("stream_",gsub("-","",ctx$streams$stream_id[i]))))))
      do.call(bslib::navset_tab,panels)
    })
    list(states=states,active=active,task=task)
  })
}
