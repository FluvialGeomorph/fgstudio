test_that("mask workers publish only current successful results and cancellation joins", {
  ctx <- list(key="key",path="context",selection="selection",group_id="group",group_path="group-path",
    streams=data.frame(stream_id="stream",stream_name="Creek"))
  revision <- "one";alive <- FALSE;calls <- 0L;published <- 0L;killed <- FALSE;dirty <- FALSE;failure <- FALSE
  store <- list(mask_request=function(...) list(revision=revision),prepare_masks=function(...) "stage",
    publish_masks=function(...) {published <<- published+1L;list(path="edition",manifest=list(products=list(
      list(level="Stream",plan=list(cells=25),valid_cells=20,file="mask-0002.tif"))))})
  shiny::testServer(event_masks_server,args=list(context=function() ctx,store=store,pending=function() dirty,
    launch=function(...) {calls <<- calls+1L;list(is_alive=function() alive,
      kill=function() {killed <<- TRUE;alive <<- FALSE},wait=function(...) TRUE,
      get_result=function() {if(failure) stop("failed verification");list()})}),{
    session$flushReact();expect_equal(calls,0L)
    session$setInputs(stream="stream",run=1);poll();expect_equal(published,1L)
    expect_equal(result()$path,"edition")
    alive <<- TRUE;session$setInputs(run=2);revision <<- "two";alive <<- FALSE;poll()
    expect_equal(published,1L);expect_null(result());expect_match(message(),"changed")
    alive <<- TRUE;session$setInputs(run=3,cancel=1)
    expect_true(killed);expect_false(busy());expect_equal(published,1L)
    dirty <<- TRUE;session$setInputs(run=4);expect_equal(calls,3L)
    dirty <<- FALSE;failure <<- TRUE;session$setInputs(run=5);poll()
    expect_match(message(),"failed verification");expect_equal(published,1L)
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
