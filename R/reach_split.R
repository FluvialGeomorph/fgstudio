reach_split_ui <- function(ns) {
  shiny::tagList(
    shiny::uiOutput(ns("split_reaches")),
    shiny::textInput(ns("split_name"),"New Reach name"),
    shiny::selectInput(ns("split_keep"),"Keep the existing name and identity on",
      c("Downstream portion"="downstream","Upstream portion"="upstream")),
    shiny::p(class="small my-1","Choose a Reach, then click on or near its blue line. The cut snaps to that Reach; review both portions before saving."),
    shiny::uiOutput(ns("split_summary")),
    shiny::div(class="d-flex gap-2 flex-wrap",
      shiny::actionButton(ns("preview_split"),"Preview split",class="btn-outline-primary btn-sm"),
      shiny::actionButton(ns("clear_split"),"Clear",class="btn-outline-secondary btn-sm"),
      shiny::actionButton(ns("save_split"),"Save split",class="btn-primary btn-sm")),
    shiny::uiOutput(ns("split_status")))
}

reach_split_server <- function(input,output,session,study,store,source,is_active,on_saved) {
  point <- shiny::reactiveVal(NULL); preview <- shiny::reactiveVal(NULL)
  status <- shiny::reactiveVal("Choose the Reach to split.")
  alive <- TRUE; saved_once <- FALSE
  enabled <- function() alive && is_active() && identical(input$selection_target,"reach") && identical(input$reach_operation,"split")
  output$split_reaches <- shiny::renderUI({
    x <- study$reach_inventory
    if (is.null(x)) return(shiny::p("No saved Reaches in this Stream."))
    x <- x[x$stream_id %in% input$reach_parent,]
    shiny::selectInput(session$ns("split_reach"),"Reach to split",
      c("Choose a Reach"="",stats::setNames(x$reach_id,x$reach_name)))
  })
  changing <- shiny::observeEvent(list(input$reach_parent,input$split_reach),{
    point(NULL); preview(NULL)
    status("Click the selected Reach's blue line to choose a cut.")
  },ignoreInit=TRUE)
  side <- shiny::observeEvent(input$split_keep,{ preview(NULL) },ignoreInit=TRUE)
  make_preview <- function() {
    if (!enabled()) return()
    preview(NULL)
    tryCatch({
      if (is.null(input$split_reach) || !nzchar(input$split_reach)) stop("Choose a Reach to split first.")
      if (is.null(point())) stop("Click the map to choose the cut location.")
      v <- shiny::withProgress(message="Previewing Reach split",value=.3,
        store$preview_reach_split(study$key,input$split_reach,point(),input$split_keep,study$path))
      preview(v); status("Gold is downstream; teal is upstream. Name the new Reach, then Save split.")
    },error=function(e) status(conditionMessage(e)))
  }
  click <- function(x) {
    if (!enabled() || is.null(x$lng) || is.null(x$lat)) return()
    if (!is.numeric(x$lng) || !is.numeric(x$lat) || length(x$lng)!=1L || length(x$lat)!=1L ||
        !is.finite(x$lng) || !is.finite(x$lat) || abs(x$lng)>180 || abs(x$lat)>90) return()
    point(sf::st_sfc(sf::st_point(c(x$lng,x$lat)),crs=4326))
    make_preview()
  }
  clicking <- shiny::observeEvent(input$map_click,click(input$map_click),ignoreInit=TRUE)
  shape_clicking <- shiny::observeEvent(input$map_shape_click,click(input$map_shape_click),ignoreInit=TRUE)
  previewing <- shiny::observeEvent(input$preview_split,make_preview(),ignoreInit=TRUE)
  clearing <- shiny::observeEvent(input$clear_split,{
    if (!enabled()) return()
    point(NULL); preview(NULL); status("Click the map for another cut.")
  },ignoreInit=TRUE)
  saving <- shiny::observeEvent(input$save_split,{
    if (!enabled() || saved_once) return()
    tryCatch({
      if (is.null(preview())) stop("Preview the current split before saving.")
      saved <- store$split_reach(study$key,input$split_reach,point(),input$split_name,input$split_keep,study$path)
      point(NULL); preview(NULL); saved_once <<- TRUE; on_saved(saved)
    },error=function(e) status(paste("Split not saved:",conditionMessage(e))))
  },ignoreInit=TRUE)
  output$split_status <- shiny::renderUI(shiny::p(class="small my-1",role="status",status()))
  output$split_summary <- shiny::renderUI({
    v <- preview(); if (is.null(v)) return(NULL)
    compact_table(data.frame(Item=c("Snap distance","Downstream length","Upstream length","Existing identity remains","Buffer on EACH side"),
      Value=c(sprintf("%.2f m",v$snap_distance_m),sprintf("%.1f m",v$lengths_m),
        v$keep_side,paste(v$source$distance,v$source$unit,"(inherited)"))))
  })
  painting <- shiny::observe({
    s <- source(); v <- preview()
    map <- leaflet::leafletProxy("map",session=session) |>
      leaflet::clearGroup("Reach split line") |> leaflet::clearGroup("Reach split preview")
    if (!enabled() || is.null(s)) return()
    ids <- s$reach_mappings$selection_id[s$reach_mappings$reach_id %in% input$split_reach]
    lines <- s$lines[s$lines$selection_id %in% ids,]
    if (nrow(lines)) map <- leaflet::addPolylines(map,data=sf::st_transform(lines,4326),
      group="Reach split line",color="#3182bd",weight=6,
      options=leaflet::pathOptions(bubblingMouseEvents=FALSE))
    if (!is.null(v)) {
      map <- leaflet::addPolygons(map,data=sf::st_transform(v$areas,4326),group="Reach split preview",
        color=c("#e6a500","#159895"),fillOpacity=.2,label=v$areas$side,
        options=leaflet::pathOptions(interactive=FALSE))
      xy <- sf::st_coordinates(sf::st_transform(v$cut,4326))
      leaflet::addCircleMarkers(map,lng=xy[1,1],lat=xy[1,2],group="Reach split preview",
        radius=6,color="#111111",fillOpacity=1,label="Snapped cut",
        options=leaflet::pathOptions(interactive=FALSE))
    }
  })
  list(preview=preview,point=point,status=status,has_pending=function() shiny::isolate(!is.null(point())),
    destroy=function() {
      alive <<- FALSE
      for (o in list(changing,side,clicking,shape_clicking,previewing,clearing,saving,painting)) o$destroy()
    })
}
