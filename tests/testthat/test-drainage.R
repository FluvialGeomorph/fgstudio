fake_drainage_job <- function(value = NULL, error = NULL) {
  state <- new.env(); state$alive <- TRUE; state$killed <- FALSE
  list(is_alive = function() state$alive,
    kill = function() { state$killed <- TRUE; state$alive <- FALSE },
    get_result = function() { if (!is.null(error)) stop(error); value }, state = state)
}

test_that("exploration requires click and reviewed location; never writes records", {
  store <- local_study_store(withr::local_tempdir())
  study <- store$create("Study")
  original <- tools::md5sum(study$path)
  workers <- new.env(); workers$jobs <- list(); args_seen <- list()
  point <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(-90, 41)), crs = 4326))
  line <- sf::st_sf(comid = "123", geometry = sf::st_sfc(sf::st_linestring(rbind(c(-90,41),c(-90,41.01))), crs=4326))
  location <- list(query_point = point, snapped_point = point, flowline = line, comid = "123", snap_distance_m = 0)
  launch <- function(operation, argument, distance) {
    args_seen[[length(args_seen)+1L]] <<- list(operation, argument, distance)
    j <- fake_drainage_job(location)
    workers$jobs[[length(workers$jobs)+1L]] <<- j
    j
  }
  shiny::testServer(mod_boundary_server, args = list(study = study, store = store,
    is_active = function() TRUE, on_saved = function(x) stop("unexpected save"), launch = launch), {
    session$flushReact()
    session$setInputs(map_mode = "explore", get_drainage = 1)
    expect_length(workers$jobs, 0)
    expect_match(exploring$status(), "Snap to a stream")
    session$setInputs(map_click = list(lng = -90, lat = 41))
    expect_length(workers$jobs, 0)
    session$setInputs(locate_stream = 1)
    expect_length(workers$jobs, 1)
    expect_equal(exploring$busy(), "locate")
    expect_match(output$drainage_status$html, "progress")
    expect_null(exploring$located())
    workers$jobs[[1]]$state$alive <- FALSE
    exploring$poll()
    expect_equal(exploring$located(), location)
    expect_null(exploring$busy())
    session$setInputs(navigation_km = 30, get_drainage = 2)
    expect_equal(args_seen[[2]][[1]], "context")
    expect_equal(exploring$busy(), "context")
    expect_equal(args_seen[[2]][[3]], 30)
    session$setInputs(map_click = list(lng = -90.1, lat = 41))
    expect_true(workers$jobs[[2]]$state$killed)
    expect_null(exploring$located())
    expect_null(exploring$result())
    session$setInputs(locate_stream = 2, cancel_drainage = 1)
    expect_true(workers$jobs[[3]]$state$killed)
    expect_match(exploring$status(), "cancelled")
    expect_null(exploring$busy())
    expect_identical(store$read(study$key)$path, study$path)
    expect_identical(tools::md5sum(study$path), original)
    expect_false(dirty())
  })
})

test_that("drawing and exploration stay separate and inactive requests are disposed", {
  store <- local_study_store(withr::local_tempdir())
  study <- store$create("Study")
  workers <- new.env(); workers$jobs <- list(); state <- new.env(); state$active <- TRUE
  launch <- function(...) { j <- fake_drainage_job(); workers$jobs[[length(workers$jobs)+1L]] <<- j; j }
  shiny::testServer(mod_boundary_server, args = list(study=study, store=store,
    is_active=function() state$active, on_saved=function(x) NULL, launch=launch), {
    session$flushReact()
    session$setInputs(map_mode = "draw", map_click = list(lng=-90,lat=41), locate_stream=1)
    expect_length(workers$jobs,0)
    session$setInputs(map_draw_all_features=draw_fixture())
    session$setInputs(map_mode="explore")
    expect_match(status(), "Save your boundary changes")
    expect_true(dirty())
    # End this drawing state, then exercise cancellation at an inactive revision.
    dirty(FALSE)
    session$setInputs(map_click=list(lng=-90.1,lat=41),locate_stream=2)
    expect_length(workers$jobs,1)
    state$active <- FALSE
    exploring$poll()
    expect_true(workers$jobs[[1]]$state$killed)
    expect_null(exploring$located())
  })
})

