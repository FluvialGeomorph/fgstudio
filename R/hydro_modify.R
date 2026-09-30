hydro_modify_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(bslib::card_header("Hydro Modify"),
    shiny::p("The first Survey Event opens by default; a choice made in Survey Events carries through here. Scan each Stream for flow blockages, then draw a cutline across each blockage, extending to lower channel elevations on both sides."),
    shiny::uiOutput(ns("streams")),shiny::uiOutput(ns("status")),
    shiny::div(class="d-flex gap-3 flex-wrap align-items-center",
      shiny::radioButtons(ns("surface"),NULL,c("Original DEM"="original","Hydro-modified DEM"="hydro"),inline=TRUE),
      shiny::actionButton(ns("apply"),"Apply cutlines",class="btn-primary"),
      shiny::actionButton(ns("return_stream"),"Return to Stream",class="btn-outline-secondary")),
    shiny::p(class="small","Each cutline lowers its intersected cells to their minimum elevation, without widening. Original DEMs and previous cutline revisions are retained."),
    leaflet::leafletOutput(ns("map"),height="650px"),
    shiny::p(class="small","Zoom in until drawing is enabled, then pan along the channel. Use the line tool to draw; double-click to finish. Use the edit/delete tools to revise cutlines. Completed drawings save automatically. Colors stretch to elevations in the current view; hillshade reveals relief."))
}

