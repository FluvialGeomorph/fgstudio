test_that("brush windows preserve top-row orientation and nested source offsets", {
  p <- list(values=matrix(0,100,200),source_size=c(2000,1000),window=c(100,300,400,200))
  expect_equal(dem_brush_window(p,list(xmin=50,xmax=100,ymin=50,ymax=100)),c(200,300,100,100))
  expect_equal(dem_brush_window(p,list(xmin=-1,xmax=201,ymin=-1,ymax=101)),p$window)
  expect_error(dem_brush_window(p,NULL),"Drag")
  expect_error(dem_brush_window(p,list(xmin=201,xmax=220,ymin=1,ymax=3)),"overlap")
  expect_error(dem_brush_window(p,list(xmin=NA,xmax=100,ymin=1,ymax=3)),"valid rectangle")
})

test_that("detail requests use only the current view brush and full preview resets the window", {
  windows <- list();n <- 0L
  p <- list(values=matrix(1,10,20),source_size=c(200,100),window=c(0,0,200,100),
    sampled_size=c(20,10),native=FALSE,band_unit="")
  shiny::testServer(stream_dem_inspection_server,args=list(
    context=function() list(attempt="one",files=data.frame(file_id="tile",title="Tile")),
    launch=function(attempt,file_id,preview=FALSE,window=NULL,cache_dir=NULL) {
      n <<- n+1L;windows[n] <<- list(window)
      list(is_alive=function() FALSE,get_result=function() list(preview=p))
    }),{
    session$flushReact();session$setInputs(file="tile",preview=1);poll();session$flushReact()
    session$setInputs(detail=1);expect_match(message(),"Drag");expect_equal(n,1L)
    brush_name <- paste0("area_",view_id())
    do.call(session$setInputs,stats::setNames(list(list(xmin=0,xmax=10,ymin=5,ymax=10)),brush_name))
    session$setInputs(detail=2);poll();session$flushReact()
    expect_equal(windows[[2]],c(0,0,100,50))
    session$setInputs(detail=3);expect_equal(n,2L);expect_match(message(),"Drag")
    session$setInputs(preview=2);poll();session$flushReact();expect_null(windows[[3]])
  })
})

test_that("selecting a saved file starts its preview and changing file clears it", {
  calls <- 0L
  p <- list(values=matrix(c(1,NA,3,4),2),sampled_size=c(2,2),source_size=c(20,20),band_unit="")
  shiny::testServer(stream_dem_inspection_server,args=list(
    context=function() list(attempt="one",files=data.frame(file_id="tile",title="Tile")),
    launch=function(attempt,file_id,preview=FALSE,window=NULL,cache_dir=NULL) {
      expect_true(preview);calls <<- calls+1L
      list(is_alive=function() FALSE,get_result=function() list(preview=p))
    }),{
    session$flushReact();expect_equal(calls,0L)
    session$setInputs(file="tile");poll();session$flushReact()
    expect_equal(calls,1L);expect_equal(result()$preview,p)
    expect_match(output$preview_panel$html,"unknown elevation unit",fixed=TRUE)
    expect_match(output$preview_panel$html,"Small features and gaps may be missed",fixed=TRUE)
    session$setInputs(file="other");expect_null(result());expect_null(output$preview_panel)
  })
})

test_that("preview rendering handles empty and constant grids", {
  path <- tempfile(fileext=".png");grDevices::png(path);on.exit({grDevices::dev.off();unlink(path)})
  expect_equal(draw_dem_preview(list(values=matrix(4,2,3))),c(4,4))
  expect_equal(draw_dem_preview(list(values=matrix(NA_real_,2,3))),c(NA_real_,NA_real_))
})

test_that("a fast successful inspection survives file-selection invalidation", {
  x <- list(title="<Synthetic>",sha256=paste(rep("a",64),collapse=""),
    observation=list(default_reader=list(),internal_compound=list(),crs_text_differs=FALSE))
  shiny::testServer(stream_dem_inspection_server,args=list(
    context=function() list(attempt="one",files=data.frame(file_id="tile",title="Tile")),
    launch=function(...) list(is_alive=function() FALSE,get_result=function() x)),{
    session$flushReact();session$setInputs(file="tile",inspect=1);poll();session$flushReact()
    expect_false(busy());expect_identical(result(),x)
    expect_match(output$result$html,"Verified SHA-256",fixed=TRUE)
    expect_match(output$result$html,"&lt;Synthetic&gt;",fixed=TRUE)
    session$setInputs(file="different");expect_null(result())
  })
})

test_that("inspection is explicit, cancellable and cannot return into a changed context", {
  context <- shiny::reactiveVal(list(attempt="one",files=data.frame(file_id="tile",title="Tile")))
  control <- new.env();control$alive <- FALSE;control$reads <- 0;control$launches <- 0
  launch <- function(attempt,file_id,...) {
    control$launches <- control$launches+1;control$alive <- TRUE
    list(is_alive=function() control$alive,kill=function() {control$alive <- FALSE},
      wait=function(timeout) NULL,get_result=function() {control$reads <- control$reads+1;list(title="Tile")})
  }
  shiny::testServer(stream_dem_inspection_server,args=list(context=context,launch=launch),{
    session$flushReact();expect_equal(control$launches,0)
    session$setInputs(inspect=1);expect_match(message(),"Select a downloaded")
    session$setInputs(file="tile",inspect=2);expect_true(busy())
    session$setInputs(inspect=3);expect_equal(control$launches,1)
    context(NULL);session$flushReact();expect_false(busy());expect_null(result());expect_equal(control$reads,0)
    context(list(attempt="two",files=data.frame(file_id="tile",title="Tile")))
    session$flushReact();session$setInputs(inspect=4)
    session$setInputs(file="other");control$alive <- FALSE;poll()
    expect_null(result());expect_equal(control$reads,0)
    session$setInputs(file="tile",inspect=5);session$setInputs(cancel=1)
    expect_false(busy());expect_match(message(),"cancelled")
  })
})

test_that("inspection errors remain visible and healthy work has no elapsed-time cutoff", {
  control <- new.env();control$alive <- FALSE;control$time <- as.POSIXct(0,origin="1970-01-01")
  shiny::testServer(stream_dem_inspection_server,args=list(
    context=function() list(attempt="one",files=data.frame(file_id="tile",title="Tile")),
    clock=function() control$time,launch=function(...) list(is_alive=function() control$alive,
      kill=function() {control$alive <- FALSE},wait=function(timeout) NULL,get_result=function() stop("bad checksum"))),{
    session$flushReact();session$setInputs(file="tile",inspect=1);poll()
    expect_match(message(),"bad checksum");expect_null(result())
    control$alive <- TRUE;session$setInputs(inspect=2);control$time <- control$time+1801;poll()
    expect_true(busy());expect_true(control$alive)
  })
})
