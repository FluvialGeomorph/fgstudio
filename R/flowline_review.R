flowline_review_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(bslib::card_header("Flowline"),
    shiny::p("Choose a Survey Event and Stream. FG Studio saves the conservative Flowline automatically; choose another smoothing strength only when the terrain calls for it."),
    shiny::uiOutput(ns("events")),shiny::uiOutput(ns("streams")),
    shiny::radioButtons(ns("bandwidth"),"Smoothing strength",
      choices=c("Conservative - 2 m (default)"="2","Moderate - 3 m"="3",
        "Stronger - 4 m"="4","Most aggressive - 5 m"="5"),
      selected="2",inline=TRUE),
    shiny::p(class="small","Changing the smoothing strength automatically saves that candidate. The selected terrain path is reused."),
    shiny::uiOutput(ns("status")),
    shiny::tags$details(class="small mb-2",shiny::tags$summary("Selection details"),
      shiny::uiOutput(ns("summary"))),
    leaflet::leafletOutput(ns("map"),height="650px"),
    shiny::p(class="small","Gold is the automatically selected and smoothed Stream path. Colored lines are the resulting Reach Flowlines, with white dots at shared boundaries. Cyan shows the complete synthetic Stream Network; magenta shows the retained NHDPlusV2 reference. Elevation colors stretch to the current view."))
}

resolve_flowline_review_inputs <- function(store,selection) {
  record <- store$hydro_read(selection$key,selection$event,selection$stream,NULL)
  if(is.null(record) || is.null(record$result))
    stop("Apply and save this Stream's Hydro DEM in Hydro Modify first.")
  candidate <- store$stream_network_read(record)
  if(is.null(candidate))
    stop("Extract and save this Stream's synthetic network in Hydro Modify first.")
  list(record=record,candidate=candidate,key=paste(selection$key,selection$event,
    selection$stream,selection$path,record$path,candidate$path,sep="\r"))
}

load_flowline_review <- function(store, selection, inputs=NULL) {
  if(is.null(inputs)) inputs <- resolve_flowline_review_inputs(store,selection)
  record <- inputs$record;candidate <- inputs$candidate
  network_path <- file.path(candidate$path,candidate$files$stream_network)
  if(!file.exists(network_path)) stop("The saved synthetic Stream Network is unavailable.")
  network <- sf::st_read(network_path,quiet=TRUE)
  segments <- store$stream_segments(selection$key,selection$stream,selection$path)
  reference <- segments$lines
  dem_path <- file.path(record$path,record$result$file)
  saved <- if(is.function(store$flowline_read))
    store$flowline_read(record,selection,segments) else NULL
  if(!is.null(saved)) {
    key <- as.character(saved$smoothing_bandwidth)
    result <- list(raw_flowline=saved$raw_flowline,
      selected_segments=saved$selected_segments,candidates=NULL,
      smoothing_candidates=stats::setNames(list(saved$stream_flowline),key),
      reach_candidates=stats::setNames(list(list(flowlines=saved$flowlines,
        boundaries=saved$boundaries)),key),flowline=saved$stream_flowline,
      reopened=TRUE)
    return(list(record=record,candidate=candidate,network=network,
      reference=reference,segments=segments,result=result,dem=dem_path,
      saved=saved,selection=selection))
  }
  result <- fluvgeo::select_stream_mainstem(network,reference)
  result$raw_flowline <- result$flowline
  result$smoothing_candidates <- list();result$reach_candidates <- list()
  value <- list(record=record,candidate=candidate,network=network,
    reference=reference,segments=segments,result=result,dem=dem_path,
    saved=NULL,selection=selection)
  prepare_flowline_bandwidth(value,2)
}

