launch_stream_dem_job <- function(stream,collection) {
  callr::r_bg(function(stream,collection) fluvgeo::discover_stream_dem_files(stream,collection),
    args=list(stream=stream,collection=collection),libpath=.libPaths(),stdout=NULL,stderr=NULL,
    user_profile=FALSE,system_profile=FALSE,supervise=TRUE)
}

stream_dem_files_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::selectInput(ns("stream"),"Stream",choices=character()),
    shiny::selectInput(ns("collection"),"Survey Collection",choices=character()),
    shiny::div(class="d-flex gap-2",
      shiny::actionButton(ns("find"),"Find DEMs",class="btn-primary btn-sm"),
      shiny::actionButton(ns("cancel"),"Cancel",class="btn-outline-secondary btn-sm")),
    shiny::tags$details(shiny::tags$summary("About this search"),shiny::p(class="small mb-0","Searches all catalog pages for source-directory files whose reported bounds intersect the Stream. Saved downloads remain listed when you refresh file choices. Bounds are not valid-elevation footprints. Save choices before switching Stream or collection; unsaved edits will be discarded.")),
    shiny::div(class="d-flex gap-2 mt-1",
      shiny::actionButton(ns("select_all"),"Select all",class="btn-outline-primary btn-sm"),
      shiny::actionButton(ns("select_none"),"Clear",class="btn-outline-secondary btn-sm"),
      shiny::actionButton(ns("save_files"),"Save file choices",class="btn-success btn-sm")),
    shiny::uiOutput(ns("status")),shiny::uiOutput(ns("acquisition")),shiny::uiOutput(ns("files")),shiny::uiOutput(ns("details")),
    stream_dem_download_ui(ns("download")))
}

