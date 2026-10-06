flowline_points_review_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(bslib::card_header("Flowline Points"),
    shiny::p("Create one Study Area longitudinal profile from every saved Stream and Reach Flowline. FG Studio uses one-meter spacing, identifies the one outlet Stream, and starts each tributary at its mainstem confluence station."),
    shiny::uiOutput(ns("streams")),
    shiny::tags$details(class="small mb-2",
      shiny::tags$summary("Advanced spacing"),
      shiny::numericInput(ns("station_distance"),"Maximum point spacing (meters)",
        value=1,min=.1,step=.1),
      shiny::p("One meter is the FG Studio default. Changing this value does not recalculate until you create a new candidate.")),
    shiny::div(class="d-flex gap-2 flex-wrap mb-2",
      shiny::actionButton(ns("create"),"Create Study Area Flowline Points",
        class="btn-primary btn-sm")),
    shiny::uiOutput(ns("status")),
    shiny::uiOutput(ns("summary")),
    bslib::layout_columns(col_widths=c(7,5),
      leaflet::leafletOutput(ns("map"),height="600px"),
      bslib::card(bslib::card_header("Study Area longitudinal elevation profile"),
        shiny::plotOutput(ns("profile"),height="520px"))),
    shiny::p(class="small mt-2","Choose a Stream tab to review its Flowline Points over its Hydro DEM. The profile always uses every saved Study Area Stream and Reach; distance increases upstream from the one Study Area outlet."))
}

load_flowline_points_review <- function(store,context) {
  if(is.null(context) || !nrow(context$streams))
    stop("Create a Survey Event before creating Flowline Points.")
  bundle <- lapply(seq_len(nrow(context$streams)),function(i) {
    stream <- context$streams[i,,drop=FALSE]
    selection <- list(key=context$key,event=context$group_id,
      stream=stream$stream_id[[1]],path=context$path,group=context$group_path,
      reaches=context$reaches[context$reaches$stream_id==stream$stream_id[[1]],,
        drop=FALSE])
    record <- store$hydro_read(selection$key,selection$event,selection$stream,NULL)
    if(is.null(record) || is.null(record$result))
      stop(paste0("Apply and save the Hydro DEM for ",stream$stream_name[[1]],
        " in Hydro Modify first."))
    segments <- store$stream_segments(selection$key,selection$stream,selection$path)
    flowline <- store$flowline_read(record,selection,segments)
    if(is.null(flowline))
      stop(paste0("Save Reach Flowlines for ",stream$stream_name[[1]],
        " on the Flowline tab first."))
    dem <- file.path(record$path,record$result$file)
    if(!file.exists(dem)) stop("A saved Hydro DEM is unavailable.")
    list(stream_id=selection$stream,stream_name=stream$stream_name[[1]],
      selection=selection,record=record,segments=segments,flowline=flowline,dem=dem)
  })
  names(bundle) <- vapply(bundle,`[[`,character(1),"stream_id")
  saved <- store$flowline_points_read(context,bundle)
  list(context=context,bundle=bundle,saved=saved,
    key=list(context=context$path,event=context$group_path,
      flowlines=vapply(bundle,function(x)x$flowline$path,character(1))))
}

flowline_points_display_sample <- function(points,maximum=5000L) {
  if(is.null(points) || nrow(points)<=maximum) return(points)
  points[unique(round(seq(1,nrow(points),length.out=maximum))),]
}