prepare_flowline_bandwidth <- function(value,bandwidth) {
  key <- as.character(as.numeric(bandwidth)[1])
  if(key %in% names(value$result$smoothing_candidates) &&
      key %in% names(value$result$reach_candidates)) return(value)
  first_candidate <- !length(value$result$smoothing_candidates)
  path <- fluvgeo::smooth_flowline(value$result$raw_flowline,
    bandwidth=as.numeric(key))
  reference <- sf::st_transform(value$reference,
    sf::st_crs(value$result$raw_flowline))
  divided <- fluvgeo::derive_reach_flowlines(value$result$raw_flowline,path,
    reference,value$segments$reach_mappings,value$selection$reaches,
    terra::rast(value$dem))
  value$result$smoothing_candidates[[key]] <- path
  value$result$reach_candidates[[key]] <- divided
  if(first_candidate) value$result$flowline <- path
  value
}

flowline_smoothing_candidate <- function(result,bandwidth=2) {
  key <- as.character(bandwidth)[1]
  if(!key %in% names(result$smoothing_candidates))
    key <- names(result$smoothing_candidates)[1]
  result$smoothing_candidates[[key]]
}

flowline_review_server <- function(id,current,context,store,active=function() TRUE,
                                   events=NULL,revision=function() 0L,
                                   on_changed=function() NULL) {
  shiny::moduleServer(id,function(input,output,session) {
    review <- shiny::reactiveVal(NULL);notice <- shiny::reactiveVal("")
    busy <- shiny::reactiveVal(FALSE)
    view_notice <- shiny::reactiveVal("");view_busy <- shiny::reactiveVal(FALSE)
    native <- shiny::reactiveVal(FALSE);refreshed <- shiny::reactiveVal(0L)
    view_job <- NULL;view_worker <- NULL;view_dir <- NULL;view_key <- NULL
    worker_ready <- shiny::reactiveVal(FALSE);worker_warming <- FALSE;worker_failed <- FALSE
    last_view <- NULL;loaded_key <- NULL
    review_cache <- new.env(parent=emptyenv())
    cache <- tempfile("flowline-map-");dir.create(cache)
    linked_survey_event_selector(input,output,session,events,context)

    selected <- shiny::reactive({
      ctx <- context()
      if(is.null(ctx) || !nrow(ctx$streams)) return(NULL)
      stream <- input$stream
      if(length(stream)!=1L || !stream %in% ctx$streams$stream_id)
        stream <- ctx$streams$stream_id[1]
      list(key=ctx$key,event=ctx$group_id,stream=stream,path=ctx$path,
        group=ctx$group_path,reaches=ctx$reaches[ctx$reaches$stream_id==stream,,drop=FALSE])
    })
    shiny::observeEvent(input$stream,{
      ctx <- context();stream_id <- input$stream
      fit_stream_map(session,ctx,stream_id)
      session$onFlushed(function() fit_stream_map(session,ctx,stream_id),once=TRUE)
    },ignoreInit=TRUE,priority=10)
    selected_flowline <- shiny::reactive({
      value <- review();if(is.null(value)) return(NULL)
      flowline_smoothing_candidate(value$result,input$bandwidth)
    })
    selected_reaches <- shiny::reactive({
      value <- review();if(is.null(value)) return(NULL)
      key <- as.character(input$bandwidth)[1]
      if(!key %in% names(value$result$reach_candidates))
        key <- names(value$result$reach_candidates)[1]
      value$result$reach_candidates[[key]]
    })
    output$streams <- shiny::renderUI({
      ctx <- context()
      if(is.null(ctx)) return(shiny::p("Create a Survey Event before deriving a Flowline."))
      panels <- lapply(seq_len(nrow(ctx$streams)),function(i)
        bslib::nav_panel(ctx$streams$stream_name[i],value=ctx$streams$stream_id[i]))
      do.call(bslib::navset_tab,c(panels,list(id=session$ns("stream"))))
    })

    publish_candidate <- function(value,bandwidth) {
      key <- as.character(as.numeric(bandwidth)[1])
      if(!key %in% names(value$result$smoothing_candidates) ||
          !key %in% names(value$result$reach_candidates))
        stop("Prepare the selected smoothing strength before saving it.")
      if(!is.null(value$saved) &&
          identical(as.numeric(value$saved$smoothing_bandwidth),as.numeric(key)))
        return(value)
      path <- value$result$smoothing_candidates[[key]]
      divided <- value$result$reach_candidates[[key]]
      saved <- store$flowline_publish(value$record,value$selection,value$segments,
        as.numeric(key),value$result$raw_flowline,path,divided$flowlines,
        divided$boundaries,value$result$selected_segments)
      value$saved <- saved
      on_changed()
      value
    }

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

    shiny::observeEvent(list(selected(),active(),revision()),{
      if(!isTRUE(active())) {stop_view();return()}
      selection <- selected()
      if(is.null(selection)) return()
      key <- paste(selection$key,selection$event,selection$stream,
        selection$path,selection$group,shiny::isolate(revision()),sep="\r")
      if(identical(key,loaded_key) && !is.null(review())) return()
      if(exists(key,envir=review_cache,inherits=FALSE)) {
        value <- get(key,envir=review_cache,inherits=FALSE)
        if(is.null(value$saved)) {
          busy(TRUE);on.exit(busy(FALSE),add=TRUE)
          notice("Saving the conservative Flowline...")
          value <- tryCatch(publish_candidate(value,2),error=function(e) {
            notice(paste("The default Flowline was not saved:",conditionMessage(e)));value})
          assign(key,value,envir=review_cache)
        }
        review(value);loaded_key <<- key;last_view <<- NULL
        if(!is.null(value$saved)) shiny::updateRadioButtons(session,"bandwidth",
          selected=as.character(value$saved$smoothing_bandwidth))
        notice(if(!is.null(value$saved))
          paste0("Reach Flowlines are saved automatically at ",
            value$saved$smoothing_bandwidth," m smoothing.") else notice())
        refreshed(shiny::isolate(refreshed())+1L)
        return()
      }
      busy(TRUE);on.exit(busy(FALSE),add=TRUE)
      tryCatch({
        inputs <- resolve_flowline_review_inputs(store,selection)
        review(NULL);last_view <<- NULL;native(FALSE)
        notice("Preparing the selected Stream path...")
        value <- load_flowline_review(store,selection,inputs)
        if(is.null(value$saved)) {
          notice("Saving the conservative Flowline...")
          value <- publish_candidate(value,2)
        }
        review(value)
        loaded_key <<- key;assign(key,value,envir=review_cache)
        if(!is.null(value$saved))
          shiny::updateRadioButtons(session,"bandwidth",
            selected=as.character(value$saved$smoothing_bandwidth))
        notice(if(!is.null(value$saved))
          paste0("Reach Flowlines are saved automatically at ",
            value$saved$smoothing_bandwidth," m smoothing.") else
          "The Flowline could not be saved.")
        refreshed(shiny::isolate(refreshed())+1L)
      },error=function(e) {loaded_key <<- NULL;notice(conditionMessage(e))})
    },ignoreNULL=FALSE)

    output$map <- leaflet::renderLeaflet({
      value <- review()
      target_bounds <- NULL
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
            "Reach Flowlines","Reach boundaries","NHDPlusV2 reference","DEM extent"),
          options=leaflet::layersControlOptions(collapsed=TRUE),position="topright") |>
        leaflet::addScaleBar(position="bottomleft")
      if(!is.null(value)) {
        b <- flowline_dem_bounds(value$dem)
        target_bounds <- stream_map_bounds(context(),value$selection$stream,b)
        network <- sf::st_transform(value$network,4326)
        reference <- sf::st_transform(value$reference,4326)
        path <- sf::st_transform(flowline_smoothing_candidate(value$result,
          shiny::isolate(input$bandwidth)),4326)
        reach_key <- as.character(shiny::isolate(input$bandwidth))[1]
        if(!length(reach_key) || is.na(reach_key) ||
           !reach_key %in% names(value$result$reach_candidates))
          reach_key <- names(value$result$reach_candidates)[1]
        divided <- value$result$reach_candidates[[reach_key]]
        reaches <- sf::st_transform(divided$flowlines,4326)
        boundaries <- sf::st_transform(divided$boundaries,4326)
        colors <- grDevices::hcl.colors(max(3,nrow(reaches)),"Dark 3")[seq_len(nrow(reaches))]
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
            options=leaflet::pathOptions(interactive=FALSE,pane="flowline-lines")) |>
          leaflet::addPolylines(data=reaches,group="Reach Flowlines",color=colors,
            weight=4,opacity=1,label=paste0(reaches$ReachName," — ",
              format(round(reaches$length_m),big.mark=",")," m"),
            options=leaflet::pathOptions(interactive=FALSE,pane="flowline-lines"))
        if(nrow(boundaries)) map <- leaflet::addCircleMarkers(map,data=boundaries,
          group="Reach boundaries",radius=5,color="#222222",weight=2,
          fillColor="#ffffff",fillOpacity=1,
          label=paste0("Boundary: ",substr(boundaries$downstream_reach_id,1,8),
            " / ",substr(boundaries$upstream_reach_id,1,8)),
          options=leaflet::pathOptions(interactive=FALSE,pane="flowline-lines"))
      }
      htmlwidgets::onRender(map,paste(readLines(system.file("www","hydro-display.js",
        package="fgstudio",mustWork=TRUE),warn=FALSE),collapse="\n"),
        data=list(bounds=target_bounds))
    })

    shiny::observeEvent(input$bandwidth,{
      value <- review();if(is.null(value)) return()
      key <- as.character(input$bandwidth)[1]
      busy(TRUE);on.exit(busy(FALSE),add=TRUE)
      if(!key %in% names(value$result$smoothing_candidates)) {
        notice("Preparing the selected smoothing strength...")
        value <- tryCatch(prepare_flowline_bandwidth(value,key),error=function(e) {
          notice(conditionMessage(e));NULL})
        if(is.null(value)) return()
      }
      if(is.null(value$saved) ||
          !identical(as.numeric(value$saved$smoothing_bandwidth),as.numeric(key))) {
        notice("Saving the selected smoothing strength...")
        value <- tryCatch(publish_candidate(value,key),error=function(e) {
          notice(paste("The selected Flowline was not saved:",conditionMessage(e)));NULL})
        if(is.null(value)) return()
      }
      review(value)
      if(!is.null(loaded_key)) assign(loaded_key,value,envir=review_cache)
      notice(paste0("Reach Flowlines are saved automatically at ",key,
        " m smoothing."))
      path <- selected_flowline();divided <- selected_reaches();if(is.null(path) || is.null(divided)) return()
      display <- sf::st_transform(path,4326)
      reaches <- sf::st_transform(divided$flowlines,4326)
      boundaries <- sf::st_transform(divided$boundaries,4326)
      colors <- grDevices::hcl.colors(max(3,nrow(reaches)),"Dark 3")[seq_len(nrow(reaches))]
      proxy <- leaflet::leafletProxy("map",session) |>
        leaflet::clearGroup("Selected Flowline") |>
        leaflet::clearGroup("Reach Flowlines") |>
        leaflet::clearGroup("Reach boundaries") |>
        leaflet::addPolylines(data=display,group="Selected Flowline",color="#ffd400",
          weight=7,opacity=1,label=paste0("Selected ",path$smoothing_bandwidth,
            " m smoothing candidate; ",format(round(path$length_m),big.mark=",")," m"),
          options=leaflet::pathOptions(interactive=FALSE,pane="flowline-lines")) |>
        leaflet::addPolylines(data=reaches,group="Reach Flowlines",color=colors,
          weight=4,opacity=1,label=paste0(reaches$ReachName," — ",
            format(round(reaches$length_m),big.mark=",")," m"),
          options=leaflet::pathOptions(interactive=FALSE,pane="flowline-lines"))
      if(nrow(boundaries)) leaflet::addCircleMarkers(proxy,data=boundaries,
        group="Reach boundaries",radius=5,color="#222222",weight=2,
        fillColor="#ffffff",fillOpacity=1,
        label="Shared Reach boundary",
        options=leaflet::pathOptions(interactive=FALSE,pane="flowline-lines"))
    },ignoreInit=TRUE)

    output$status <- shiny::renderUI(shiny::tagList(
      shiny::p(role="status",notice()),shiny::p(class="small",view_notice()),
      if(busy() || view_busy()) shiny::tags$progress(style="width:100%",
        `aria-label`=if(busy()) "Preparing Flowline review" else "Loading Flowline terrain display")))
    output$summary <- shiny::renderUI({
      value <- review();path <- selected_flowline();divided <- selected_reaches()
      if(is.null(value) || is.null(path) || is.null(divided)) return(NULL)
      margin <- if(is.na(path$reference_margin_m)) "Only one complete path" else
        paste0(format(round(path$reference_margin_m,1),big.mark=",")," m")
      paths_compared <- if(is.null(value$result$candidates)) "Reused saved selection" else
        nrow(value$result$candidates)
      compact_table(data.frame(Item=c("Selection","Complete paths compared","Smoothed Flowline length",
        "Source network lines","Reference mismatch","Next-best reference margin",
        "Smoothing","Maximum smoothing displacement","Length change from raw path",
        "Reach Flowlines","Local candidate"),
        Value=c("Automatic reference-constrained longest path",paths_compared,
          paste0(format(round(path$length_m),big.mark=",")," m"),path$source_segment_count,
          paste0(format(round(path$reference_hausdorff_m,1),big.mark=",")," m"),margin,
          paste0(path$smoothing_method,"; ",path$smoothing_bandwidth," ",
            path$smoothing_unit," bandwidth",
            if(path$smoothing_bandwidth==2) " (historical default)" else ""),
          paste0(round(path$maximum_displacement,2)," ",path$smoothing_unit),
          paste0(round(path$length_change_percent,1),"%"),
          paste(divided$flowlines$ReachName,collapse="; "),
          if(!is.null(value$saved) && identical(value$saved$smoothing_bandwidth,
            as.numeric(input$bandwidth))) "Saved automatically for these exact inputs" else "Not saved")))
    })
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
    list(review=review,selected=selected,flowline=selected_flowline,
      reach_flowlines=selected_reaches,poll=poll)
  })
}

