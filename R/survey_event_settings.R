survey_event_settings_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::p("Define a Survey Event from your saved Survey Collections and DEM choices. Confirm the survey date, Streams and output cell size."),
    shiny::uiOutput(ns("status")),
    shiny::uiOutput(ns("event_choices")),
    shiny::uiOutput(ns("definition_choices")),
    shiny::actionButton(ns("new"),"Define a Survey Event",class="btn-primary btn-sm"),
    shiny::p(class="small","Opens a review of the selected collections and dates. Nothing is saved until you choose Save Survey Event; no DEMs are downloaded or created."),
    shiny::tableOutput(ns("inventory")),
    shiny::conditionalPanel("input.group != null && input.group !== ''",ns=ns,
      event_masks_ui(ns("masks"))),
    shiny::tags$details(shiny::tags$summary("Acquisition date evidence"),shiny::tableOutput(ns("evidence"))))
}

survey_event_settings_server <- function(id,current,store,selection_path,selection_pending) {
  shiny::moduleServer(id,function(input,output,session) {
    saved <- shiny::reactiveVal(list(path=NULL,groups=list()))
    discovery <- shiny::reactiveVal(NULL); editing <- shiny::reactiveVal(FALSE)
    status <- shiny::reactiveVal("Save Survey Collection selections and the Study Area analysis CRS first.")
    edit_id <- NULL; expected <- NULL
    preflight_context <- shiny::reactive({
      if(length(input$group)!=1L) return(NULL)
      x <- current(); g <- saved()$groups[[input$group]]
      if(is.null(x) || is.null(g)) return(NULL)
      list(key=x$key,path=x$path,selection=selection_path(),group_id=g$settings$group_id,group_path=g$path,
        vertical_reference=x$vertical_reference,
        streams=x$stream_inventory[x$stream_inventory$stream_id %in% g$streams$stream_id,,drop=FALSE])
    })
    masks <- event_masks_server("masks",preflight_context,store,
      pending=function() isTRUE(editing()) || selection_pending())
    reload <- function() {
      x <- current(); editing(FALSE); shiny::removeModal(session=session)
      saved(list(path=NULL,groups=list())); discovery(NULL)
      if(is.null(x)) return()
      tryCatch({
        saved(store$acquisition_groups(x$key)); discovery(store$survey_collections(x$key)$discovery)
        status("Choose saved Survey Collections below to define a Survey Event, or select an existing Survey Event to review it.")
      },error=function(e) status(conditionMessage(e)))
    }
    shiny::observeEvent(list(current()$key,current()$path,selection_path()),reload(),ignoreNULL=FALSE)
    output$event_choices <- shiny::renderUI({
      groups <- saved()$groups
      if(!length(groups)) return(shiny::p("No Survey Events have been defined yet. Start with the saved collections below."))
      labels <- vapply(groups,function(g) paste0(g$settings$year,
        if(!is.na(g$settings$month)) sprintf("-%02d",g$settings$month) else "",
        " | ",paste(g$members$title,collapse=", ")," | ",g$settings$cell_size," ",g$settings$unit),character(1))
      shiny::tagList(shiny::selectInput(session$ns("group"),"Saved Survey Event",
        choices=stats::setNames(as.character(names(groups)),labels),selectize=FALSE,
        selected=shiny::isolate(input$group)),
        shiny::actionButton(session$ns("edit"),"Review / edit Survey Event",class="btn-outline-primary btn-sm"))
    })
    proposals <- shiny::reactive({
      if(is.null(discovery())) return(NULL)
      fluvgeo::propose_survey_acquisition_groups(discovery())
    })
    definition_options <- shiny::reactive({
      p <- proposals();if(is.null(p) || !nrow(p)) return(list())
      keys <- ifelse(is.na(p$proposed_month),paste0("collection:",p$candidate_key),paste0("month:",p$proposed_month))
      lapply(stats::setNames(unique(keys),unique(keys)),function(k) {
        rows <- p[keys==k,,drop=FALSE]
        list(members=rows$candidate_key,month=rows$proposed_month[1],
          label=paste(if(is.na(rows$proposed_month[1])) "Date needs review" else rows$proposed_month[1],
            paste(rows$title,collapse=", "),sep=" | "))
      })
    })
    output$definition_choices <- shiny::renderUI({
      options <- definition_options()
      if(!length(options)) return(shiny::p("Save selections in Survey Collections first."))
      shiny::selectInput(session$ns("definition"),"Saved Survey Collections for this Survey Event",
        choices=stats::setNames(names(options),vapply(options,`[[`,character(1),"label")),selectize=FALSE)
    })
    output$evidence <- shiny::renderTable({
      p <- proposals(); if(is.null(p)) return(NULL)
      p[c("title","catalog","record_id","acquisition_evidence","proposed_month","review")]
    },spacing="xs")
    open_editor <- function(group_id=NULL) {
      x <- current(); d <- discovery()
      if(is.null(x) || is.null(d) || is.null(x$analysis_crs)) {
        status("Save Survey Collection selections and the Study Area analysis CRS first."); return()
      }
      if(selection_pending()) { status("Save pending collection and DEM file selections first."); return() }
      g <- if(is.null(group_id)) NULL else saved()$groups[[group_id]]
      if(!is.null(group_id) && is.null(g)) { status("Choose a saved Survey Event."); return() }
      edit_id <<- group_id
      expected <<- list(context=x$path,selection=selection_path(),groups=saved()$path)
      p <- proposals(); s <- x$stream_inventory; e <- x$event_inventory
      options <- definition_options()
      choice <- if(length(input$definition)==1L) options[[input$definition]] else if(length(options)) options[[1]] else NULL
      if(is.null(g) && is.null(choice)) {status("Save Survey Collection selections first.");return()}
      month <- if(is.null(choice)) NA_character_ else choice$month
      suggested_streams <- if(!is.null(g)) g$streams$stream_id else s$stream_id[vapply(s$stream_id,function(id)
        any(vapply(choice$members,function(k) length(store$dem_files(x$key,id,k)$result$selected)>0L,logical(1))),logical(1))]
      if(is.null(g) && !length(suggested_streams) && nrow(s)==1L) suggested_streams <- s$stream_id
      ns <- session$ns
      shiny::showModal(shiny::modalDialog(title="Define a Survey Event",size="l",easyClose=FALSE,
        shiny::tags$details(shiny::tags$summary("Change the suggested collections and survey month"),
          shiny::selectInput(ns("proposal"),"Suggested survey month",choices=c("Choose a saved date suggestion"="",
            stats::setNames(sort(unique(stats::na.omit(p$proposed_month))),sort(unique(stats::na.omit(p$proposed_month))))),selectize=FALSE),
          shiny::actionButton(ns("apply_proposal"),"Use suggested collections",class="btn-outline-primary btn-sm")),
        shiny::checkboxGroupInput(ns("members"),"Survey Collections",choices=stats::setNames(p$candidate_key,
          paste(p$title,p$date_label,p$review,sep=" | ")),selected=if(!is.null(g)) g$members$candidate_key else choice$members),
        shiny::checkboxGroupInput(ns("streams"),"Streams supplied by this acquisition",choices=stats::setNames(as.character(s$stream_id),s$stream_name),
          selected=suggested_streams),
        bslib::layout_columns(
          shiny::numericInput(ns("year"),"Survey year",value=if(!is.null(g)) g$settings$year else if(!is.na(month)) as.integer(substr(month,1,4)) else NA,min=1,max=9999,step=1),
          shiny::selectInput(ns("month"),"Month / precision",choices=c("Unknown (year only)"="",stats::setNames(1:12,month.name)),
            selected=if(!is.null(g)) {if(is.na(g$settings$month)) "" else as.character(g$settings$month)} else if(!is.na(month)) as.character(as.integer(substr(month,6,7))) else ""),
          shiny::numericInput(ns("cell_size"),paste("Output cell size (",x$analysis_crs$unit,")"),
            value=if(is.null(g)) NA else g$settings$cell_size,min=0)),
        shiny::checkboxGroupInput(ns("events"),"Link existing Reach Events (optional)",
          choices=stats::setNames(as.character(e$survey_event_id),if(is.null(e)) character() else
            paste(x$reach_inventory$reach_name[match(e$reach_id,x$reach_inventory$reach_id)],
              e$survey_year,substr(e$survey_event_id,1,8),sep=" | ")),
          selected=if(!is.null(g)) g$event_links$survey_event_id),
        shiny::p(class="small","One Study Area CRS and fixed (0, 0) anchor apply. Equal cell sizes align across Events. Finer output cells do not improve source information. This saves the local Survey Event definition; FGDB Reach Event records are not created here."),
        shiny::uiOutput(ns("editor_status")),
        footer=shiny::tagList(shiny::actionButton(ns("discard"),"Cancel"),
          shiny::actionButton(ns("save"),"Save Survey Event",class="btn-success"))),session=session)
      editing(TRUE)
    }
    shiny::observeEvent(input$new,open_editor(),ignoreInit=TRUE)
    shiny::observeEvent(input$edit,open_editor(input$group),ignoreInit=TRUE)
    shiny::observeEvent(input$discard,{ editing(FALSE); shiny::removeModal(session=session) },ignoreInit=TRUE)
    shiny::observeEvent(input$apply_proposal,{
      if(!editing() || !nzchar(input$proposal)) return()
      p <- proposals(); m <- input$proposal
      shiny::updateCheckboxGroupInput(session,"members",selected=p$candidate_key[!is.na(p$proposed_month) & p$proposed_month==m])
      shiny::updateNumericInput(session,"year",value=as.integer(substr(m,1,4)))
      shiny::updateSelectInput(session,"month",selected=as.character(as.integer(substr(m,6,7))))
    },ignoreInit=TRUE)
    shiny::observeEvent(input$save,{
      if(!editing()) return()
      tryCatch({
        if(selection_pending()) stop("Save pending collection choices first.")
        next_saved <- store$save_acquisition_group(current()$key,
          members=if(is.null(input$members)) character() else input$members,
          stream_ids=if(is.null(input$streams)) character() else input$streams,
          year=input$year,month=if(is.null(input$month) || !nzchar(input$month)) NA_integer_ else as.integer(input$month),
          cell_size=input$cell_size,rationale=if(is.null(edit_id)) "" else saved()$groups[[edit_id]]$settings$rationale,
          event_ids=if(is.null(input$events)) character() else input$events,group_id=edit_id,
          expected_path=expected$context,expected_selection=expected$selection,expected_groups=expected$groups)
        selected <- if(!is.null(edit_id)) edit_id else setdiff(names(next_saved$groups),names(saved()$groups))[1]
        saved(next_saved); editing(FALSE); shiny::removeModal(session=session)
        shiny::updateSelectInput(session,"group",selected=selected)
        status("Event settings saved. Prior revisions and acquisition evidence are retained.")
      },error=function(e) status(paste("Event settings not saved:",conditionMessage(e))))
    },ignoreInit=TRUE)
    output$status <- shiny::renderUI(shiny::div(role="status",status()))
    output$editor_status <- shiny::renderUI(shiny::div(role="status",status()))
    output$inventory <- shiny::renderTable({
      groups <- saved()$groups; if(!length(groups)) return(NULL)
      do.call(rbind,lapply(groups,function(g) data.frame(Year=g$settings$year,Month=g$settings$month,
        Cell_size=g$settings$cell_size,Unit=g$settings$unit,Collections=nrow(g$members),Streams=nrow(g$streams),
        Reach_events=nrow(g$event_links),Review=if(is.null(current()$analysis_crs) ||
          !identical(g$settings$wkt,current()$analysis_crs$wkt) ||
          !identical(g$settings$selection_revision,basename(selection_path()))) "Changed setup: review required" else "Saved")))
    },spacing="xs")
    list(has_pending=function() isTRUE(shiny::isolate(editing())),status=status)
  })
}
