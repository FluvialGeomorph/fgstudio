# Interactive inundation review is a session candidate; no dataset is published.
cross_section_review_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(bslib::card_header("Cross Sections: inundation review"),
    shiny::p("Select a Survey Event, Stream and Reach. Adjust the channel and floodplain REM levels while reviewing their mapped extents."),
    bslib::layout_columns(col_widths=c(4,8),
      shiny::div(shiny::uiOutput(ns("events")), shiny::uiOutput(ns("selection")),
        shiny::sliderInput(ns("channel"), "Channel REM elevation (ft)", 100, 130, 103, step=.1),
        shiny::sliderInput(ns("floodplain"), "Floodplain REM elevation (ft)", 100, 130, 106, step=.1),
        shiny::p(class="small", "Floodplain elevation must exceed channel elevation. Initial floodplain depth is twice channel depth. The current REM covers approximately 150 m on either side of the Reach; an extent reaching its edge may be incomplete."),
        shiny::uiOutput(ns("status"))),
      leaflet::leafletOutput(ns("map"), height="650px")))
}

cross_section_review_server <- function(id, context, store, events, active, revision) {
  shiny::moduleServer(id, function(input, output, session) {
    linked_survey_event_selector(input, output, session, events, context)
    review <- shiny::reactiveVal(NULL); selected <- shiny::reactiveVal(NULL)
    rem <- shiny::reactiveVal(NULL); extents <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(""); job <- NULL; job_kind <- NULL
    job_key <- NULL; loaded <- NULL; generation <- 0L
    cache <- tempfile("cross-section-review-"); dir.create(cache)
    stop_job <- function() { if (!is.null(job) && job$is_alive()) job$kill(); job <<- NULL; job_kind <<- NULL }
    session$onSessionEnded(function() { stop_job(); unlink(cache, recursive=TRUE) })
    output$selection <- shiny::renderUI({
      x <- review(); if (is.null(x)) return(NULL)
      streams <- vapply(x$bundle, `[[`, character(1), "stream_name")
      id <- input$stream
      if (is.null(id) || !id %in% names(streams)) id <- names(streams)[1]
      lines <- x$bundle[[id]]$flowline$flowlines
      shiny::tagList(shiny::selectInput(session$ns("stream"), "Stream", choices=stats::setNames(names(streams),streams), selected=id),
        shiny::selectInput(session$ns("reach"), "Reach", choices=stats::setNames(as.character(lines$reach_id), as.character(lines$ReachName))))
    })
    output$status <- shiny::renderUI(shiny::p(role="status", status()))
    shiny::observeEvent(list(context(), active(), revision()), {
      if (!isTRUE(active())) return()
      ctx <- context(); if (is.null(ctx)) return()
      key <- paste(ctx$path, ctx$group_path, revision(), sep="|")
      if (identical(key, loaded)) return()
      stop_job(); rem(NULL); extents(NULL); review(NULL); selected(NULL)
      tryCatch({
        value <- load_flowline_points_review(store, ctx)
        if (is.null(value$saved)) stop("Create and save Flowline Points before reviewing inundation.")
        review(value); loaded <<- key; status("Choose a Stream and Reach.")
      }, error=function(e) { loaded <<- NULL; status(conditionMessage(e)) })
    }, ignoreNULL=FALSE)
    shiny::observeEvent(list(input$stream, input$reach, review()), {
      value <- review(); if (is.null(value) || is.null(input$stream) || is.null(input$reach)) return()
      bundle <- value$bundle[[input$stream]]; if (is.null(bundle)) return()
      line <- bundle$flowline$flowlines[bundle$flowline$flowlines$reach_id == input$reach,,drop=FALSE]
      points <- value$saved$points[value$saved$points$reach_id == input$reach,,drop=FALSE]
      if (nrow(line)!=1L || !nrow(points)) return()
      stop_job(); rem(NULL); extents(NULL); generation <<- generation+1L
      selected(list(line=line, points=points, dem=bundle$dem, key=generation))
      status("Preparing the Reach REM in the background...")
      directory <- file.path(cache, paste0("reach-",generation)); dir.create(directory)
      job_key <<- generation; job_kind <<- "rem"
      job <<- callr::r_bg(function(dem,line,points,directory) {
        result <- fluvgeo::detrend(terra::rast(dem), line, points, buffer_distance=150)
        path <- file.path(directory,"rem.tif"); terra::writeRaster(result$rem,path,overwrite=TRUE)
        # A display-only overview; analysis uses the full-resolution REM.
        factor <- max(1L, ceiling(sqrt(terra::ncell(result$rem)/250000)))
        view <- if(factor>1L) terra::aggregate(result$rem,fact=factor,fun="mean",na.rm=TRUE) else result$rem
        view <- terra::project(view,"EPSG:3857")
        display <- file.path(directory,"display.tif"); terra::writeRaster(view,display,overwrite=TRUE)
        list(path=path,display=display)
      }, args=list(dem=bundle$dem,line=line,points=points,directory=directory),
      libpath=.libPaths(), supervise=TRUE, stdout=NULL, stderr=NULL)
    }, ignoreInit=TRUE)
    levels <- shiny::debounce(shiny::reactive(list(channel=input$channel, floodplain=input$floodplain)), 400)
    shiny::observeEvent(list(levels(), rem()), {
      x <- rem(); s <- selected(); v <- levels()
      if (is.null(x) || is.null(s) || is.null(v$channel) || is.null(v$floodplain)) return()
      if (!is.finite(v$channel) || !is.finite(v$floodplain) || v$channel>=v$floodplain) {
        stop_job(); extents(NULL); status("Set the floodplain elevation above the channel elevation."); return()
      }
      stop_job(); extents(NULL); status("Updating inundation extents...")
      job_kind <<- "extent"; job_key <<- list(s$key, v$channel, v$floodplain)
      job <<- callr::r_bg(function(path,line,channel,floodplain)
        fluvgeo::water_surface_extents(terra::rast(path),line,channel,floodplain),
        args=list(path=x$path,line=s$line,channel=v$channel,floodplain=v$floodplain),
        libpath=.libPaths(),supervise=TRUE,stdout=NULL,stderr=NULL)
    }, ignoreInit=TRUE)
    shiny::observe({
      shiny::invalidateLater(200, session)
      if (is.null(job) || job$is_alive()) return()
      kind <- job_kind; key <- job_key
      result <- tryCatch(job$get_result(), error=function(e) e); job <<- NULL; job_kind <<- NULL
      if (inherits(result,"error")) { status(paste("Unable to prepare inundation:",conditionMessage(result))); return() }
      s <- selected(); if (is.null(s)) return()
      if (identical(kind,"rem") && identical(key,s$key)) { rem(result); status("REM ready; calculating inundation.") }
      if (identical(kind,"extent") && identical(key,list(s$key,input$channel,input$floodplain))) {
        extents(result); status("Inundation ready for review. Cross-section layout is not yet available.")
      }
    })
    output$map <- leaflet::renderLeaflet({
      x <- rem(); s <- selected(); if (is.null(x) || is.null(s)) return(fg_leaflet() |> leaflet::addProviderTiles("Esri.WorldImagery"))
      raster <- terra::rast(x$display); limits <- as.numeric(terra::global(raster, range, na.rm=TRUE)[1,])
      pal <- leaflet::colorNumeric(terrain_palette(), domain=limits, na.color="transparent")
      line <- sf::st_transform(s$line,4326); b <- sf::st_bbox(line)
      fg_leaflet() |> leaflet::addProviderTiles("Esri.WorldImagery") |>
        leaflet::addRasterImage(raster, colors=pal, project=FALSE, opacity=.8, maxBytes=12*1024^2, group="REM") |>
        leaflet::addPolylines(data=line,color="black",weight=3,group="Flowline") |>
        leaflet::addLegend(pal=pal,values=limits,title="REM elevation (ft)",position="bottomright") |>
        leaflet::fitBounds(unname(b[["xmin"]]),unname(b[["ymin"]]),
          unname(b[["xmax"]]),unname(b[["ymax"]])) |>
        leaflet::addLayersControl(overlayGroups=c("REM","Flowline","Channel","Floodplain"))
    })
    shiny::observeEvent(extents(), {
      x <- extents(); proxy <- leaflet::leafletProxy("map",session)
      proxy <- leaflet::clearGroup(proxy,"Channel") |> leaflet::clearGroup("Floodplain")
      if (is.null(x)) return()
      proxy |> leaflet::addPolygons(data=sf::st_transform(x$floodplain_outer,4326), group="Floodplain",color="forestgreen",weight=2,fillOpacity=.08) |>
        leaflet::addPolygons(data=sf::st_transform(x$channel_outer,4326),group="Channel",color="navy",weight=2,fillOpacity=.15)
    }, ignoreNULL=FALSE)
  })
}
