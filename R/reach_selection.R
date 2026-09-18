reach_selection_ui <- function(ns, study, draft = NULL) {
  streams <- study$stream_inventory
  choices <- if (inherits(streams, "sf")) stats::setNames(streams$stream_id, streams$stream_name) else character()
  shiny::tagList(
    shiny::selectInput(ns("reach_parent"), "Parent Stream", c("Choose a Stream" = "", choices),
      selected = if (is.null(draft$parent)) "" else draft$parent),
    shiny::radioButtons(ns("reach_operation"), "Action",
      c("Add new" = "new", "Split existing" = "split", "Combine existing" = "merge"),
      selected = if (is.null(draft$operation)) "new" else draft$operation, inline = TRUE),
    shiny::conditionalPanel("input.reach_operation === 'new'", ns = ns,
    shiny::textInput(ns("reach_name"), "New Reach name", value = if (is.null(draft$name)) "" else draft$name),
    shiny::uiOutput(ns("reach_guidance")),
    shiny::uiOutput(ns("reach_segments")),
    shiny::div(class = "d-flex gap-2 flex-wrap",
      shiny::actionButton(ns("preview_reach"), "Preview Reach", class = "btn-outline-primary btn-sm"),
      shiny::actionButton(ns("clear_reach"), "Clear", class = "btn-outline-secondary btn-sm"),
      shiny::actionButton(ns("save_reach"), "Save Reach", class = "btn-primary btn-sm")),
    shiny::uiOutput(ns("reach_status")),
    shiny::p(class = "small text-body-secondary", "Checked segments form one Reach. Width is inherited from the Stream; adjacent Reach buffers may overlap.")),
    shiny::conditionalPanel("input.reach_operation === 'merge'", ns = ns, reach_merge_ui(ns)),
    shiny::conditionalPanel("input.reach_operation === 'split'", ns = ns, reach_split_ui(ns)))
}

