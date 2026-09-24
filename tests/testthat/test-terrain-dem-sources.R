test_that("saved Event/Stream assignments resolve only selected receipt-backed files", {
  fixture <- Sys.getenv('FGSTUDIO_REAL_MOSAIC_RESULT')
  skip_if(!nzchar(fixture),'Provide the existing real Reach fixture')
  t <- readRDS(fixture)
  s <- local_study_store(dirname(dirname(t$context_path)))
  x <- s$read(t$key)
  resolve <- function() terrain_dem_sources(s,t$key,t$group_id,t$reach$stream_id,x$path,t$group_path)
  sources <- resolve()
  expect_true(nrow(sources)>0)
  expect_true(all(file.exists(sources$path)))
  expected <- unlist(lapply(unique(sources$selection_path),function(p)
    fluvgeo::read_stream_dem_selection(p)$selected),use.names=FALSE)
  expect_identical(sources$file_id,expected)
  expect_error(terrain_dem_sources(s,t$key,t$group_id,'unassigned',x$path,t$group_path),'not assigned')
  original <- fluvgeo::read_stream_dem_download
  with_mocked_bindings({
    expect_error(resolve(),'unavailable.*Collections')
  },read_stream_dem_download=function(...) {
    result <- original(...);result$files$outcome[1] <- 'UNAVAILABLE';result
  },.package='fluvgeo')
  t$source_selection <- sources;t$sources <- unique(sources$path)
  before <- terrain_dem_trial_recipe(t)
  t$source_selection <- sources[nrow(sources):1,]
  expect_false(identical(before,terrain_dem_trial_recipe(t)))
  t$source_selection <- sources; t$use_saved_sources <- TRUE
  changed <- shiny::reactiveVal(FALSE)
  view_store <- list(dem_request=function(...) list(),find_dem=function(...) t)
  withr::local_options(list(fgstudio.mosaic_trial=NULL,fgstudio.dem_trial=FALSE))
  with_mocked_bindings({
    shiny::testServer(terrain_mosaic_trial_server,args=list(
      current=function() list(key=t$key),
      event_context=function() list(group_id=t$group_id,path=x$path,group_path=t$group_path),
      store=view_store),{
      expect_match(output$details$html,'selected automatically')
      changed(TRUE);session$flushReact()
      expect_match(output$summary$html,'No DEM has been saved')
    })
  },terrain_dem_sources=function(...) if(changed()) sources[nrow(sources):1,] else sources)
})
