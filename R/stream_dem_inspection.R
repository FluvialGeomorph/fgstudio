launch_stream_dem_inspection_job <- function(attempt,file_id,preview=FALSE,window=NULL,cache_dir=NULL) {
  callr::r_bg(function(attempt,file_id,preview,window,cache_dir) {
    if(preview) fluvgeo::preview_stream_dem_download(attempt,file_id,window=window,cache_dir=cache_dir) else fluvgeo::inspect_stream_dem_download(attempt,file_id,cache_dir=cache_dir,refresh=TRUE)
  },args=list(attempt=attempt,file_id=file_id,preview=preview,window=window,cache_dir=cache_dir),libpath=.libPaths(),
    stdout=NULL,stderr=NULL,poll_connection=FALSE,user_profile=FALSE,system_profile=FALSE,supervise=TRUE)
}

stream_dem_inspection_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(shiny::tags$summary("View downloaded DEM"),
    shiny::uiOutput(ns("choices")),
    shiny::actionButton(ns("inspect"),"Recheck file integrity",class="btn-sm"),
    shiny::actionButton(ns("preview"),"Preview elevations",class="btn-sm"),
    shiny::actionButton(ns("cancel"),"Cancel inspection",class="btn-sm"),
    shiny::uiOutput(ns("status")),shiny::uiOutput(ns("preview_panel")),shiny::uiOutput(ns("result")))
}

