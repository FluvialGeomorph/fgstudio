test_that("Stream selections deduplicate source IDs and require a current contained preview", {
  context <- shiny::reactiveVal(stream_test_context())
  state <- new.env(); state$saves <- 0L; state$active <- TRUE
  writer <- list(save_stream=function(...) {state$saves <- state$saves+1L; list(key="test")})
  host <- function(id) shiny::moduleServer(id,function(input,output,session) {
    p <- stream_selection_server(input,output,session,list(result=context),
      list(key="test",path="test",boundary=TRUE,boundary_sf=stream_test_parent()),writer,
      function() state$active,function(x) NULL)
  })
  shiny::testServer(host, {
    session$flushReact()
    expect_equal(nrow(p$pool()),2)
    expect_equal(p$pool()$direction[p$pool()$source_id == "101"],"upstream,downstream")
    session$setInputs(map_mode="explore",selection_target="stream",stream_action="select",
      buffer_distance=100,buffer_unit="m",stream_name="Creek")
    session$setInputs(lines_upstream="c101")
    expect_equal(p$selected(),"c101")
    session$setInputs(save_stream=1)
    expect_equal(state$saves,0)
    session$setInputs(map_shape_click=list(id="c102"))
    expect_length(p$selected(),2)
    session$setInputs(preview_stream=1)
    expect_equal(p$preview()$containment,"inside")
    session$setInputs(buffer_distance=120)
    expect_null(p$preview())
    session$setInputs(lines_upstream="forged")
    expect_length(p$selected(),2)
    session$setInputs(preview_stream=2)
    session$setInputs(save_stream=2)
    expect_equal(state$saves,1)
    expect_false(p$has_pending())
    session$setInputs(save_stream=3)
    expect_equal(state$saves,1)
    p$destroy()
  })
})

test_that("a boundary-coincident Stream previews clipping and can be saved", {
  store <- local_study_store(withr::local_tempdir())
  study <- store$create("Edge study")
  parent <- sf::st_sf(geometry=sf::st_sfc(sf::st_polygon(list(rbind(
    c(-90,39.9),c(-89.9,39.9),c(-89.9,40.1),c(-90,40.1),c(-90,39.9)))),crs=4326))
  study <- store$save_boundary(study$key,parent,study$path)
  saved <- NULL
  shiny::testServer(mod_boundary_server,args=list(study=study,store=store,
    is_active=function() TRUE,on_saved=function(x) saved <<- x),{
    session$flushReact()
    session$setInputs(selection_target="stream",map_mode="explore",stream_action="select")
    exploring$result(stream_test_context()); session$flushReact()
    session$setInputs(lines_upstream="c101",stream_name="Edge",buffer_distance=100,buffer_unit="m")
    session$setInputs(preview_stream=1)
    expect_true(stream_selection$preview()$clipped)
    expect_match(output$stream_summary$html,"removed")
    expect_match(output$workflow_next$html,"clipped gold")
    expect_true("Unclipped buffer" %in% layer_groups())
    session$setInputs(save_stream=1)
    expect_equal(saved$streams,1)
    expect_equal(saved$stream_inventory$stream_name,"Edge")
  })
})

test_that("slanted boundary clipping is saveable in the Stream editor", {
  x <- -90 + .00123456789
  parent <- sf::st_sf(geometry=sf::st_sfc(sf::st_polygon(list(rbind(
    c(x,40),c(x+.02,40.0123456789),c(x+.01,40.03),c(x-.01,40.02),c(x,40)))),crs=4326))
  line <- sf::st_sf(nhdplus_comid="101",gnis_name="Slanted",geometry=sf::st_sfc(sf::st_linestring(rbind(
    c(x+.001,40.015),c(x+.009,40.018))),crs=4326))
  context <- shiny::reactiveVal(list(layers=list(upstream=line),location=list(comid="101"),retrieved_at="Test"))
  saves <- 0L
  host <- function(id) shiny::moduleServer(id,function(input,output,session) {
    p <- stream_selection_server(input,output,session,list(result=context),
      list(key="test",path="test",boundary=TRUE,boundary_sf=parent),
      list(save_stream=function(...) { saves <<- saves+1L; list() }),function() TRUE,function(x) NULL)
  })
  shiny::testServer(host,{
    session$flushReact()
    session$setInputs(map_mode="explore",selection_target="stream",stream_action="select",
      buffer_distance=1000,buffer_unit="m",stream_name="Slanted")
    session$setInputs(lines_upstream="c101",preview_stream=1)
    expect_true(p$preview()$clipped)
    expect_equal(p$preview()$containment,"inside")
    session$setInputs(save_stream=1)
    expect_equal(saves,1L)
  })
})

