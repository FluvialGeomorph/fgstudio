hydro_modify_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(bslib::card_header("Hydro Modify"),
    shiny::p("Choose a Survey Event and Stream. Inspect road crossings and other false flow barriers, and draw cutlines only where water should pass. When the Hydro DEM routes correctly, extract its Stream Network."),
    shiny::uiOutput(ns("events")),shiny::uiOutput(ns("streams")),shiny::uiOutput(ns("status")),
    shiny::div(class="d-flex gap-3 flex-wrap align-items-center",
      shiny::radioButtons(ns("surface"),NULL,c("Original DEM"="original","Hydro-modified DEM"="hydro"),inline=TRUE),
      shiny::uiOutput(ns("apply_control"))),
    shiny::p(class="small","Each cutline lowers its intersected cells to their minimum elevation, without widening. Original DEMs and previous cutline revisions are retained."),
    leaflet::leafletOutput(ns("map"),height="650px"),
    shiny::p(class="small","Zoom in until drawing is enabled, then pan along the channel. Use the line tool to draw; double-click to finish. Use the edit/delete tools to revise cutlines. Completed drawings save automatically. Colors stretch to elevations in the current view; hillshade reveals relief."),
    bslib::card(bslib::card_header("Synthetic Stream"),
      shiny::p("Extract a first-cut terrain-derived stream network from the saved Hydro DEM. Review the line against the terrain before proceeding."),
      shiny::div(class="d-flex gap-3 flex-wrap align-items-end",
        shiny::numericInput(ns("threshold_ha"),"Initiation area (hectares)",value=1,min=.01,step=.1,width="15rem"),
        shiny::actionButton(ns("extract_stream"),"Extract stream network",class="btn-primary")),
      shiny::uiOutput(ns("stream_status"))))
}