reach_selection_server <- function(input, output, session, study, store, is_active, on_saved, draft = NULL) {
  source <- shiny::reactiveVal(NULL)
  selected <- shiny::reactiveVal(if (is.null(draft$selected)) character() else draft$selected[nzchar(draft$selected)])
  preview <- shiny::reactiveVal(NULL)
  status <- shiny::reactiveVal(if (isTRUE(draft$after_save)) "Reach saved. Check segments for the next Reach." else "Choose a parent Stream.")
  alive <- TRUE; saved_once <- FALSE
  enabled <- function() alive && is_active() && identical(input$selection_target, "reach") &&
    !isTRUE(input$reach_operation %in% c("merge","split"))
  proxy <- function() leaflet::leafletProxy("map", session = session)
  loading <- shiny::observeEvent(input$reach_parent, {
    if (!alive) return()
    source(NULL); preview(NULL)
    if (!identical(input$reach_parent, draft$parent)) selected(character())
    if (is.null(input$reach_parent) || !nzchar(input$reach_parent) || is.null(store)) return()
    tryCatch({
      value <- store$stream_segments(study$key, input$reach_parent, study$path)
      source(value)
      selected(intersect(selected(), setdiff(value$lines$selection_id, value$assigned_selection_ids)))
      status(if (length(setdiff(value$lines$selection_id, value$assigned_selection_ids)))
        "Check one or more segments, or click their blue lines." else "All retained segments already have Reaches.")
    }, error = function(e) status(conditionMessage(e)))
  }, ignoreNULL = TRUE)
  choose <- function(id) {
    if (!enabled() || is.null(source()) || anyNA(id)) return()
    if (is.null(id)) id <- character()
    x <- source()
    if (!all(id %in% setdiff(x$lines$selection_id, x$assigned_selection_ids))) return()
    id <- x$lines$selection_id[x$lines$selection_id %in% id]
    if (identical(id, selected())) return()
    added <- setdiff(id, selected())
    selected(id); preview(NULL)
    shiny::updateCheckboxGroupInput(session, "reach_segment", selected = id)
    if (length(id) && (is.null(input$reach_name) || !nzchar(trimws(input$reach_name))))
      shiny::updateTextInput(session, "reach_name", value = paste("Reach", x$lines$source_id[match(id[1],x$lines$selection_id)]))
    if (length(added)) {
      b <- sf::st_bbox(sf::st_transform(x$lines[x$lines$selection_id %in% added, ], 4326))
      leaflet::fitBounds(proxy(), b[[1]], b[[2]], b[[3]], b[[4]])
    }
    status(if (length(id)) "Review the name, then Preview Reach." else "Check segments for a Reach.")
  }
  picking <- shiny::observeEvent(input$reach_segment, choose(input$reach_segment), ignoreInit = TRUE, ignoreNULL = FALSE)
  clicking <- shiny::observeEvent(input$map_shape_click, {
    id <- input$map_shape_click$id
    if (is.character(id) && length(id) == 1L && startsWith(id, "reach-source-")) {
      key <- substring(id, 14L)
      choose(if (key %in% selected()) setdiff(selected(), key) else c(selected(), key))
    }
  }, ignoreInit = TRUE)
  clearing <- shiny::observeEvent(input$clear_reach, {
    if (!enabled()) return()
    selected(character()); preview(NULL)
    shiny::updateCheckboxGroupInput(session, "reach_segment", selected = character())
    shiny::updateTextInput(session, "reach_name", value = "")
    status("Check segments for a Reach.")
  }, ignoreInit = TRUE)
  previewing <- shiny::observeEvent(input$preview_reach, {
    if (!enabled()) return()
    preview(NULL)
    tryCatch({
      if (!length(selected())) stop("Select at least one retained segment.")
      value <- store$preview_reach(study$key, input$reach_parent, selected(), study$path)
      preview(value)
      status(paste("Review the gold Reach area, then Save Reach.",
        if (value$polygon_parts > 1L) "The area has disconnected parts; no connecting geometry was invented." else ""))
    }, error = function(e) status(conditionMessage(e)))
  }, ignoreInit = TRUE)
  saving <- shiny::observeEvent(input$save_reach, {
    if (!enabled() || saved_once) return()
    tryCatch({
      if (is.null(preview())) stop("Preview this Reach before saving.")
      saved <- store$save_reach(study$key, input$reach_parent, selected(), input$reach_name, study$path)
      selected(character()); preview(NULL); saved_once <<- TRUE
      on_saved(saved)
    }, error = function(e) status(paste("Reach not saved:", conditionMessage(e))))
  }, ignoreInit = TRUE)
  output$reach_segments <- shiny::renderUI({
    x <- source(); if (is.null(x)) return(NULL)
    ids <- setdiff(x$lines$selection_id, x$assigned_selection_ids)
    rows <- match(ids,x$lines$selection_id)
    shiny::div(style = "max-height:16rem;overflow-y:auto;",
      shiny::checkboxGroupInput(session$ns("reach_segment"), "Segments: downstream to upstream",
        if (length(ids)) stats::setNames(ids, paste0(
          ifelse(x$ordering$order_status[rows] == "ordered",
            paste0(rows, ". "), "Order unresolved - "), "NHDPlus ", x$lines$source_id[rows],
          if (isTRUE(x$piece_state)) paste0(" / piece ",rows) else "")) else character(),
        selected = shiny::isolate(selected())))
  })
  output$reach_guidance <- shiny::renderUI({
    x <- source(); if (is.null(x)) return(NULL)
    compact_table(data.frame(Item = c("Buffer on EACH side", "Assigned / available segments", "Selected segments", "Preview parts", "Next"),
      Value = c(paste(x$distance, x$unit, "(inherited)"),
        paste(length(x$assigned_selection_ids), "/", length(setdiff(x$lines$selection_id, x$assigned_selection_ids))),
        length(selected()), if (is.null(preview())) "Not previewed" else preview()$polygon_parts,
        if (!length(selected())) "Check segments" else if (is.null(preview())) "Name and preview" else "Review and save")))
  })
  output$reach_status <- shiny::renderUI(shiny::p(class = "small my-1", role = "status", status()))
  painting <- shiny::observe({
    x <- source(); id <- selected(); value <- preview()
    m <- proxy() |> leaflet::clearGroup("Reach candidates") |> leaflet::clearGroup("Reach preview")
    if (!enabled() || is.null(x)) return()
    lines <- sf::st_transform(x$lines, 4326)
    m <- leaflet::addPolylines(m, data = lines, group = "Reach candidates",
      layerId = paste0("reach-source-", lines$selection_id), label = paste("NHDPlus", lines$source_id),
      color = ifelse(lines$selection_id %in% id, "#e6a500", ifelse(lines$selection_id %in% x$assigned_selection_ids, "#777777", "#3182bd")),
      weight = ifelse(lines$selection_id %in% id, 7, 4), options = leaflet::pathOptions(bubblingMouseEvents = FALSE))
    if (!is.null(value)) leaflet::addPolygons(m, data = sf::st_transform(value$area, 4326),
      group = "Reach preview", color = "#e6a500", fillOpacity = .25, options = leaflet::pathOptions(interactive = FALSE))
  })
  list(source = source, selected = selected, preview = preview, status = status,
    has_pending = function() shiny::isolate(length(selected()) > 0L),
    state = function() shiny::isolate(list(parent = input$reach_parent, selected = selected(), operation = input$reach_operation,
      name = if (saved_once) "" else input$reach_name, after_save = saved_once)),
    destroy = function() {
      alive <<- FALSE
      for (o in list(loading, picking, clicking, clearing, previewing, saving, painting)) o$destroy()
    })
}