test_that("both boundary writers reject exclusion of saved Stream areas", {
  store <- local_study_store(withr::local_tempdir())
  study <- store$create("Study")
  study <- store$save_boundary(study$key,stream_test_parent(),study$path)
  study <- store$save_stream(study$key,channel_candidates(stream_test_context()),"Creek",100,"m","Test",study$path)
  expect_equal(study$streams,1)
  original <- tools::md5sum(study$path)
  small <- sf::st_sf(geometry=sf::st_sfc(sf::st_polygon(list(
    rbind(c(-90,40),c(-89.9,40),c(-89.9,40.1),c(-90,40.1),c(-90,40)))),crs=4326))
  expect_error(store$save_boundary(study$key,small,study$path),"exclude saved areas: stream Creek")
  sources <- small; sources$candidate_key <- "p1"; sources$source_type <- "huc12"
  sources$source_id <- "123"; sources$name <- "Test"; sources$retrieved_at <- "Test"; sources$source_description <- "Synthetic"
  expect_error(store$save_selected_boundary(study$key,sources,study$path),"exclude saved areas")
  expect_identical(tools::md5sum(study$path),original)
  expect_identical(store$read(study$key)$path,study$path)
  expect_length(list.files(dirname(study$path),pattern="boundary-selection"),0)
  enlarged <- store$save_boundary(study$key,stream_test_parent(),study$path)
  expect_equal(enlarged$stream_inventory$stream_id,study$stream_inventory$stream_id)
})

test_that("completed exploration and map position survive creation and reopen defaults to view", {
  store <- local_study_store(withr::local_tempdir())
  context <- stream_test_context()
  bounds <- list(west=-90.1,east=-89.9,south=39.9,north=40.1)
  draft <- list(pool=NULL,selected=character(),map_mode="explore",target="stream",
    exploration=list(result=context,clicked=NULL,located=NULL),bounds=bounds,
    stream=list(pool=channel_candidates(context),selected="c101"))
  shiny::testServer(mod_study_server,args=list(store=store), {
    session$flushReact()
    module_env <- environment(refresh)
    stub <- get("editor",module_env)
    stub$selection_state <- function() draft
    assign("editor",stub,module_env)
    session$setInputs(name="New study",notes="",create=1)
    restored <- get("editor",module_env)$selection_state()
    expect_equal(restored$exploration$result,context)
    expect_equal(restored$bounds,bounds)
    expect_equal(restored$stream$selected,"c101")
    # Same-study parent revision retains choices but never reuses a prior preview.
    parent <- store$save_boundary(current()$key,stream_test_parent(),current()$path)
    current(parent); session$flushReact()
    expect_equal(get("editor",module_env)$selection_state()$stream$selected,"c101")
    key <- current()$key
    session$setInputs(saved=key,open=1)
    expect_null(get("editor",module_env)$selection_state()$exploration$result)
  })
  saved <- store$create("With boundary")
  saved <- store$save_boundary(saved$key,stream_test_parent(),saved$path)
  expect_equal(boundary_initial_mode(saved,FALSE,NULL),"view")
  shiny::testServer(mod_boundary_server,args=list(study=saved,store=store,
    is_active=function() TRUE,on_saved=function(x) NULL), {
    session$flushReact()
    expect_false(grepl("addDrawToolbar",output$map,fixed=TRUE))
    session$setInputs(map_mode="view",map_draw_all_features=draw_fixture(),save=1)
    expect_false(dirty())
    expect_identical(store$read(saved$key)$path,saved$path)
  })
})
