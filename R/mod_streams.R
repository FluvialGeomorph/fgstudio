# Text entry is a proposed inventory, not a geocoder result or derived network.
stream_names_input <- function(text) {
  if (!is.character(text) || length(text) != 1L || is.na(text))
    stop("Enter at least one Stream name.", call. = FALSE)
  names <- trimws(strsplit(text, "[\r\n]+")[[1]])
  names <- names[nzchar(names)]
  if (!length(names)) stop("Enter at least one Stream name.", call. = FALSE)
  if (anyDuplicated(tolower(names)))
    stop("Each Stream needs a different name. Remove duplicate names before saving.", call. = FALSE)
  names
}

mod_streams_ui <- function(id, study, draft = list(names = "", rationale = "")) {
  ns <- shiny::NS(id)
  bslib::card(
    bslib::card_header("3. Define Streams"),
    if (isTRUE(study$can_define_streams)) shiny::tagList(
      shiny::p("Which Streams belong in this study? Enter the initial set below. Names establish the study inventory; Stream areas and channel lines can be defined separately."),
      shiny::textAreaInput(ns("names"), "Stream names (one per line)", value = draft$names,
        placeholder = "Cole Creek\nAnother Creek", rows = 3),
      shiny::textInput(ns("rationale"), "Why these Streams? (optional)", value = draft$rationale,
        placeholder = "For example: Streams requested by the customer"),
      shiny::p(class = "small text-body-secondary", "Review the full initial list before saving. Adding, renaming or removing Streams after this first save is not implemented yet."),
      shiny::actionButton(ns("save"), "Save Streams", class = "btn-primary")
    ) else if (study$streams > 0L) shiny::tagList(
      shiny::p(paste("Saved Streams in", study$name)),
      shiny::tableOutput(ns("inventory")),
      shiny::p("Stream identities and their Study Area links are saved. Next: define the Streams' spatial extents and Reach divisions; names alone do not provide analysis geometry."),
      shiny::p(class = "small text-body-secondary", "Changing this saved inventory is a later editing step. It will not be replaced by another initial definition.")
    ) else shiny::p("This study already has related hierarchy or network records. Initial Stream definition cannot safely replace them."),
    shiny::uiOutput(ns("status"))
  )
}

mod_streams_server <- function(id, study, store, is_active, boundary_pending, on_saved) {
  shiny::moduleServer(id, function(input, output, session) {
    status <- shiny::reactiveVal(NULL)
    saved_once <- FALSE
    output$inventory <- shiny::renderTable({
      x <- study$stream_inventory
      if (is.null(x) || !nrow(x)) return(NULL)
      data.frame(Stream = x$stream_name,
        Area = if (inherits(x, "sf")) "Recorded" else "Not defined")
    }, striped = TRUE, spacing = "xs", width = "100%", rownames = FALSE)
    saving <- shiny::observeEvent(input$save, {
      if (!is_active() || saved_once || !isTRUE(study$can_define_streams)) return()
      if (boundary_pending()) {
        status("Save or finish your boundary work first. Your Stream list will be kept while that revision is saved.")
        return()
      }
      names <- tryCatch(stream_names_input(input$names), error = function(e) {
        status(conditionMessage(e)); NULL
      })
      if (is.null(names)) return()
      rationale <- "User explicitly selected these named Streams for this Study Area in FG Studio; no Stream geometry or network was inferred."
      if (!is.null(input$rationale) && nzchar(trimws(input$rationale)))
        rationale <- paste(rationale, trimws(input$rationale))
      tryCatch({
        saved <- store$define_streams(study$key, names, rationale, study$path)
        saved_once <<- TRUE
        on_saved(saved)
      }, error = function(e) {
        status("Streams could not be saved. Reopen the study to check its latest revision before retrying. Earlier records were retained.")
        message("fgstudio Stream save failed [", class(e)[[1]], "]")
      })
    }, ignoreInit = TRUE)
    output$status <- shiny::renderUI({
      if (!is.null(status())) shiny::p(role = "status", status())
    })
    list(destroy = function() saving$destroy(), draft = function() shiny::isolate(list(
      names = if (is.null(input$names)) "" else input$names,
      rationale = if (is.null(input$rationale)) "" else input$rationale)))
  })
}
