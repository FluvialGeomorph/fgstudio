launch_survey_collection_job <- function(boundary) {
  callr::r_bg(function(boundary) fluvgeo::discover_survey_collections(boundary),
    args=list(boundary=boundary),libpath=.libPaths(),stdout=NULL,stderr=NULL,
    user_profile=FALSE,system_profile=FALSE,supervise=TRUE)
}

mod_survey_collections_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(bslib::card_header("Survey Collections"),
    shiny::div(class="d-flex gap-2",
      shiny::actionButton(ns("search"),"Find surveys",class="btn-primary btn-sm"),
      shiny::actionButton(ns("cancel"),"Cancel search",class="btn-outline-secondary btn-sm"),
      shiny::actionButton(ns("save"),"Save selections",class="btn-success btn-sm")),
    shiny::p(class="small text-body-secondary mb-0","Public locations only: search sends the area to USGS/NOAA."),
    shiny::uiOutput(ns("status")),shiny::tags$details(shiny::tags$summary("Search details"),shiny::tableOutput(ns("searches"))),
    bslib::layout_columns(col_widths=c(5,7),
      bslib::navset_card_tab(id=ns("workflow"),
        bslib::nav_panel("Discover / select",
          shiny::uiOutput(ns("choices")),
          shiny::selectInput(ns("focus"),"Inspect footprint / metadata",choices=character()),
          shiny::uiOutput(ns("details"))),
        bslib::nav_panel("Plan acquisition",
      shiny::p(class="small mb-1","Choose a selected Survey Collection, review its product evidence, then add products to your plan. Save selections above saves the plan too. No downloads occur."),
      shiny::selectInput(ns("plan_collection"),"Survey Collection",choices=character()),
      shiny::uiOutput(ns("products")),
      shiny::checkboxGroupInput(ns("plan_products"),"Products to acquire",choices=c("Existing DEM"="DEM","Lidar point cloud"="POINT_CLOUD")),
      shiny::actionButton(ns("apply_plan"),"Update acquisition plan",class="btn-outline-primary btn-sm"),
      shiny::p(class="small text-body-secondary mb-0","Planned or unresolved products may be recorded as intent. DEM acquisition comes first; point-cloud processing is a later capability. Cross-listed collections remain separate."),
      shiny::tableOutput(ns("plan"))),
        bslib::nav_panel("DEM files",stream_dem_files_ui(ns("dem_files"))),
        bslib::nav_panel("Event setup",survey_event_settings_ui(ns("event_settings")))),
      bslib::card(full_screen=TRUE,bslib::card_header("Shared coverage map"),
        shiny::conditionalPanel("input.workflow != 'DEM files'",ns=ns,
          shiny::radioButtons(ns("map_mode"),"Show footprints",inline=TRUE,
          choices=c("Inspected only"="focus","Included collections"="included","Custom comparison"="custom")),
          shiny::conditionalPanel("input.map_mode == 'custom'",ns=ns,shiny::uiOutput(ns("map_choices")))),
        shiny::div(class="d-flex gap-2",
          shiny::actionButton(ns("zoom_study"),"Zoom to current area",class="btn-outline-secondary btn-sm"),
          shiny::actionButton(ns("zoom_visible"),"Zoom to visible footprints",class="btn-outline-secondary btn-sm")),
        shiny::p(class="small mb-0","Map visibility never changes acquisition choices. In DEM files: green is the Stream AOI; purple outlines are reported file bounds."),
        leaflet::leafletOutput(ns("map"),height="65vh"))),
    shiny::tags$details(open=NA,shiny::tags$summary("Selected Survey Collections"),shiny::tableOutput(ns("selected"))))
}

