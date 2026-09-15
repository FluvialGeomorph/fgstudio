mod_study_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_columns(
    col_widths = c(4, 8),
    bslib::card(
      bslib::card_header("1. Start a Study Area"),
      shiny::p("Give your study a working name. Its geographic scope can come next."),
      shiny::textInput(ns("name"), "Study Area name", placeholder = "e.g., Papillion Creek"),
      shiny::textAreaInput(ns("notes"), "Purpose / customer question (optional)",
        placeholder = "What do you want to understand about this study area?", rows = 4),
      shiny::actionButton(ns("create"), "Create Study Area", class = "btn-primary"),
      shiny::uiOutput(ns("message")),
      shiny::tags$hr(),
      shiny::tags$h3("Continue a saved study", class = "h5"),
      shiny::selectInput(ns("saved"), "Saved in this local workspace", choices = character()),
      bslib::layout_columns(
        shiny::actionButton(ns("open"), "Open study"),
        shiny::actionButton(ns("refresh"), "Refresh list")),
      shiny::uiOutput(ns("catalog_note"))
    ),
    bslib::card(
      bslib::card_header("Your Study Area"),
      shiny::uiOutput(ns("summary")),
      shiny::uiOutput(ns("boundary_editor")),
      shiny::uiOutput(ns("streams_editor"))
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
    shiny::observeEvent(current(), {
      x <- current()
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
          notice(list(kind = "success", text = "Boundary saved. The previous Study Area revision was retained."))
        })
      output$boundary_editor <- shiny::renderUI(mod_boundary_ui(session$ns(editor_id)))
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
        notice(list(kind = "info", text = "A study is already open. Choose 'Start another study' before creating a new one."))
      } else if (is.null(input$name) || !nzchar(trimws(input$name))) {
        notice(list(kind = "warning", text = "Enter a Study Area name to begin."))
      } else {
        attempt(function() store$create(input$name, if (is.null(input$notes)) "" else input$notes))
      }
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$open, {
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
    shiny::observeEvent(input$another, {
      current(NULL)
      notice(NULL)
      shiny::updateTextInput(session, "name", value = "")
      shiny::updateTextAreaInput(session, "notes", value = "")
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
      if (is.null(x)) return(shiny::tagList(
        shiny::tags$h2("Begin with the study, not the files"),
        shiny::p("Create a Study Area or open a saved draft to continue."),
        shiny::tags$h3("A small first step", class = "h5"),
        shiny::p("No DEM, coordinate system, boundary or completed project hierarchy is needed to start."),
        shiny::p("This first working increment saves your study definition. It does not run an L1 analysis.")))
      purpose <- if (is.null(x$purpose) || is.na(x$purpose) || !nzchar(x$purpose)) "No purpose recorded yet." else x$purpose
      shiny::tagList(
        shiny::span("Saved draft", class = "badge text-bg-success"),
        shiny::div(class = "d-flex align-items-baseline gap-3 flex-wrap",
          shiny::tags$h2(x$name),
          shiny::actionLink(session$ns("edit_name"), "Edit name")),
        shiny::p(purpose, style = "white-space: pre-wrap; overflow-wrap: anywhere;"),
        shiny::actionLink(session$ns("edit_purpose"), "Edit purpose"),
        shiny::tags$h3("What is known", class = "h5"),
        shiny::tags$ul(
          shiny::tags$li("Your Study Area has a stable identity and a saved local record."),
          shiny::tags$li("Boundary: ", if (x$boundary) "recorded" else "not defined yet"),
          shiny::tags$li(sprintf("Recorded: %d Streams, %d Reaches, %d Survey Events.",
            x$streams, x$reaches, x$events))),
        bslib::card(
          bslib::card_header("What comes next"),
          shiny::p(if (x$streams > 0L) "Your Stream inventory is saved. Next we will define spatial extents and Reach divisions." else
            "Define the initial Streams using the form below the map. A Study Area boundary may be drawn before or after naming Streams."),
          shiny::p("Use Explore drainage on the map to compare reference watersheds and channels. Adopting those geometries and defining Reaches are not implemented yet.")),
        shiny::tags$details(shiny::tags$summary("Saved record details"),
          if (!is.na(x$notes)) shiny::p(x$notes, style = "white-space: pre-wrap; overflow-wrap: anywhere;"),
          shiny::p("Study Area ID: ", shiny::tags$code(x$study_id)),
          shiny::p("Stored as a GeoPackage on the computer running FG Studio. This is not an FGDB submission.")),
        shiny::actionButton(session$ns("another"), "Start another study")
      )
    })
    list(current = shiny::reactive(current()), notice = shiny::reactive(notice()))
  })
}
