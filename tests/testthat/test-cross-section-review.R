test_that("channel-only endpoint editing cannot invent a floodplain bend", {
  f <- cross_section_review_fixture()
  line <- sf::st_sf(ReachName="R1",geometry=sf::st_sfc(sf::st_linestring(rbind(c(0,0),c(200,0))),crs=26915))
  f$footprints$floodplain_outer <- f$footprints$channel_outer
  f$layout <- fluvgeo::cross_section_layout(line,f$footprints$channel_outer,f$footprints$floodplain_outer)
  expect_identical(cross_section_vertex_labels(f$layout$sections[1,]),
    c("Left bank / cross section endpoint","Right bank / cross section endpoint"))
  shiny::testServer(cross_section_review_server,args=list(context=function()NULL,
    store=list(),events=NULL,active=function()FALSE,revision=function()0L),{
    session$flushReact();extents(f$footprints);layout(f$layout);session$flushReact()
    before <- sf::st_as_binary(sf::st_geometry(layout()$sections))
    session$setInputs(section="sample-3",vertex="1",add_bend=1)
    expect_match(status(),"no constructed overbank")
    expect_identical(sf::st_as_binary(sf::st_geometry(layout()$sections)),before)
    session$setInputs(vertex="2",add_bend=2)
    expect_match(status(),"no constructed overbank")
    session$setInputs(vertex="1",move=1)
    click <- sf::st_coordinates(sf::st_transform(sf::st_sfc(sf::st_point(c(51,-5)),crs=26915),4326))[1,]
    session$setInputs(map_click=list(lng=click[1],lat=click[2]))
    expect_identical(layout()$sections$left_leg_status[3],"no_floodplain")
    expect_equal(nrow(sf::st_coordinates(layout()$sections[3,])),2)
    expect_true(layout()$sections$channel_rotated[3])
    expect_false(layout()$sections$channel_skewed[3])
    expect_true(fluvgeo::check_cross_section_layout(layout()$sections))
  })
})

test_that("manual vertex moves retain session identity and refresh coverage and sequence", {
  f <- cross_section_review_fixture()
  shiny::testServer(cross_section_review_server,args=list(context=function()NULL,
    store=list(),events=NULL,active=function()FALSE,revision=function()0L),{
    session$flushReact()
    extents(f$footprints);layout(f$layout)
    session$flushReact()
    session$setInputs(section="sample-3",vertex="1",move=1)
    expect_identical(editing()$id,"sample-3")
    click <- sf::st_coordinates(sf::st_transform(sf::st_sfc(
      sf::st_point(c(50,-15)),crs=26915),4326))[1,]
    session$setInputs(map_click=list(lng=click[1],lat=click[2]))
    expect_null(editing())
    expect_true(layout()$sections$edited[3])
    expect_identical(layout()$sections$left_leg_status[3],"manual_review")
    expect_true(is.na(layout()$sections$left_rotation_deg[3]))
    expect_equal(layout()$sections$left_boundary_gap_m[3],15,tolerance=1e-5)
    expect_equal(layout()$sections$right_boundary_gap_m[3],0,tolerance=1e-5)
    expect_identical(layout()$sections$candidate_id,f$layout$sections$candidate_id)
    session$setInputs(section="sample-2",delete=1)
    expect_false("sample-2" %in% layout()$sections$candidate_id)
    expect_identical(layout()$sections$Seq,1:9)
    expect_identical(layout()$sections$candidate_id[2],"sample-3")
  })
})

test_that("raw level changes clear candidates before debounce or worker completion", {
  f <- cross_section_review_fixture()
  shiny::testServer(cross_section_review_server,args=list(context=function()NULL,
    store=list(),events=NULL,active=function()FALSE,revision=function()0L),{
    session$setInputs(channel=103,floodplain=106,spacing=20,tangent_distance=20,smoothing=2,centerline_spacing=2,overbank_angle=30,overbank_bends=TRUE)
    extents(f$footprints);layout(f$layout);editing(list(id="sample-1",vertex=1L))
    session$flushReact()
    session$setInputs(channel=104)
    expect_null(layout())
    expect_null(extents())
    expect_null(editing())
    extents(f$footprints);layout(f$layout)
    session$setInputs(overbank_angle=45)
    expect_null(layout())
    expect_null(extents())
  })
})

test_that("floodplain bends can be added, edited and removed without moving banks", {
  f <- cross_section_review_fixture()
  shiny::testServer(cross_section_review_server,args=list(context=function()NULL,
    store=list(),events=NULL,active=function()FALSE,revision=function()0L),{
    session$flushReact();extents(f$footprints);layout(f$layout);session$flushReact()
    original <- sf::st_coordinates(layout()$sections[3,])[,1:2]
    session$setInputs(section="sample-3",vertex="1",add_bend=1)
    x <- layout()$sections[3,]
    expect_equal(nrow(sf::st_coordinates(x)),5)
    expect_identical(x$left_bank_vertex,3L)
    expect_equal(sf::st_coordinates(x)[3:4,1:2],original[2:3,],ignore_attr=TRUE)
    expect_identical(x$candidate_id,"sample-3")
    expect_equal(cross_section_vertex_labels(x)[2],"Left floodplain bend")
    session$setInputs(vertex="2",move=1)
    click <- sf::st_coordinates(sf::st_transform(sf::st_sfc(sf::st_point(c(48,-15)),crs=26915),4326))[1,]
    session$setInputs(map_click=list(lng=click[1],lat=click[2]))
    expect_equal(unname(sf::st_coordinates(layout()$sections[3,])[2,1:2]),c(48,-15),tolerance=1e-5)
    session$setInputs(vertex="5",add_bend=2)
    x <- layout()$sections[3,]
    expect_equal(nrow(sf::st_coordinates(x)),6)
    expect_equal(cross_section_vertex_labels(x)[5],"Right floodplain bend")
    session$setInputs(vertex="5",remove_bend=1)
    session$setInputs(vertex="2",remove_bend=2)
    x <- layout()$sections[3,]
    expect_equal(nrow(sf::st_coordinates(x)),4)
    expect_equal(sf::st_coordinates(x)[,1:2],original,ignore_attr=TRUE)
    expect_true(fluvgeo::check_cross_section_layout(layout()$sections))
  })
})

test_that("a missing Survey Event clears the previous review", {
  f <- cross_section_review_fixture()
  active <- shiny::reactiveVal(FALSE)
  shiny::testServer(cross_section_review_server,args=list(context=function()NULL,
    store=list(),events=NULL,active=active,revision=function()0L),{
    session$flushReact()
    extents(f$footprints);layout(f$layout)
    active(TRUE);session$flushReact()
    expect_null(layout())
    expect_null(extents())
    expect_match(status(),"Survey Event")
  })
})

test_that("a replacement worker restarts polling after cancellation with unchanged status", {
  shiny::testServer(cross_section_review_server,args=list(context=function()NULL,
    store=list(),events=NULL,active=function()FALSE,revision=function()0L),{
    session$flushReact()
    status("Updating inundation and section candidates...")
    watch_job(list(is_alive=function()TRUE,kill=function()NULL,wait=function(timeout)NULL))
    session$flushReact()
    stop_job();session$elapse(250);session$flushReact()
    expect_null(job)
    watch_job(list(is_alive=function()FALSE,get_result=function()simpleError("replacement result consumed")))
    session$flushReact()
    expect_null(job)
    expect_match(status(),"replacement result consumed")
  })
})
