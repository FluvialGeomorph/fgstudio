test_that("DEM jobs reuse completed real-window results and cancel unpublished work", {
  fixture <- Sys.getenv("FGSTUDIO_REAL_MOSAIC_RESULT")
  skip_if(!nzchar(fixture), "Provide the small real Reach fixture")
  trial <- readRDS(fixture)
  cache <- tempfile(); dir.create(cache); withr::defer(unlink(cache,recursive=TRUE))
  withr::local_options(list(fgstudio.dem_trial=TRUE,fgstudio.dem_trial_cache=cache))
  ctx <- list(group_id=trial$group_id,path=trial$context_path,group_path=trial$group_path)
  active <- shiny::reactiveVal(ctx); calls <- 0; alive <- TRUE; killed <- FALSE
  launcher <- function(trial,directory) {
    calls <<- calls+1
    list(is_alive=function() alive,kill=function() {killed <<- TRUE;alive <<- FALSE},
      wait=function(...) NULL,get_result=function() trial)
  }
  wrapper <- function(id) shiny::moduleServer(id,function(input,output,session) {
    task <- terrain_dem_trial_job(input,output,session,trial,active,
      function() list(key=trial$key),launch=launcher)
  })
  shiny::testServer(wrapper,{
    session$flushReact(); expect_equal(calls,1); expect_true(task$busy())
    alive <<- FALSE; task$poll(); expect_false(task$busy()); expect_equal(task$value()$stage,'international_feet')
    active(modifyList(ctx,list(group_id='other')));session$flushReact();expect_null(task$value())
    active(ctx);session$flushReact();expect_equal(calls,1);expect_match(task$notice(),'Reused')
    # Discard only this test's cache index, never the referenced real raster.
    unlink(list.files(cache,pattern='[.]rds$',full.names=TRUE))
    alive <<- TRUE;session$setInputs(resume_dem=1);expect_equal(calls,2)
    session$setInputs(cancel_dem=1);expect_true(killed);expect_false(task$busy())
    expect_length(list.files(cache,pattern='dem-job-'),1) # completed mock job retained
    expect_true(file.exists(trial$result$path))
  })
})