test_that("exploration is available before project creation", {
  store <- local_study_store(withr::local_tempdir())
  shiny::testServer(mod_study_server, args=list(store=store), {
    session$flushReact()
    expect_match(output$boundary_editor$html, "Explore before defining")
    expect_length(store$catalog()$choices,0)
  })
})

test_that("partial results render, service errors recover, and deadlines stop workers", {
  point <- sf::st_sf(geometry=sf::st_sfc(sf::st_point(c(-90,41)),crs=4326))
  line <- sf::st_sf(comid="123",geometry=sf::st_sfc(sf::st_linestring(rbind(c(-90,41),c(-90,41.01))),crs=4326))
  location <- list(query_point=point,snapped_point=point,flowline=line,comid="123",snap_distance_m=0)
  response <- list(location=location,layers=list(huc12=NULL,basin=NULL,upstream=line,downstream=NULL),
    status=data.frame(layer=names(drainage_groups),status=c("unavailable","unavailable","available","unavailable"),
      features=c(0L,0L,1L,0L),detail="Service evidence"),distance_km=50,retrieved_at="Test",sources="Synthetic")
  state <- new.env(); state$time <- Sys.time(); state$job <- NULL; state$fail <- FALSE
  launch <- function(operation, ...) {
    state$job <- fake_drainage_job(if(operation=="locate") location else response,
      if(state$fail) "Service failure" else NULL)
    state$job
  }
  # Small host exposes the helper without a real service or storage adapter.
  host <- function(id) shiny::moduleServer(id,function(input,output,session) {
    ex <- drainage_explorer(input,output,session,function() TRUE,launch,clock=function() state$time)
  })
  shiny::testServer(host, {
    session$flushReact()
    session$setInputs(map_mode="explore",map_click=list(lng=-90,lat=41))
    session$setInputs(locate_stream=1)
    expect_equal(ex$busy(),"locate")
    state$time <- state$time+3; ex$poll(); session$flushReact()
    expect_match(output$drainage_status$html,"3 seconds elapsed")
    state$job$state$alive <- FALSE; ex$poll()
    session$setInputs(navigation_km=50,get_drainage=1)
    state$job$state$alive <- FALSE; ex$poll()
    session$flushReact()
    expect_equal(ex$result()$status$features, c(0L,0L,1L,0L))
    expect_match(output$drainage_results$html,"Unavailable")
    expect_match(output$drainage_results$html,"Which upstream channels")
    state$fail <- TRUE
    session$setInputs(get_drainage=2)
    state$job$state$alive <- FALSE; ex$poll()
    expect_match(ex$status(),"Service failure")
    expect_null(ex$busy())
    expect_null(ex$result())
    state$fail <- FALSE
    session$setInputs(get_drainage=3)
    state$time <- state$time+121; ex$poll()
    expect_true(state$job$state$killed)
    expect_match(ex$status(),"two minutes")
    expect_null(ex$busy())
    session$setInputs(get_drainage=4)
    session$setInputs(map_mode="draw")
    expect_true(state$job$state$killed)
    expect_match(ex$status(),"stopped when leaving")
    expect_equal(ex$located(), location) # Completed discovery survives mode changes.
    ex$destroy()
  })
})

test_that("worker launch failure clears service activity", {
  host <- function(id) shiny::moduleServer(id,function(input,output,session) {
    ex <- drainage_explorer(input,output,session,function() TRUE,
      launch=function(...) stop("Worker could not launch"))
  })
  shiny::testServer(host,{
    session$flushReact()
    session$setInputs(map_mode="explore",map_click=list(lng=-90,lat=41))
    session$setInputs(locate_stream=1)
    expect_null(ex$busy())
    expect_match(ex$status(),"could not start")
    expect_false(grepl("<progress",output$drainage_status$html,fixed=TRUE))
  })
})