hydro_modify_server <- function(id,current,context,store,active=function() TRUE,
  events=NULL,on_changed=function() NULL,
  launch_burn=launch_hydro_burn,launch_passthrough=launch_hydro_passthrough,
  launch_extract=launch_stream_extraction,
  launch_threshold=launch_stream_threshold) {
  shiny::moduleServer(id,function(input,output,session) {
    source <- shiny::reactiveVal(NULL); record <- shiny::reactiveVal(NULL)
    network <- shiny::reactiveVal(NULL); stream_notice <- shiny::reactiveVal("")
    notice <- shiny::reactiveVal(""); view_notice <- shiny::reactiveVal("")
    stream_busy <- shiny::reactiveVal(FALSE);burn_busy <- shiny::reactiveVal(FALSE)
    view_busy <- shiny::reactiveVal(FALSE)
    native <- shiny::reactiveVal(FALSE); refreshed <- shiny::reactiveVal(0L)
    view_job <- NULL; view_worker <- NULL; view_dir <- NULL; burn_job <- NULL; burn_dir <- NULL; burn_record <- NULL
    stream_job <- NULL; stream_dir <- NULL; stream_record <- NULL; stream_context <- NULL
    worker_ready <- shiny::reactiveVal(FALSE); worker_warming <- FALSE; worker_failed <- FALSE
    burn_source <- NULL;burn_context <- NULL;burn_passthrough <- FALSE
    burn_continue_stream <- FALSE;burn_threshold <- NULL
    view_key <- NULL; last_view <- NULL; loaded_key <- NULL
    cache <- tempfile("hydro-map-");dir.create(cache)
    linked_survey_event_selector(input,output,session,events,context)
    # Do not compete with initial Study restoration. Start the display worker
    # when Hydro Modify is actually opened, before browser bounds are processed.
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
          answer <- view_worker$read()
          if(!is.null(answer$error)) stop(answer$error)
          worker_ready(TRUE);worker_warming <<- FALSE
        } else if(identical(view_worker$get_state(),"idle")) {
          view_worker$call(function() {loadNamespace("fluvgeo");loadNamespace("terra");loadNamespace("sf");NULL})
          worker_warming <<- TRUE
        }
      },error=function(e) {worker_failed <<- TRUE;view_busy(FALSE);view_notice(hydro_error_message(e))})
    })
    stop_view <- function() {
      # Let an in-flight cache build finish; discard its display if selection changed.
      native(FALSE)
      view_busy(FALSE)
    }
    stop_burn <- function() {
      if(!is.null(burn_job)) {if(burn_job$is_alive()) burn_job$kill();burn_job <<- NULL}
      if(!is.null(burn_dir)) unlink(burn_dir,recursive=TRUE)
      burn_dir <<- NULL;burn_record <<- NULL;burn_source <<- NULL;burn_context <<- NULL
      burn_passthrough <<- FALSE;burn_continue_stream <<- FALSE;burn_threshold <<- NULL
      burn_busy(FALSE)
    }
    stop_stream <- function() {
      if(!is.null(stream_job)) {if(stream_job$is_alive()) stream_job$kill();stream_job <<- NULL}
      if(!is.null(stream_dir)) try(store$stream_network_discard(stream_dir),silent=TRUE)
      stream_dir <<- NULL;stream_record <<- NULL;stream_context <<- NULL
      stream_busy(FALSE)
    }
    output$streams <- shiny::renderUI({
      ctx <- context()
      if(is.null(ctx)) return(shiny::p("Create a Survey Event in Survey Events, or finish any pending settings or source-selection edits."))
      panels <- lapply(seq_len(nrow(ctx$streams)),function(i)
        bslib::nav_panel(ctx$streams$stream_name[i],value=ctx$streams$stream_id[i]))
      do.call(bslib::navset_tab,c(panels,list(id=session$ns("stream"))))
    })
    output$map <- leaflet::renderLeaflet({
      dem <- source()
      candidate <- network()
      target_bounds <- NULL
      map <- leaflet::leaflet(options=leaflet::leafletOptions(maxZoom=23)) |>
        leaflet::addMapPane("hydro-basemap",zIndex=200) |>
        leaflet::addMapPane("hydro-hillshade",zIndex=300) |>
        leaflet::addMapPane("hydro-elevation",zIndex=350) |>
        leaflet::addProviderTiles("Esri.WorldImagery",group="Imagery",options=leaflet::providerTileOptions(maxNativeZoom=19,maxZoom=23,pane="hydro-basemap")) |>
        leaflet::addProviderTiles("OpenStreetMap",group="Street map",options=leaflet::providerTileOptions(maxNativeZoom=19,maxZoom=23,pane="hydro-basemap")) |>
        leaflet::hideGroup("Street map") |>
        add_opentopomap(pane="hydro-basemap") |>
        leaflet::addLayersControl(baseGroups=c("Imagery","Street map","OpenTopoMap"),
          overlayGroups=c("Elevation","Hillshade","Synthetic stream","Cutlines","DEM extent"),
          options=leaflet::layersControlOptions(collapsed=TRUE),position="topright") |>
        leaflet::addScaleBar(position="bottomleft") |>
        leaflet.extras::addDrawToolbar(targetGroup="Cutlines",polylineOptions=FALSE,
          polygonOptions=FALSE,rectangleOptions=FALSE,circleOptions=FALSE,markerOptions=FALSE,
          circleMarkerOptions=FALSE,editOptions=leaflet.extras::editToolbarOptions(edit=FALSE,remove=FALSE))
      if(!is.null(dem)) {
        b <- hydro_dem_bounds(dem)
        target_bounds <- stream_map_bounds(context(),input$stream,b)
        map <- leaflet::fitBounds(map,b[1],b[2],b[3],b[4]) |>
          leaflet::addRectangles(b[1],b[2],b[3],b[4],group="DEM extent",color="#e68a00",weight=2,fill=FALSE)
        saved <- shiny::isolate(record())
        if(!is.null(saved) && nrow(saved$lines)) map <- leaflet::addPolylines(map,data=saved$lines,
          group="Cutlines",layerId=as.character(saved$lines$cutline_id),label=paste("Cutline",saved$lines$cutline_id),color="#ff00ff",weight=3)
        if(!is.null(candidate)) {
          lines <- sf::st_read(file.path(candidate$path,candidate$files$stream_network),quiet=TRUE)
          map <- leaflet::addPolylines(map,data=sf::st_transform(lines,4326),group="Synthetic stream",color="#00d5ff",
            weight=4,opacity=.95,label=paste0("Terrain-derived stream; threshold ",candidate$threshold_ha," ha"))
        }
      }
      htmlwidgets::onRender(map,paste(readLines(system.file("www","hydro-display.js",
        package="fgstudio",mustWork=TRUE),warn=FALSE),collapse="\n"),
        data=list(bounds=target_bounds))
    })
    selected <- shiny::reactive({
      ctx <- context();if(is.null(ctx) || length(input$stream)!=1L || !input$stream %in% ctx$streams$stream_id) return(NULL)
      list(key=ctx$key,event=ctx$group_id,stream=input$stream,path=ctx$path,group=ctx$group_path)
    })
    shiny::observeEvent(input$stream,{
      ctx <- context();stream_id <- input$stream
      fit_stream_map(session,ctx,stream_id)
      session$onFlushed(function() fit_stream_map(session,ctx,stream_id),once=TRUE)
    },ignoreInit=TRUE,priority=10)
    shiny::observeEvent(network(),shiny::updateActionButton(session,"extract_stream",
      label=if(is.null(network())) "Extract stream network" else "Update stream threshold"),
      ignoreNULL=FALSE)
    shiny::observeEvent(list(selected(),active()),{
      if(!isTRUE(active())) {stop_view();return()}
      s <- selected()
      if(is.null(s)) return()
      key <- paste(s$key,s$event,s$stream,s$path,s$group,sep="\r")
      if(identical(key,loaded_key) && !is.null(source())) return()
      stop_view();stop_burn();stop_stream();source(NULL);record(NULL);network(NULL);native(FALSE);last_view <<- NULL
      # source() recreates the widget, discarding the old editable group itself.
      # A queued proxy clear can arrive AFTER that replacement and erase the
      # saved cutlines just restored by renderLeaflet().
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
        candidate <- if(!is.null(saved) && !is.null(saved$result)) store$stream_network_read(saved) else NULL
        network(candidate)
        shiny::updateNumericInput(session,"threshold_ha",value=if(is.null(candidate)) 1 else candidate$threshold_ha)
        if(is.null(saved$result)) shiny::updateRadioButtons(session,"surface",selected="original")
        notice(if(is.null(saved)) "No cutlines saved for this DEM." else paste(nrow(saved$lines),"saved cutlines."))
        stream_notice(if(is.null(candidate)) "No synthetic stream has been extracted from this Hydro DEM." else
          paste0("Saved candidate: ",candidate$stream_lines," lines, ",format(round(candidate$stream_length_m),big.mark=","),
            " m at ",candidate$threshold_ha," ha."))
        loaded_key <<- key
        refreshed(shiny::isolate(refreshed())+1L)
      },error=function(e) {loaded_key <<- NULL;notice(conditionMessage(e))})
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
      if(!worker_ready()) {if(!worker_failed) {view_notice("Opening DEM viewer...");view_busy(TRUE)};return()}
      if(!is.null(view_job) || !identical(view_worker$get_state(),"idle")) return()
      last_view <<- signature;stop_view();native(FALSE);view_key <<- signature
      view_dir <<- tempfile("view-",cache);dir.create(view_dir)
      view_notice("Loading elevation detail...")
      view_busy(TRUE)
      tryCatch({
        display_cache <- file.path(dirname(shiny::isolate(current())$path),"terrain-display")
        view_worker$call(function(path,b,directory,display_cache)
          fluvgeo::prepare_hydro_dem_view(path,b,directory,cache_directory=display_cache,build_cache=FALSE),
          args=list(path=path,b=b,directory=view_dir,display_cache=display_cache))
        view_job <<- list(is_alive=function() !identical(unname(view_worker$poll_io(0)["process"]),"ready"),
          get_result=function() {answer <- view_worker$read();if(!is.null(answer$error)) stop(answer$error);answer$result})
      },error=function(e) {view_busy(FALSE);view_notice(conditionMessage(e))})
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
        stop_burn();stop_stream();record(saved);network(NULL)
        on_changed()
        shiny::updateRadioButtons(session,"surface",selected="original")
        notice(paste(nrow(lines),"cutlines saved."))
      },error=function(e) notice(paste("Cutlines were not saved:",conditionMessage(e))))
    },ignoreInit=TRUE)
    output$status <- shiny::renderUI(shiny::tagList(
      shiny::p(role="status",notice()),shiny::p(class="small",view_notice()),
      if(burn_busy() || view_busy()) shiny::tags$progress(style="width:100%",
        `aria-label`=if(burn_busy()) "Applying cutlines" else "Loading terrain display"),
      if(!is.null(source())) shiny::p(class=if(draw_ready()) "text-success" else "text-body-secondary",
        if(draw_ready()) "Fine-scale inspection: cutline drawing is enabled." else "Zoom in further and wait for elevation detail to enable cutline drawing.")))
    output$apply_control <- shiny::renderUI({
      rec <- record()
      if(is.null(rec) || is.null(rec$lines) || !nrow(rec$lines) ||
          !is.null(rec$result) || burn_busy()) return(NULL)
      count <- nrow(rec$lines)
      shiny::actionButton(session$ns("apply"),paste0("Apply ",count," saved cutline",
        if(count==1) "" else "s"," to DEM"),class="btn-primary")
    })
    output$stream_status <- shiny::renderUI({
      rec <- record();candidate <- network()
      shiny::tagList(shiny::p(role="status",stream_notice()),
        if(stream_busy()) shiny::tags$progress(style="width:100%",`aria-label`="Extracting stream network"),
        if(!is.null(candidate)) shiny::p(class="small",
          "Cyan lines are the extracted candidate. The Hydro DEM remains unchanged."),
        if(is.null(rec)) shiny::p(class="small text-body-secondary",
          "No cutlines are saved. Extraction will use the original Stream DEM unchanged.")
        else if(is.null(rec$result) && nrow(rec$lines)) shiny::p(class="small text-body-secondary",
          "Apply the saved cutlines before extracting a stream network.")
        else if(is.null(rec$result)) shiny::p(class="small text-body-secondary",
          "Extraction will preserve the original Stream DEM."))
    })
    begin_hydro <- function(rec,dem,s,passthrough=FALSE,
                            continue_stream=FALSE,threshold=NULL) {
      burn_record <<- rec;burn_source <<- dem;burn_context <<- s
      burn_passthrough <<- passthrough;burn_continue_stream <<- continue_stream
      burn_threshold <<- threshold;burn_dir <<- store$hydro_prepare(rec)
      filename <- file.path(burn_dir,"hydro-dem.tif")
      burn_job <<- if(passthrough) launch_passthrough(dem$result$path,filename) else
        launch_burn(dem$result$path,rec$lines,filename)
      burn_busy(TRUE)
      notice(if(passthrough)
        "Preparing the unchanged Stream DEM for extraction..." else
        "Applying the saved cutlines. You can continue inspecting the map.")
    }
    begin_stream <- function(rec,s,threshold) {
      stream_record <<- rec;stream_context <<- s
      stream_dir <<- store$stream_network_prepare(rec)
      candidate <- shiny::isolate(network())
      if(!is.null(candidate)) {
        if(isTRUE(all.equal(threshold,candidate$threshold_ha))) {
          store$stream_network_discard(stream_dir);stream_dir <<- NULL
          stream_record <<- NULL;stream_context <<- NULL
          stream_notice("The saved candidate already uses this initiation threshold.")
          return(invisible(FALSE))
        }
        stream_job <<- launch_threshold(candidate,stream_dir,threshold)
        stream_notice("Updating the candidate from the saved flow-routing results...")
      } else {
        reference <- store$stream_segments(s$key,s$stream,s$path)$lines
        stream_job <<- launch_extract(file.path(rec$path,rec$result$file),reference,
          stream_dir,threshold,getOption("fgstudio.stream_memory_mb",3072))
        stream_notice("Locating the outlet and extracting the terrain-derived network in the background...")
      }
      stream_busy(TRUE)
      invisible(TRUE)
    }
    shiny::observeEvent(input$apply,{
      if(!is.null(burn_job)) return()
      tryCatch({
        rec <- record();dem <- source()
        if(is.null(rec) || !nrow(rec$lines) || is.null(dem)) stop("Draw at least one cutline first.")
        if(!is.null(rec$result)) return()
        begin_hydro(rec,dem,selected())
      },error=function(e) {stop_burn();notice(conditionMessage(e))})
    },ignoreInit=TRUE)
    shiny::observeEvent(input$extract_stream,{
      if(!is.null(stream_job)) return()
      tryCatch({
        rec <- record();s <- selected();dem <- source()
        if(is.null(s) || is.null(dem)) stop("Open a Stream with a saved DEM first.")
        threshold <- input$threshold_ha
        if(length(threshold)!=1L || !is.finite(threshold) || threshold<=0)
          stop("Enter a positive initiation area in hectares.")
        if(is.null(rec)) {
          empty <- sf::st_sf(cutline_id=integer(),geometry=sf::st_sfc(crs=4326))
          rec <- store$hydro_save(s$key,s$event,s$stream,dem$saved_dem$id,empty,
            expected=NULL,context=s$path)
          record(rec)
        }
        if(is.null(rec$result)) {
          if(nrow(rec$lines)) stop("Apply the saved cutlines before extracting a stream network.")
          begin_hydro(rec,dem,s,passthrough=TRUE,continue_stream=TRUE,
            threshold=threshold)
          stream_notice("Preparing the unchanged Stream DEM before extraction...")
          return()
        }
        begin_stream(rec,s,threshold)
      },error=function(e) {stop_burn();stop_stream();stream_notice(conditionMessage(e))})
    },ignoreInit=TRUE)
    session$onSessionEnded(function() {
      if(!is.null(view_worker)) view_worker$kill()
      stop_burn();stop_stream();unlink(cache,recursive=TRUE)
    })
    poll <- function() {
      if(!is.null(stream_job) && !stream_job$is_alive()) {
        job <- stream_job;stream_job <<- NULL
        stream_busy(FALSE)
        tryCatch({
          answer <- job$get_result();s <- shiny::isolate(selected())
          if(!identical(s,stream_context))
            stop("Study, Survey Event or Stream changed during extraction.")
          rec <- shiny::isolate(record())
          if(is.null(rec) || !identical(rec$id,stream_record$id))
            stop("The Hydro DEM changed during extraction; run the current DEM again.")
          saved <- store$stream_network_publish(stream_record,stream_dir,answer$result,answer$outlet)
          stream_dir <<- NULL;stream_record <<- NULL;stream_context <<- NULL
          network(saved)
          on_changed()
          stream_notice(paste0("Candidate saved: ",saved$stream_lines," lines, ",
            format(round(saved$stream_length_m),big.mark=",")," m at ",saved$threshold_ha,
            " ha. Review the cyan line on the map."))
        },error=function(e) {stop_stream();stream_notice(paste("Stream extraction failed:",hydro_error_message(e)))})
      }
      if(!is.null(burn_job) && !burn_job$is_alive()) {
        job <- burn_job;burn_job <<- NULL
        burn_busy(FALSE)
        tryCatch({
          passthrough <- burn_passthrough
          continue_stream <- burn_continue_stream
          threshold <- burn_threshold
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
          record(saved);network(NULL);burn_dir <<- NULL;burn_record <<- NULL
          burn_passthrough <<- FALSE;burn_continue_stream <<- FALSE;burn_threshold <<- NULL
          on_changed()
          shiny::updateRadioButtons(session,"surface",selected="hydro")
          notice(if(passthrough)
            "No cutlines were needed; the original Stream DEM is ready for extraction." else
            "Hydro-modified DEM saved. Switch between Original DEM and Hydro-modified DEM to review the cuts.")
          if(length(result$skipped_nodata_cutlines)) notice(paste0("Hydro-modified DEM saved. Cutline(s) ",
            paste(result$skipped_nodata_cutlines,collapse=", ")," were not applied: no elevation cells in this Stream DEM. Hover over cutlines to identify them; choose the correct Stream or edit those lines."))
          if(continue_stream) begin_stream(saved,s,threshold)
        },error=function(e) {stop_burn();notice(paste("Hydro modification failed:",hydro_error_message(e)))})
      }
      if(!is.null(view_job) && !view_job$is_alive()) {
        job <- view_job;view_job <<- NULL
        view_busy(FALSE)
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
    list(source=source,record=record,network=network,draw_ready=draw_ready)
  })
}

