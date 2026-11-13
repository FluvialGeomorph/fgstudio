mod_study_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    fillable = FALSE, fill = FALSE,
    sidebar = bslib::sidebar(id = ns("workspace_sidebar"), title = "Study Workspace",
      width = 260, open = "open",
      shiny::tabsetPanel(id = ns("workspace_task"), type = "tabs", selected = "new",
        shiny::tabPanel("New", value = "new",
          shiny::textInput(ns("name"), "Study Area name", placeholder = "e.g., Papillion Creek"),
          shiny::tags$details(class = "small mb-2", shiny::tags$summary("Purpose / customer question (optional)"),
            shiny::textAreaInput(ns("notes"), "Purpose",
              placeholder = "What do you want to understand about this study area?", rows = 2)),
          shiny::actionButton(ns("create"), "Create Study Area", class = "btn-primary btn-sm")),
        shiny::tabPanel("Open", value = "open",
          shiny::selectInput(ns("saved"), "Saved studies", choices = character()),
          shiny::div(class = "d-flex gap-2 flex-wrap",
            shiny::actionButton(ns("open"), "Open study", class = "btn-primary btn-sm fg-open-study"),
            shiny::actionButton(ns("refresh"), "Refresh list", class = "btn-outline-secondary btn-sm")),
          shiny::uiOutput(ns("catalog_note")))),
      shiny::uiOutput(ns("message"))
    ),
    bslib::card(
      bslib::card_header("Study Workspace"),
      shiny::uiOutput(ns("summary")),
      shiny::div(class = "fg-study-tabs", shiny::tabsetPanel(id=ns("study_task"),type="tabs",
        shiny::tabPanel("Overview",value="Study overview",shiny::uiOutput(ns("overview"))),
        shiny::tabPanel("Study Structure",value="Study structure",shiny::uiOutput(ns("boundary_editor")),shiny::uiOutput(ns("streams_editor"))),
        shiny::tabPanel("Collections",value="Survey Collections",mod_survey_collections_ui(ns("survey_collections"))),
        shiny::tabPanel("Analysis CRS",value="Analysis CRS",shiny::tabsetPanel(type="tabs",
          shiny::tabPanel("Horizontal CRS",study_analysis_crs_ui(ns("analysis_crs"))),
          shiny::tabPanel("Vertical Reference",study_vertical_reference_ui(ns("vertical_reference")))),
          shiny::actionButton(ns("continue_event"), "Continue to Survey Events", class="btn-primary")),
        shiny::tabPanel("Survey Events",value="Define a Survey Event",survey_event_settings_ui(ns("event_settings"))),
        shiny::tabPanel("Hydro Modify",value="Hydro Modify",hydro_modify_ui(ns("hydro"))),
        shiny::tabPanel("Flowline",value="Flowline",flowline_review_ui(ns("flowline"))),
        shiny::tabPanel("Flowline Points",value="Flowline Points",
          flowline_points_review_ui(ns("flowline_points")))))
    )
  )
}

