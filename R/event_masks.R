launch_event_masks <- function(request,directory,existing=NULL) {
  callr::r_bg(function(request,directory,existing) {
    if(!is.null(existing)) {
      m <- tryCatch(fluvgeo::read_event_masks(existing),error=function(e) NULL)
      hash <- function(path) {con<-file(path,"rb");on.exit(close(con));unclass(as.character(openssl::sha256(con)))}
      if(!is.null(m) && identical(m$inputs,lapply(request[c("context","selection","group")],hash)) &&
          identical(m$stream_id,request$stream_id)) return(list(manifest=m,path=existing))
    }
    list(manifest=do.call(fluvgeo::write_event_masks,c(request,list(directory=directory))),path=NULL)
  },args=list(request=request,directory=directory,existing=existing),libpath=.libPaths(),stdout=NULL,stderr=NULL,
    poll_connection=FALSE,user_profile=FALSE,system_profile=FALSE,supervise=TRUE)
}

event_masks_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h4("Analysis masks"),
    shiny::p("Masks are prepared automatically for this Survey Event's Streams and Reaches using your saved boundaries and cell size."),
    shiny::conditionalPanel("output.busy",ns=ns,
      shiny::actionButton(ns("cancel"),"Pause mask preparation",class="btn-outline-secondary btn-sm")),
    shiny::uiOutput(ns("status")),shiny::uiOutput(ns("result")),
    shiny::conditionalPanel("output.has_masks",ns=ns,
      shiny::selectInput(ns("product"),"Mask to view",choices=character()),
      shiny::plotOutput(ns("map"),height="500px"),
      shiny::p(class="small","Blue shows included mask cells; the orange outline shows the saved boundary. The overview is sampled for display; saved masks retain the full cell size. Masks define the analysis area, not DEM coverage.")))
}

mask_recovery_message <- function(e) {
  detail <- conditionMessage(e)
  action <- if(grepl("cell size|spacing",detail,ignore.case=TRUE))
    "Open Review / edit Survey Event to correct the invalid cell size." else
    if(grepl("disk|space",detail,ignore.case=TRUE)) "Free disk space on the drive holding the study, then reopen the Survey Event." else
    if(grepl("CRS|reference",detail,ignore.case=TRUE)) "Open Analysis setup to correct the horizontal CRS, then review and save the Survey Event again." else
    if(grepl("polygon|geometry|Reach|overlap",detail,ignore.case=TRUE)) "Open Study geometry to review the Stream and Reach boundaries, then review and save the Survey Event again." else
    if(grepl("changed|stale|selection|pending",detail,ignore.case=TRUE)) "Save or cancel pending edits, then use Review / edit Survey Event to save it against the current setup." else
    if(grepl("processx|pipe|Access is denied",detail,ignore.case=TRUE)) "The local app needs to be restarted with permission to run background workers. Ask the developer to restart the preview." else
      "Share this message with the developer; the saved inputs have been retained."
  paste("Masks could not be created.",detail,action)
}

draw_event_mask <- function(path,boundary) {
  raster <- terra::rast(path)
  if(terra::ncell(raster)>250000) raster <- terra::spatSample(raster,250000,method="regular",as.raster=TRUE)
  # Display in the saved analysis CRS; map display must not transform mask data.
  area <- sf::st_transform(boundary,terra::crs(raster))
  terra::plot(raster,col="#2378b5",legend=FALSE,axes=FALSE,range=c(0,1),mar=c(1,1,1,1))
  graphics::plot(sf::st_geometry(area),add=TRUE,border="#e68a00",col=NA,lwd=2)
  invisible(NULL)
}

