# Name editing is separate from segment selection; no geometry is submitted.
study_feature_names <- function(input, output, session, current, store, has_pending, on_saved,
                                on_focus = function(shape) NULL) {
  target <- shiny::reactiveVal(NULL); problem <- shiny::reactiveVal(NULL)
  start <- function(level) {
    x <- current(); if (is.null(x)) return()
    if (has_pending()) {
      shiny::showNotification("Save or Clear unfinished selections before renaming.", type = "warning")
      return()
    }
    inventory <- x[[paste0(level,"_inventory")]]
    if (is.null(inventory) || !nrow(inventory)) return()
    target(list(study = x, level = level)); problem(NULL)
    shiny::showModal(shiny::modalDialog(title = paste("Rename", level),
      shiny::selectInput(session$ns("feature_name_id"), "Saved record",
        saved_feature_choices(x, level)),
      shiny::uiOutput(session$ns("feature_name_field")),
      shiny::uiOutput(session$ns("feature_name_error")),
      shiny::p(class = "small", "Only the name changes. Geometry, identity and associated records stay unchanged."),
      footer = shiny::tagList(shiny::modalButton("Cancel"),
        shiny::actionButton(session$ns("save_feature_name"), "Save name", class = "btn-primary"))))
  }
  shiny::observeEvent(input$rename_stream, start("stream"), ignoreInit = TRUE)
  shiny::observeEvent(input$rename_reach, start("reach"), ignoreInit = TRUE)
  shiny::observeEvent(list(target(), input$feature_name_id), {
    t <- target(); x <- current()
    if (is.null(t) || is.null(x) || !identical(t$study$path, x$path)) return()
    on_focus(saved_feature_shape(x, t$level, input$feature_name_id))
  })
  output$feature_name_field <- shiny::renderUI({
    t <- target(); if (is.null(t)) return(NULL)
    x <- t$study[[paste0(t$level,"_inventory")]]
    j <- match(input$feature_name_id,x[[paste0(t$level,"_id")]])
    if (length(j) != 1L || is.na(j)) return(NULL)
    shiny::textInput(session$ns("feature_new_name"), "Name", value = x[[paste0(t$level,"_name")]][j])
  })
  output$feature_name_error <- shiny::renderUI({
    if (!is.null(problem())) shiny::p(role = "alert", problem())
  })
  shiny::observeEvent(input$save_feature_name, {
    t <- target(); x <- current()
    if (is.null(t) || is.null(x)) return()
    tryCatch({
      if (!identical(t$study$path,x$path)) stop("Study changed. Reopen Rename to use the current revision.")
      if (has_pending()) stop("Save or Clear unfinished selections before renaming.")
      saved <- store$rename_feature(x$key,t$level,input$feature_name_id,input$feature_new_name,x$path)
      target(NULL); shiny::removeModal(); on_saved(saved)
    }, error = function(e) problem(conditionMessage(e)))
  }, ignoreInit = TRUE)
  list(target = target, problem = problem)
}