launch_hydro_burn <- function(source,lines,filename) {
  callr::r_bg(function(source,lines,filename) fluvgeo::burn_hydro_cutlines(source,lines,filename),
    args=list(source=source,lines=lines,filename=filename),libpath=.libPaths(),supervise=TRUE,
    stdout=NULL,stderr=NULL,user_profile=FALSE,system_profile=FALSE)
}

launch_hydro_passthrough <- function(source,filename) {
  callr::r_bg(function(source,filename) {
    if(!file.exists(source) || file.exists(filename) ||
        !file.copy(source,filename,overwrite=FALSE))
      stop("The original Stream DEM could not be prepared for extraction.")
    con <- file(filename,"rb");on.exit(close(con),add=TRUE)
    list(path=filename,method="unchanged_source",cutline_count=0L,
      changed_cells=0L,skipped_nodata_cutlines=integer(),
      output_sha256=unclass(as.character(openssl::sha256(con))))
  },args=list(source=source,filename=filename),libpath=.libPaths(),supervise=TRUE,
    stdout=NULL,stderr=NULL,user_profile=FALSE,system_profile=FALSE)
}

launch_stream_extraction <- function(source,reference_lines,directory,threshold_ha,
                                     memory_budget_mb) {
  callr::r_bg(function(source,reference_lines,directory,threshold_ha,memory_budget_mb) {
    outlet <- fluvgeo::locate_stream_outlet(source,reference_lines)
    result <- fluvgeo::extract_synthetic_stream_network(source,outlet$cell,directory,
      threshold_ha=threshold_ha,memory_budget_mb=memory_budget_mb)
    list(result=result,outlet=outlet)
  },args=list(source=source,reference_lines=reference_lines,directory=directory,
    threshold_ha=threshold_ha,memory_budget_mb=memory_budget_mb),libpath=.libPaths(),
    supervise=TRUE,stdout=NULL,stderr=NULL,user_profile=FALSE,system_profile=FALSE)
}

