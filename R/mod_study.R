mod_study_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_columns(
    col_widths = bslib::breakpoints(sm = c(12, 12), lg = c(3, 9), xxl = c(2, 10)),
    bslib::card(
      bslib::card_header("Study workspace"),
      shiny::tabsetPanel(id = ns("workspace_task"), type = "pills", selected = "new",
        shiny::tabPanel("New", value = "new",
          shiny::textInput(ns("name"), "Study Area name", placeholder = "e.g., Papillion Creek"),
          shiny::tags$details(class = "small mb-2", shiny::tags$summary("Purpose / customer question (optional)"),
            shiny::textAreaInput(ns("notes"), "Purpose",
              placeholder = "What do you want to understand about this study area?", rows = 2)),
          shiny::actionButton(ns("create"), "Create Study Area", class = "btn-primary btn-sm")),
        shiny::tabPanel("Open", value = "open",
          shiny::selectInput(ns("saved"), "Saved studies", choices = character()),
          shiny::div(class = "d-flex gap-2 flex-wrap",
            shiny::actionButton(ns("open"), "Open study", class = "btn-primary btn-sm"),
            shiny::actionButton(ns("refresh"), "Refresh list", class = "btn-outline-secondary btn-sm")),
          shiny::uiOutput(ns("catalog_note")))),
      shiny::uiOutput(ns("message"))
    ),
    bslib::card(
      bslib::card_header("Your Study Area"),
      shiny::uiOutput(ns("summary")),
      shiny::tabsetPanel(id=ns("study_task"),type="pills",
        shiny::tabPanel("Study geometry",shiny::uiOutput(ns("boundary_editor")),shiny::uiOutput(ns("streams_editor"))),
        shiny::tabPanel("Survey Collections",mod_survey_collections_ui(ns("survey_collections"))))
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
    collections <- mod_survey_collections_server("survey_collections",current,store)
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
    attempt <- function(action) {
      tryCatch({
        study <- action()
        editor_key <<- NULL
        current(NULL) # Explicit reopen resets editors even for the same saved revision.
        current(study)
        notice(list(kind = "success", text = "Study Area saved and reopened from local storage."))
        refresh(study$key)
        shiny::updateTabsetPanel(session, "workspace_task", selected = "open")
      }, error = function(e) {
        # Avoid exposing paths or database internals in user-facing errors.
        notice(list(kind = "danger", text = paste(
          "The study could not be saved or opened. Your existing studies were not replaced.",
          "Refresh the saved list before trying again; a completed save may already be there.")))
        message("fgstudio study operation failed [", class(e)[[1]], "]")
      })
    }
    shiny::observeEvent(input$create, {
      if (!is.null(current())) {
        notice(list(kind = "info", text = "Choose Workspace - New to start a different study."))
      } else if (is.null(input$name) || !nzchar(trimws(input$name))) {
        notice(list(kind = "warning", text = "Enter a Study Area name to begin."))
      } else {
        pending_selection <<- if (is.null(editor)) NULL else editor$selection_state()
        attempt(function() store$create(input$name, if (is.null(input$notes)) "" else input$notes))
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
      notice(NULL)
      shiny::updateTextInput(session, "name", value = "")
      shiny::updateTextAreaInput(session, "notes", value = "")
    }
    shiny::observeEvent(input$workspace_task, {
      if (!identical(input$workspace_task, "new") || is.null(current())) return()
      if (collections$has_pending() || (!is.null(editor) && editor$has_unsaved()) ||
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
          shiny::span("Saved draft", class = "badge text-bg-success"),
          shiny::actionLink(session$ns("edit_name"), "Edit name"),
          shiny::actionLink(session$ns("edit_purpose"), "Edit purpose"),
          if (x$streams > 0L) shiny::actionLink(session$ns("rename_stream"), "Rename Stream"),
          if (x$reaches > 0L) shiny::actionLink(session$ns("rename_reach"), "Rename Reach")),
        compact_table(data.frame(Item = c("Purpose", "Boundary", "Streams / Reaches / Surveys", "Next"),
          Status = c(purpose, if (x$boundary) "Saved - editable" else "Not defined",
            sprintf("%d / %d / %d", x$streams, x$reaches, x$events),
            if (x$reaches > 0L) "Open Survey Collections to discover and select lidar acquisitions" else
            if (x$streams > 0L) "Choose Reaches on the map to define Reaches within a Stream" else
              if (x$boundary) "Choose Streams on the map to define a Stream" else "Select or draw a Study Area boundary")))
      )
    })
    list(current = shiny::reactive(current()), notice = shiny::reactive(notice()))
  })
}