mod_study_server <- function(id, store) {
  shiny::moduleServer(id, function(input, output, session) {
    current <- shiny::reactiveVal(NULL)
    notice <- shiny::reactiveVal(NULL)
    catalog_state <- shiny::reactiveVal(NULL)
    rename_target <- shiny::reactiveVal(NULL)
    rename_error <- shiny::reactiveVal(NULL)
    purpose_target <- shiny::reactiveVal(NULL)
    purpose_error <- shiny::reactiveVal(NULL)
    editor <- NULL
    streams_editor <- NULL
    editor_key <- NULL
    generation <- 0L
    pending_selection <- NULL
    hydro_revision <- shiny::reactiveVal(0L)
    flowline_revision <- shiny::reactiveVal(0L)
    advance <- function(value) value(shiny::isolate(value()) + 1L)
    collections <- mod_survey_collections_server("survey_collections",current,store)
    event_settings <- survey_event_settings_server("event_settings",current,store,
      collections$selection_path,collections$has_pending)
    next_definition_tab <- shiny::reactive({
      x <- current()
      if(is.null(x) || !isTRUE(x$boundary) || x$streams < 1L || x$reaches < 1L)
        return("Study structure")
      if(is.null(collections$selection_path())) return("Survey Collections")
      if(is.null(x$analysis_crs) || is.null(x$vertical_reference))
        return("Analysis CRS")
      if(!length(event_settings$choices())) return("Define a Survey Event")
      "Hydro Modify"
    })
    hydro_modify_server("hydro",current,event_settings$context,store,
      active=function() identical(input$study_task,"Hydro Modify"),events=event_settings,
      on_changed=function() {advance(hydro_revision);advance(flowline_revision)})
    flowline_review_server("flowline",current,event_settings$context,store,
      active=function() identical(input$study_task,"Flowline"),events=event_settings,
      revision=hydro_revision,on_changed=function() advance(flowline_revision))
    flowline_points_review_server("flowline_points",current,event_settings$context,
      store,active=function() identical(input$study_task,"Flowline Points"),
      events=event_settings,revision=shiny::reactive(paste(hydro_revision(),
        flowline_revision(),sep=":")))
    shiny::observeEvent(input$continue_event,
      shiny::updateTabsetPanel(session,"study_task",selected="Define a Survey Event"),ignoreInit=TRUE)
    analysis_pending <- function() collections$has_pending() || event_settings$has_pending() ||
        (!is.null(editor) && editor$has_unsaved()) ||
        (!is.null(streams_editor) && any(nzchar(unlist(streams_editor$draft()))))
    study_vertical_reference_server("vertical_reference",current,store,has_pending=analysis_pending,
      on_saved=function(x) {
        current(x); refresh(x$key)
        notice(list(kind="success",text="Vertical specification saved. Elevations and source references are unchanged."))
      })
    study_analysis_crs_server("analysis_crs", current, store,
      has_pending = analysis_pending,
      on_saved = function(x) {
        current(x); refresh(x$key)
        notice(list(kind = "success", text = "Analysis CRS saved. Earlier revisions were retained."))
      })
    feature_names <- study_feature_names(input, output, session, current, store,
      on_focus = function(shape) if (!is.null(editor)) editor$focus_feature(shape),
      has_pending = function() (!is.null(editor) && editor$has_unsaved()) ||
        (!is.null(streams_editor) && any(nzchar(unlist(streams_editor$draft())))),
      on_saved = function(x) {
        current(x); refresh(x$key)
        notice(list(kind = "success", text = "Name saved. Geometry, identities and associated records are unchanged."))
      })
    shiny::observeEvent(current(), {
      x <- current()
      selection_draft <- if (!is.null(editor) && !is.null(x) && identical(editor_key, x$key))
        editor$selection_state() else pending_selection
      pending_selection <<- NULL
      stream_draft <- if (!is.null(streams_editor) && !is.null(x) && identical(editor_key, x$key))
        streams_editor$draft() else list(names = "", rationale = "")
      if (!is.null(editor)) editor$destroy()
      if (!is.null(streams_editor)) streams_editor$destroy()
      if (is.null(x)) {
        editor <<- mod_boundary_server("preview_map", list(boundary_sf = NULL), NULL,
          is_active = function() is.null(shiny::isolate(current())),
          on_saved = function(x) stop("Exploration cannot save."), exploration_only = TRUE)
        output$boundary_editor <- shiny::renderUI(mod_boundary_ui(session$ns("preview_map"), exploration_only = TRUE))
        output$streams_editor <- shiny::renderUI(NULL)
        editor_key <<- NULL
        return()
      }
      editor_key <<- x$key
      generation <<- generation + 1L
      editor_id <- paste0("boundary_", generation)
      editor <<- mod_boundary_server(editor_id, x, store,
        is_active = function() {
          active <- shiny::isolate(current())
          !is.null(active) && identical(active$key, x$key) && identical(active$path, x$path)
        }, on_saved = function(study) {
          current(study)
          notice(list(kind = "success", text = "Geometry saved. Earlier revisions were retained."))
        }, selection_draft = selection_draft)
      output$boundary_editor <- shiny::renderUI(mod_boundary_ui(session$ns(editor_id), selection_draft = selection_draft, study = x))
      streams_id <- paste0("streams_", generation)
      streams_editor <<- mod_streams_server(streams_id, x, store,
        is_active = function() {
          active <- shiny::isolate(current())
          !is.null(active) && identical(active$key, x$key) && identical(active$path, x$path)
        }, boundary_pending = function() !is.null(editor) && editor$has_unsaved(),
        on_saved = function(study) {
          current(study)
          refresh(study$key)
          notice(list(kind = "success", text = "Streams saved under this Study Area. Earlier revisions were retained."))
        })
      output$streams_editor <- shiny::renderUI(mod_streams_ui(session$ns(streams_id), x, stream_draft))
    }, ignoreNULL = FALSE)
    refresh <- function(selected = character()) {
      listing <- store$catalog()
      catalog_state(listing)
      shiny::updateSelectInput(session, "saved", choices = listing$choices, selected = selected)
    }
    shiny::observeEvent(TRUE, refresh(), once = TRUE)
    remember_study <- function(key=NULL) {
      query <- shiny::parseQueryString(session$clientData$url_search)
      query$study <- key
      fields <- if (length(query)) paste0(utils::URLencode(names(query),reserved=TRUE),"=",
        vapply(query,utils::URLencode,character(1),reserved=TRUE)) else character()
      shiny::updateQueryString(paste0("?",paste(fields,collapse="&")),mode="replace",session=session)
    }
    attempt <- function(action, destination="Study overview") {
      tryCatch({
        study <- action()
        editor_key <<- NULL
        current(NULL) # Explicit reopen resets editors even for the same saved revision.
        current(study)
        notice(list(kind = "success", text = "Study Area saved and reopened from local storage."))
        refresh(study$key)
        shiny::updateTabsetPanel(session, "workspace_task", selected = "open")
        shiny::updateTabsetPanel(session, "study_task", selected = destination)
        remember_study(study$key)
      }, error = function(e) {
        # Avoid exposing paths or database internals in user-facing errors.
        notice(list(kind = "danger", text = paste(
          "The study could not be saved or opened. Your existing studies were not replaced.",
          "Refresh the saved list before trying again; a completed save may already be there.")))
        message("fgstudio study operation failed [", class(e)[[1]], "]")
      })
    }
    restore_study <- function(search) {
      key <- shiny::parseQueryString(search)$study
      if (is.null(key)) return(invisible(NULL))
      attempt(function() store$read(key))
    }
    # The per-tab URL identifies saved data, never unsaved form state or a path.
    # Restore once after initial inputs; later query updates must not reopen it.
    shiny::observeEvent(session$clientData$url_search, {
      restore_study(session$clientData$url_search)
    },once=TRUE,priority=-1)
    shiny::observeEvent(input$create, {
      if (!is.null(current())) {
        notice(list(kind = "info", text = "Choose Workspace - New to start a different study."))
      } else if (is.null(input$name) || !nzchar(trimws(input$name))) {
        notice(list(kind = "warning", text = "Enter a Study Area name to begin."))
      } else {
        pending_selection <<- if (is.null(editor)) NULL else editor$selection_state()
        attempt(function() store$create(input$name, if (is.null(input$notes)) "" else input$notes),
          destination="Study structure")
      }
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$open, {
      pending_selection <<- NULL
      if (is.null(input$saved) || !nzchar(input$saved)) {
        notice(list(kind = "warning", text = "Choose a saved Study Area first."))
      } else {
        attempt(function() store$read(input$saved))
      }
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$refresh, refresh(), ignoreInit = TRUE)
    shiny::observeEvent(input$edit_name, {
      x <- current()
      if (is.null(x)) return()
      if (!is.null(editor) && editor$has_unsaved()) {
        notice(list(kind = "warning", text = "Save your boundary changes before editing the name, or reopen the study to discard the drawing changes."))
        return()
      }
      rename_target(x)
      rename_error(NULL)
      shiny::showModal(shiny::modalDialog(title = "Edit Study Area name",
        shiny::textInput(session$ns("new_name"), "Study Area name", value = x$name),
        shiny::uiOutput(session$ns("rename_error")),
        footer = shiny::tagList(shiny::modalButton("Cancel"),
          shiny::actionButton(session$ns("save_name"), "Save name", class = "btn-primary"))))
    }, ignoreInit = TRUE)
    output$rename_error <- shiny::renderUI({
      if (!is.null(rename_error())) shiny::p(role = "alert", rename_error())
    })
    shiny::observeEvent(input$save_name, {
      target <- rename_target()
      x <- current()
      if (is.null(target) || is.null(x) || !identical(target$path, x$path)) return()
      if (is.null(input$new_name) || !nzchar(trimws(input$new_name))) {
        rename_error("Enter a Study Area name.")
        return()
      }
      tryCatch({
        saved <- store$rename(x$key, input$new_name, x$path)
        current(saved)
        refresh(saved$key)
        notice(list(kind = "success", text = "Study Area name saved. Its identity and boundary are unchanged."))
        rename_target(NULL)
        shiny::removeModal()
      }, error = function(e) rename_error("Name could not be saved. Reopen the study before retrying; earlier revisions were retained."))
    }, ignoreInit = TRUE)
    start_new <- function() {
      pending_selection <<- NULL
      current(NULL)
      remember_study()
      notice(NULL)
      shiny::updateTextInput(session, "name", value = "")
      shiny::updateTextAreaInput(session, "notes", value = "")
    }
    shiny::observeEvent(input$workspace_task, {
      if (!identical(input$workspace_task, "new") || is.null(current())) return()
      if (collections$has_pending() || event_settings$has_pending() || (!is.null(editor) && editor$has_unsaved()) ||
          (!is.null(streams_editor) && any(nzchar(unlist(streams_editor$draft()))))) {
        shiny::updateTabsetPanel(session, "workspace_task", selected = "open")
        shiny::showModal(shiny::modalDialog(title = "Start a new study?",
          "Your saved study is safe. Unsaved drawing, selections and form entries will be discarded.",
          footer = shiny::tagList(shiny::modalButton("Keep working"),
            shiny::actionButton(session$ns("confirm_new"), "Discard draft and start new", class = "btn-primary"))))
      } else start_new()
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$confirm_new, {
      start_new()
      shiny::removeModal()
      shiny::updateTabsetPanel(session, "workspace_task", selected = "new")
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$edit_purpose, {
      x <- current()
      if (is.null(x)) return()
      if (!is.null(editor) && editor$has_unsaved()) {
        notice(list(kind = "warning", text = "Save your boundary changes before editing Purpose, or reopen the study to discard the drawing changes."))
        return()
      }
      purpose_target(x)
      purpose_error(NULL)
      shiny::showModal(shiny::modalDialog(title = "Edit Study Area purpose",
        shiny::textAreaInput(session$ns("new_purpose"), "Purpose / customer question (optional)",
          value = if (is.na(x$purpose)) "" else x$purpose, rows = 4),
        shiny::p("Update the current question or leave it blank. Earlier revisions and supporting notes are retained."),
        shiny::uiOutput(session$ns("purpose_error")),
        footer = shiny::tagList(shiny::modalButton("Cancel"),
          shiny::actionButton(session$ns("save_purpose"), "Save purpose", class = "btn-primary"))))
    }, ignoreInit = TRUE)
    output$purpose_error <- shiny::renderUI({
      if (!is.null(purpose_error())) shiny::p(role = "alert", purpose_error())
    })
    shiny::observeEvent(input$save_purpose, {
      target <- purpose_target(); x <- current()
      if (is.null(target) || is.null(x) || !identical(target$path, x$path)) return()
      tryCatch({
        saved <- store$set_purpose(x$key, input$new_purpose, x$path)
        current(saved)
        refresh(saved$key)
        notice(list(kind = "success", text = "Study Area purpose saved. Earlier revisions and supporting notes were retained."))
        purpose_target(NULL)
        shiny::removeModal()
      }, error = function(e) purpose_error("Purpose could not be saved. Reopen the study before retrying; earlier revisions were retained."))
    }, ignoreInit = TRUE)
    output$message <- shiny::renderUI({
      x <- notice()
      if (!is.null(x)) shiny::div(class = paste0("alert alert-", x$kind), role = "status", x$text)
    })
    output$catalog_note <- shiny::renderUI({
      x <- catalog_state()
      if (is.null(x)) return(NULL)
      shiny::tagList(
        if (!length(x$choices)) shiny::p("No saved studies yet."),
        if (x$unreadable > 0L) shiny::p(role = "status",
          "Some study folders could not be read. They have been retained; ask the developer to inspect them."))
    })
    output$summary <- shiny::renderUI({
      x <- current()
      if (is.null(x)) return(compact_table(data.frame(Step = c("Explore", "Create", "Save"),
        Action = c("Find and select candidates below", "Name the study in New; map/results/choices carry forward", "Preview and save the boundary"))))
      purpose <- if (is.null(x$purpose) || is.na(x$purpose) || !nzchar(x$purpose)) "No purpose recorded yet." else x$purpose
      shiny::tagList(
        shiny::div(class = "d-flex align-items-baseline gap-3 flex-wrap",
          shiny::tags$h2(x$name, class = "h4 mb-0"),
          shiny::span("Saved locally", class = "badge text-bg-success")),
        shiny::p(class="mb-1",shiny::strong("Purpose: "),purpose),
        shiny::tags$details(class="small mb-2",shiny::tags$summary("Change names or purpose"),
          shiny::div(class="d-flex gap-3 flex-wrap mt-2",
            shiny::actionLink(session$ns("edit_name"), "Edit Study Area name"),
            shiny::actionLink(session$ns("edit_purpose"), "Edit purpose"),
            if (x$streams > 0L) shiny::actionLink(session$ns("rename_stream"), "Rename Stream"),
            if (x$reaches > 0L) shiny::actionLink(session$ns("rename_reach"), "Rename Reach")))
      )
    })
    output$overview <- shiny::renderUI({
      x <- current()
      if(is.null(x)) return(shiny::tagList(
        shiny::tags$h3("Start a Study Area",class="h5"),
        shiny::p("Use New to name the Study Area. FG Studio will then open Study Structure so you can define its boundary, Streams, and Reaches.")))
      streams <- if(is.null(x$stream_inventory)) data.frame() else sf::st_drop_geometry(x$stream_inventory)
      reaches <- if(is.null(x$reach_inventory)) data.frame() else sf::st_drop_geometry(x$reach_inventory)
      structure <- if(!nrow(streams)) data.frame(Stream="Not defined",Reaches="Not defined") else
        data.frame(Stream=streams$stream_name,Reaches=vapply(streams$stream_id,function(id) {
          names <- sort(reaches$reach_name[reaches$stream_id==id])
          if(length(names)) paste(names,collapse=", ") else "Not defined"
        },character(1)))
      event_labels <- names(event_settings$choices())
      event_overview <- event_settings$overview()
      vertical <- if(is.null(x$vertical_reference)) "Not defined" else
        paste0(x$vertical_reference$reference_name[1]," (",
          gsub("_"," ",x$vertical_reference$elevation_unit[1],fixed=TRUE),")")
      destination <- next_definition_tab()
      next_label <- switch(destination,
        "Study structure"="Continue defining Study Structure",
        "Survey Collections"="Continue with Survey Collections",
        "Analysis CRS"="Continue with Analysis CRS",
        "Define a Survey Event"="Continue with Survey Events",
        "Continue to Hydro Modify")
      shiny::tagList(
        shiny::div(class="alert alert-light border",role="note",
          shiny::tags$h3("Review this Study",class="h5"),
          shiny::p(class="mb-0","This page summarizes the saved definition. Open a workflow tab for its maps and evidence; use the continuation button only when you intend to add or change the definition.")),
        bslib::card(bslib::card_header("Study Area, Streams, and Reaches"),
          leaflet::leafletOutput(session$ns("overview_map"),height="520px")),
        bslib::layout_columns(col_widths=c(6,6),
          bslib::card(bslib::card_header("Saved definition"),
            compact_table(data.frame(Item=c("Boundary","Streams / Reaches","Survey Collections","Horizontal CRS","Vertical reference","Survey Events"),
              Selection=c(if(isTRUE(x$boundary)) "Saved" else "Not defined",
                sprintf("%d / %d",x$streams,x$reaches),
                if(is.null(collections$selection_path())) "Not selected" else "Saved selections",
                if(is.null(x$analysis_crs)) "Not defined" else x$analysis_crs$name,
                vertical,if(length(event_labels)) paste(event_labels,collapse=", ") else "Not defined")))),
          bslib::card(bslib::card_header("Stream and Reach structure"),compact_table(structure))),
        if(nrow(event_overview)) bslib::card(
          bslib::card_header("Survey Event definitions"),
          compact_table(event_overview)),
        shiny::tags$h3("Review details",class="h5 mt-3"),
        shiny::p("Use the tabs above to inspect the saved maps, source evidence, settings, and derived results. Editing controls remain with the definition they change."),
        shiny::tags$h3("Continue defining or updating",class="h5"),
        shiny::p("FG Studio identified the next incomplete or downstream step from the saved definition. You can also open any tab above directly."),
        shiny::actionButton(session$ns("continue_definition"),next_label,class="btn-primary"))
    })
    output$overview_map <- leaflet::renderLeaflet({
      x <- current()
      map <- fg_leaflet() |>
        leaflet::addProviderTiles(leaflet::providers$OpenStreetMap,group="Street map") |>
        add_opentopomap()
      if(is.null(x) || !inherits(x$boundary_sf,"sf")) return(map)
      boundary <- sf::st_transform(x$boundary_sf,4326)
      bounds <- sf::st_bbox(boundary)
      map <- leaflet::addPolygons(map,data=boundary,group="Study Area",
        color="#222222",weight=3,fillOpacity=.02,label=x$name,
        options=leaflet::pathOptions(interactive=TRUE,bubblingMouseEvents=FALSE))
      map <- saved_feature_layers(map,x,identify=TRUE) |>
        leaflet::addLayersControl(baseGroups=c("Street map","OpenTopoMap"),
          overlayGroups=c("Study Area","Saved Streams","Saved Reaches"),
          options=leaflet::layersControlOptions(collapsed=TRUE)) |>
        leaflet::fitBounds(bounds[[1]],bounds[[2]],bounds[[3]],bounds[[4]],
          options=list(padding=c(20,20)))
      map
    })
    shiny::observeEvent(input$continue_definition,
      shiny::updateTabsetPanel(session,"study_task",selected=next_definition_tab()),
      ignoreInit=TRUE)
    list(current = shiny::reactive(current()), notice = shiny::reactive(notice()))
  })
}
