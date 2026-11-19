flowline_points_review_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(bslib::card_header("Flowline Points"),
    shiny::p("Select a Survey Event from the list. FG Studio creates one-meter Flowline Points automatically after every Stream has saved Reach Flowlines, then displays all Streams and Reaches on the shared profile."),
    shiny::uiOutput(ns("events")),
    shiny::p(class="small fw-semibold mb-1","Stream (select a tab to change the map)"),
    shiny::uiOutput(ns("streams")),
    shiny::uiOutput(ns("status")),
    bslib::layout_columns(col_widths=c(7,5),
      leaflet::leafletOutput(ns("map"),height="600px"),
      bslib::card(bslib::card_header("Study Area longitudinal elevation profile"),
        shiny::plotOutput(ns("profile"),height="520px"))),
    shiny::tags$details(class="small mb-2",
      shiny::tags$summary("Advanced spacing"),
      shiny::numericInput(ns("station_distance"),"Maximum point spacing (meters)",
        value=1,min=.1,step=.1),
      shiny::p("One meter is the FG Studio default. Use this only to replace the saved candidate with a different spacing."),
      shiny::actionButton(ns("create"),"Recreate Flowline Points",
        class="btn-outline-primary btn-sm")),
    shiny::tags$details(class="small mb-2",shiny::tags$summary("Profile details"),
      shiny::uiOutput(ns("summary"))),
    shiny::p(class="small mt-2","Stream tabs change the map. Flowline Points appear when you zoom to inspection scale; only points in the visible window are drawn. The profile always includes every Stream and Reach, measured upstream from the Study Area outlet."))
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
      stop(paste0("Open the Flowline tab for ",stream$stream_name[[1]],
        " so its Reach Flowlines can be created first."))
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

flowline_points_display_sample <- function(points,maximum=1000L) {
  if(is.null(points) || nrow(points)<=maximum) return(points)
  points[unique(round(seq(1,nrow(points),length.out=maximum))),]
}

flowline_points_in_view <- function(points,bounds,zoom,minimum_zoom=17L,
                                    maximum=1000L) {
  if(is.null(points)) return(NULL)
  empty <- points[0,,drop=FALSE]
  b <- unname(unlist(bounds[c("west","south","east","north")]))
  if(length(zoom)!=1L || !is.finite(zoom) || zoom<minimum_zoom ||
      length(b)!=4L || any(!is.finite(b)) || b[1]>=b[3] || b[2]>=b[4])
    return(empty)
  window <- sf::st_as_sfc(sf::st_bbox(c(xmin=b[1],ymin=b[2],
    xmax=b[3],ymax=b[4]),crs=4326))
  local <- sf::st_bbox(sf::st_transform(window,sf::st_crs(points)))
  xy <- sf::st_coordinates(points)
  keep <- xy[,1]>=local[["xmin"]] & xy[,1]<=local[["xmax"]] &
    xy[,2]>=local[["ymin"]] & xy[,2]<=local[["ymax"]]
  flowline_points_display_sample(points[keep,,drop=FALSE],maximum)
}

