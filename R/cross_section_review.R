# Interactive inundation review is a session candidate; no dataset is published.
cross_section_vertex_labels <- function(section) {
  count <- nrow(sf::st_coordinates(section))
  left <- section$left_bank_vertex[1];right <- section$right_bank_vertex[1]
  labels <- character(count)
  labels[c(1L,left,right,count)] <- c("Left outer endpoint","Left bank","Right bank","Right outer endpoint")
  if(left>2L)labels[2:(left-1L)] <- if(left==3L)"Left floodplain bend" else paste("Left floodplain bend",seq_len(left-2L))
  if(count-right>1L)labels[(right+1L):(count-1L)] <- if(count-right==2L)"Right floodplain bend" else paste("Right floodplain bend",seq_len(count-right-1L))
  labels
}
cross_section_number_points <- function(sections) {
  geometry <- lapply(seq_len(nrow(sections)),function(i) {
    xy<-sf::st_coordinates(sections[i,])[,1:2,drop=FALSE]
    sf::st_point(colMeans(xy[sections$left_bank_vertex[i]:sections$right_bank_vertex[i],,drop=FALSE]))
  })
  sf::st_sf(Seq=sections$Seq,geometry=sf::st_sfc(geometry,crs=sf::st_crs(sections)))
}
cross_section_review_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(bslib::card_header("Cross Sections: layout and deconfliction"),
    shiny::p("Select a Survey Event, Stream and Reach. FG Studio lays out candidate cross sections and reduces overlaps automatically. Review the mapped extents and any remaining highlighted conflicts."),
    bslib::layout_columns(col_widths=c(4,8),
      shiny::div(shiny::uiOutput(ns("events")), shiny::uiOutput(ns("selection")),
        shiny::sliderInput(ns("channel"), "Channel REM elevation (ft)", 100, 130, 103, step=.1),
        shiny::sliderInput(ns("floodplain"), "Floodplain REM elevation (ft)", 100, 130, 109, step=.1),
        shiny::numericInput(ns("spacing"), "Cross-section spacing (m)", 20, min=1),
        shiny::checkboxInput(ns("overbank_bends"),"Allow additional floodplain vertices for deconfliction",FALSE),
        shiny::tags$details(shiny::tags$summary("Advanced layout"),
        shiny::numericInput(ns("tangent_distance"), "Centerline tangent distance (m)", 20, min=1),
        shiny::numericInput(ns("centerline_spacing"), "Centerline boundary spacing (m)", 2, min=0),
        shiny::numericInput(ns("smoothing"), "Centerline smoothing (Chaikin passes)", 2, min=0, max=10, step=1),
        shiny::numericInput(ns("overbank_angle"), "Maximum floodplain leg rotation (degrees)", 30, min=0, max=60, step=5),
        shiny::p(class="small","Extra vertices are optional and need not lie on a centerline. Rotation changes cut lines, not centerline smoothing; rotations over 30 degrees remain flagged for review.")),
        shiny::p(class="small", "Review the channel, left floodplain and right floodplain polygons and their independent polygon centerlines. Raw centerlines and skeletons are available in Layers. Orange sections need correction. Changing levels or layout settings replaces unsaved edits. Save a draft to retain corrections for these exact inputs."),
        shiny::uiOutput(ns("editor")),
        shiny::p(class="small", "Midwest starting REM levels: channel 103 ft and floodplain 109 ft, relative to the 100-ft reference. The current REM corridor can truncate mapped floodplain evidence."),
        shiny::uiOutput(ns("status"))),
      leaflet::leafletOutput(ns("map"), height="650px")))
}

