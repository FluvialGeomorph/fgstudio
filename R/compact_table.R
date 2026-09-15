# Small, escaped, responsive status tables; no HTML accepted from service values.
compact_table <- function(x) {
  shiny::div(class = "table-responsive",
    shiny::tags$table(class = "table table-sm table-striped align-middle mb-1 small",
      style = "width:100%; overflow-wrap:anywhere;",
      shiny::tags$thead(shiny::tags$tr(lapply(names(x), shiny::tags$th))),
      shiny::tags$tbody(lapply(seq_len(nrow(x)), function(i)
        shiny::tags$tr(lapply(x[i, , drop = FALSE], function(value)
          shiny::tags$td(as.character(value), style = "padding:.25rem .5rem;")))))))
}
