flowline_review_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(bslib::card_header("Flowline"),
    shiny::p("FG Studio automatically follows the terrain-derived path that best agrees with the Stream you defined, then retains the longest matching head-to-outlet route. Branching tributaries are excluded without another segment-selection step."),
    shiny::uiOutput(ns("streams")),
    shiny::radioButtons(ns("bandwidth"),"Smoothing strength",
      choices=c("Conservative — 2 m (default)"="2","Moderate — 3 m"="3",
        "Stronger — 4 m"="4","Most aggressive — 5 m"="5"),
      selected="2",inline=TRUE),
    shiny::p(class="small","Choose among the legacy 2–5 map-unit range. This changes only the displayed Flowline candidate; terrain processing and mainstem selection are reused."),
    shiny::uiOutput(ns("status")),
    shiny::uiOutput(ns("summary")),
    shiny::div(class="d-flex gap-2 flex-wrap mb-2",
      shiny::actionButton(ns("return_stream"),"Return to Stream",class="btn-outline-secondary btn-sm")),
    leaflet::leafletOutput(ns("map"),height="650px"),
    shiny::p(class="small","Gold is the automatically selected and smoothed Flowline. Cyan shows the complete synthetic Stream Network; magenta shows the retained NHDPlusV2 reference. Elevation colors stretch to the current view."))
}

load_flowline_review <- function(store, selection) {
  record <- store$hydro_read(selection$key,selection$event,selection$stream,NULL)
  if(is.null(record) || is.null(record$result))
    stop("Apply and save this Stream's Hydro DEM in Hydro Modify first.")
  candidate <- store$stream_network_read(record)
  if(is.null(candidate))
    stop("Extract and save this Stream's synthetic network in Hydro Modify first.")
  network_path <- file.path(candidate$path,candidate$files$stream_network)
  if(!file.exists(network_path)) stop("The saved synthetic Stream Network is unavailable.")
  network <- sf::st_read(network_path,quiet=TRUE)
  reference <- store$stream_segments(selection$key,selection$stream,selection$path)$lines
  result <- fluvgeo::select_stream_mainstem(network,reference)
  result$raw_flowline <- result$flowline
  result$smoothing_candidates <- stats::setNames(lapply(2:5,function(bandwidth)
    fluvgeo::smooth_flowline(result$raw_flowline,bandwidth=bandwidth)),as.character(2:5))
  result$flowline <- result$smoothing_candidates[["2"]]
  list(record=record,candidate=candidate,network=network,reference=reference,
    result=result,dem=file.path(record$path,record$result$file))
}

flowline_smoothing_candidate <- function(result,bandwidth=2) {
  key <- as.character(bandwidth)[1]
  if(!key %in% names(result$smoothing_candidates)) key <- "2"
  result$smoothing_candidates[[key]]
}

