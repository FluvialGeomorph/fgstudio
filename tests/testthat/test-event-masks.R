test_that("saved Events automatically prepare every Stream and stop stale or cancelled jobs", {
  local_mocked_bindings(read_study_context=function(...) list(streams=data.frame(stream_id=c("a","b"),stream_name=c("A","B"))),.package="fluvgeo")
  ctx <- list(key="key",path="context",selection="selection",group_id="group",group_path="group-path",
    streams=data.frame(stream_id=c("a","b"),stream_name=c("A","B")))
  active <- shiny::reactiveVal(ctx); dirty <- shiny::reactiveVal(FALSE)
  revision <- "one";alive <- TRUE;calls <- 0L;published <- 0L;killed <- FALSE;failure <- FALSE
  store <- list(mask_request=function(key,group,id,...) list(stream_id=id,revision=revision),
    prepare_masks=function(...) "stage",find_masks=function(...) NULL,
    publish_masks=function(key,group,request,...) {published <<- published+1L;list(path="edition",manifest=list(products=list(
      list(level="Stream",id=request$stream_id,plan=list(cells=25),valid_cells=20,file="mask.tif"))))})
  shiny::testServer(event_masks_server,args=list(context=active,store=store,pending=dirty,
    launch=function(...,cache_dir) {expect_null(cache_dir);calls <<- calls+1L;list(is_alive=function() alive,
      kill=function() {killed <<- TRUE;alive <<- FALSE},wait=function(...) TRUE,
      get_result=function() {if(failure) stop("failed verification");list(manifest=list(),path=NULL)})}),{
    session$flushReact();expect_equal(calls,1L)
    alive <<- FALSE;poll();poll();expect_equal(published,2L)
    expect_named(results(),c("a","b"));expect_false(busy())
    alive <<- TRUE;dirty(TRUE);session$flushReact();dirty(FALSE);session$flushReact()
    revision <<- "two";alive <<- FALSE;poll()
    expect_equal(published,2L);expect_match(message(),"changed")
    alive <<- TRUE;active(modifyList(ctx,list(group_path="next")));session$flushReact()
    session$setInputs(cancel=1)
    expect_true(killed);expect_false(busy());expect_equal(published,2L)
    failure <<- TRUE;active(modifyList(ctx,list(group_path="third")));session$flushReact();poll()
    expect_match(message(),"failed verification");expect_equal(published,2L)
  })
})
test_that("mask storage publishes immutable editions only while saved inputs match", {
  f <- event_test_setup();s <- f$store;x <- f$x
  withr::defer(unlink(dirname(dirname(x$path)),recursive=TRUE))
  groups <- s$save_acquisition_group(x$key,"USIEI:1",x$stream_inventory$stream_id,2020,2,1,"Reviewed",
    character(),NULL,x$path,f$selection,NULL)
  g <- groups$groups[[1]];id <- g$settings$group_id
  request <- s$mask_request(x$key,id,x$stream_inventory$stream_id[1],x$path,f$selection,g$path)
  stage <- s$prepare_masks(x$key);expect_false(dir.exists(stage));dir.create(stage)
  hash <- function(path) {con <- file(path,"rb");on.exit(close(con));unclass(as.character(openssl::sha256(con)))}
  manifest <- list(schema="EVENT_MASKS_1",inputs=lapply(request[c("context","selection","group")],hash),
    group_id=id,stream_id=request$stream_id)
  jsonlite::write_json(manifest,file.path(stage,"verified.json"),auto_unbox=TRUE)
  published <- s$publish_masks(x$key,id,request,stage,manifest)
  expect_true(file.exists(file.path(published$path,"verified.json")));expect_false(dir.exists(stage))
  second <- s$prepare_masks(x$key);dir.create(second)
  file.copy(file.path(published$path,"verified.json"),file.path(second,"verified.json"))
  x <- s$rename(x$key,"Revised",x$path)
  expect_error(s$publish_masks(x$key,id,request,second,manifest),"changed")
  expect_true(dir.exists(second));expect_true(dir.exists(published$path))
  expect_error(s$discard_masks(x$key,published$path),"Invalid mask staging")
  s$discard_masks(x$key,second)
  expect_false(dir.exists(second));expect_true(dir.exists(published$path))
  orphan <- s$prepare_masks(x$key);dir.create(orphan)
  jsonlite::write_json(list(schema="FGSTUDIO_MASK_JOB_1",owner_pid=999998L,worker_pid=999999L),
    paste0(orphan,".json"),auto_unbox=TRUE)
  with_mocked_bindings({
    next_attempt <- s$prepare_masks(x$key)
    expect_false(dir.exists(orphan));expect_false(file.exists(paste0(orphan,".json")))
    expect_true(file.exists(published$path))
    s$discard_masks(x$key,next_attempt)
  },ps_pids=function() integer(),.package="ps")
})

test_that("mask review maps display generated rasters and boundaries without changing files", {
  fixture <- Sys.getenv("FGSTUDIO_REAL_MOSAIC_RESULT")
  skip_if(!nzchar(fixture), "Provide the small real Reach fixture")
  trial <- readRDS(fixture); path <- trial$mask_file
  before <- tools::md5sum(path)
  area <- trial$reach
  image <- tempfile(fileext=".png"); withr::defer(unlink(image))
  grDevices::png(image,width=700,height=500)
  expect_no_error(draw_event_mask(path,area))
  grDevices::dev.off()
  expect_gt(file.info(image)$size,0)
  expect_identical(tools::md5sum(path),before)
  expect_match(mask_recovery_message(simpleError("Invalid cell size")),"invalid cell size")
  expect_match(mask_recovery_message(simpleError("Missing Reach polygons")),"Geometry")
  html <- as.character(survey_event_settings_ui("event"))
  expect_false(grepl("Mask to view|Analysis masks|Mask troubleshooting",html))
  withr::local_options(list(fgstudio.mask_diagnostics=TRUE))
  expect_match(as.character(event_masks_ui("masks")),"Mask troubleshooting")
  expect_false(grepl("Stream to mask|Create masks",html))
  expect_false(grepl("Grid and source preflight|Check grid and saved sources|Review DEM sources",html))
})