mod_survey_collections_server <- function(id,current,store,launch=launch_survey_collection_job) {
  shiny::moduleServer(id,function(input,output,session) {
    result <- shiny::reactiveVal(NULL); saved_keys <- shiny::reactiveVal(character())
    saved_path <- shiny::reactiveVal(NULL); status <- shiny::reactiveVal("Open a study with a saved boundary.")
    empty_plan <- function() data.frame(candidate_key=character(),product=character())
    plan <- shiny::reactiveVal(empty_plan()); saved_plan <- shiny::reactiveVal(empty_plan())
    busy <- shiny::reactiveVal(FALSE); job <- NULL; started <- NULL; active_key <- NULL
    key <- shiny::reactive({ x <- current(); if(is.null(x)) NULL else x$key })
    cancel <- function() {
      if(!is.null(job)) try(job$kill(),silent=TRUE)
      job <<- NULL; busy(FALSE)
      shiny::removeNotification(session$ns("activity"),session=session)
    }
    # Hidden renderUI controls are not initialized when a saved study opens.
    # NULL means unavailable; character(0) is an explicit empty selection.
    chosen <- shiny::reactive({ if(is.null(input$chosen)) saved_keys() else input$chosen })
    dem_files <- stream_dem_files_server("dem_files",current,result,plan,chosen,store=store)
    selection_pending <- function() !setequal(shiny::isolate(chosen()),shiny::isolate(saved_keys())) ||
      !identical(shiny::isolate(plan()),shiny::isolate(saved_plan())) || dem_files$has_pending()
    event_settings <- survey_event_settings_server("event_settings",current,store,saved_path,selection_pending)
    shiny::observeEvent(key(), {
      if(!is.null(key()) && identical(key(),active_key)) return()
      active_key <<- key()
      cancel(); result(NULL); saved_keys(character()); saved_path(NULL)
      plan(empty_plan()); saved_plan(empty_plan())
      x <- current()
      if(is.null(x)) { status("Open a study with a saved boundary."); return() }
      tryCatch({
        old <- store$survey_collections(x$key)
        saved_path(old$path)
        if(!is.null(old$discovery)) {
          saved_keys(old$discovery$selected); result(old$discovery)
          p <- old$discovery$acquisition_plan
          if(!is.null(p)) { plan(p); saved_plan(p) }
          status("Saved selections reopened. Dates, status and links are catalog reports, not verified acquisitions.")
        } else status("Find Survey Collections for the saved Study Area boundary.")
      },error=function(e) status(paste("Saved selections could not be read:",conditionMessage(e))))
    },ignoreNULL=FALSE)
    shiny::observeEvent(input$search, {
      x <- current()
      if(is.null(x) || !isTRUE(x$boundary)) { status("Save the Study Area boundary first."); return() }
      if(!setequal(chosen(),saved_keys()) || !identical(plan(),saved_plan())) { status("Save your selections and acquisition plan before refreshing the search."); return() }
      cancel()
      tryCatch({
        job <<- launch(x$boundary_sf); started <<- Sys.time(); busy(TRUE)
        status("Searching USGS and NOAA catalogs. Existing selections remain until you save.")
        shiny::showNotification("Searching Survey Collection catalogs…",id=session$ns("activity"),duration=NULL,session=session)
      },error=function(e) { cancel(); status("Search could not start; saved selections are unchanged.") })
    },ignoreInit=TRUE)
    poll <- function() {
      if(is.null(job)) return()
      if(as.numeric(difftime(Sys.time(),started,units="secs")) > 180) {
        cancel(); status("Search timed out; this is not a no-results response. Saved selections are unchanged."); return()
      }
      if(job$is_alive()) return()
      tryCatch({
        next_result <- job$get_result()
        # Retain selected records absent from this refresh, with their original
        # snapshot and query evidence. No implicit deselection or identity merge.
        old <- result()
        if(!is.null(old)) {
          keep <- old$records$candidate_key %in% saved_keys() & !old$records$candidate_key %in% next_result$records$candidate_key
          if(any(keep)) {
            next_result$records <- rbind(next_result$records,old$records[keep,])
            next_result$searches <- unique(rbind(next_result$searches,old$searches))
          }
        }
        result(next_result)
        status("Search finished. Review query outcomes below; saved selections absent from this refresh are retained with their older retrieval date.")
      },error=function(e) status("Search failed; not evidence of no collections. Previous results and saved selections are retained."))
      cancel()
    }
    shiny::observe({ if(busy()) { shiny::invalidateLater(350,session); poll() } })
    shiny::observeEvent(input$cancel,{cancel();status("Search cancelled. Saved selections are unchanged.")},ignoreInit=TRUE)
    shiny::observeEvent(input$save, {
      x <- current(); r <- result()
      if(is.null(x) || is.null(r) || busy()) { status("Finish a search before saving selections."); return() }
      tryCatch({
        r$acquisition_plan <- plan()[plan()$candidate_key %in% chosen(),,drop=FALSE]
        rownames(r$acquisition_plan) <- NULL
        path <- store$save_survey_collections(x$key,r,chosen(),x$path,saved_path())
        saved_path(path); saved_keys(chosen())
        plan(r$acquisition_plan); saved_plan(r$acquisition_plan)
        status("Survey Collection selections saved with acquisition plan. No Survey Events or downloads created.")
      },error=function(e) status(paste("Selections not saved:",conditionMessage(e))))
    },ignoreInit=TRUE)
    output$status <- shiny::renderUI(shiny::div(role="status",status(),
      if(busy()) shiny::tags$progress(style="width:100%",`aria-label`="Searching catalogs")))
    output$searches <- shiny::renderTable({
      r <- result(); if(is.null(r)) return(NULL)
      r$searches[c("catalog","outcome","returned","message")]
    },spacing="xs",striped=TRUE,rownames=FALSE)
    output$choices <- shiny::renderUI({
      r <- result(); if(is.null(r)) return(NULL)
      if(!nrow(r$records)) return(shiny::p("No candidate records. Check query outcomes above before interpreting this result."))
      x <- r$records; o <- order(x$date_label,x$title,x$catalog); x <- x[o,]
      labels <- paste(x$title,x$date_label,x$status,x$catalog,sep=" | ")
      shiny::div(style="max-height:290px;overflow-y:auto;",
        shiny::checkboxGroupInput(session$ns("chosen"),"Include for later acquisition / analysis",choices=stats::setNames(x$candidate_key,labels),
          selected=shiny::isolate(saved_keys())))
    })
    shiny::observeEvent(result(), {
      x <- result()$records
      shiny::updateSelectInput(session,"focus",choices=c("Study Area"="",stats::setNames(x$candidate_key,paste(x$title,x$catalog,sep=" / "))))
    })
    output$map_choices <- shiny::renderUI({
      r <- result(); if(is.null(r)) return(NULL)
      x <- r$records
      shiny::div(style="max-height:160px;overflow-y:auto;",
        shiny::checkboxGroupInput(session$ns("visible"),"Visible footprints only",
          choices=stats::setNames(x$candidate_key,paste(x$title,x$catalog,sep=" / ")),
          selected=shiny::isolate(input$visible)))
    })
    visible_keys <- shiny::reactive({
      mode <- input$map_mode
      if(identical(mode,"custom")) input$visible else if(identical(mode,"included")) chosen() else input$focus
    })
    zoom <- function(g) {
      if(is.null(g) || !nrow(g)) return()
      b <- sf::st_bbox(sf::st_transform(g,4326))
      leaflet::fitBounds(leaflet::leafletProxy("map",session=session),b[[1]],b[[2]],b[[3]],b[[4]])
    }
    shiny::observeEvent(input$zoom_study,{
      zoom(if(identical(input$workflow,"DEM files")) dem_files$aoi() else current()$boundary_sf)
    },ignoreInit=TRUE)
    shiny::observeEvent(input$zoom_visible,{
      if(identical(input$workflow,"DEM files")) zoom(dem_files$files()) else {
        r <- result(); if(!is.null(r)) zoom(r$records[r$records$candidate_key %in% visible_keys(),])
      }
    },ignoreInit=TRUE)
    output$map <- leaflet::renderLeaflet({
      m <- leaflet::addProviderTiles(leaflet::leaflet(),leaflet::providers$OpenStreetMap)
      x <- current()
      if(!is.null(x) && isTRUE(x$boundary)) {
        g <- sf::st_transform(x$boundary_sf,4326); b <- sf::st_bbox(g)
        m <- leaflet::addPolygons(m,data=g,color="#222222",weight=2,fillOpacity=.03,group="Study Area")
        m <- leaflet::fitBounds(m,b[[1]],b[[2]],b[[3]],b[[4]])
      }
      m
    })
    shiny::observe({
      current() # Reapply overlays after a same-study context redraws the map.
      if(identical(input$workflow,"DEM files")) {
        m <- leaflet::clearGroup(leaflet::leafletProxy("map",session=session),"Survey Collections")
        m <- leaflet::clearGroup(m,"DEM files"); m <- leaflet::clearGroup(m,"Stream AOI")
        f <- dem_files$files(); a <- dem_files$aoi()
        if(!is.null(f) && nrow(f)) m <- leaflet::addPolygons(m,data=f,color="#8157ba",weight=2,fillOpacity=.08,
          group="DEM files",label=lapply(f$title,htmltools::htmlEscape))
        if(!is.null(a) && nrow(a)) leaflet::addPolygons(m,data=sf::st_transform(a,4326),color="#167a35",weight=3,fillOpacity=0,group="Stream AOI")
        return()
      }
      m <- leaflet::clearGroup(leaflet::leafletProxy("map",session=session),"DEM files")
      leaflet::clearGroup(m,"Stream AOI")
      r <- result(); if(is.null(r)) return()
      x <- r$records[r$records$candidate_key %in% visible_keys(),]
      m <- leaflet::clearGroup(leaflet::leafletProxy("map",session=session),"Survey Collections")
      if(nrow(x)) leaflet::addPolygons(m,data=x,color=ifelse(x$candidate_key %in% chosen(),"#e58b00","#168a9c"),
        weight=2,fillOpacity=.10,group="Survey Collections",label=lapply(x$title,htmltools::htmlEscape))
    })
    shiny::observeEvent(list(input$workflow,dem_files$aoi()),{
      if(identical(input$workflow,"DEM files")) zoom(dem_files$aoi())
    },ignoreInit=TRUE)
    shiny::observeEvent(input$focus, {
      r <- result(); if(is.null(r)) return()
      g <- r$records[r$records$candidate_key %in% input$focus,]
      if(!nrow(g)) g <- current()$boundary_sf
      b <- sf::st_bbox(sf::st_transform(g,4326))
      leaflet::fitBounds(leaflet::leafletProxy("map",session=session),b[[1]],b[[2]],b[[3]],b[[4]])
    },ignoreInit=TRUE)
    output$details <- shiny::renderUI({
      r <- result(); if(is.null(r)) return(NULL)
      x <- r$records[r$records$candidate_key %in% input$focus,]
      if(nrow(x)!=1L) return(NULL)
      link <- function(value,label) if(!is.na(value) && grepl("^https?://[^[:space:]]+$",value))
        shiny::tags$a(label,href=value,target="_blank",rel="noopener noreferrer")
      shiny::tagList(compact_table(data.frame(Item=c("Catalog / ID","Acquisition period","Reported status","Reported availability","Footprint","Retrieved"),
        Value=c(paste(x$catalog,x$record_id),x$date_label,x$status,x$availability,x$coverage,x$retrieved_at))),
        link(x$metadata_url,"Catalog / metadata"),shiny::span(" · "),link(x$access_url,"Reported access link"))
    })
    output$selected <- shiny::renderTable({
      r <- result(); if(is.null(r)) return(NULL)
      sf::st_drop_geometry(r$records[r$records$candidate_key %in% chosen(),c("title","date_label","status","catalog")])
    },spacing="xs",striped=TRUE,rownames=FALSE)
    shiny::observe({
      r <- result(); if(is.null(r)) {
        shiny::updateSelectInput(session,"plan_collection",choices=character()); return()
      }
      x <- r$records[r$records$candidate_key %in% chosen(),]
      shiny::updateSelectInput(session,"plan_collection",choices=stats::setNames(x$candidate_key,paste(x$title,x$catalog,sep=" / ")),
        selected=shiny::isolate(input$plan_collection))
    })
    shiny::observeEvent(input$plan_collection,{
      shiny::updateCheckboxGroupInput(session,"plan_products",selected=plan()$product[plan()$candidate_key %in% input$plan_collection])
      if(length(input$plan_collection)==1L && nzchar(input$plan_collection))
        shiny::updateSelectInput(session,"focus",selected=input$plan_collection)
    },ignoreNULL=FALSE)
    output$products <- shiny::renderUI({
      r <- result(); if(is.null(r)) return(NULL)
      products <- fluvgeo::survey_collection_products(r)
      products <- products[products$candidate_key %in% input$plan_collection,]
      if(!nrow(products)) return(shiny::p("Select a Survey Collection above to plan its products."))
      display <- products[c("product","reported_status","reported_products","access_evidence")]
      names(display) <- c("Product","Provider category / status","Provider description","Access evidence")
      dem <- products[products$product=="DEM",]
      shiny::tagList(compact_table(display),
        compact_table(data.frame(Item=c("Reported DEM pixel size","Resolution screen","Suitability"),
          Value=c(if(is.na(dem$dem_pixel_size_m)) "Unknown — verify product metadata" else paste(dem$dem_pixel_size_m,"m"),
            dem$resolution_screen,"Not reviewed — inspect downloaded terrain and processing metadata"))),
        lapply(seq_len(nrow(products)),function(i) {
          url <- products$access_url[i]
          if(grepl("^https?://[^[:space:]]+$",url)) shiny::div(shiny::tags$a(paste(products$product[i],"reported access"),href=url,target="_blank",rel="noopener noreferrer"))
        }),shiny::p(class="small mb-0","A DEM must be 1 m or finer. Resolution alone does not establish suitability (including hydro-flattening). After inspection, return here to revise the plan or choose point clouds. Downloads and inspection are not yet implemented."),
        shiny::p(class="small mb-0","USGS categories such as Meets are not download readiness. Unknown access is not unavailability."))
    })
    shiny::observeEvent(input$apply_plan,{
      k <- input$plan_collection; products <- input$plan_products
      if(length(k)!=1L || !k %in% chosen()) { status("Select an included Survey Collection first."); return() }
      if(!all(products %in% c("DEM","POINT_CLOUD"))) { status("Choose a supported product."); return() }
      p <- plan(); p <- p[p$candidate_key!=k,,drop=FALSE]
      if(length(products)) p <- rbind(p,data.frame(candidate_key=k,product=unique(products)))
      rownames(p) <- NULL; plan(p)
      status("Acquisition plan updated in this session. Save selections to retain it.")
    },ignoreInit=TRUE)
    output$plan <- shiny::renderTable({
      r <- result(); if(is.null(r)) return(NULL)
      p <- plan(); p <- p[p$candidate_key %in% chosen(),,drop=FALSE]
      if(!nrow(p)) return(data.frame(Next="Choose products for each selected Survey Collection."))
      data.frame(Collection=r$records$title[match(p$candidate_key,r$records$candidate_key)],
        Catalog=r$records$catalog[match(p$candidate_key,r$records$candidate_key)],Product=p$product,State="Planned acquisition; not downloaded")
    },spacing="xs",striped=TRUE,rownames=FALSE)
    session$onSessionEnded(cancel)
    list(poll=poll,result=result,status=status,has_pending=function()
      selection_pending() || event_settings$has_pending())
  })
}