flowline_review_server <- function(id,current,context,store,active=function() TRUE) {
  shiny::moduleServer(id,function(input,output,session) {
    review <- shiny::reactiveVal(NULL);notice <- shiny::reactiveVal("")
    view_notice <- shiny::reactiveVal("");view_busy <- shiny::reactiveVal(FALSE)
    native <- shiny::reactiveVal(FALSE);refreshed <- shiny::reactiveVal(0L)
    view_job <- NULL;view_worker <- NULL;view_dir <- NULL;view_key <- NULL
    worker_ready <- shiny::reactiveVal(FALSE);worker_warming <- FALSE;worker_failed <- FALSE
    last_view <- NULL;cache <- tempfile("flowline-map-");dir.create(cache)

    selected <- shiny::reactive({
      ctx <- context()
      if(is.null(ctx) || !nrow(ctx$streams)) return(NULL)
      stream <- input$stream
      if(length(stream)!=1L || !stream %in% ctx$streams$stream_id)
        stream <- ctx$streams$stream_id[1]
      list(key=ctx$key,event=ctx$group_id,stream=stream,path=ctx$path,
        group=ctx$group_path)
    })
    selected_flowline <- shiny::reactive({
      value <- review();if(is.null(value)) return(NULL)
      flowline_smoothing_candidate(value$result,input$bandwidth)
    })
    output$streams <- shiny::renderUI({
      ctx <- context()
      if(is.null(ctx)) return(shiny::p("Create a Survey Event before deriving a Flowline."))
      panels <- lapply(seq_len(nrow(ctx$streams)),function(i)
        bslib::nav_panel(ctx$streams$stream_name[i],value=ctx$streams$stream_id[i]))
      shiny::tagList(if(!is.null(ctx$event_label))
        shiny::p(shiny::strong(paste("Survey Event:",ctx$event_label))),
        do.call(bslib::navset_tab,c(panels,list(id=session$ns("stream")))))
    })

    stop_view <- function() {native(FALSE);view_busy(FALSE)}
    shiny::observe({
      shiny::invalidateLater(200,session)
      if(worker_ready() || worker_failed || is.null(context()) || !isTRUE(active())) return()
      tryCatch({
        if(is.null(view_worker)) {
          view_worker <<- callr::r_session$new(options=callr::r_session_options(
            libpath=.libPaths(),stdout=NULL,stderr=NULL,supervise=TRUE),wait=FALSE)
          return()
        }
        if(identical(view_worker$get_state(),"starting")) {
          if(!identical(unname(view_worker$poll_io(0)["process"]),"ready")) return()
          view_worker$read()
        }
        if(worker_warming) {
          if(!identical(unname(view_worker$poll_io(0)["process"]),"ready")) return()
          answer <- view_worker$read();if(!is.null(answer$error)) stop(answer$error)
          worker_ready(TRUE);worker_warming <<- FALSE
        } else if(identical(view_worker$get_state(),"idle")) {
          view_worker$call(function(){loadNamespace("fluvgeo");loadNamespace("terra");loadNamespace("sf");NULL})
          worker_warming <<- TRUE
        }
      },error=function(e){worker_failed <<- TRUE;stop_view();view_notice(hydro_error_message(e))})
    })

    shiny::observeEvent(list(selected(),active()),{
      if(!isTRUE(active())) {stop_view();return()}
      selection <- selected();review(NULL);last_view <<- NULL;native(FALSE)
      if(is.null(selection)) return()
      notice("Selecting the mainstem from the saved Stream Network...")
      tryCatch({
        value <- load_flowline_review(store,selection)
        review(value)
        path <- flowline_smoothing_candidate(value$result,shiny::isolate(input$bandwidth))
        notice(paste0("Flowline selected and smoothed automatically: ",
          format(round(path$length_m),big.mark=",")," m from ",
          path$source_segment_count," network lines. ",nrow(value$result$candidates),
          " complete head-to-outlet paths were evaluated."))
        refreshed(shiny::isolate(refreshed())+1L)
      },error=function(e) notice(conditionMessage(e)))
    },ignoreNULL=FALSE)

    output$map <- leaflet::renderLeaflet({
      value <- review()
      map <- leaflet::leaflet(options=leaflet::leafletOptions(maxZoom=23)) |>
        leaflet::addMapPane("flowline-basemap",zIndex=200) |>
        leaflet::addMapPane("hydro-hillshade",zIndex=300) |>
        leaflet::addMapPane("hydro-elevation",zIndex=350) |>
        leaflet::addMapPane("flowline-lines",zIndex=500) |>
        leaflet::addProviderTiles("Esri.WorldImagery",group="Imagery",
          options=leaflet::providerTileOptions(maxNativeZoom=19,maxZoom=23,pane="flowline-basemap")) |>
        leaflet::addProviderTiles("OpenStreetMap",group="Street map",
          options=leaflet::providerTileOptions(maxNativeZoom=19,maxZoom=23,pane="flowline-basemap")) |>
        leaflet::hideGroup("Street map") |>
        add_opentopomap(pane="flowline-basemap") |>
        leaflet::addLayersControl(baseGroups=c("Imagery","Street map","OpenTopoMap"),
          overlayGroups=c("Elevation","Hillshade","Selected Flowline","Synthetic Stream Network",
            "NHDPlusV2 reference","DEM extent"),
          options=leaflet::layersControlOptions(collapsed=TRUE),position="topright") |>
        leaflet::addScaleBar(position="bottomleft")
      if(!is.null(value)) {
        b <- flowline_dem_bounds(value$dem)
        network <- sf::st_transform(value$network,4326)
        reference <- sf::st_transform(value$reference,4326)
        path <- sf::st_transform(flowline_smoothing_candidate(value$result,
          shiny::isolate(input$bandwidth)),4326)
        map <- leaflet::fitBounds(map,b[1],b[2],b[3],b[4]) |>
          leaflet::addRectangles(b[1],b[2],b[3],b[4],group="DEM extent",
            color="#e68a00",weight=2,fill=FALSE,options=leaflet::pathOptions(pane="flowline-lines")) |>
          leaflet::addPolylines(data=network,group="Synthetic Stream Network",
            color="#00a9c7",weight=2,opacity=.4,
            label=paste0("Synthetic network line ",network$stream_line_id),
            options=leaflet::pathOptions(interactive=FALSE,pane="flowline-lines")) |>
          leaflet::addPolylines(data=reference,group="NHDPlusV2 reference",
            color="#d01c8b",weight=4,opacity=.85,dashArray="8,6",
            label="Saved NHDPlusV2 Stream reference",
            options=leaflet::pathOptions(interactive=FALSE,pane="flowline-lines")) |>
          leaflet::addPolylines(data=path,group="Selected Flowline",color="#ffd400",
            weight=7,opacity=1,label=paste0("Automatically selected and smoothed Flowline; ",
              format(round(path$length_m),big.mark=",")," m"),
            options=leaflet::pathOptions(interactive=FALSE,pane="flowline-lines"))
      }
      htmlwidgets::onRender(map,paste(readLines(system.file("www","hydro-display.js",
        package="fgstudio",mustWork=TRUE),warn=FALSE),collapse="\n"))
    })

    shiny::observeEvent(input$bandwidth,{
      path <- selected_flowline();if(is.null(path)) return()
      display <- sf::st_transform(path,4326)
      leaflet::leafletProxy("map",session) |>
        leaflet::clearGroup("Selected Flowline") |>
        leaflet::addPolylines(data=display,group="Selected Flowline",color="#ffd400",
          weight=7,opacity=1,label=paste0("Selected ",path$smoothing_bandwidth,
            " m smoothing candidate; ",format(round(path$length_m),big.mark=",")," m"),
          options=leaflet::pathOptions(interactive=FALSE,pane="flowline-lines"))
    },ignoreInit=TRUE)

    output$status <- shiny::renderUI(shiny::tagList(
      shiny::p(role="status",notice()),shiny::p(class="small",view_notice()),
      if(view_busy()) shiny::tags$progress(style="width:100%",`aria-label`="Loading Flowline terrain display")))
    output$summary <- shiny::renderUI({
      value <- review();path <- selected_flowline();if(is.null(value) || is.null(path)) return(NULL)
      margin <- if(is.na(path$reference_margin_m)) "Only one complete path" else
        paste0(format(round(path$reference_margin_m,1),big.mark=",")," m")
      compact_table(data.frame(Item=c("Selection","Complete paths compared","Smoothed Flowline length",
        "Source network lines","Reference mismatch","Next-best reference margin",
        "Smoothing","Maximum smoothing displacement","Length change from raw path"),
        Value=c("Automatic reference-constrained longest path",nrow(value$result$candidates),
          paste0(format(round(path$length_m),big.mark=",")," m"),path$source_segment_count,
          paste0(format(round(path$reference_hausdorff_m,1),big.mark=",")," m"),margin,
          paste0(path$smoothing_method,"; ",path$smoothing_bandwidth," ",
            path$smoothing_unit," bandwidth",
            if(path$smoothing_bandwidth==2) " (historical default)" else ""),
          paste0(round(path$maximum_displacement,2)," ",path$smoothing_unit),
          paste0(round(path$length_change_percent,1),"%"))))
    })
    fit_stream <- function(){value<-shiny::isolate(review());if(is.null(value))return()
      b<-flowline_dem_bounds(value$dem);leaflet::fitBounds(leaflet::leafletProxy("map",session),b[1],b[2],b[3],b[4])}
    shiny::observeEvent(input$return_stream,fit_stream(),ignoreInit=TRUE)

    bounds <- shiny::debounce(shiny::reactive(input$map_bounds),350)
    shiny::observe({
      shiny::invalidateLater(200,session)
      b <- bounds();value <- review();refreshed()
      if(!isTRUE(active()) || is.null(value) || !valid_map_bounds(b)) return()
      signature <- list(path=value$dem,bounds=b)
      if(identical(signature,last_view)) return()
      if(!worker_ready()) {if(!worker_failed){view_notice("Opening DEM viewer...");view_busy(TRUE)};return()}
      if(!is.null(view_job) || !identical(view_worker$get_state(),"idle")) return()
      last_view <<- signature;stop_view();view_key <<- signature
      view_dir <<- tempfile("view-",cache);dir.create(view_dir)
      view_notice("Loading elevation detail...");view_busy(TRUE)
      tryCatch({
        display_cache <- file.path(dirname(shiny::isolate(current())$path),"terrain-display")
        view_worker$call(function(path,b,directory,display_cache)
          fluvgeo::prepare_hydro_dem_view(path,b,directory,cache_directory=display_cache,build_cache=FALSE),
          args=list(path=value$dem,b=b,directory=view_dir,display_cache=display_cache))
        view_job <<- list(is_alive=function() !identical(unname(view_worker$poll_io(0)["process"]),"ready"),
          get_result=function(){answer<-view_worker$read();if(!is.null(answer$error))stop(answer$error);answer$result})
      },error=function(e){stop_view();view_notice(conditionMessage(e))})
    })
    poll <- function(){
      if(!is.null(view_job) && !view_job$is_alive()) {
        job <- view_job;view_job <<- NULL;view_busy(FALSE);finished <- view_dir
        on.exit(unlink(finished,recursive=TRUE),add=TRUE)
        tryCatch({
          v <- job$get_result();value <- shiny::isolate(review())
          if(is.null(value) || !identical(view_key,list(path=value$dem,bounds=shiny::isolate(bounds())))) return()
          proxy <- leaflet::leafletProxy("map",session)
          if(isTRUE(v$empty)) {
            leaflet::clearImages(proxy) |> leaflet::removeControl("elevation-legend")
            native(FALSE);view_notice(v$message);return()
          }
          pal <- leaflet::colorNumeric(terrain_palette(),domain=v$limits,na.color="transparent")
          proxy <- leaflet::clearImages(proxy) |> leaflet::removeControl("elevation-legend")
          proxy <- leaflet::addRasterImage(proxy,terra::rast(v$hill),
            colors=leaflet::colorNumeric("Greys",c(0,255),reverse=TRUE,na.color="transparent"),
            opacity=1,project=FALSE,layerId="hill",group="Hillshade",maxBytes=12*1024^2,
            options=leaflet::gridOptions(pane="hydro-hillshade"))
          proxy <- leaflet::addRasterImage(proxy,terra::rast(v$elevation),colors=pal,
            opacity=1,project=FALSE,layerId="elevation",group="Elevation",maxBytes=12*1024^2,
            options=leaflet::gridOptions(pane="hydro-elevation"))
          leaflet::addLegend(proxy,pal=pal,values=v$limits,title=paste("Elevation",v$unit),
            group="Elevation",position="bottomright",layerId="elevation-legend")
          native(v$native);view_notice(if(v$native) "Full source-cell detail; display reprojection only." else
            "Overview: zoom closer for source-cell detail.")
        },error=function(e){native(FALSE);view_notice(hydro_error_message(e))})
      }
    }
    shiny::observe({shiny::invalidateLater(300,session);poll()})
    session$onSessionEnded(function(){if(!is.null(view_worker))view_worker$kill();unlink(cache,recursive=TRUE)})
    list(review=review,selected=selected,flowline=selected_flowline,poll=poll)
  })
}

flowline_dem_bounds <- function(path) {
  raster <- terra::rast(path);extent <- unname(as.vector(terra::ext(raster)))
  bounds <- sf::st_bbox(c(xmin=extent[1],ymin=extent[3],xmax=extent[2],ymax=extent[4]),
    crs=sf::st_crs(terra::crs(raster)))
  unname(sf::st_transform(bounds,4326))
}