launch_stream_threshold <- function(candidate,directory,threshold_ha) {
  worker <- reuse_stream_network_threshold
  callr::r_bg(function(candidate,directory,threshold_ha,worker)
    worker(candidate,directory,threshold_ha),
    args=list(candidate=candidate,directory=directory,threshold_ha=threshold_ha,
      worker=worker),libpath=.libPaths(),supervise=TRUE,stdout=NULL,stderr=NULL,
    user_profile=FALSE,system_profile=FALSE)
}

reuse_stream_network_threshold <- function(candidate,directory,threshold_ha) {
  if(is.null(candidate$path) || !dir.exists(candidate$path) || !dir.exists(directory))
    stop("Saved routing outputs are unavailable.")
  files <- candidate$files
  reusable <- setdiff(names(files),"stream_network")
  for(name in reusable) {
    from <- file.path(candidate$path,files[[name]])
    to <- file.path(directory,files[[name]])
    dir.create(dirname(to),recursive=TRUE,showWarnings=FALSE)
    if(!file.exists(from) || (!file.link(from,to) && !file.copy(from,to)))
      stop("Could not reuse saved routing output: ",files[[name]])
  }
  network_file <- "stream-network.gpkg"
  threshold <- fluvgeo::threshold_synthetic_stream_network(
    file.path(directory,files$direction),file.path(directory,files$accumulation),
    file.path(directory,network_file),threshold_ha)
  result <- candidate
  result$path <- result$outlet <- result$app <- result$app_files <- NULL
  result$threshold_ha <- threshold$threshold_ha
  result$threshold_cells <- threshold$threshold_cells
  result$cell_area_m2 <- threshold$cell_area_m2
  result$stream_lines <- threshold$stream_lines
  result$stream_length_m <- threshold$stream_length_m
  result$completed <- threshold$completed
  result$files$stream_network <- network_file
  result$hashes$stream_network <- threshold$stream_network_sha256
  saveRDS(result,file.path(directory,"result.rds"))
  portable <- result;portable$route <- NULL
  jsonlite::write_json(portable,file.path(directory,"provenance.json"),
    auto_unbox=TRUE,pretty=TRUE,null="null")
  list(result=result,outlet=candidate$outlet)
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
