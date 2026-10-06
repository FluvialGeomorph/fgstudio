fg_working_overlay <- function() {
  shiny::tagList(
    shiny::tags$head(
      shiny::tags$style(shiny::HTML("#fg-working-overlay{display:none;position:fixed;inset:0;z-index:20000;background:rgba(18,32,45,.38);align-items:center;justify-content:center}.fg-working-card{width:min(28rem,calc(100vw - 2rem));background:white;border-radius:.5rem;padding:1.25rem;box-shadow:0 .5rem 2rem rgba(0,0,0,.3)}")),
      shiny::tags$script(shiny::HTML(paste(readLines(system.file("www",
        "working-overlay.js",package="fgstudio",mustWork=TRUE),warn=FALSE),
        collapse="\n")))),
    shiny::div(id="fg-working-overlay",role="dialog",`aria-modal`="true",
      `aria-hidden`="true",class="fg-working-overlay",
      shiny::div(class="fg-working-card",
        shiny::tags$h2(class="h5","FG Studio is working"),
        shiny::p(id="fg-working-detail",class="mb-2",
          "Preparing the current workspace. Please wait."),
        shiny::tags$progress(style="width:100%",`aria-label`="FG Studio is working"))))
}

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
    theme = bslib::bs_theme(version = 5, bootswatch = "flatly"),
    fg_working_overlay(),
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