stream_dem_inspection_server <- function(id,context,launch=launch_stream_dem_inspection_job,clock=Sys.time) {
  shiny::moduleServer(id,function(input,output,session) {
    cache_dir <- tempfile("dem-view-session-");dir.create(cache_dir)
    result <- shiny::reactiveVal(NULL);message <- shiny::reactiveVal("")
    busy <- shiny::reactiveVal(FALSE)
    view_id <- shiny::reactiveVal(0L)
    shiny::observeEvent(result(),{view_id(shiny::isolate(view_id())+1L)},ignoreNULL=FALSE,priority=150)
    job <- NULL;job_context <- NULL;started <- NULL
    stop_job <- function() {
      if(!is.null(job) && job$is_alive()) {job$kill();job$wait(timeout=2000)}
      if(!is.null(job) && job$is_alive()) stop("Inspection worker has not stopped.")
      job <<- NULL;busy(FALSE)
    }
    shiny::observeEvent(context(),{
      result(NULL)
      tryCatch({stop_job();message("")},error=function(e) message(conditionMessage(e)))
    },ignoreNULL=FALSE,priority=200)
    output$choices <- shiny::renderUI({
      x <- context()
      if(is.null(x) || !nrow(x$files)) return(shiny::p("Download a source file first."))
      shiny::selectInput(session$ns("file"),"Source file",stats::setNames(x$files$file_id,x$files$title))
    })
    shiny::observeEvent(input$file,{
      stop_job();result(NULL)
      x <- context()
      if(!is.null(x) && length(input$file)==1L && input$file %in% x$files$file_id) start(TRUE)
    },ignoreNULL=FALSE,priority=100)
    start <- function(preview=FALSE,window=NULL) {
      if(busy()) {message("Wait for the inspection or cancel it first.");return()}
      result(NULL)
      tryCatch({
        x <- context()
        if(is.null(x) || length(input$file)!=1L || !input$file %in% x$files$file_id)
          stop("Select a downloaded source file.")
        job_context <<- list(context=x,file=input$file);started <<- clock()
        source_attempt <- if("attempt" %in% names(x$files)) x$files$attempt[match(input$file,x$files$file_id)] else x$attempt
        job <<- launch(source_attempt,input$file,preview=preview,window=window,cache_dir=cache_dir)
        busy(TRUE)
        message(if(preview) "Verifying source and preparing elevation preview..." else "Verifying source checksum and reading GeoTIFF metadata...")
      },error=function(e) message(conditionMessage(e)))
    }
    shiny::observeEvent(input$inspect,start(),ignoreInit=TRUE)
    shiny::observeEvent(input$preview,start(TRUE),ignoreInit=TRUE)
    shiny::observeEvent(input$detail,{
      if(busy()) {message("Wait for the current operation or cancel it first.");return()}
      tryCatch({
        p <- result()$preview
        brush <- input[[paste0("area_",view_id())]]
        window <- dem_brush_window(p,brush)
        start(TRUE,window)
      },error=function(e) message(conditionMessage(e)))
    },ignoreInit=TRUE)
    poll <- function() {
      if(is.null(job)) return()
      same <- identical(job_context,list(context=shiny::isolate(context()),file=shiny::isolate(input$file)))
      if(!same) {
        result(NULL)
        tryCatch({stop_job();message("Selection changed; inspect the current file.")},
          error=function(e) message(conditionMessage(e)))
        return()
      }
      if(job$is_alive()) return()
      tryCatch({result(job$get_result());message("Source view ready. Unchanged views are reused within this session.")},
        error=function(e) {result(NULL);message(paste("Inspection failed:",conditionMessage(e)))})
      job <<- NULL;busy(FALSE)
    }
    shiny::observe({if(busy()) {shiny::invalidateLater(500,session);poll()}})
    shiny::observeEvent(input$cancel,{
      tryCatch({stop_job();result(NULL);message("Inspection cancelled.")},error=function(e) message(conditionMessage(e)))
    },ignoreInit=TRUE)
    output$status <- shiny::renderUI(shiny::div(role="status",message(),
      if(busy()) shiny::tags$progress(style="width:100%")))
    output$preview_panel <- shiny::renderUI({
      p <- result()$preview;if(is.null(p)) return(NULL)
      unit <- if(length(p$band_unit)==1L && nzchar(p$band_unit)) p$band_unit else "unknown elevation unit"
      shiny::tagList(shiny::h5("Source-grid elevation overview"),
        shiny::plotOutput(session$ns("elevation"),height="420px",
          brush=shiny::brushOpts(id=session$ns(paste0("area_",view_id())),resetOnNew=TRUE)),
        shiny::actionButton(session$ns("detail"),"Inspect selected area",class="btn-sm"),
        shiny::p(class="small","Drag a rectangle on the image, then inspect it. Repeat for finer detail; Preview elevations returns to the whole tile. The colour scale is recalculated for each view."),
        if(!is.null(p$window)) shiny::p(class="small",paste(
          if(isTRUE(p$native)) "Native source grid: no data downsampling for this window." else "Sampled view: select a smaller area for native cells.",
          "Column",p$window[1]+1,"to",p$window[1]+p$window[3],
          "; row",p$window[2]+1,"to",p$window[2]+p$window[4],"(1-based).")),
        shiny::p(class="small",paste("Elevation unit:",unit,". Display:",paste(p$sampled_size,collapse=" x "),
          "display cells; full source grid:",paste(p$source_size,collapse=" x "),"cells.")),
        shiny::p(class="small","Nearest-neighbour overview; existing overviews are ignored. Band scale/offset are applied. Grey marks sampled NoData/non-finite cells. Small features and gaps may be missed. Source pixel orientation is retained; the image is not necessarily north-up. This is not a valid-data footprint or suitability decision."))
    })
    output$elevation <- shiny::renderPlot({
      p <- result()$preview;shiny::req(!is.null(p))
      draw_dem_preview(p)
    },res=96)
    output$result <- shiny::renderUI({
      r <- result();if(is.null(r)) return(NULL)
      obs <- r$observation
      show <- function(x) if(is.null(x) || !length(x) || !nzchar(paste(x,collapse=""))) "Unknown" else paste(x,collapse=", ")
      reader <- function(x,label) shiny::tags$details(shiny::tags$summary(label),
        compact_table(data.frame(Field=c("Columns, rows","Column, row pixel spacing","Horizontal CRS unit","GDAL affine transform (source CRS units)","Pixel type","Declared NoData","Band elevation unit","Vertical CRS observation"),
          Value=c(show(x$grid$size),show(x$grid$spacing),show(x$grid$horizontal_unit),show(x$grid$geotransform),show(x$grid$pixel_type),show(x$grid$nodata),show(x$band_unit),show(x$status)))),
        shiny::tags$pre(style="max-height:220px;overflow:auto;white-space:pre-wrap",show(x$wkt)))
      shiny::tags$details(shiny::tags$summary("File metadata and integrity"),shiny::p(r$title),
        shiny::p(class="small",style="overflow-wrap:anywhere",paste("Verified SHA-256:",r$sha256)),
        reader(obs$default_reader,"Ordinary reader metadata"),reader(obs$internal_compound,"Embedded compound CRS metadata"),
        shiny::p(if(obs$crs_text_differs) "CRS text differs between readers; review the declarations." else "CRS text matches between readers."),
        shiny::p(class="small","Metadata readability does not prove all pixels are readable. Grid spacing is in source CRS units; the 1 m ground-resolution requirement has not been evaluated. A vertical CRS not exposed by a reader remains unknown. Coverage, hydro-flattening and suitability still need review."))
    })
    session$onSessionEnded(function() try({stop_job();unlink(cache_dir,recursive=TRUE)},silent=TRUE))
    list(result=result,busy=busy,poll=poll)
  })
}

