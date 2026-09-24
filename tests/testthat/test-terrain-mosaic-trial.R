test_that("DEM view is available and renders actual development results when supplied", {
  withr::local_options(list(fgstudio.mosaic_trial = NULL))
  expect_match(as.character(terrain_mosaic_trial_ui("trial")), "DEM")
  path <- Sys.getenv("FGSTUDIO_REAL_MOSAIC_RESULT")
  skip_if(!nzchar(path), "Set FGSTUDIO_REAL_MOSAIC_RESULT to a real-window worker result")
  trial <- readRDS(path)
  options(fgstudio.mosaic_trial = path)
  expect_match(as.character(terrain_mosaic_trial_ui("trial")), "DEM")
  context <- shiny::reactiveVal(list(group_id = trial$group_id))
  shiny::testServer(terrain_mosaic_trial_server, args = list(id = "trial",
      current = function() list(key = trial$key), event_context = context), {
    expect_match(output$summary$html, "portion of Reach")
    expect_match(output$summary$html, if (identical(trial$stage, "international_feet")) "NAVD88 international feet" else "no resampling or elevation conversion")
    expect_true(length(output$map) > 0)
    if (!is.null(trial$group_id)) {
      if (identical(trial$stage, "reach_masked")) expect_match(output$summary$html, "Unit conversion is pending")
      context(list(group_id = "another-event")); session$flushReact()
      expect_match(output$summary$html, "Select Survey Event")
      expect_error(output$map, class = "shiny.silent.error")
    }
  })
})
