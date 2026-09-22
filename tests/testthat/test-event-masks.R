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
    launch=function(...) {calls <<- calls+1L;list(is_alive=function() alive,
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
})

test_that("mask review maps display generated rasters and boundaries without changing files", {
  path <- tempfile(fileext=".tif"); withr::defer(unlink(path))
  r <- terra::rast(nrows=501,ncols=501,xmin=500000,xmax=500501,ymin=4500000,ymax=4500501,crs="EPSG:26915")
  terra::values(r) <- rep(c(1,NA),length.out=terra::ncell(r))
  terra::writeRaster(r,path,datatype="INT1U",NAflag=255)
  before <- tools::md5sum(path)
  area <- sf::st_sf(geometry=sf::st_as_sfc(sf::st_bbox(c(xmin=500000,ymin=4500000,xmax=500501,ymax=4500501),crs=26915)))
  image <- tempfile(fileext=".png"); withr::defer(unlink(image))
  grDevices::png(image,width=700,height=500)
  expect_no_error(draw_event_mask(path,area))
  grDevices::dev.off()
  expect_gt(file.info(image)$size,0)
  expect_identical(tools::md5sum(path),before)
  expect_match(mask_recovery_message(simpleError("Invalid cell size")),"invalid cell size")
  expect_match(mask_recovery_message(simpleError("Missing Reach polygons")),"Study geometry")
  html <- as.character(survey_event_settings_ui("event"))
  expect_match(html,"Masks are prepared automatically")
  expect_false(grepl("Stream to mask|Create masks",html))
  expect_false(grepl("Grid and source preflight|Check grid and saved sources|Review DEM sources",html))
})