flowline_dem_bounds <- function(path) {
  raster <- terra::rast(path);extent <- unname(as.vector(terra::ext(raster)))
  bounds <- sf::st_bbox(c(xmin=extent[1],ymin=extent[3],xmax=extent[2],ymax=extent[4]),
    crs=sf::st_crs(terra::crs(raster)))
  unname(sf::st_transform(bounds,4326))
}

stream_map_bounds <- function(context,stream_id,fallback=NULL) {
  if(is.null(context) || is.null(context$streams)) return(fallback)
  streams <- context$streams
  if(!inherits(streams,"sf") || length(stream_id)!=1L ||
      !"stream_id" %in% names(streams) || !stream_id %in% streams$stream_id)
    return(fallback)
  feature <- streams[streams$stream_id==stream_id,,drop=FALSE]
  if(!nrow(feature) || all(sf::st_is_empty(feature))) return(fallback)
  bounds <- unname(sf::st_bbox(sf::st_transform(feature,4326))[
    c("xmin","ymin","xmax","ymax")])
  if(length(bounds)!=4L || any(!is.finite(bounds)) ||
      bounds[1]>=bounds[3] || bounds[2]>=bounds[4]) fallback else bounds
}

fit_stream_map <- function(session,context,stream_id,map_id="map") {
  bounds <- stream_map_bounds(context,stream_id)
  if(is.null(bounds)) return(invisible(FALSE))
  leaflet::fitBounds(leaflet::leafletProxy(map_id,session),bounds[1],bounds[2],
    bounds[3],bounds[4],options=list(animate=FALSE,padding=c(16,16)))
  invisible(TRUE)
}