cross_section_review_server <- function(id, context, store, events, active, revision) {
  shiny::moduleServer(id, function(input, output, session) {
    linked_survey_event_selector(input, output, session, events, context)
    review <- shiny::reactiveVal(NULL); selected <- shiny::reactiveVal(NULL)
    rem <- shiny::reactiveVal(NULL); extents <- shiny::reactiveVal(NULL)
    layout <- shiny::reactiveVal(NULL)
    saved_draft <- shiny::reactiveVal(NULL)
    editing <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(""); job <- NULL; job_kind <- NULL
    job_revision <- shiny::reactiveVal(0L)
    watch_job <- function(value) {
      job <<- value
      job_revision(shiny::isolate(job_revision())+1L)
    }
    job_key <- NULL; loaded <- NULL; generation <- 0L
    cache <- tempfile("cross-section-review-"); dir.create(cache)
    stop_job <- function() { if (!is.null(job) && job$is_alive()) {job$kill();job$wait(timeout=2000)}; job <<- NULL; job_kind <<- NULL }
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
    output$status <- shiny::renderUI(shiny::tagList(shiny::p(role="status", status()),
      if(grepl("^(Preparing|Precomputing|Updating)",status())) shiny::tags$progress(
        style="width:100%",`aria-label`=status())))
    shiny::observeEvent(list(context(), active(), revision()), {
      if (!isTRUE(active())) {
        if(!is.null(job) || is.null(layout())) {stop_job();loaded <<- NULL}
        return()
      }
      ctx <- context()
      if (is.null(ctx)) {
        stop_job(); rem(NULL); extents(NULL); layout(NULL); review(NULL); selected(NULL)
        loaded <<- NULL; status("Choose a saved Survey Event."); return()
      }
      key <- paste(ctx$path, ctx$group_path, revision(), sep="|")
      if (identical(key, loaded)) return()
      stop_job(); rem(NULL); extents(NULL); layout(NULL); editing(NULL); review(NULL); selected(NULL)
      tryCatch({
        value <- load_flowline_points_review(store, ctx)
        if (is.null(value$saved)) stop("Create and save Flowline Points before reviewing inundation.")
        review(value); loaded <<- key; status("Choose a Stream and Reach.")
      }, error=function(e) { loaded <<- NULL; status(conditionMessage(e)) })
    }, ignoreNULL=FALSE,priority=30)
    shiny::observeEvent(list(input$stream, input$reach, review()), {
      value <- review(); if (is.null(value) || is.null(input$stream) || is.null(input$reach)) return()
      bundle <- value$bundle[[input$stream]]; if (is.null(bundle)) return()
      line <- bundle$flowline$flowlines[bundle$flowline$flowlines$reach_id == input$reach,,drop=FALSE]
      points <- value$saved$points[value$saved$points$reach_id == input$reach,,drop=FALSE]
      if (nrow(line)!=1L || !nrow(points)) {
        stop_job(); rem(NULL); extents(NULL); layout(NULL); selected(NULL)
        status("Choose a Reach with saved Flowline Points."); return()
      }
      stop_job(); rem(NULL); extents(NULL); layout(NULL); editing(NULL); generation <<- generation+1L
      ctx <- context()
      saved <- tryCatch(if(is.function(store$cross_section_read))
        store$cross_section_read(ctx,value$saved,input$reach) else NULL,
        error=function(e){status(conditionMessage(e));NULL})
      saved_draft(saved)
      if(!is.null(saved)) {
        shiny::updateSliderInput(session,"channel",value=saved$settings$channel)
        shiny::updateSliderInput(session,"floodplain",value=saved$settings$floodplain)
        shiny::updateNumericInput(session,"spacing",value=saved$settings$spacing_m)
        shiny::updateNumericInput(session,"tangent_distance",value=saved$settings$tangent_distance_m)
        shiny::updateNumericInput(session,"smoothing",value=saved$settings$smoothing_refinements)
        shiny::updateNumericInput(session,"centerline_spacing",value=saved$settings$centerline_spacing_m)
        shiny::updateNumericInput(session,"overbank_angle",value=saved$settings$overbank_angle_limit_deg)
        shiny::updateCheckboxInput(session,"overbank_bends",value=saved$settings$allow_overbank_bends)
      }
      selected(list(line=line, points=points, dem=bundle$dem, key=generation,context=ctx,
        saved_points=value$saved,inputs=if(is.function(store$cross_section_inputs))
          store$cross_section_inputs(ctx,value$saved,input$reach) else NULL))
      request <- store$cross_section_rem_request(ctx,value$saved,input$reach)
      prepared <- cross_section_rem_artifact(request)
      if(!is.null(prepared)) {rem(prepared);status("Using the precomputed Reach REM.");return()}
      status("Precomputing the Reach REM for reuse...")
      job_key <<- generation; job_kind <<- "rem"
      watch_job(callr::r_bg(cross_section_rem_artifact,
        args=list(request=request,dem=bundle$dem,line=line,points=points),
      libpath=.libPaths(), supervise=TRUE, stdout=NULL, stderr=NULL))
    }, ignoreInit=TRUE)
    levels <- shiny::debounce(shiny::reactive(list(channel=input$channel, floodplain=input$floodplain,
      spacing=input$spacing, tangent_distance=input$tangent_distance, smoothing=input$smoothing,centerline_spacing=input$centerline_spacing,
      overbank_angle=input$overbank_angle,overbank_bends=input$overbank_bends)), 400)
    shiny::observeEvent(list(input$channel,input$floodplain,input$spacing,input$tangent_distance,input$smoothing,input$centerline_spacing,input$overbank_angle,input$overbank_bends), {
      if(identical(job_kind,"extent")) stop_job()
      extents(NULL); layout(NULL); editing(NULL)
    },priority=10)
    shiny::observeEvent(list(levels(), rem()), {
      if(!shiny::isolate(isTRUE(active())))return()
      x <- rem(); s <- selected(); v <- levels()
      if (is.null(x) || is.null(s) || is.null(v$channel) || is.null(v$floodplain)) return()
      if (!is.finite(v$channel) || !is.finite(v$floodplain) || v$channel>=v$floodplain) {
        stop_job(); extents(NULL); layout(NULL); status("Set the floodplain elevation above the channel elevation."); return()
      }
      if (is.null(v$spacing) || !is.finite(v$spacing) || v$spacing<=0 ||
          is.null(v$tangent_distance) || !is.finite(v$tangent_distance) || v$tangent_distance<=0 ||
          is.null(v$smoothing) || !is.finite(v$smoothing) || v$smoothing<0 || v$smoothing>10 || v$smoothing!=as.integer(v$smoothing) ||
          is.null(v$centerline_spacing) || !is.finite(v$centerline_spacing) || v$centerline_spacing<=0 ||
          is.null(v$overbank_angle) || !is.finite(v$overbank_angle) || v$overbank_angle<0 || v$overbank_angle>60 ||
          is.null(v$overbank_bends)) {
        stop_job(); layout(NULL); status("Set positive distances, 0 to 10 smoothing passes and 0 to 60 degrees of floodplain leg rotation."); return()
      }
      stop_job(); extents(NULL); layout(NULL); editing(NULL); status("Updating inundation and section candidates...")
      current_settings <- list(channel=as.numeric(v$channel),floodplain=as.numeric(v$floodplain),
        spacing_m=as.numeric(v$spacing),tangent_distance_m=as.numeric(v$tangent_distance),
        smoothing_refinements=as.integer(v$smoothing),centerline_spacing_m=as.numeric(v$centerline_spacing),
        overbank_angle_limit_deg=as.numeric(v$overbank_angle),allow_overbank_bends=isTRUE(v$overbank_bends))
      previous <- saved_draft()
      if((is.null(previous) || !identical(previous$settings,current_settings)) && is.function(store$cross_section_read)) {
        previous <- tryCatch(store$cross_section_read(s$context,s$saved_points,s$line$reach_id[1],current_settings),
          error=function(e)e)
        if(inherits(previous,"error")) {status(conditionMessage(previous));return()}
        if(!is.null(previous))saved_draft(previous)
      }
      if(!is.null(previous) && identical(previous$settings,current_settings)) {
        restored<-store$cross_section_reopen(previous)
        extents(restored$footprints);layout(restored)
        status("Saved draft and precomputed REM reopened; no layout recomputation needed.");return()
      }
      region_directory <- file.path(cache,x$key);dir.create(region_directory,showWarnings=FALSE)
      job_kind <<- "extent"; job_key <<- list(s$key, v$channel, v$floodplain,v$spacing,v$tangent_distance,v$smoothing,v$centerline_spacing,v$overbank_angle,v$overbank_bends)
      watch_job(callr::r_bg(function(path,line,channel,floodplain,spacing,window,smoothing,boundary_spacing,overbank_angle,overbank_bends,region_directory) {
        footprints <- fluvgeo::water_surface_extents(terra::rast(path),line,channel,floodplain)
        candidate <- tryCatch({
        key <- paste(format(openssl::sha256(serialize(list(channel,floodplain,boundary_spacing,smoothing,"polygon-centerline-v2"),NULL))),collapse="")
        cached <- file.path(region_directory,paste0("regions-",key,".rds"))
        artifacts <- if(file.exists(cached))readRDS(cached) else NULL
        if(is.null(artifacts)) {
          artifacts <- fluvgeo::cross_section_regions(line,footprints$channel_outer,footprints$floodplain_outer,
            centerline_spacing_m=boundary_spacing,smoothing_refinements=smoothing)
          pending <- paste0(cached,".pending")
          saveRDS(artifacts,pending)
          if(!file.rename(pending,cached))stop("Could not retain the centerline review cache.")
        }
        fluvgeo::cross_section_layout(line,footprints$channel_outer,
          footprints$floodplain_outer,spacing_m=spacing,tangent_distance_m=window,
          centerline_spacing_m=boundary_spacing,
          smoothing_refinements=smoothing,region_artifacts=artifacts,overbank_angle_limit_deg=overbank_angle,allow_overbank_bends=overbank_bends)
        },
          error=function(e)list(error=conditionMessage(e)))
        list(footprints=footprints,layout=if(is.null(candidate$error))candidate else NULL,
          layout_error=candidate$error)
      },
        args=list(path=x$path,line=s$line,channel=v$channel,floodplain=v$floodplain,
          spacing=v$spacing,window=v$tangent_distance,smoothing=v$smoothing,boundary_spacing=v$centerline_spacing,overbank_angle=v$overbank_angle,overbank_bends=v$overbank_bends,region_directory=region_directory),
        libpath=.libPaths(),supervise=TRUE,stdout=NULL,stderr=NULL))
    }, ignoreInit=TRUE)
    shiny::observe({
      job_revision() # Every replacement wakes polling, even when its status text is unchanged.
      if(is.null(job))return()
      shiny::invalidateLater(200, session)
      if (job$is_alive()) return()
      kind <- job_kind; key <- job_key
      result <- tryCatch(job$get_result(), error=function(e) e); job <<- NULL; job_kind <<- NULL
      if (inherits(result,"error")) { status(paste("Unable to prepare inundation:",conditionMessage(result))); return() }
      s <- selected(); if (is.null(s)) return()
      if (identical(kind,"rem") && identical(key,s$key)) { rem(result); status("REM ready; calculating inundation.") }
      if (identical(kind,"extent") && identical(key,list(s$key,input$channel,input$floodplain,input$spacing,input$tangent_distance,input$smoothing,input$centerline_spacing,input$overbank_angle,input$overbank_bends))) {
        restored <- saved_draft()
        current_settings <- list(channel=as.numeric(input$channel),floodplain=as.numeric(input$floodplain),
          spacing_m=as.numeric(input$spacing),tangent_distance_m=as.numeric(input$tangent_distance),smoothing_refinements=as.integer(input$smoothing),centerline_spacing_m=as.numeric(input$centerline_spacing),overbank_angle_limit_deg=as.numeric(input$overbank_angle),allow_overbank_bends=isTRUE(input$overbank_bends))
        if(!is.null(restored) && identical(restored$settings,current_settings)) {
          result$layout <- store$cross_section_reopen(restored)
          result$layout_error <- NULL
        } else if(!is.null(result$layout)) {
          previous_ids <- result$layout$sections$candidate_id
          result$layout$sections$candidate_id <- vapply(seq_len(nrow(result$layout$sections)),
            function(i)paste(format(openssl::rand_bytes(16)),collapse=""),character(1))
          if(!is.null(result$layout$boundary_anchors))result$layout$boundary_anchors$candidate_id <-
            result$layout$sections$candidate_id[match(result$layout$boundary_anchors$candidate_id,previous_ids)]
        }
        extents(result$footprints); layout(result$layout)
        status(if(!is.null(restored) && identical(restored$settings,current_settings))
          "Saved draft reopened for these inputs. Conflicts and coverage still require review." else if(is.null(result$layout_error))
          "Candidates ready. Review inferred directions, conflicts and floodplain coverage before use." else
          paste("Inundation ready. Layout unavailable:",result$layout_error))
      }
    })
    output$map <- leaflet::renderLeaflet({
      x <- rem(); s <- selected(); if (is.null(x) || is.null(s)) return(fg_leaflet() |> leaflet::addProviderTiles("Esri.WorldImagery"))
      raster <- terra::rast(x$display); limits <- x$limits
      pal <- leaflet::colorNumeric(terrain_palette(), domain=limits, na.color="transparent")
      line <- sf::st_transform(s$line,4326); b <- sf::st_bbox(line)
      fg_leaflet() |> leaflet::addProviderTiles("Esri.WorldImagery") |>
        leaflet::addRasterImage(raster, colors=pal, project=FALSE, opacity=.8, maxBytes=12*1024^2, group="REM") |>
        leaflet::addPolylines(data=line,color="black",weight=3,group="Flowline") |>
        leaflet::addLegend(pal=pal,values=limits,title="REM elevation (ft)",position="bottomright") |>
        leaflet::fitBounds(unname(b[["xmin"]]),unname(b[["ymin"]]),
          unname(b[["xmax"]]),unname(b[["ymax"]])) |>
        leaflet::addLayersControl(overlayGroups=c("REM","Flowline","Channel","Floodplain","Left floodplain","Right floodplain","Centerlines","Raw centerlines","Polygon skeletons","Candidates","Section numbers","Direction review points","Ordering boundaries","Ordered boundary targets")) |>
        leaflet::hideGroup(c("Raw centerlines","Polygon skeletons","Direction review points","Ordering boundaries","Ordered boundary targets"))
    })
    shiny::observeEvent(extents(), {
      x <- extents(); proxy <- leaflet::leafletProxy("map",session)
      proxy <- leaflet::clearGroup(proxy,"Channel") |> leaflet::clearGroup("Floodplain")
      if (is.null(x)) return()
      proxy |> leaflet::addPolygons(data=sf::st_transform(x$floodplain_outer,4326), group="Floodplain",color="forestgreen",weight=2,fillOpacity=.08) |>
        leaflet::addPolygons(data=sf::st_transform(x$channel_outer,4326),group="Channel",color="navy",weight=2,fillOpacity=.15)
    }, ignoreNULL=FALSE)
    output$editor <- shiny::renderUI({
      x <- layout(); if(is.null(x)) return(NULL)
      sections <- x$sections
      selected_row <- match(input$section,sections$candidate_id)
      if(!length(selected_row) || is.na(selected_row))selected_row <- 1L
      labels <- if(nrow(sections))cross_section_vertex_labels(sections[selected_row,]) else character()
      shiny::tagList(
        if(!is.null(x$region_diagnostics)) shiny::p(sprintf(
          "%d polygon components; %d centerlines unavailable; %d smoothing proposals rejected to keep paths inside their polygons.",
          nrow(x$region_diagnostics),sum(!x$region_diagnostics$centerline_available),sum(x$region_diagnostics$smoothing_rejected))),
        shiny::p(sprintf("%d candidates; %d missing channel crossings; %d sections in conflict; %d incomplete floodplain legs; %d sides with no mapped floodplain width at the bank.",
          nrow(sections),nrow(x$failures),sum(sections$conflict),
          sum(!sections$left_supported & sections$left_leg_status!="no_floodplain")+
            sum(!sections$right_supported & sections$right_leg_status!="no_floodplain"),
          sum(sections$left_leg_status=="no_floodplain")+sum(sections$right_leg_status=="no_floodplain"))),
        shiny::p(class="small",sprintf("Direction evidence: %d shortened tangent windows; %d raw-centerline measurements; %d floodplain legs rotated from their centerline normal. These are separate from missing geometry. Rotations are limited to %.0f degrees and retain full floodplain coverage; remaining conflicts need correction.",
          sum(sections$channel_short_tangent)+sum(sections$left_short_tangent)+sum(sections$right_short_tangent),
          sum(sections$channel_raw_centerline)+sum(sections$left_raw_centerline)+sum(sections$right_raw_centerline),
          sum(abs(sections$left_rotation_deg)>1e-6,na.rm=TRUE)+sum(abs(sections$right_rotation_deg)>1e-6,na.rm=TRUE),
          x$parameters$overbank_angle_limit_deg)),
        shiny::p(class="small",sprintf("%d floodplain direction matches adjusted to stay inside their polygon instead of jumping across a channel indentation.",
          sum(sections$left_visibility_adjusted)+sum(sections$right_visibility_adjusted))),
        shiny::p(class="small",sprintf("Conflicts: %d sections with channel contacts; %d floodplain legs with contacts. %d added floodplain vertices. Channel cuts stay perpendicular to their centerline direction; outer boundary targets follow section order.",
          sum(sections$channel_conflict),sum(sections$left_conflict)+sum(sections$right_conflict),
          sum(sections$left_bend_count)+sum(sections$right_bend_count))),
        shiny::p(class="small",sprintf("Floodplain boundary-order conflicts: %d sections; channel-bank order needs review at %d sections. Ordered boundary targets and Ordering boundaries are available in Layers; targets remain fixed during routing.",
          sum(sections$left_order_conflict | sections$right_order_conflict),sum(sections$channel_order_review))),
        shiny::tags$details(shiny::tags$summary("Optional manual correction"),
        shiny::selectInput(session$ns("section"),"Section to correct",
          choices=stats::setNames(sections$candidate_id,paste("Section",sections$Seq)),
          selected=shiny::isolate(input$section)),
        shiny::selectInput(session$ns("vertex"),"Vertex to move",choices=stats::setNames(seq_along(labels),labels),
          selected=shiny::isolate(input$vertex)),
        shiny::actionButton(session$ns("move"),"Move vertex on map"),
        shiny::actionButton(session$ns("cancel_move"),"Cancel move"),
        shiny::actionButton(session$ns("add_bend"),"Add floodplain bend"),
        shiny::actionButton(session$ns("remove_bend"),"Remove floodplain bend"),
        shiny::actionButton(session$ns("delete"),"Delete section"),
        shiny::p(class="small","Select a section and vertex, choose Move vertex on map, then click its new position. Add/Remove floodplain bend uses the selected vertex's side; a new bend starts at the leg midpoint and can be moved. Deletion resequences review numbers; session keys stay unchanged.")),
        shiny::actionButton(session$ns("save_draft"),"Save draft",class="btn-primary"))
    })
    shiny::observeEvent(input$move, {
      if(is.null(layout()) || is.null(input$section)) return()
      editing(list(id=input$section,vertex=as.integer(input$vertex)))
      status("Click the map to place the selected vertex, or choose Cancel move.")
    })
    shiny::observeEvent(input$cancel_move, {editing(NULL);status("Vertex move cancelled.")})
    shiny::observeEvent(input$map_click, {
      edit <- editing(); x <- layout(); footprint <- extents()
      if(is.null(edit) || is.null(x) || is.null(footprint)) return()
      tryCatch({
        i <- match(edit$id,x$sections$candidate_id)
        if(is.na(i) || !edit$vertex %in% seq_len(nrow(sf::st_coordinates(x$sections[i,])))) stop("Select a current candidate and vertex.")
        click <- sf::st_transform(sf::st_sfc(sf::st_point(c(input$map_click$lng,input$map_click$lat)),crs=4326),sf::st_crs(x$sections))
        xy <- sf::st_coordinates(x$sections[i,])[,1:2,drop=FALSE]
        xy[edit$vertex,] <- sf::st_coordinates(click)[1,1:2]
        sf::st_geometry(x$sections)[[i]] <- sf::st_linestring(xy)
        x$sections$edited[i] <- TRUE
        side <- if(edit$vertex<=x$sections$left_bank_vertex[i])"left" else "right"
        bank <- x$sections[[paste0(side,"_bank_vertex")]][i]
        x$sections[[paste0(side,"_leg_status")]][i] <- "manual_review"
        x$sections[[paste0(side,"_supported")]][i] <- sqrt(sum((xy[if(side=="left")1 else nrow(xy),]-xy[bank,])^2))>1e-7
        x$sections[[paste0(side,"_rotation_deg")]][i] <- NA_real_
        x$sections <- fluvgeo::cross_section_layout_review(x$sections,footprint$floodplain_outer,boundary_chains=x$boundary_chains)
        layout(x); editing(NULL)
        status(sprintf("Section %d updated. Boundary gaps: left %.1f m, right %.1f m. %s",
          x$sections$Seq[i],x$sections$left_boundary_gap_m[i],x$sections$right_boundary_gap_m[i],
          if(x$sections$conflict[i] || x$sections$self_crossing[i] || !x$sections$oriented[i]) "Geometry still needs correction." else "Review orientation and floodplain coverage."))
      },error=function(e)status(conditionMessage(e)))
    })
    change_bend <- function(add) {
      x <- layout();footprint <- extents()
      if(is.null(x) || is.null(footprint) || is.null(input$section) || is.null(input$vertex))return()
      tryCatch({
        i <- match(input$section,x$sections$candidate_id)
        if(is.na(i))stop("Select a current section.")
        xy <- sf::st_coordinates(x$sections[i,])[,1:2,drop=FALSE]
        left <- x$sections$left_bank_vertex[i];right <- x$sections$right_bank_vertex[i]
        side <- if(as.integer(input$vertex)<=left)"left" else "right"
        has_bend <- if(side=="left")left>2L else nrow(xy)-right>1L
        if(!add && !has_bend)stop("This side has no bend to remove.")
        if(add) {
          vertex <- as.integer(input$vertex)
          edge <- if(side=="left")min(max(1L,vertex),left-1L) else min(max(right,vertex),nrow(xy)-1L)
          if(sqrt(sum((xy[edge+1L,]-xy[edge,])^2))<=1e-7)stop("Move the outer endpoint before adding a bend to a zero-width leg.")
          xy <- rbind(xy[seq_len(edge),,drop=FALSE],colMeans(xy[edge:(edge+1L),,drop=FALSE]),xy[(edge+1L):nrow(xy),,drop=FALSE])
          if(side=="left") {left<-left+1L;right<-right+1L}
        } else {
          vertex <- as.integer(input$vertex)
          remove <- if(side=="left")min(max(2L,vertex),left-1L) else min(max(right+1L,vertex),nrow(xy)-1L)
          xy <- xy[-remove,,drop=FALSE]
          if(side=="left") {left<-left-1L;right<-right-1L}
        }
        sf::st_geometry(x$sections)[[i]] <- sf::st_linestring(xy)
        x$sections$left_bank_vertex[i] <- as.integer(left);x$sections$right_bank_vertex[i] <- as.integer(right)
        x$sections[[paste0(side,"_bend_added")]][i] <- if(side=="left")left>2L else nrow(xy)-right>1L
        x$sections[[paste0(side,"_leg_status")]][i] <- "manual_review"
        x$sections[[paste0(side,"_rotation_deg")]][i] <- NA_real_
        x$sections$edited[i] <- TRUE
        x$sections <- fluvgeo::cross_section_layout_review(x$sections,footprint$floodplain_outer,boundary_chains=x$boundary_chains)
        layout(x);editing(NULL)
        next_vertex <- if(add) {if(side=="left")2L else nrow(xy)-1L} else {if(side=="left")1L else nrow(xy)}
        shiny::updateSelectInput(session,"vertex",selected=as.character(next_vertex))
        status(paste(if(add)"Bend added to" else "Bend removed from",side,"floodplain leg. Review conflicts and coverage."))
      },error=function(e)status(conditionMessage(e)))
    }
    shiny::observeEvent(input$add_bend,change_bend(TRUE))
    shiny::observeEvent(input$remove_bend,change_bend(FALSE))
    shiny::observeEvent(input$delete, {
      x <- layout(); footprint <- extents(); if(is.null(x) || is.null(footprint)) return()
      x$sections <- x$sections[x$sections$candidate_id!=input$section,,drop=FALSE]
      x$sections$Seq <- seq_len(nrow(x$sections))
      if(!is.null(x$boundary_anchors)) {
        x$boundary_anchors <- x$boundary_anchors[x$boundary_anchors$candidate_id %in% x$sections$candidate_id,]
        x$boundary_anchors$Seq <- x$sections$Seq[match(x$boundary_anchors$candidate_id,x$sections$candidate_id)]
      }
      x$sections <- fluvgeo::cross_section_layout_review(x$sections,footprint$floodplain_outer,boundary_chains=x$boundary_chains)
      layout(x); editing(NULL); status("Section deleted; review numbers resequenced.")
    })
    shiny::observeEvent(input$save_draft, {
      s <- selected();x <- layout();footprint <- extents()
      if(is.null(s) || is.null(x) || is.null(footprint)) return()
      tryCatch({
        fresh <- load_flowline_points_review(store,context())
        if(is.null(fresh$saved))stop("Inputs changed; recreate and save Flowline Points first.")
        expected <- store$cross_section_inputs(context(),fresh$saved,input$reach)
        if(!identical(expected,s$inputs))stop("Inputs changed; reopen Cross Sections before saving.")
        settings <- list(channel=as.numeric(input$channel),floodplain=as.numeric(input$floodplain),
          spacing_m=as.numeric(input$spacing),tangent_distance_m=as.numeric(input$tangent_distance),smoothing_refinements=as.integer(input$smoothing),centerline_spacing_m=as.numeric(input$centerline_spacing),overbank_angle_limit_deg=as.numeric(input$overbank_angle),allow_overbank_bends=isTRUE(input$overbank_bends))
        saved <- store$cross_section_publish(s$context,s$saved_points,input$reach,settings,x,footprint,s$inputs)
        saved_draft(saved)
        status("Draft saved with layout metadata. Reopening these exact inputs retains the corrected geometry; scientific review remains open.")
      },error=function(e)status(paste("Draft not saved:",conditionMessage(e))))
    })
    shiny::observeEvent(list(layout(),input$section), {
      x <- layout(); proxy <- leaflet::leafletProxy("map",session)
      proxy <- leaflet::clearGroup(proxy,"Candidates") |> leaflet::clearGroup("Centerlines") |>
        leaflet::clearGroup("Ordering boundaries") |> leaflet::clearGroup("Ordered boundary targets") |>
        leaflet::clearGroup("Section numbers") |>
        leaflet::clearGroup("Direction review points") |> leaflet::clearGroup("Selected section") |>
        leaflet::clearGroup("Left floodplain") |> leaflet::clearGroup("Right floodplain") |>
        leaflet::clearGroup("Raw centerlines") |> leaflet::clearGroup("Polygon skeletons")
      if(is.null(x)) return()
      sections <- sf::st_transform(x$sections,4326)
      if(!is.null(x$boundary_chains) && nrow(x$boundary_chains))proxy <- leaflet::addPolylines(proxy,
        data=sf::st_transform(x$boundary_chains,4326),group="Ordering boundaries",color="#555555",weight=3,
        label=paste(x$boundary_chains$role,"boundary; increasing distance follows upstream section order"))
      targets <- x$boundary_anchors
      if(!is.null(targets) && nrow(targets)) {
        targets <- targets[targets$role=="outer",]
        proxy <- leaflet::addCircleMarkers(proxy,data=sf::st_transform(targets,4326),group="Ordered boundary targets",
          radius=4,color="#ffcc00",fillOpacity=1,
          label=paste("Planned",targets$side,"outer target; Section",targets$Seq),
          popup=paste0("Section ",targets$Seq," ",targets$side," planned outer target<br>Boundary position: ",
            round(targets$measure,2)," ",targets$measure_units,"<br>Status: ",targets$status))
      }
      if(nrow(sections)) {
        number_points <- cross_section_number_points(x$sections)
        proxy <- leaflet::addLabelOnlyMarkers(proxy,data=sf::st_transform(number_points,4326),
          group="Section numbers",label=as.character(number_points$Seq),
          labelOptions=leaflet::labelOptions(noHide=TRUE,direction="center",textOnly=FALSE,
            style=list("color"="#111","background"="white","font-size"="11px","padding"="1px 3px")))
      flagged <- sections$conflict | sections$self_crossing | !sections$oriented | sections$channel_direction_unavailable |
          sections$channel_skewed | sections$channel_order_review | sections$left_order_conflict | sections$right_order_conflict |
          (!is.na(sections$left_rotation_deg) & abs(sections$left_rotation_deg)>30+1e-7) |
          (!is.na(sections$right_rotation_deg) & abs(sections$right_rotation_deg)>30+1e-7) |
          (!sections$left_supported & sections$left_leg_status!="no_floodplain") |
          (!sections$right_supported & sections$right_leg_status!="no_floodplain") |
          sections$left_boundary_gap_m>.1 | sections$right_boundary_gap_m>.1 | sections$outside_floodplain_m>.1
        proxy <- leaflet::addPolylines(proxy,data=sections,group="Candidates",layerId=~candidate_id,
          color=ifelse(flagged,"#ff8c00","white"),weight=3,
          label=paste("Section",sections$Seq),popup=paste0("Section ",sections$Seq,
            "<br>Conflicts with: ",sections$conflicts_with,"<br>Left boundary gap: ",round(sections$left_boundary_gap_m,1),
            " m<br>Right boundary gap: ",round(sections$right_boundary_gap_m,1)," m<br>Outside floodplain: ",
            round(sections$outside_floodplain_m,1)," m<br>Left to right: ",sections$oriented,
            "<br>Left leg: ",gsub("_"," ",sections$left_leg_status),"; rotation: ",round(sections$left_rotation_deg,3)," degrees",
            "<br>Right leg: ",gsub("_"," ",sections$right_leg_status),"; rotation: ",round(sections$right_rotation_deg,3)," degrees",
            "<br>Channel departure from perpendicular: ",round(sections$channel_rotation_deg,3)," degrees",
            "<br>Boundary order: left ",sections$left_order_status,"; right ",sections$right_order_status,
            "<br>Channel bank order: left ",sections$channel_left_order_status,"; right ",sections$channel_right_order_status,
            "<br>Added vertices: left ",sections$left_bend_count,"; right ",sections$right_bend_count))
        one <- sections[sections$candidate_id %in% input$section,,drop=FALSE]
        if(nrow(one)) {
          vertices <- sf::st_as_sf(as.data.frame(sf::st_coordinates(one)[,1:2]),coords=c("X","Y"),crs=4326)
          proxy <- leaflet::addCircleMarkers(proxy,data=vertices,group="Selected section",radius=5,
            color="cyan",fillOpacity=1,label=cross_section_vertex_labels(one))
        }
      }
      colors <- c(channel="#2b8cbe",left_floodplain="#d01c8b",right_floodplain="#238b45")
      if(!is.null(x$regions)) for(side in c("left_floodplain","right_floodplain")) {
        region <- x$regions[x$regions$region==side,,drop=FALSE]
        if(nrow(region))proxy <- leaflet::addPolygons(proxy,data=sf::st_transform(region,4326),
          group=if(side=="left_floodplain")"Left floodplain" else "Right floodplain",
          color=colors[[side]],weight=1,fillOpacity=.2,label=~region_id)
      }
      if(nrow(x$paths)) proxy <- leaflet::addPolylines(proxy,data=sf::st_transform(x$paths,4326),group="Centerlines",
        color=unname(colors[x$paths$region]),weight=4,label=~paste(region_id,"polygon centerline"))
      if(!is.null(x$raw_centerlines) && nrow(x$raw_centerlines))proxy <- leaflet::addPolylines(proxy,
        data=sf::st_transform(x$raw_centerlines,4326),group="Raw centerlines",color="#ffbf00",weight=2,dashArray="5 4",label=~region_id)
      if(!is.null(x$skeletons) && nrow(x$skeletons))proxy <- leaflet::addPolylines(proxy,
        data=sf::st_transform(x$skeletons,4326),group="Polygon skeletons",color="#888888",weight=1,label=~region_id)
      evidence <- x$samples[x$samples$inferred,,drop=FALSE]
      if(nrow(evidence)) leaflet::addCircleMarkers(proxy,data=sf::st_transform(evidence,4326),group="Direction review points",
        radius=3,color="#ff8c00",fillOpacity=.7,label=paste(evidence$side,
          ifelse(evidence$direction_status!="centerline",gsub("_"," ",evidence$direction_status),
            paste(ifelse(evidence$short_tangent,"shortened tangent window", "full tangent window"),
              ifelse(evidence$raw_centerline,"on raw centerline","on smoothed centerline")))))
    },ignoreNULL=FALSE)
  })
}
