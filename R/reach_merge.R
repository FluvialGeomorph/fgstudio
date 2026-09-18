reach_merge_ui <- function(ns) {
  shiny::tagList(
    shiny::uiOutput(ns("merge_choices")),
    shiny::uiOutput(ns("merge_keeper")),
    shiny::textInput(ns("merge_name"), "Combined Reach name"),
    shiny::uiOutput(ns("merge_summary")),
    shiny::div(class = "d-flex gap-2 flex-wrap",
      shiny::actionButton(ns("preview_merge"), "Preview combination", class = "btn-outline-primary btn-sm"),
      shiny::actionButton(ns("clear_merge"), "Clear", class = "btn-outline-secondary btn-sm"),
      shiny::actionButton(ns("save_merge"), "Save combined Reach", class = "btn-primary btn-sm")),
    shiny::uiOutput(ns("merge_status")),
    shiny::p(class = "small text-body-secondary", "One selected identity is retained. Survey Events follow that identity; earlier revisions preserve the original Reaches."))
}

reach_merge_server <- function(input, output, session, study, store, source, is_active, on_saved) {
  selected <- shiny::reactiveVal(character()); preview <- shiny::reactiveVal(NULL)
  status <- shiny::reactiveVal("Select at least two saved Reaches in this Stream.")
  alive <- TRUE; saved_once <- FALSE
  enabled <- function() alive && is_active() && identical(input$selection_target, "reach") &&
    identical(input$reach_operation, "merge")
  candidates <- shiny::reactive({
    x <- study$reach_inventory
    if (is.null(x) || is.null(input$reach_parent)) return(NULL)
    x[x$stream_id == input$reach_parent, ]
  })
  changing_parent <- shiny::observeEvent(input$reach_parent, {
    selected(character()); preview(NULL)
  }, ignoreInit = TRUE)
  choose <- function(ids) {
    if (!enabled() || anyNA(ids)) return()
    x <- candidates()
    if (!all(ids %in% x$reach_id)) return()
    ids <- sort(unique(as.character(ids)))
    if (identical(ids, selected())) return()
    selected(ids); preview(NULL)
    shiny::updateCheckboxGroupInput(session, "merge_ids", selected = ids)
  }
  picking <- shiny::observeEvent(input$merge_ids, choose(input$merge_ids), ignoreInit = TRUE, ignoreNULL = FALSE)
  clicking <- shiny::observeEvent(input$map_shape_click, {
    id <- input$map_shape_click$id
    if (is.character(id) && length(id) == 1L && startsWith(id, "merge-")) {
      rid <- substring(id, 7L)
      choose(if (rid %in% selected()) setdiff(selected(), rid) else c(selected(), rid))
    }
  }, ignoreInit = TRUE)
  clearing <- shiny::observeEvent(input$clear_merge, {
    if (!enabled()) return()
    choose(character())
    shiny::updateTextInput(session, "merge_name", value = "")
    status("Select at least two saved Reaches.")
  }, ignoreInit = TRUE)
  keeper <- shiny::observeEvent(input$merge_keep, {
    preview(NULL)
    x <- candidates()
    if (!is.null(input$merge_keep) && input$merge_keep %in% selected())
      shiny::updateTextInput(session, "merge_name", value = x$reach_name[match(input$merge_keep, x$reach_id)])
  }, ignoreInit = TRUE)
  previewing <- shiny::observeEvent(input$preview_merge, {
    if (!enabled()) return()
    preview(NULL)
    tryCatch({
      if (length(selected()) < 2L) stop("Select at least two saved Reaches.")
      if (is.null(input$merge_keep) || !input$merge_keep %in% selected()) stop("Choose which selected Reach identity to keep.")
      value <- store$preview_reach_merge(study$key, selected(), input$merge_keep, study$path)
      preview(value)
      status("Review the combined gold area and reassignment summary before saving.")
    }, error = function(e) status(conditionMessage(e)))
  }, ignoreInit = TRUE)
  saving <- shiny::observeEvent(input$save_merge, {
    if (!enabled() || saved_once) return()
    tryCatch({
      if (is.null(preview())) stop("Preview the current combination before saving.")
      saved <- store$merge_reaches(study$key, selected(), input$merge_keep, input$merge_name, study$path)
      selected(character()); preview(NULL); saved_once <<- TRUE
      on_saved(saved)
    }, error = function(e) status(paste("Combination not saved:", conditionMessage(e))))
  }, ignoreInit = TRUE)
  output$merge_choices <- shiny::renderUI({
    x <- candidates()
    if (is.null(x) || !nrow(x)) return(shiny::p("No saved Reaches in this Stream."))
    shiny::checkboxGroupInput(session$ns("merge_ids"), "Reaches to combine",
      stats::setNames(x$reach_id, x$reach_name), selected = shiny::isolate(selected()))
  })
  output$merge_keeper <- shiny::renderUI({
    x <- candidates(); ids <- selected()
    choices <- if (!length(ids)) character() else stats::setNames(ids, x$reach_name[match(ids, x$reach_id)])
    old <- shiny::isolate(input$merge_keep)
    shiny::selectInput(session$ns("merge_keep"), "Keep this Reach's identity",
      c("Choose one selected Reach" = "", choices),
      selected = if (!is.null(old) && old %in% ids) old else "")
  })
  output$merge_summary <- shiny::renderUI({
    value <- preview(); x <- candidates()
    compact_table(data.frame(Item = c("Selected Reaches", "Combined segments", "Identity retained", "Identities retired in new revision", "Survey Events reassigned", "Preview parts"),
      Value = c(length(selected()), if (is.null(value)) "Preview required" else length(value$source_id),
        if (is.null(value)) "Choose and preview" else x$reach_name[match(value$retain_reach_id, x$reach_id)],
        if (is.null(value)) "Preview required" else length(value$retired_reach_ids),
        if (is.null(value)) "Preview required" else value$reassigned_events,
        if (is.null(value)) "Preview required" else value$polygon_parts)))
  })
  output$merge_status <- shiny::renderUI(shiny::p(role = "status", class = "small my-1", status()))
  painting <- shiny::observe({
    x <- candidates(); ids <- selected(); value <- preview()
    m <- leaflet::leafletProxy("map", session = session) |>
      leaflet::clearGroup("Reach merge candidates") |> leaflet::clearGroup("Reach merge preview")
    if (!enabled() || !inherits(x, "sf") || !nrow(x)) return()
    m <- leaflet::addPolygons(m, data = sf::st_transform(x, 4326), group = "Reach merge candidates",
      layerId = paste0("merge-", x$reach_id), label = x$reach_name,
      color = ifelse(x$reach_id %in% ids, "#e6a500", "#3182bd"), fillOpacity = .12,
      options = leaflet::pathOptions(bubblingMouseEvents = FALSE))
    if (!is.null(value)) leaflet::addPolygons(m, data = sf::st_transform(value$area, 4326),
      group = "Reach merge preview", color = "#e6a500", fillOpacity = .3,
      options = leaflet::pathOptions(interactive = FALSE))
  })
  list(selected = selected, preview = preview, status = status,
    has_pending = function() shiny::isolate(length(selected()) > 0L),
    destroy = function() {
      alive <<- FALSE
      for (o in list(changing_parent, picking, clicking, clearing, keeper, previewing, saving, painting)) o$destroy()
    })
}