flowline_points_review_server <- function(id,current,context,store,
                                          active=function() TRUE) {
  shiny::moduleServer(id,function(input,output,session) {
    review <- shiny::reactiveVal(NULL);points <- shiny::reactiveVal(NULL)
    notice <- shiny::reactiveVal("");busy <- shiny::reactiveVal(FALSE)
    view_notice <- shiny::reactiveVal("");view_busy <- shiny::reactiveVal(FALSE)
    refreshed <- shiny::reactiveVal(0L);last_view <- NULL;view_key <- NULL
    loaded_key <- NULL;view_job <- NULL;view_worker <- NULL;view_dir <- NULL
    worker_ready <- shiny::reactiveVal(FALSE);worker_warming <- FALSE;worker_failed <- FALSE
    cache <- tempfile("flowline-points-map-");dir.create(cache)

    selected_id <- shiny::reactive({
      ctx <- context();if(is.null(ctx) || !nrow(ctx$streams)) return(NULL)
      stream <- input$stream
      if(length(stream)!=1L || !stream %in% ctx$streams$stream_id)
        stream <- ctx$streams$stream_id[1]
      stream
    })
    selected <- shiny::reactive({
      value <- review();id <- selected_id()
      if(is.null(value) || is.null(id)) return(NULL)
      value$bundle[[id]]
    })
    output$streams <- shiny::renderUI({
      ctx <- context()
      if(is.null(ctx)) return(shiny::p("Create a Survey Event before creating Flowline Points."))
      panels <- lapply(seq_len(nrow(ctx$streams)),function(i)
        bslib::nav_panel(ctx$streams$stream_name[i],value=ctx$streams$stream_id[i]))
      shiny::tagList(if(!is.null(ctx$event_label))
        shiny::p(shiny::strong(paste("Survey Event:",ctx$event_label))),
        shiny::p(class="small","Stream tabs change the map review only; the saved profile includes all Streams."),
        do.call(bslib::navset_tab,c(panels,list(id=session$ns("stream")))))
    })

    stop_view <- function(){view_busy(FALSE)}
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
          view_worker$call(function(){loadNamespace("fluvgeo");loadNamespace("terra");NULL})
          worker_warming <<- TRUE
        }
      },error=function(e){worker_failed <<- TRUE;stop_view();view_notice(hydro_error_message(e))})
    })

    shiny::observeEvent(list(context(),active()),{
      if(!isTRUE(active())) {stop_view();return()}
      ctx <- context();if(is.null(ctx)) return()
      notice("Opening the saved Study Area Flowlines and Hydro DEMs...")
      tryCatch({
        value <- load_flowline_points_review(store,ctx)
        if(identical(value$key,loaded_key) && !is.null(review())) return()
        review(value);loaded_key <<- value$key;last_view <<- NULL
        if(!is.null(value$saved)) {
          points(value$saved$points)
          shiny::updateNumericInput(session,"station_distance",
            value=value$saved$station_distance_m)
          notice(paste0("Reopened ",format(value$saved$point_count,big.mark=","),
            " saved Flowline Points for ",value$saved$stream_count,
            " Streams in one Study Area reference frame."))
        } else {
          points(NULL)
          notice("Ready to create one Study Area profile from all saved Reach Flowlines.")
        }
        refreshed(shiny::isolate(refreshed())+1L)
      },error=function(e){loaded_key <<- NULL;review(NULL);points(NULL);
        notice(conditionMessage(e))})
    },ignoreNULL=FALSE)

    shiny::observeEvent(input$create,{
      value <- review();spacing <- as.numeric(input$station_distance)
      if(is.null(value)) return()
      if(length(spacing)!=1L || !is.finite(spacing) || spacing<=0) {
        notice("Maximum point spacing must be one positive value in meters.");return()
      }
      busy(TRUE);on.exit(busy(FALSE),add=TRUE)
      notice("Connecting Streams and sampling their Hydro DEM elevations...")
      tryCatch({
        saved <- shiny::withProgress(message="Creating the Study Area profile",value=0,{
          shiny::incProgress(.1,detail="Connecting tributaries to the outlet Stream")
          result <- fluvgeo::study_area_flowline_points(
            flowlines=lapply(value$bundle,function(x)x$flowline$flowlines),
            dems=lapply(value$bundle,function(x)terra::rast(x$dem)),
            stream_corridors=value$context$streams,
            station_distance=spacing)
          shiny::incProgress(.75,detail="Validating shared kilometer stationing")
          fluvgeo::check_flowline_points(result$points,"fgstudio_replacement")
          shiny::incProgress(.1,detail="Saving the review candidate")
          store$flowline_points_publish(value$context,value$bundle,spacing,
            result$points,result$connections)
        })
        value$saved <- saved;review(value);points(saved$points)
        notice(paste0("Saved ",format(saved$point_count,big.mark=","),
          " Flowline Points across ",saved$stream_count," Streams at ",
          format(saved$station_distance_m,trim=TRUE)," m maximum spacing."))
      },error=function(e) notice(paste("Flowline Points were not created:",
        conditionMessage(e))))
    },ignoreInit=TRUE)

    output$map <- leaflet::renderLeaflet({
      value <- selected()
      map <- leaflet::leaflet(options=leaflet::leafletOptions(maxZoom=23,
        preferCanvas=TRUE)) |>
        leaflet::addMapPane("flowline-points-basemap",zIndex=200) |>
        leaflet::addMapPane("hydro-hillshade",zIndex=300) |>
        leaflet::addMapPane("hydro-elevation",zIndex=350) |>
        leaflet::addMapPane("flowline-points-lines",zIndex=500) |>
        leaflet::addProviderTiles("Esri.WorldImagery",group="Imagery",
          options=leaflet::providerTileOptions(maxNativeZoom=19,maxZoom=23,
            pane="flowline-points-basemap")) |>
        leaflet::addProviderTiles("OpenStreetMap",group="Street map",
          options=leaflet::providerTileOptions(maxNativeZoom=19,maxZoom=23,
            pane="flowline-points-basemap")) |>
        leaflet::hideGroup("Street map") |>
        add_opentopomap(pane="flowline-points-basemap") |>
        leaflet::addLayersControl(baseGroups=c("Imagery","Street map","OpenTopoMap"),
          overlayGroups=c("Elevation","Hillshade","Reach Flowlines","Flowline Points","Confluence","DEM extent"),
          options=leaflet::layersControlOptions(collapsed=TRUE),position="topright") |>
        leaflet::addScaleBar(position="bottomleft")
      if(!is.null(value)) {
        b <- flowline_dem_bounds(value$dem)
        lines <- sf::st_transform(value$flowline$flowlines,4326)
        colors <- grDevices::hcl.colors(max(3,nrow(lines)),"Dark 3")[seq_len(nrow(lines))]
        map <- leaflet::fitBounds(map,b[1],b[2],b[3],b[4]) |>
          leaflet::addRectangles(b[1],b[2],b[3],b[4],group="DEM extent",
            color="#e68a00",weight=2,fill=FALSE,
            options=leaflet::pathOptions(pane="flowline-points-lines")) |>
          leaflet::addPolylines(data=lines,group="Reach Flowlines",color=colors,
            weight=4,opacity=.9,label=lines$ReachName,
            options=leaflet::pathOptions(interactive=FALSE,pane="flowline-points-lines"))
        shown <- shiny::isolate(points())
        if(!is.null(shown)) shown <- shown[shown$stream_id==value$stream_id,]
        shown <- flowline_points_display_sample(shown)
        if(!is.null(shown) && nrow(shown)) map <- leaflet::addCircleMarkers(map,
          data=sf::st_transform(shown,4326),group="Flowline Points",radius=2,
          stroke=FALSE,fillColor="#d7301f",fillOpacity=.9,
          options=leaflet::pathOptions(interactive=FALSE,pane="flowline-points-lines"))
        saved <- shiny::isolate(review())$saved
        if(!is.null(saved)) {
          confluence <- saved$connections[saved$connections$stream_id==value$stream_id,]
          if(nrow(confluence) && !confluence$is_study_outlet)
            map <- leaflet::addCircleMarkers(map,data=sf::st_transform(confluence,4326),
              group="Confluence",radius=6,color="#6f42c1",weight=2,
              fillColor="white",fillOpacity=1,label=paste0("Starts at ",
                round(confluence$confluence_measure_km,3)," km"),
              options=leaflet::pathOptions(pane="flowline-points-lines"))
        }
      }
      htmlwidgets::onRender(map,paste(readLines(system.file("www","hydro-display.js",
        package="fgstudio",mustWork=TRUE),warn=FALSE),collapse="\n"))
    })

    output$profile <- shiny::renderPlot({
      x <- points()
      if(is.null(x) || !nrow(x)) {
        graphics::plot.new();graphics::text(.5,.5,"Create Flowline Points to view the Study Area profile.")
        return()
      }
      streams <- unique(x$stream_id)
      labels <- vapply(streams,function(id)unique(x$stream_name[x$stream_id==id])[1],character(1))
      colors <- stats::setNames(grDevices::hcl.colors(max(3,length(streams)),"Dark 3")[seq_along(streams)],streams)
      graphics::plot(range(x$km_to_mouth),range(x$Z),type="n",
        xlab="Distance upstream from Study Area outlet (km)",
        ylab="Hydro DEM elevation")
      for(stream in streams) {
        rows <- x[x$stream_id==stream,]
        graphics::lines(rows$km_to_mouth,rows$Z,col=colors[stream],lwd=1.5)
        graphics::points(rows$km_to_mouth,rows$Z,pch=16,cex=.14,col=colors[stream])
        starts <- tapply(rows$km_to_mouth,rows$reach_id,min)
        if(length(starts)>1L) graphics::abline(v=starts[-1],col=colors[stream],lty=3)
      }
      graphics::legend("topright",legend=labels,col=colors[streams],lty=1,lwd=2,
        cex=.7,bg="white")
    })

    output$status <- shiny::renderUI(shiny::tagList(
      shiny::p(role="status",notice()),shiny::p(class="small",view_notice()),
      if(busy() || view_busy()) shiny::tags$progress(style="width:100%",
        `aria-label`="FG Studio is creating or displaying Flowline Points")))
    output$summary <- shiny::renderUI({
      x <- points();value <- review()
      if(is.null(x) || is.null(value) || is.null(value$saved)) return(NULL)
      outlet <- value$saved$connections$stream_name[
        value$saved$connections$is_study_outlet][1]
      compact_table(data.frame(Item=c("Saved points","Streams","Reach Flowlines",
        "Study Area outlet","Maximum spacing","Distance range","Legacy fields","Local candidate"),
        Value=c(format(nrow(x),big.mark=","),length(unique(x$stream_id)),
          length(unique(x$reach_id)),outlet,
          paste0(format(value$saved$station_distance_m,trim=TRUE)," m"),
          paste0(round(min(x$km_to_mouth),3)," - ",round(max(x$km_to_mouth),3)," km"),
          "ReachName, POINT_X, POINT_Y, POINT_M, POINT_M_uncalibrated, calibration_diff, Z, km_to_mouth",
          "Saved for the exact Study, Flowline, Hydro DEM, and Stream-connection inputs")))
    })

    bounds <- shiny::debounce(shiny::reactive(input$map_bounds),350)
    shiny::observe({
      shiny::invalidateLater(200,session)
      b <- bounds();value <- selected();refreshed()
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
          fluvgeo::prepare_hydro_dem_view(path,b,directory,cache_directory=display_cache,
            build_cache=FALSE),args=list(path=value$dem,b=b,directory=view_dir,
              display_cache=display_cache))
        view_job <<- list(is_alive=function()
          !identical(unname(view_worker$poll_io(0)["process"]),"ready"),
          get_result=function(){answer<-view_worker$read();if(!is.null(answer$error))
            stop(answer$error);answer$result})
      },error=function(e){stop_view();view_notice(conditionMessage(e))})
    })
    poll <- function(){
      if(!is.null(view_job) && !view_job$is_alive()) {
        job <- view_job;view_job <<- NULL;view_busy(FALSE);finished <- view_dir
        on.exit(unlink(finished,recursive=TRUE),add=TRUE)
        tryCatch({
          v <- job$get_result();value <- shiny::isolate(selected())
          if(is.null(value) || !identical(view_key,
            list(path=value$dem,bounds=shiny::isolate(bounds())))) return()
          proxy <- leaflet::leafletProxy("map",session)
          if(isTRUE(v$empty)) {
            leaflet::clearImages(proxy) |> leaflet::removeControl("elevation-legend")
            view_notice(v$message);return()
          }
          pal <- leaflet::colorNumeric(terrain_palette(),domain=v$limits,
            na.color="transparent")
          proxy <- leaflet::clearImages(proxy) |>
            leaflet::removeControl("elevation-legend") |>
            leaflet::addRasterImage(terra::rast(v$hill),colors=leaflet::colorNumeric(
              "Greys",c(0,255),reverse=TRUE,na.color="transparent"),opacity=1,
              project=FALSE,layerId="hill",group="Hillshade",maxBytes=12*1024^2,
              options=leaflet::gridOptions(pane="hydro-hillshade")) |>
            leaflet::addRasterImage(terra::rast(v$elevation),colors=pal,opacity=1,
              project=FALSE,layerId="elevation",group="Elevation",maxBytes=12*1024^2,
              options=leaflet::gridOptions(pane="hydro-elevation"))
          leaflet::addLegend(proxy,pal=pal,values=v$limits,
            title=paste("Elevation",v$unit),group="Elevation",position="bottomright",
            layerId="elevation-legend")
          view_notice(if(v$native) "Full source-cell detail; display reprojection only." else
            "Overview: zoom closer for source-cell detail.")
        },error=function(e)view_notice(hydro_error_message(e)))
      }
    }
    shiny::observe({shiny::invalidateLater(300,session);poll()})
    session$onSessionEnded(function(){if(!is.null(view_worker))view_worker$kill();
      unlink(cache,recursive=TRUE)})
    list(review=review,points=points,selected=selected,poll=poll)
  })
}