event_masks_server <- function(id,context,store,pending,launch=launch_event_masks) {
  shiny::moduleServer(id,function(input,output,session) {
    results <- shiny::reactiveVal(list()); busy <- shiny::reactiveVal(FALSE)
    message <- shiny::reactiveVal("Save a Survey Event to prepare its masks automatically.")
    job <- NULL; request <- NULL; directory <- NULL; owner <- NULL; queue <- character()
    stop_job <- function() {
      if(!is.null(job) && job$is_alive()) {job$kill();job$wait(timeout=2000)}
      if(!is.null(job) && job$is_alive()) stop("Mask worker has not stopped.")
      job <<- NULL; busy(FALSE)
    }
    make_request <- function(stream_id) {
      x <- context()
      store$mask_request(x$key,x$group_id,stream_id,x$path,x$selection,x$group_path)
    }
    next_stream <- function() {
      if(!length(queue)) {busy(FALSE);message("Masks ready. Saved boundaries and cell size are used automatically.");return()}
      id <- queue[1]; queue <<- queue[-1]
      tryCatch({
        request <<- make_request(id);directory <<- store$prepare_masks(owner$key)
        existing <- store$find_masks(owner$key,request)
        job <<- launch(request,directory,existing);busy(TRUE)
        name <- owner$streams$stream_name[match(id,owner$streams$stream_id)]
        message(paste(if(is.null(existing)) "Preparing masks for" else "Opening saved masks for",name))
      },error=function(e) {queue <<- character();busy(FALSE);message(mask_recovery_message(e))})
    }
    shiny::observeEvent(list(context(),pending()),{
      stop_job();results(list());queue <<- character();owner <<- context()
      if(is.null(owner)) {message("Save a Survey Event to prepare its masks automatically.");return()}
      if(pending()) {message("Masks will update after the Survey Event edits are saved or cancelled.");return()}
      queue <<- owner$streams$stream_id
      next_stream()
    },ignoreNULL=FALSE,priority=100)
    poll <- function() {
      if(is.null(job)) return()
      if(pending()) {stop_job();queue <<- character();message("Waiting for saved Survey Event settings.");return()}
      if(job$is_alive()) return()
      tryCatch({
        if(!identical(request,make_request(request$stream_id))) stop("Saved mask setup changed.")
        completed <- job$get_result()
        edition <- if(is.null(completed$path))
          store$publish_masks(owner$key,owner$group_id,request,directory,completed$manifest) else completed
        all <- results();all[[request$stream_id]] <- edition;results(all)
        job <<- NULL;next_stream()
      },error=function(e) {job <<- NULL;queue <<- character();busy(FALSE);message(mask_recovery_message(e))})
    }
    shiny::observe({if(busy()) {shiny::invalidateLater(500,session);poll()}})
    shiny::observeEvent(input$cancel,{
      stop_job();queue <<- character();message("Mask preparation paused. Saved masks remain available; reopening the Survey Event resumes preparation.")
    },ignoreInit=TRUE)
    products <- shiny::reactive({
      all <- results(); rows <- list();seen <- character()
      for(r in all) for(p in r$manifest$products) {
        key <- paste(p$level,p$id,sep=":")
        if(key %in% seen) next
        seen <- c(seen,key);p$path <- file.path(r$path,p$file);rows[[key]] <- p
      }
      rows
    })
    output$status <- shiny::renderUI(shiny::div(role="status",message(),if(busy()) shiny::tags$progress(style="width:100%")))
    output$result <- shiny::renderUI({
      rows <- products();if(!length(rows)) return(NULL)
      if(any(vapply(rows,function(p) p$valid_cells==0,logical(1))))
        shiny::p("Some masks have no included cells. Review their boundaries in Study geometry and the Survey Event cell size. Saving corrections updates the masks automatically.")
    })
    output$has_masks <- shiny::reactive(length(products())>0)
    output$busy <- shiny::reactive(busy())
    shiny::outputOptions(output,"has_masks",suspendWhenHidden=FALSE)
    shiny::outputOptions(output,"busy",suspendWhenHidden=FALSE)
    shiny::observeEvent(products(),{
      rows <- products();if(!length(rows)) return()
      ctx <- fluvgeo::read_study_context(owner$path)
      labels <- vapply(rows,function(p) {
        if(p$level=="Study Area") return("Study Area")
        if(p$level=="Stream") return(paste("Stream:",ctx$streams$stream_name[match(p$id,ctx$streams$stream_id)]))
        paste("Reach:",ctx$reaches$reach_name[match(p$id,ctx$reaches$reach_id)])
      },character(1))
      chosen <- shiny::isolate(input$product)
      if(length(chosen)!=1L || !chosen %in% names(rows)) {
        streams <- names(rows)[vapply(rows,function(p) p$level=="Stream",logical(1))]
        chosen <- if(length(streams)) streams[1] else names(rows)[1]
      }
      shiny::updateSelectInput(session,"product",choices=stats::setNames(names(rows),labels),selected=chosen)
    })
    output$map <- shiny::renderPlot({
      shiny::req(input$product);p <- products()[[input$product]];shiny::req(p)
      ctx <- fluvgeo::read_study_context(owner$path)
      area <- switch(p$level,"Study Area"=ctx$study_area,"Stream"=ctx$streams[ctx$streams$stream_id==p$id,,drop=FALSE],
        "Reach"=ctx$reaches[ctx$reaches$reach_id==p$id,,drop=FALSE])
      draw_event_mask(p$path,area)
    })
    session$onSessionEnded(function() try(stop_job(),silent=TRUE))
    list(result=results,busy=busy,poll=poll,message=message)
  })
}