dem_brush_window <- function(preview,brush) {
  if(is.null(preview) || is.null(brush)) stop("Drag a rectangle on the current elevation image first.")
  bounds <- unlist(brush[c("xmin","xmax","ymin","ymax")],use.names=FALSE)
  if(!is.numeric(bounds) || length(bounds)!=4L || any(!is.finite(bounds)))
    stop("Select a valid rectangle on the current image.")
  dims <- c(ncol(preview$values),nrow(preview$values))
  x <- pmax(0,pmin(dims[1],bounds[1:2]))
  y <- pmax(0,pmin(dims[2],bounds[3:4]))
  if(x[2]<=x[1] || y[2]<=y[1]) stop("The selection must overlap the elevation image.")
  w <- preview$window
  if(is.null(w)) w <- c(0,0,preview$source_size)
  first <- floor(c(x[1]/dims[1],(dims[2]-y[2])/dims[2])*w[3:4])
  last <- ceiling(c(x[2]/dims[1],(dims[2]-y[1])/dims[2])*w[3:4])
  c(w[1:2]+first,pmax(1,last-first))
}

draw_dem_preview <- function(preview) {
  values <- preview$values;finite <- is.finite(values)
  colours <- matrix("#d9d9d9",nrow(values),ncol(values))
  palette <- grDevices::hcl.colors(256,"Viridis")
  limits <- if(any(finite)) range(values[finite]) else c(NA_real_,NA_real_)
  if(any(finite)) {
    index <- if(diff(limits)==0) rep(128L,sum(finite)) else
      1L+floor(255*(values[finite]-limits[1])/diff(limits))
    colours[finite] <- palette[index]
  }
  old <- graphics::par(mar=c(4,4,3,1));on.exit(graphics::par(old))
  graphics::plot.new()
  graphics::plot.window(xlim=c(0,ncol(values)),ylim=c(0,nrow(values)),asp=1)
  graphics::rasterImage(grDevices::as.raster(colours),0,0,ncol(values),nrow(values),interpolate=FALSE)
  graphics::box()
  graphics::title(xlab="Source grid columns (left to right)",ylab="Source grid rows (top to bottom)",
    main=if(any(finite)) paste(if(isTRUE(preview$native)) "Native elevations:" else "Sampled elevations:",
      format(limits[1],digits=6),"to",format(limits[2],digits=6)) else "No finite elevations in this sample")
  if(any(finite)) graphics::legend("bottomleft",legend=format(limits,digits=6),
    fill=if(diff(limits)==0) rep(palette[128],2) else palette[c(1,256)],bg="white",cex=.85)
  invisible(limits)
}
