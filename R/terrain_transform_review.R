terrain_transform_review_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::uiOutput(ns("panel"))
}

terrain_transform_choices <- function(review,choices) {
  chosen <- lapply(review$groups,function(g) {
    if(!isTRUE(g$requires_choice)) return(list(group=g$key,kind="no_datum_change",explanation=g$explanation))
    key <- choices[[g$key]]
    candidates <- Filter(function(c) identical(c$key,key) && isTRUE(c$selectable),g$catalog$candidates)
    if(length(candidates)!=1L) stop("Choose an available operation for every source reference pair.")
    list(group=g$key,kind="analyst_selected",operation=candidates[[1L]])
  })
  chosen
}

terrain_transform_review_server <- function(id,current,context,store,
    launch=function(args) callr::r_bg(function(args) do.call(fluvgeo::review_terrain_transformations,args),
      args=list(args=args),libpath=.libPaths(),stdout=NULL,stderr=NULL,poll_connection=FALSE,
      user_profile=FALSE,system_profile=FALSE,supervise=TRUE)) {
  shiny::moduleServer(id,function(input,output,session) {
    review <- shiny::reactiveVal(NULL); saved <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(""); busy <- shiny::reactiveVal(FALSE)
    job <- NULL; request <- NULL; pending_save <- NULL
    cancel <- function() {
      if(!is.null(job) && job$is_alive()) job$kill()
      job <<- NULL;pending_save <<- NULL;busy(FALSE)
    }
    session$onSessionEnded(cancel)
    begin <- function() {
      cancel();review(NULL);saved(NULL)
      tryCatch({
        x <- current();ctx <- context()
        if(is.null(x) || is.null(ctx)) stop("Select a saved Survey Event first.")
        request <<- store$transform_request(x$key,ctx$group_id,x$path,ctx$group_path)
        job <<- launch(request$args);busy(TRUE);status("Finding candidate transformations...")
      },error=function(e) status(conditionMessage(e)))
    }
    shiny::observeEvent(context(),{
      cancel();request <<- NULL;review(NULL);saved(NULL);status("")
      if(!is.null(context()) && is.function(store$transform_request)) begin()
    },ignoreNULL=FALSE)
    shiny::observeEvent(input$discover,begin(),ignoreInit=TRUE)
    shiny::observe({
      if(!busy()) return()
      shiny::invalidateLater(250,session)
      if(job$is_alive()) return()
      busy(FALSE)
      tryCatch({
        result <- job$get_result()
        fresh <- store$transform_request(request$key,request$group_id,request$context,request$group)
        if(!identical(fresh,request)) stop("Saved inputs changed. Review candidates again.")
        if(!is.null(pending_save)) {
          record <- store$save_transform_plan(request,review(),pending_save$choices,
            expected=pending_save$expected,checked=result)
          saved(record)
          status("Transformation plan saved. The exact choices and candidate evidence are retained. Execution of selected transformations is not enabled yet.")
        } else {
          previous <- store$transform_plan(request,result)
          review(result);saved(previous)
          status(if(!is.null(previous) && isTRUE(previous$current))
            "Saved transformation plan restored. Execution of selected transformations is not enabled yet." else
            if(!is.null(previous)) "Inputs or operation resources changed. Choose again; the earlier plan is retained." else
            "Review the candidates below. Saving a plan does not run a transformation; execution integration is pending.")
        }
      },error=function(e) status(conditionMessage(e)))
      job <<- NULL;pending_save <<- NULL
    })
    output$status <- shiny::renderUI(shiny::p(role="status",class="mt-2",status()))
    output$panel <- shiny::renderUI({
      r <- review()
      if(is.null(r)) {
        if(busy()) return(shiny::p(role="status",class="small text-muted",
          "Checking source and Study datums..."))
        if(!busy() && nzchar(status())) return(shiny::div(role="status",
          shiny::p(paste("Reference compatibility could not be checked:",status())),
          shiny::actionButton(session$ns("discover"),"Retry reference check",class="btn-outline-secondary btn-sm")))
        return(NULL)
      }
      if(!any(vapply(r$groups,function(g) isTRUE(g$requires_choice),logical(1)))) return(NULL)
      shiny::tags$details(open=TRUE,class="mb-3",shiny::tags$summary("Datum transformations"),
        shiny::p("A source-to-target datum change requires an explicit operation choice."),
        shiny::actionButton(session$ns("discover"),"Refresh candidates",class="btn-outline-primary btn-sm"),
        shiny::uiOutput(session$ns("status")),shiny::uiOutput(session$ns("candidates")))
    })
    output$candidates <- shiny::renderUI({
      r <- review();if(is.null(r)) return(NULL)
      old <- saved()
      groups <- Filter(function(g) isTRUE(g$requires_choice),r$groups)
      if(!length(groups)) return(NULL)
      shiny::tagList(lapply(groups,function(g) {
        catalog <- g$catalog
        eligible <- Filter(function(c) isTRUE(c$selectable),catalog$candidates)
        selected <- ""
        if(!is.null(old) && isTRUE(old$current)) {
          found <- Filter(function(z) identical(z$group,g$key),old$record$selections)
          if(length(found) && !is.null(found[[1]]$operation)) selected <- found[[1]]$operation$key
        }
        shiny::div(class="border rounded p-3 my-3",
          shiny::h5(paste(catalog$source$name,"to",catalog$target$name)),
          shiny::p(g$explanation),shiny::p(class="small",paste(length(g$source_indices),"source DEM file(s).",
            "Area screening: entire analysis bounding box.")),
          if(length(unlist(lapply(r$observations[g$source_indices],`[[`,"messages"))))
            shiny::tags$details(shiny::tags$summary("Source metadata notices"),
              shiny::p("Reader notices are retained with the source evidence in the saved plan."),
              shiny::p(class="small",unlist(lapply(r$observations[g$source_indices],`[[`,"messages"))[1L])),
          shiny::p(class="small",paste("Search bounds (west, south, east, north):",paste(round(catalog$aoi,5),collapse=", "))),
          if(isTRUE(g$requires_choice)) shiny::tagList(
            shiny::selectInput(session$ns(paste0("choice_",g$key)),"Select the coordinate operation",
              choices=c("Choose an operation"="",stats::setNames(vapply(eligible,`[[`,character(1),"key"),
                vapply(eligible,`[[`,character(1),"description"))),selected=selected,selectize=FALSE),
            if(!length(eligible)) shiny::p("No selectable operation is available. See the reasons below.")),
          lapply(catalog$candidates,function(c) shiny::tags$details(class="mb-2",
            shiny::tags$summary(paste(c$description,"-",if(isTRUE(c$selectable)) "Locally available" else "Unavailable")),
            shiny::p(paste("Stated accuracy:",if(is.null(c$accuracy) || is.na(c$accuracy) || c$accuracy<0) "Unknown" else paste(c$accuracy,"m"))),
            if(nzchar(c$reason)) shiny::p(c$reason),
            shiny::p(if(!length(c$grids)) "No transformation grids required." else paste("Required grids:",
              paste(vapply(c$grids,function(z) paste(z$out_short_name,
                if(isTRUE(z$locally_verified)) "(available; checksum recorded)" else "(unavailable)"),character(1)),collapse="; "))),
            shiny::p(class="small",paste("Source coordinate epoch:",if(is.null(catalog$source$epoch)) "Unknown" else catalog$source$epoch,
              "| Target coordinate epoch:",if(is.null(catalog$target$epoch)) "Unknown" else catalog$target$epoch)),
            shiny::p(class="small","Catalog accuracy describes the operation, not the source DEM accuracy."),
            shiny::tags$details(shiny::tags$summary("Operation provenance"),
              shiny::pre(style="white-space:pre-wrap",c$definition)))) )
      }),shiny::actionButton(session$ns("save"),"Save transformation plan",class="btn-primary btn-sm"))
    })
    shiny::observeEvent(input$save,{
      if(busy()) return()
      tryCatch({
        r <- review();if(is.null(r)) stop("Review candidates first.")
        choices <- stats::setNames(lapply(r$groups,function(g) input[[paste0("choice_",g$key)]]),
          vapply(r$groups,`[[`,character(1),"key"))
        terrain_transform_choices(r,choices)
        pending_save <<- list(choices=choices,expected=saved()$path)
        job <<- launch(request$args);busy(TRUE)
        status("Rechecking references and operation resources before saving...")
      },error=function(e) status(paste("Plan not saved:",conditionMessage(e))))
    },ignoreInit=TRUE)
    list(review=review,status=status,busy=busy)
  })
}
