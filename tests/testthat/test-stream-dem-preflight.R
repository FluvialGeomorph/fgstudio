test_that("preflight runs explicitly, rejects stale results and cancels workers", {
  ctx <- list(key="key",path="context",selection="selection",group_id="group",group_path="group-path",
    streams=data.frame(stream_id="stream",stream_name="Creek"))
  revision <- "one"; alive <- FALSE; calls <- 0L; killed <- FALSE
  store <- list(dem_preflight_request=function(...) list(revision=revision))
  shiny::testServer(stream_dem_preflight_server,args=list(context=function() ctx,store=store,pending=function() FALSE,
    launch=function(request) {
      calls <<- calls+1L
      list(is_alive=function() alive,kill=function() {killed <<- TRUE;alive <<- FALSE},wait=function(...) TRUE,
        get_result=function() list(marker=request$revision,checked_at="test time",grid_source_screen="PASS",
          grid=list(cell_size=1,unit="metre"),notes="No processing approval",
          grids=data.frame(level="Stream",columns=5,rows=5,cells=25,mask_bytes=25,float64_bytes=200),
          sources=data.frame(collection="Collection",file_id="tile",spacing_x=1,spacing_y=1,source_unit="metre",
            metres_x=1,metres_y=1,alignment="Aligned",grid_screen="PASS",issues="",band_unit="Unknown")))
    }),{
    session$flushReact();expect_equal(calls,0L)
    session$setInputs(stream="stream",run=1);poll();expect_equal(result()$marker,"one")
    expect_match(output$result$html,"Uncompressed payload")
    alive <<- TRUE;session$setInputs(run=2);expect_true(busy())
    revision <<- "two";alive <<- FALSE;poll();expect_null(result());expect_match(message(),"changed")
    alive <<- TRUE;session$setInputs(run=3,cancel=1)
    expect_true(killed);expect_false(busy());expect_null(result())
  })
})

test_that("unsaved Event edits block source checks and failed workers publish nothing", {
  ctx <- list(key="key",path="context",selection="selection",group_id="group",group_path="group-path",
    streams=data.frame(stream_id="stream",stream_name="Creek"))
  dirty <- TRUE;calls <- 0L
  shiny::testServer(stream_dem_preflight_server,args=list(context=function() ctx,
    store=list(dem_preflight_request=function(...) list()),pending=function() dirty,
    launch=function(...) {calls <<- calls+1L;list(is_alive=function() FALSE,get_result=function() stop("bad checksum"))}),{
    session$flushReact();session$setInputs(stream="stream",run=1)
    expect_equal(calls,0L);expect_match(message(),"pending")
    dirty <<- FALSE;session$setInputs(run=2);poll()
    expect_null(result());expect_match(message(),"bad checksum");expect_false(busy())
  })
})