flowline_points_review_server <- function(id,current,context,store,
                                          active=function() TRUE,events=NULL,
                                          revision=function() 0L) {
  shiny::moduleServer(id,function(input,output,session) {
    review <- shiny::reactiveVal(NULL);points <- shiny::reactiveVal(NULL)
    notice <- shiny::reactiveVal("");busy <- shiny::reactiveVal(FALSE)
    view_notice <- shiny::reactiveVal("");view_busy <- shiny::reactiveVal(FALSE)
    refreshed <- shiny::reactiveVal(0L);last_view <- NULL;view_key <- NULL
    loaded_key <- NULL;view_job <- NULL;view_worker <- NULL;view_dir <- NULL
    load_generation <- 0L;session_closed <- FALSE
    worker_ready <- shiny::reactiveVal(FALSE);worker_warming <- FALSE;worker_failed <- FALSE
    cache <- tempfile("flowline-points-map-");dir.create(cache)
    rem_queue <- list();rem_job <- NULL;rem_current <- NULL;rem_busy <- shiny::reactiveVal(FALSE)
    rem_revision <- shiny::reactiveVal(0L);rem_notice <- shiny::reactiveVal("");rem_failures<-character()
    queue_rems <- function(value) {
      stop_rem()
      rem_failures<<-character()
      rem_queue <<- cross_section_rem_queue(store,value)
      rem_revision(shiny::isolate(rem_revision())+1L)
    }
    stop_rem <- function() {
      if(!is.null(rem_job) && rem_job$is_alive()) {
        rem_job$kill();rem_job$wait(timeout=2000)
        if(!is.null(rem_current))rem_queue <<- c(list(rem_current),rem_queue)
      }
      rem_job <<- NULL;rem_current <<- NULL;rem_busy(FALSE)
    }
    linked_survey_event_selector(input,output,session,events,context)

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
    shiny::observeEvent(input$stream,{
      ctx <- context();stream_id <- input$stream
      fit_stream_map(session,ctx,stream_id)
      session$onFlushed(function() fit_stream_map(session,ctx,stream_id),once=TRUE)
    },ignoreInit=TRUE,priority=10)
    output$streams <- shiny::renderUI({
      ctx <- context()
      if(is.null(ctx)) return(shiny::p("Create a Survey Event before creating Flowline Points."))
      panels <- lapply(seq_len(nrow(ctx$streams)),function(i)
        bslib::nav_panel(ctx$streams$stream_name[i],value=ctx$streams$stream_id[i]))
      do.call(bslib::navset_tab,c(panels,list(id=session$ns("stream"))))
    })

    create_points <- function(value,spacing,automatic=FALSE) {
      if(length(spacing)!=1L || !is.finite(spacing) || spacing<=0)
        stop("Maximum point spacing must be one positive value in meters.")
      busy(TRUE);on.exit(busy(FALSE),add=TRUE)
      notice(if(automatic)
        "Creating the default one-meter Flowline Points..." else
        "Recreating Flowline Points at the selected spacing...")
      saved <- shiny::withProgress(message="Creating Flowline Points",value=0,{
        shiny::incProgress(.1,detail="Connecting tributaries to the outlet Stream")
        result <- fluvgeo::study_area_flowline_points(
          flowlines=lapply(value$bundle,function(x)x$flowline$flowlines),
          dems=lapply(value$bundle,function(x)terra::rast(x$dem)),
          stream_corridors=value$context$streams,station_distance=spacing)
        shiny::incProgress(.75,detail="Validating shared kilometer stationing")
        fluvgeo::check_flowline_points(result$points,"fgstudio_replacement")
        shiny::incProgress(.1,detail="Saving the review candidate")
        store$flowline_points_publish(value$context,value$bundle,spacing,
          result$points,result$connections)
      })
      value$saved <- saved;review(value);points(saved$points)
      queue_rems(value)
      notice(paste0("Saved ",format(saved$point_count,big.mark=","),
        " Flowline Points across ",saved$stream_count," Streams at ",
        format(saved$station_distance_m,trim=TRUE)," m maximum spacing."))
      value
    }

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

    load_review <- function(ctx,key,generation) {
      if(!identical(generation,load_generation) ||
          !isTRUE(shiny::isolate(active()))) return()
      on.exit(if(identical(generation,load_generation)) busy(FALSE),add=TRUE)
      tryCatch({
        value <- load_flowline_points_review(store,ctx)
        if(!identical(generation,load_generation) ||
            !isTRUE(shiny::isolate(active()))) return()
        review(value);loaded_key <<- key
        if(!is.null(value$saved)) {
          points(value$saved$points)
          shiny::updateNumericInput(session,"station_distance",
            value=value$saved$station_distance_m)
          notice("Saved Flowline Points are ready for review and downstream analysis.")
          queue_rems(value)
        } else {
          value <- create_points(value,1,automatic=TRUE)
        }
        refreshed(shiny::isolate(refreshed())+1L)
      },error=function(e){loaded_key <<- NULL;notice(conditionMessage(e))})
    }
    schedule_review_load <- function(ctx,key) {
      load_generation <<- load_generation+1L;generation <- load_generation
      notice("Opening this Survey Event's saved Flowline Points...")
      # Clear the preceding Event immediately, then yield one browser paint so
      # the tab shell and progress cue precede GeoPackage/point reopening.
      review(NULL);points(NULL);last_view <<- NULL;stop_view();view_notice("")
      busy(TRUE)
      session$onFlushed(function() {
        if(session_closed) return()
        later::later(function() {
          if(session_closed) return()
          shiny::withReactiveDomain(session,load_review(ctx,key,generation))
        },.05)
      },once=TRUE)
    }
    shiny::observeEvent(list(context(),active(),revision()),{
      if(!isTRUE(active())) {
        load_generation <<- load_generation+1L;busy(FALSE);stop_view();return()
      }
      ctx <- context();if(is.null(ctx)) return()
      key <- paste(ctx$path,ctx$group_path,shiny::isolate(revision()),sep="\r")
      if(identical(key,loaded_key) && !is.null(review())) return()
      schedule_review_load(ctx,key)
    },ignoreNULL=FALSE)

    shiny::observeEvent(input$create,{
      value <- review();spacing <- as.numeric(input$station_distance)
      if(is.null(value)) return()
      tryCatch({
        create_points(value,spacing)
      },error=function(e) notice(paste("Flowline Points were not created:",
        conditionMessage(e))))
    },ignoreInit=TRUE)
    shiny::observe({
      rem_revision()
      if(!isTRUE(active())) {stop_rem();return()}
      if(!is.null(rem_job)) {
        shiny::invalidateLater(250,session)
        if(rem_job$is_alive())return()
        tryCatch(rem_job$get_result(),error=function(e)rem_failures<<-c(rem_failures,conditionMessage(e)))
        rem_job <<- NULL;rem_current <<- NULL;rem_busy(FALSE)
      }
      if(is.null(review()$saved))return()
      if(!length(rem_queue)) {rem_notice(if(length(rem_failures))
        "Some REM preparations failed; Cross Sections will retry the selected Reach." else
        "Cross-section REMs are precomputed for the saved inputs.");return()}
      if(busy() || view_busy() || !is.null(view_job)) {shiny::invalidateLater(250,session);return()}
      args<-rem_queue[[1]];rem_queue <<- rem_queue[-1];rem_current <<- args
      rem_notice(paste("Precomputing cross-section REM:",args$line$ReachName[1]))
      rem_busy(TRUE)
      rem_job <<- callr::r_bg(cross_section_rem_artifact,args=args,libpath=.libPaths(),supervise=TRUE,stdout=NULL,stderr=NULL)
      shiny::invalidateLater(250,session)
    },priority=20)

    output$map <- leaflet::renderLeaflet({
      value <- selected()
      generation <- refreshed()
      target_bounds <- NULL
      map <- fg_leaflet() |>
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
        target_bounds <- stream_map_bounds(context(),value$stream_id,b)
        lines <- sf::st_transform(value$flowline$flowlines,4326)
        colors <- grDevices::hcl.colors(max(3,nrow(lines)),"Dark 3")[seq_len(nrow(lines))]
        map <- leaflet::fitBounds(map,b[1],b[2],b[3],b[4]) |>
          leaflet::addRectangles(b[1],b[2],b[3],b[4],group="DEM extent",
            color="#e68a00",weight=2,fill=FALSE,
            options=leaflet::pathOptions(pane="flowline-points-lines")) |>
          leaflet::addPolylines(data=lines,group="Reach Flowlines",color=colors,
            weight=4,opacity=.9,label=lines$ReachName,
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
        package="fgstudio",mustWork=TRUE),warn=FALSE),collapse="\n"),
        data=list(bounds=target_bounds,readyInput=session$ns("map_ready"),
          readyToken=if(is.null(value)) NULL else
            paste(value$stream_id,generation,sep=":")))
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
      shiny::p(role="status",notice()),shiny::p(class="small",view_notice()),shiny::p(class="small",rem_notice()),
      if(busy() || view_busy() || rem_busy()) shiny::tags$progress(style="width:100%",
        `aria-label`="FG Studio is preparing Flowline Points or cross-section REMs")))
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
    map_token <- shiny::reactive({
      value <- selected()
      if(is.null(value)) return(NULL)
      paste(value$stream_id,refreshed(),sep=":")
    })
    map_ready <- shiny::reactive({
      ready <- input$map_ready
      !is.null(ready) && identical(ready$token,map_token())
    })
    shiny::observe({
      b <- bounds();zoom <- input$map_zoom;value <- selected();x <- points();refreshed()
      if(!isTRUE(active()) || !isTRUE(map_ready()) || is.null(value) || is.null(b)) return()
      proxy <- leaflet::leafletProxy("map",session) |>
        leaflet::clearGroup("Flowline Points")
      if(is.null(x)) return()
      shown <- x[x$stream_id==value$stream_id,,drop=FALSE]
      shown <- flowline_points_in_view(shown,b,zoom)
      if(nrow(shown)) leaflet::addCircleMarkers(proxy,
        data=sf::st_transform(shown,4326),group="Flowline Points",radius=2,
        stroke=FALSE,fillColor="#d7301f",fillOpacity=.9,
        options=leaflet::pathOptions(interactive=FALSE,pane="flowline-points-lines"))
    })
    shiny::observe({
      shiny::invalidateLater(200,session)
      b <- bounds();value <- selected();token <- map_token()
      if(!isTRUE(active()) || !isTRUE(map_ready()) || is.null(value) ||
          !valid_map_bounds(b)) return()
      if(rem_busy())return()
      signature <- list(path=value$dem,bounds=b,map=token)
      if(identical(signature,last_view)) return()
      if(!worker_ready()) {if(!worker_failed){view_notice("Opening DEM viewer...");view_busy(TRUE)};return()}
      if(!is.null(view_job) || !identical(view_worker$get_state(),"idle")) return()
      stop_view();view_key <<- signature
      view_dir <<- tempfile("view-",cache);dir.create(view_dir)
      view_notice("Loading elevation detail...");view_busy(TRUE)
      tryCatch({
        display_cache <- file.path(dirname(shiny::isolate(current())$path),"terrain-display")
        view_worker$call(function(path,b,directory,display_cache,source_id)
          fluvgeo::prepare_hydro_dem_view(path,b,directory,cache_directory=display_cache,
            build_cache=FALSE,source_id=source_id),args=list(path=value$dem,b=b,
              directory=view_dir,display_cache=display_cache,
              source_id=value$record$result$output_sha256))
        view_job <<- list(is_alive=function()
          !identical(unname(view_worker$poll_io(0)["process"]),"ready"),
          get_result=function(){answer<-view_worker$read();if(!is.null(answer$error))
            stop(answer$error);answer$result})
      },error=function(e){view_key <<- NULL;stop_view();view_notice(conditionMessage(e))})
    })
    poll <- function(){
      if(!is.null(view_job) && !view_job$is_alive()) {
        job <- view_job;view_job <<- NULL;view_busy(FALSE);finished <- view_dir
        on.exit(unlink(finished,recursive=TRUE),add=TRUE)
        tryCatch({
          v <- job$get_result();value <- shiny::isolate(selected())
          current_key <- if(is.null(value)) NULL else list(path=value$dem,
            bounds=shiny::isolate(bounds()),map=shiny::isolate(map_token()))
          if(!isTRUE(shiny::isolate(map_ready())) ||
              !identical(view_key,current_key)) {view_key <<- NULL;return()}
          proxy <- leaflet::leafletProxy("map",session)
          if(isTRUE(v$empty)) {
            leaflet::clearImages(proxy) |> leaflet::removeControl("elevation-legend")
            last_view <<- view_key;view_key <<- NULL;view_notice(v$message);return()
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
          last_view <<- view_key;view_key <<- NULL
          view_notice(if(v$native) "Full source-cell detail; display reprojection only." else
            "Overview: zoom closer for source-cell detail.")
        },error=function(e){view_key <<- NULL;view_notice(hydro_error_message(e))})
      }
    }
    shiny::observe({shiny::invalidateLater(300,session);poll()})
    session$onSessionEnded(function(){
      session_closed <<- TRUE
      stop_rem();if(!is.null(view_worker))view_worker$kill();unlink(cache,recursive=TRUE)
    })
    list(review=review,points=points,selected=selected,poll=poll,
      loaded_inputs=shiny::reactive(list(value=review(),key=loaded_key)))
  })
}
