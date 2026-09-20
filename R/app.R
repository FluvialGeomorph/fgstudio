#' Create the FluvialGeomorph Studio application
#'
#' @param data_dir Local server-side storage directory. This initial app is for
#'   a trusted, single-analyst workstation, not a shared hosted service.
#' @return A Shiny application object. Constructing it initializes the data folder.
#' @export
fgstudio_app <- function(data_dir = file.path(getwd(), ".local-data")) {
  store <- local_study_store(data_dir)
  ui <- bslib::page_fluid(
    title = "FluvialGeomorph Studio",
    theme = bslib::bs_theme(version = 5, primary = "#245c4f"),
    shiny::div(class = "container-fluid py-2",
      shiny::tags$header(
        shiny::p("FLUVIALGEOMORPH STUDIO", class = "text-uppercase text-body-secondary mb-1"),
        shiny::tags$h1("Define your Study Area", class = "h3 mb-1")),
      shiny::div(class = "small text-body-secondary mb-2",
        "Development preview | Local storage | Not connected to FGDB"),
      mod_study_ui("study"),
      shiny::tags$footer(class = "text-body-secondary mt-3 small",
        "Saved studies remain on this computer. Reload reopens the saved study in this tab; unsaved edits are lost. This preview has no shared-user access controls.")
    )
  )
  shiny::shinyApp(ui, function(input, output, session) {
    mod_study_server("study", store)
  })
}

#' Run FluvialGeomorph Studio locally
#'
#' @inheritParams fgstudio_app
#' @param port Local port, or NULL to select an available port.
#' @param launch.browser Open the application in a browser?
#' @return Runs the application until stopped, invisibly returning Shiny's result.
#' @export
run_app <- function(data_dir = file.path(getwd(), ".local-data"),
                    port = NULL, launch.browser = interactive()) {
  shiny::runApp(fgstudio_app(data_dir), host = "127.0.0.1", port = port,
    launch.browser = launch.browser)
}