stream_dem_files_server <- function(id,current,discovery,plan,included,launch=launch_stream_dem_job,store=NULL) {
  shiny::moduleServer(id,function(input,output,session) {
    result <- shiny::reactiveVal(NULL); status <- shiny::reactiveVal("Choose a Stream and a planned DEM collection.")
    busy <- shiny::reactiveVal(FALSE); job <- NULL; started <- NULL
    saved_path <- shiny::reactiveVal(NULL); saved_ids <- shiny::reactiveVal(character())
    saved_inventory <- shiny::reactiveVal(FALSE)
    download <- stream_dem_download_server("download",current,
      selection=shiny::reactive(list(path=if(saved_inventory()) saved_path() else NULL,ids=saved_ids(),draft=input$visible,
        stream=input$stream,collection=input$collection)),
      scope=shiny::reactive(list(current()$path,input$stream,input$collection,discovery(),plan(),included(),saved_path(),saved_inventory())),store=store)
    streams <- shiny::reactive({
      x <- current(); s <- x$stream_inventory
      if(!inherits(s,"sf")) return(NULL)
      s[as.character(sf::st_geometry_type(s)) %in% c("POLYGON","MULTIPOLYGON") & !sf::st_is_empty(s),]
    })
    aoi <- shiny::reactive({s <- streams(); if(is.null(s)) NULL else s[s$stream_id %in% input$stream,]})
    collections <- shiny::reactive({
      r <- discovery(); if(is.null(r)) return(NULL)
      keys <- intersect(included(),plan()$candidate_key[plan()$product=="DEM"])
      r$records[r$records$candidate_key %in% keys,]
    })
    shiny::observe({
      s <- streams()
      choices <- if(is.null(s)) character() else stats::setNames(s$stream_id,s$stream_name)
      shiny::updateSelectInput(session,"stream",choices=choices,selected=shiny::isolate(input$stream))
    })
    shiny::observe({
      c <- collections()
      choices <- if(is.null(c)) character() else stats::setNames(c$candidate_key,paste(c$title,c$catalog,sep=" / "))
      shiny::updateSelectInput(session,"collection",choices=choices,selected=shiny::isolate(input$collection))
    })
    cancel <- function() {
      if(!is.null(job)) try(job$kill(),silent=TRUE)
      job <<- NULL; busy(FALSE)
      shiny::removeNotification(session$ns("activity"),session=session)
    }
    # A different revision, discovery snapshot, Stream or collection invalidates
    # these session-only file candidates; never display them for another AOI.
    shiny::observeEvent(list(current()$path,discovery(),collections(),input$stream,input$collection),{
      cancel(); result(NULL); status("Choose a Stream and a planned DEM collection, then find files.")
      saved_path(NULL); saved_ids(character()); saved_inventory(FALSE)
      if(!is.null(store) && length(input$stream)==1L && nzchar(input$stream) &&
          length(input$collection)==1L && nzchar(input$collection) && !is.null(current())) {
        tryCatch({
          old <- store$dem_files(current()$key,input$stream,input$collection)
          saved_path(old$path)
          if(!is.null(old$result) && input$collection %in% collections()$candidate_key) {
            store$check_dem_files(current()$key,old$result,current()$path,old$path)
            saved_ids(old$result$selected); result(old$result); saved_inventory(TRUE)
            status("Saved file choices reopened. Download outcomes appear below; suitability remains unreviewed.")
          }
        },error=function(e) status(paste("Saved file choices unavailable:",conditionMessage(e))))
      }
    },ignoreNULL=FALSE)
    shiny::observeEvent(input$find,{
      if(!is.null(result()) && (!saved_inventory() || !setequal(input$visible,saved_ids()))) {status("Save changed file choices before refreshing.");return()}
      s <- aoi(); c <- collections()
      if(is.null(s) || nrow(s)!=1L || is.null(c)) {status("Save a Stream polygon and include a DEM in the acquisition plan first.");return()}
      c <- c[c$candidate_key %in% input$collection,]
      if(nrow(c)!=1L) {status("Choose one planned DEM collection.");return()}
      cancel(); result(NULL); saved_inventory(FALSE)
      tryCatch({
        job <<- launch(s,c); started <<- Sys.time(); busy(TRUE)
        status("Finding source DEM file metadata; no rasters are being downloaded.")
        shiny::showNotification("Finding Stream DEM files\u2026",id=session$ns("activity"),duration=NULL,session=session)
      },error=function(e) status("File search could not start; no data changed."))
    },ignoreInit=TRUE)
    poll <- function() {
      if(is.null(job)) return()
      if(job$is_alive()) return()
      tryCatch({
        r <- job$get_result(); result(r); status(paste(r$outcome,r$message,sep=": "))
      },error=function(e) status("File search failed; this is not a no-files result."))
      cancel()
    }
    shiny::observe({if(busy()) {shiny::invalidateLater(350,session);poll()}})
    shiny::observeEvent(input$cancel,{cancel();status("File search cancelled; no data changed.")},ignoreInit=TRUE)
    shiny::observeEvent(input$select_all,{
      r <- result(); if(is.null(r)) return()
      shiny::updateCheckboxGroupInput(session,"visible",selected=r$files$file_id)
    },ignoreInit=TRUE)
    shiny::observeEvent(input$select_none,{
      shiny::updateCheckboxGroupInput(session,"visible",selected=character())
    },ignoreInit=TRUE)
    shiny::observeEvent(input$save_files,{
      r <- result(); x <- current()
      if(is.null(store) || is.null(r) || busy() || !r$outcome %in% c("COMPLETE","PARTIAL")) {
        status("Finish a successful file search first.");return()
      }
      tryCatch({
        ids <- if(is.null(input$visible)) character() else input$visible
        path <- store$save_dem_files(x$key,r,ids,x$path,saved_path())
        saved_path(path);saved_ids(ids);saved_inventory(TRUE)
        status("File choices saved. Use Download saved files to acquire sources.")
      },error=function(e) status(paste("File choices not saved:",conditionMessage(e))))
    },ignoreInit=TRUE)
    output$status <- shiny::renderUI(shiny::div(role="status",status(),
      if(busy()) shiny::tags$progress(style="width:100%",`aria-label`="Finding DEM files")))
    output$files <- shiny::renderUI({
      r <- result(); if(is.null(r) || !nrow(r$files)) return(NULL)
      f <- r$files
      labels <- paste(f$title,ifelse(is.na(f$size_bytes),"size unknown",paste(round(f$size_bytes/1e6,1),"MB")),sep=" | ")
      shiny::div(style="max-height:180px;overflow-y:auto;",shiny::checkboxGroupInput(session$ns("visible"),
        "Tiles",choices=stats::setNames(f$file_id,labels),selected=shiny::isolate(intersect(saved_ids(),f$file_id))))
    })
    visible_files <- shiny::reactive({r <- result();if(is.null(r)) NULL else r$files[r$files$file_id %in% input$visible,]})
    output$acquisition <- shiny::renderUI({
      r <- result(); if(is.null(r) || !nrow(r$files)) return(NULL)
      f <- visible_files()
      known <- is.finite(f$size_bytes) & f$size_bytes >= 0
      unknown_size <- sum(!known)
      size <- if(!nrow(f)) "No tiles selected" else if(!any(known)) "Unknown" else
        paste0(format(round(sum(f$size_bytes[known])/1e6,1),trim=TRUE)," MB",if(unknown_size) " known subtotal" else " reported")
      unknown_resolution <- sum(!is.finite(f$pixel_size_m) | f$pixel_size_m <= 0)
      coarse <- sum(is.finite(f$pixel_size_m) & f$pixel_size_m > 1)
      state <- if(!saved_inventory() || is.null(saved_path()) || !setequal(input$visible,saved_ids())) "Not saved" else "Saved"
      shiny::tags$details(shiny::tags$summary(paste("Download review:",nrow(f),"selected /",nrow(r$files),"tiles;",state)),
        compact_table(data.frame(Item=c("Tiles","Download size","Unknown file sizes","Resolution screen","Choices"),
          Value=c(paste(nrow(f),"selected /",nrow(r$files),"returned"),size,as.character(unknown_size),
            paste(coarse,"coarser than 1 m;",unknown_resolution,"unknown"),state))),
        shiny::p(class="small mb-1",if(!nrow(f)) "Select tiles to show their details and map outlines." else
          "Save these choices before downloading. Resolution does not establish terrain suitability."),
        if(coarse) shiny::p(class="small text-warning mb-1","Tiles coarser than 1 m cannot serve as analysis DEMs; revise the selection or plan point-cloud acquisition."),
        if(identical(r$outcome,"PARTIAL")) shiny::p(class="small text-warning mb-1","Incomplete catalog result: these counts and sizes cover returned tiles only."))
    })
    output$details <- shiny::renderUI({
      f <- visible_files();if(is.null(f) || !nrow(f)) return(NULL)
      shiny::div(style="max-height:220px;overflow:auto;",tabindex="0",role="region",`aria-label`="Selected DEM tiles",
        compact_table(data.frame(File=f$title,MB=ifelse(is.na(f$size_bytes),"Unknown",round(f$size_bytes/1e6,1)),
        `Pixel size (m)`=ifelse(is.na(f$pixel_size_m),"Unknown",f$pixel_size_m),Evidence=f$resolution_evidence,
        Format=f$format,`Publication (not acquisition)`=f$publication_date,check.names=FALSE)))
    })
    session$onSessionEnded(cancel)
    list(aoi=aoi,files=visible_files,result=result,poll=poll,status=status,
      has_pending=function() !is.null(shiny::isolate(result())) &&
        (!shiny::isolate(saved_inventory()) ||
          (!is.null(shiny::isolate(input$visible)) && !setequal(shiny::isolate(input$visible),shiny::isolate(saved_ids())))))
  })
}