hydro_modify_server <- function(id,current,context,store,active=function() TRUE,
  launch_burn=launch_hydro_burn) {
  shiny::moduleServer(id,function(input,output,session) {
    source <- shiny::reactiveVal(NULL); record <- shiny::reactiveVal(NULL)
    notice <- shiny::reactiveVal(""); view_notice <- shiny::reactiveVal("")
    native <- shiny::reactiveVal(FALSE); refreshed <- shiny::reactiveVal(0L)
    view_job <- NULL; view_worker <- NULL; view_dir <- NULL; burn_job <- NULL; burn_dir <- NULL; burn_record <- NULL
    worker_ready <- shiny::reactiveVal(FALSE); worker_warming <- FALSE; worker_failed <- FALSE
    burn_source <- NULL;burn_context <- NULL
    view_key <- NULL; last_view <- NULL
    cache <- tempfile("hydro-map-");dir.create(cache)
    # Start and load the display worker while the selected Event is being used,
    # before the analyst opens Hydro Modify or the browser supplies map bounds.
    shiny::observe({
      shiny::invalidateLater(200,session)
      if(worker_ready() || worker_failed || is.null(context())) return()
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
          answer <- view_worker$read()
          if(!is.null(answer$error)) stop(answer$error)
          worker_ready(TRUE);worker_warming <<- FALSE
        } else if(identical(view_worker$get_state(),"idle")) {
          view_worker$call(function() {loadNamespace("fluvgeo");loadNamespace("terra");loadNamespace("sf");NULL})
          worker_warming <<- TRUE
        }
      },error=function(e) {worker_failed <<- TRUE;view_notice(hydro_error_message(e))})
    })
    stop_view <- function() {
      # Let an in-flight cache build finish; discard its display if selection changed.
      native(FALSE)
    }
    stop_burn <- function() {
      if(!is.null(burn_job)) {if(burn_job$is_alive()) burn_job$kill();burn_job <<- NULL}
      if(!is.null(burn_dir)) unlink(burn_dir,recursive=TRUE)
      burn_dir <<- NULL;burn_record <<- NULL;burn_source <<- NULL;burn_context <<- NULL
    }
    fit_stream <- function() {
      dem <- shiny::isolate(source());if(is.null(dem)) return()
      b <- hydro_dem_bounds(dem)
      leaflet::fitBounds(leaflet::leafletProxy("map",session),b[1],b[2],b[3],b[4])
    }
    shiny::observeEvent(input$return_stream,fit_stream(),ignoreInit=TRUE)
    output$streams <- shiny::renderUI({
      ctx <- context()
      if(is.null(ctx)) return(shiny::p("Create a Survey Event in Survey Events, or finish any pending settings or source-selection edits."))
      panels <- lapply(seq_len(nrow(ctx$streams)),function(i)
        bslib::nav_panel(ctx$streams$stream_name[i],value=ctx$streams$stream_id[i]))
      shiny::tagList(if(!is.null(ctx$event_label)) shiny::p(shiny::strong(paste("Survey Event:",ctx$event_label))),
        do.call(bslib::navset_tab,c(panels,list(id=session$ns("stream")))) )
    })
    output$map <- leaflet::renderLeaflet({
      dem <- source()
      map <- leaflet::leaflet(options=leaflet::leafletOptions(maxZoom=23)) |>
        leaflet::addMapPane("hydro-basemap",zIndex=200) |>
        leaflet::addMapPane("hydro-hillshade",zIndex=300) |>
        leaflet::addMapPane("hydro-elevation",zIndex=350) |>
        leaflet::addProviderTiles("Esri.WorldImagery",group="Imagery",options=leaflet::providerTileOptions(maxNativeZoom=19,maxZoom=23,pane="hydro-basemap")) |>
        leaflet::addProviderTiles("OpenStreetMap",group="Street map",options=leaflet::providerTileOptions(maxNativeZoom=19,maxZoom=23,pane="hydro-basemap")) |>
        leaflet::hideGroup("Street map") |>
        add_opentopomap(pane="hydro-basemap") |>
        leaflet::addLayersControl(baseGroups=c("Imagery","Street map","OpenTopoMap"),
          overlayGroups=c("Elevation","Hillshade","Cutlines","DEM extent"),
          options=leaflet::layersControlOptions(collapsed=TRUE),position="topright") |>
        leaflet::addScaleBar(position="bottomleft") |>
        leaflet.extras::addDrawToolbar(targetGroup="Cutlines",polylineOptions=FALSE,
          polygonOptions=FALSE,rectangleOptions=FALSE,circleOptions=FALSE,markerOptions=FALSE,
          circleMarkerOptions=FALSE,editOptions=leaflet.extras::editToolbarOptions(edit=FALSE,remove=FALSE))
      if(!is.null(dem)) {
        b <- hydro_dem_bounds(dem)
        map <- leaflet::fitBounds(map,b[1],b[2],b[3],b[4]) |>
          leaflet::addRectangles(b[1],b[2],b[3],b[4],group="DEM extent",color="#e68a00",weight=2,fill=FALSE)
        saved <- shiny::isolate(record())
        if(!is.null(saved) && nrow(saved$lines)) map <- leaflet::addPolylines(map,data=saved$lines,
          group="Cutlines",layerId=as.character(saved$lines$cutline_id),label=paste("Cutline",saved$lines$cutline_id),color="#ff00ff",weight=3)
      }
      htmlwidgets::onRender(map,paste(readLines(system.file("www","hydro-display.js",
        package="fgstudio",mustWork=TRUE),warn=FALSE),collapse="\n"))
    })
    selected <- shiny::reactive({
      ctx <- context();if(is.null(ctx) || length(input$stream)!=1L || !input$stream %in% ctx$streams$stream_id) return(NULL)
      list(key=ctx$key,event=ctx$group_id,stream=input$stream,path=ctx$path,group=ctx$group_path)
    })
    shiny::observeEvent(list(selected(),active()),{
      if(!isTRUE(active())) {stop_view();return()}
      s <- selected();stop_view();stop_burn();source(NULL);record(NULL);native(FALSE);last_view <<- NULL
      # source() recreates the widget, discarding the old editable group itself.
      # A queued proxy clear can arrive AFTER that replacement and erase the
      # saved cutlines just restored by renderLeaflet().
      if(is.null(s)) return()
      tryCatch({
        binding <- store$dem_request(s$key,s$event,s$path,s$group)
        dem <- store$find_dem(binding,stream_id=s$stream,scope="stream")
        drawing <- store$hydro_read(s$key,s$event,s$stream,NULL)
        if(!is.null(drawing)) {
          pinned <- store$find_dem(binding,stream_id=s$stream,scope="stream",edition_id=drawing$source)
          if(identical(pinned$saved_dem$id,drawing$source)) dem <- pinned
        }
        if(is.null(dem)) stop("Build this Stream's DEM in Survey Events first.")
        if(isTRUE(dem$use_saved_sources) && !identical(dem$source_selection,
          terrain_dem_sources(store,s$key,s$event,s$stream,s$path,s$group)))
          stop("Source selections changed. Review this Stream's DEM in Survey Events first.")
        source(dem)
        saved <- store$hydro_read(s$key,s$event,s$stream,dem$saved_dem$id);record(saved)
        if(is.null(saved$result)) shiny::updateRadioButtons(session,"surface",selected="original")
        notice(if(is.null(saved)) "No cutlines saved for this DEM." else paste(nrow(saved$lines),"saved cutlines."))
        refreshed(shiny::isolate(refreshed())+1L)
      },error=function(e) notice(conditionMessage(e)))
    },ignoreNULL=FALSE)
    surface <- shiny::reactive({
      dem <- source();if(is.null(dem)) return(NULL)
      if(identical(input$surface,"hydro")) {
        rec <- record();if(is.null(rec$result)) return(NULL)
        return(file.path(rec$path,rec$result$file))
      }
      dem$result$path
    })
    bounds <- shiny::debounce(shiny::reactive(input$map_bounds),350)
    shiny::observe({
      shiny::invalidateLater(200,session)
      b <- bounds();path <- surface();refreshed()
      if(!isTRUE(active()) || is.null(path) || !valid_map_bounds(b)) {
        native(FALSE)
        if(isTRUE(active()) && is.null(path)) {
          leaflet::clearImages(leaflet::leafletProxy("map",session))
          view_notice(if(identical(input$surface,"hydro")) "Apply saved cutlines first, or select Original DEM." else "Select a Survey Event and Stream with a saved DEM.")
        }
        return()
      }
      signature <- list(path=path,bounds=b)
      if(identical(signature,last_view)) return()
      if(!worker_ready()) {if(!worker_failed) view_notice("Opening DEM viewer...");return()}
      if(!is.null(view_job) || !identical(view_worker$get_state(),"idle")) return()
      last_view <<- signature;stop_view();native(FALSE);view_key <<- signature
      view_dir <<- tempfile("view-",cache);dir.create(view_dir)
      view_notice("Loading elevation detail...")
      tryCatch({
        display_cache <- file.path(dirname(shiny::isolate(current())$path),"terrain-display")
        view_worker$call(function(path,b,directory,display_cache)
          fluvgeo::prepare_hydro_dem_view(path,b,directory,cache_directory=display_cache,build_cache=FALSE),
          args=list(path=path,b=b,directory=view_dir,display_cache=display_cache))
        view_job <<- list(is_alive=function() !identical(unname(view_worker$poll_io(0)["process"]),"ready"),
          get_result=function() {answer <- view_worker$read();if(!is.null(answer$error)) stop(answer$error);answer$result})
      },error=function(e) view_notice(conditionMessage(e)))
    })
    draw_ready <- shiny::reactive({
      z <- input$map_zoom;b <- input$map_bounds;r <- source()
      if(is.null(z) || !valid_map_bounds(b) || is.null(r)) return(FALSE)
      # At least two screen pixels per source cell, using ground resolution.
      spacing <- min(r$result$resolution)
      if(!is.null(r$horizontal_unit) && r$horizontal_unit %in% c("foot","feet","ft")) spacing <- spacing*.3048
      isTRUE(active()) && isTRUE(native()) &&
        156543.03392*cos((b$north+b$south)/2*pi/180)/2^z <= spacing/2
    })
    shiny::observe({
      ready <- draw_ready()
      proxy <- leaflet::leafletProxy("map",session)
      leaflet.extras::removeDrawToolbar(proxy,clearFeatures=FALSE)
      if(ready) leaflet.extras::addDrawToolbar(proxy,targetGroup="Cutlines",singleFeature=FALSE,
        polylineOptions=leaflet.extras::drawPolylineOptions(shapeOptions=leaflet.extras::drawShapeOptions(color="#ff00ff")),
        polygonOptions=FALSE,rectangleOptions=FALSE,circleOptions=FALSE,markerOptions=FALSE,
        circleMarkerOptions=FALSE,editOptions=leaflet.extras::editToolbarOptions())
    })
    shiny::observeEvent(input$map_draw_all_features,{
      if(!draw_ready()) return()
      s <- selected();dem <- source();if(is.null(s) || is.null(dem)) return()
      tryCatch({
        lines <- hydro_drawn_lines(input$map_draw_all_features)
        saved <- store$hydro_save(s$key,s$event,s$stream,dem$saved_dem$id,lines,
          expected=record()$id,context=s$path)
        stop_burn();record(saved)
        shiny::updateRadioButtons(session,"surface",selected="original")
        notice(paste(nrow(lines),"cutlines saved."))
      },error=function(e) notice(paste("Cutlines were not saved:",conditionMessage(e))))
    },ignoreInit=TRUE)
    output$status <- shiny::renderUI(shiny::tagList(
      shiny::p(role="status",notice()),shiny::p(class="small",view_notice()),
      if(!is.null(source())) shiny::p(class=if(draw_ready()) "text-success" else "text-body-secondary",
        if(draw_ready()) "Fine-scale inspection: cutline drawing is enabled." else "Zoom in further and wait for elevation detail to enable cutline drawing.")))
    shiny::observeEvent(input$apply,{
      if(!is.null(burn_job)) return()
      tryCatch({
        rec <- record();dem <- source()
        if(is.null(rec) || !nrow(rec$lines) || is.null(dem)) stop("Draw at least one cutline first.")
        if(!is.null(rec$result)) {
          shiny::updateRadioButtons(session,"surface",selected="hydro")
          notice("Showing the saved hydro-modified DEM.");return()
        }
        burn_record <<- rec;burn_source <<- dem;burn_context <<- selected();burn_dir <<- store$hydro_prepare(rec)
        burn_job <<- launch_burn(dem$result$path,rec$lines,file.path(burn_dir,"hydro-dem.tif"))
        notice("Applying cutlines. You can continue inspecting the map.")
      },error=function(e) {stop_burn();notice(conditionMessage(e))})
    },ignoreInit=TRUE)
    session$onSessionEnded(function() {
      if(!is.null(view_worker)) view_worker$kill()
      stop_burn();unlink(cache,recursive=TRUE)
    })
    poll <- function() {
      if(!is.null(burn_job) && !burn_job$is_alive()) {
        job <- burn_job;burn_job <<- NULL
        tryCatch({
          result <- job$get_result();s <- shiny::isolate(selected())
          if(!identical(s,burn_context)) stop("Study, Survey Event or Stream changed while applying cutlines.")
          rec <- shiny::isolate(record())
          if(!identical(rec$id,burn_record$id)) stop("Cutlines changed; apply the current drawing.")
          binding <- store$dem_request(s$key,s$event,s$path,s$group)
          latest <- burn_source
          if(!identical(shiny::isolate(source())$saved_dem$id,burn_record$source)) stop("Displayed DEM changed; reopen this Stream.")
          if(isTRUE(latest$use_saved_sources) && !identical(latest$source_selection,
            terrain_dem_sources(store,s$key,s$event,s$stream,s$path,s$group)))
            stop("Source selections changed; review the DEM in Survey Events.")
          result$source_execution <- latest$execution
          saved <- store$hydro_publish(burn_record,burn_dir,result)
          record(saved);burn_dir <<- NULL;burn_record <<- NULL
          shiny::updateRadioButtons(session,"surface",selected="hydro")
          notice("Hydro-modified DEM saved. Switch between Original DEM and Hydro-modified DEM to review the cuts.")
          if(length(result$skipped_nodata_cutlines)) notice(paste0("Hydro-modified DEM saved. Cutline(s) ",
            paste(result$skipped_nodata_cutlines,collapse=", ")," were not applied: no elevation cells in this Stream DEM. Hover over cutlines to identify them; choose the correct Stream or edit those lines."))
        },error=function(e) {stop_burn();notice(paste("Hydro modification failed:",hydro_error_message(e)))})
      }
      if(!is.null(view_job) && !view_job$is_alive()) {
        job <- view_job;view_job <<- NULL
        finished_directory <- view_dir
        on.exit(unlink(finished_directory,recursive=TRUE),add=TRUE)
        tryCatch({
          v <- job$get_result()
          if(!identical(view_key,list(path=shiny::isolate(surface()),bounds=shiny::isolate(bounds())))) return()
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
          leaflet::addLegend(proxy,pal=pal,values=v$limits,title=paste("Elevation",v$unit),group="Elevation",position="bottomright",layerId="elevation-legend")
          native(v$native);view_notice(if(v$native) "Full source-cell detail; display reprojection only." else "Overview: zoom closer for source-cell detail.")
        },error=function(e) {native(FALSE);view_notice(hydro_error_message(e))})
      }
    }
    shiny::observe({shiny::invalidateLater(300,session);poll()})
    list(source=source,record=record,draw_ready=draw_ready)
  })
}

launch_hydro_burn <- function(source,lines,filename) {
  callr::r_bg(function(source,lines,filename) fluvgeo::burn_hydro_cutlines(source,lines,filename),
    args=list(source=source,lines=lines,filename=filename),libpath=.libPaths(),supervise=TRUE,
    stdout=NULL,stderr=NULL,user_profile=FALSE,system_profile=FALSE)
}

hydro_error_message <- function(error) {
  while(inherits(error$parent,"condition")) error <- error$parent
  conditionMessage(error)
}

hydro_dem_bounds <- function(dem) {
  r <- terra::rast(dem$result$path);e <- unname(as.vector(terra::ext(r)))
  b <- sf::st_bbox(c(xmin=e[1],ymin=e[3],xmax=e[2],ymax=e[4]),crs=sf::st_crs(terra::crs(r)))
  unname(sf::st_transform(b,4326))
}
