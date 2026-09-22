test_that("download requires saved choices and joins workers before cancellation cleanup", {
  x <- shiny::reactiveVal(list(key="synthetic",path="revision-1"))
  selected <- shiny::reactiveVal(list(path="selection",ids="one",draft=character(),stream="s",collection="c"))
  scope <- shiny::reactiveVal("scope-1")
  calls <- character();alive <- FALSE
  finish <- function() alive <<- FALSE
  result <- list(files=data.frame(title="Tile",file_id="one",outcome="DOWNLOADED",bytes=32,message="Verified"))
  store <- list(dem_download=function(...) NULL,dem_destination=function(...) "synthetic/source-dem",
    prepare_dem_download=function(...) {calls <<- c(calls,"prepare");"synthetic-attempt"})
  launch <- function(attempt,verify_only=FALSE) {
    calls <<- c(calls,"launch");alive <<- TRUE
    list(is_alive=function() alive,kill=function() {calls <<- c(calls,"kill");alive <<- FALSE},
      wait=function(timeout) {calls <<- c(calls,"wait")},get_result=function() result)
  }
  shiny::testServer(stream_dem_download_server,args=list(current=x,selection=selected,scope=scope,store=store,launch=launch),{
    session$flushReact();session$setInputs(start=1)
    expect_match(message(),"Save the current nonempty");expect_length(calls,0)
    selected(list(path="selection",ids="one",draft="one",stream="s",collection="c"));session$setInputs(start=2)
    expect_identical(calls,c("prepare","launch"));expect_true(busy())
    session$setInputs(start=3);expect_length(calls,2)
    # Checkbox edits alone do not retarget the immutable active attempt.
    selected(list(path="selection",ids="one",draft="two",stream="s",collection="c"));session$flushReact()
    expect_true(busy())
    testthat::with_mocked_bindings({
      scope("scope-2");session$flushReact()
      expect_false(busy());expect_null(state())
    },cancel_stream_dem_download=function(attempt) {
      expect_false(alive);calls <<- c(calls,"cleanup")
    },.package="fluvgeo")
    expect_identical(tail(calls,3),c("kill","wait","cleanup"))
    selected(list(path="selection",ids="one",draft="one",stream="s",collection="c"));session$setInputs(start=4)
    finish();poll();session$flushReact()
    expect_identical(state()$files$outcome,"DOWNLOADED");expect_match(message(),"1 / 1")
    expect_match(output$files$html,"DEM download outcomes")
  })
})

test_that("saved downloads reopen in a verification worker without starting transfers", {
  launches <- logical()
  result <- list(files=data.frame(title="Tile",file_id="one",outcome="UNAVAILABLE",bytes=32,message="Checksum failed"))
  store <- list(dem_download=function(...) "attempt",dem_destination=function(...) "source-dem")
  shiny::testServer(stream_dem_download_server,args=list(current=function() list(key="key",path="revision"),
    selection=function() list(path="selection",stream="s",collection="c"),scope=function() "scope",store=store,
    launch=function(attempt,verify_only) {
      launches <<- c(launches,verify_only)
      list(is_alive=function() FALSE,get_result=function() result)
    }),{
      session$flushReact();poll();session$flushReact()
      expect_identical(launches,TRUE)
      expect_identical(state()$files$outcome,"UNAVAILABLE")
      expect_match(message(),"start again to retry",fixed=TRUE)
    })
})

test_that("delayed process termination cannot expose a result in a new scope", {
  scope <- shiny::reactiveVal("original")
  control <- new.env();control$alive <- TRUE;control$result_reads <- 0L
  store <- list(dem_download=function(...) NULL,dem_destination=function(...) "synthetic/source-dem",
    prepare_dem_download=function(...) "attempt")
  launch <- function(...) list(is_alive=function() control$alive,kill=function() FALSE,
    wait=function(timeout) NULL,get_result=function() {control$result_reads <- control$result_reads+1L;list()})
  shiny::testServer(stream_dem_download_server,args=list(current=function() list(key="key",path="revision"),
    selection=function() list(path="selection",ids="one",draft="one",stream="s",collection="c"),
    scope=scope,store=store,launch=launch),{
    session$flushReact();session$setInputs(start=1)
    scope("different");session$flushReact()
    expect_true(busy());expect_match(message(),"has not stopped")
    control$alive <- FALSE
    testthat::with_mocked_bindings({poll()},cancel_stream_dem_download=function(...) NULL,.package="fluvgeo")
    expect_false(busy());expect_null(state());expect_equal(control$result_reads,0L)
  })
})

test_that("healthy workers are not killed after the former duration cap", {
  control <- new.env();control$time <- as.POSIXct(0,origin="1970-01-01");control$alive <- TRUE
  store <- list(dem_download=function(...) NULL,dem_destination=function(...) "synthetic/source-dem",
    prepare_dem_download=function(...) "attempt")
  shiny::testServer(stream_dem_download_server,args=list(current=function() list(key="key",path="revision"),
    selection=function() list(path="selection",ids="one",draft="one",stream="s",collection="c"),
    scope=function() "scope",store=store,clock=function() control$time,
    launch=function(...) list(is_alive=function() control$alive,kill=function() {control$alive <- FALSE},
      wait=function(timeout) NULL)),{
    session$flushReact();session$setInputs(start=1)
    control$time <- control$time+8*3600+1
    testthat::with_mocked_bindings({poll()},
      cancel_stream_dem_download=function(...) {expect_false(control$alive)},
      read_stream_dem_download=function(...) NULL,.package="fluvgeo")
    expect_true(busy());expect_true(control$alive)
    expect_false(grepl("timed out",message()))
  })
})

test_that("saved download history opens even while file choices are unsaved", {
  paths <- NULL
  store <- list(dem_download_history=function(...) c("new-attempt","old-attempt"),
    dem_destination=function(...) "source-dem")
  shiny::testServer(stream_dem_download_server,args=list(current=function() list(key="key",path="revision"),
    selection=function() list(path=NULL,stream="s",collection="c",ids="selected"),scope=function() "scope",store=store,
    launch=function(attempt,verify_only) {
      paths <<- attempt
      list(is_alive=function() FALSE,get_result=function() list(files=data.frame(file_id="old",title="Saved tile",
        outcome="DOWNLOADED",bytes=32,message="Verified",attempt="old-attempt")))
    }),{
      session$flushReact();poll();session$flushReact()
      expect_identical(paths,c("new-attempt","old-attempt"))
      expect_match(output$files$html,"Saved previously")
      expect_identical(inspection_context()$files$attempt,"old-attempt")
    })
})

test_that("available older copies survive failed retries in saved history", {
  testthat::with_mocked_bindings({
    h <- read_saved_dem_history(c("new","old"))
    expect_identical(h$files$file_id,c("tile","missing"))
    expect_identical(h$files$attempt,c("old","new"))
    expect_identical(h$files$outcome,c("DOWNLOADED","UNAVAILABLE"))
  },read_stream_dem_download=function(attempt,verify) list(files=data.frame(
    file_id=c("tile","missing"),title=c("Tile","Missing"),
    outcome=c(if(attempt=="old") "DOWNLOADED" else "FAILED","UNAVAILABLE"),bytes=32,message="fixture")),
  .package="fluvgeo")
})
