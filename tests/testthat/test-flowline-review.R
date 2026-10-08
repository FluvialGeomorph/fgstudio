flowline_review_fixture <- function(directory) {
  study <- file.path(directory,"study.gpkg");file.create(study)
  hydro_directory <- file.path(directory,"hydro");dir.create(hydro_directory)
  network_directory <- file.path(directory,"network");dir.create(network_directory)
  dem_path <- file.path(hydro_directory,"hydro-dem.tif")
  dem <- -terra::init(terra::rast(ncols=7,nrows=5,
    extent=terra::ext(-3,4,-1,4),crs="EPSG:26915"),"x")
  terra::writeRaster(dem,dem_path)
  network <- sf::st_sf(stream_line_id=c("A","B","T"),
    upstream_cell=c(1,2,3),downstream_cell=c(3,3,4),geometry=sf::st_sfc(
      sf::st_linestring(matrix(c(-2,3,1,1),ncol=2,byrow=TRUE)),
      sf::st_linestring(matrix(c(0,1,1,1),ncol=2,byrow=TRUE)),
      sf::st_linestring(matrix(c(1,1,3,1),ncol=2,byrow=TRUE)),crs=26915))
  sf::st_write(network,file.path(network_directory,"stream-network.gpkg"),quiet=TRUE)
  reference <- sf::st_sf(source_id="100",selection_id="100",geometry=sf::st_sfc(
    sf::st_linestring(matrix(c(0,1,3,1),ncol=2,byrow=TRUE)),crs=26915))
  group <- file.path(directory,"event.rds");saveRDS(list(event="e"),group)
  record <- list(id="hydro-1",key="study",event="event",stream="s1",source="source",
    context=study,path=hydro_directory,
    result=list(file="hydro-dem.tif",output_sha256="hydro-sha"))
  candidate <- list(path=network_directory,threshold_ha=1,
    files=list(stream_network="stream-network.gpkg"))
  segment_reads <- 0L;saved <- NULL;publications <- 0L
  store <- list(hydro_read=function(...)record,stream_network_read=function(...)candidate,
    stream_segments=function(...) {
      segment_reads <<- segment_reads+1L
      list(lines=reference,sha256=paste(rep("a",64),collapse=""),
        reach_mappings=data.frame(reach_id="r1",selection_id="100",source_id="100"))
    },flowline_read=function(...) saved,
    flowline_publish=function(record,selection,segments,bandwidth,raw_flowline,
                              stream_flowline,flowlines,boundaries,selected_segments) {
      publications <<- publications+1L
      saved <<- list(smoothing_bandwidth=bandwidth,raw_flowline=raw_flowline,
        stream_flowline=stream_flowline,flowlines=flowlines,boundaries=boundaries,
        selected_segments=selected_segments)
      saved
    })
  list(study=study,group=group,store=store,reference=reference,
    segment_reads=function()segment_reads,publications=function()publications)
}

test_that("Flowline review automatically selects, smooths and displays one path",{
  fixture <- flowline_review_fixture(withr::local_tempdir())
  active_state <- shiny::reactiveVal(TRUE)
  context <- list(key="study",path=fixture$study,group_id="event",group_path=fixture$group,
    event_label="2019-12",streams=data.frame(stream_id="s1",stream_name="Stream one"),
    reaches=data.frame(reach_id="r1",stream_id="s1",reach_name="Reach one"))
  shiny::testServer(flowline_review_server,args=list(current=function()list(path=fixture$study),
    context=function()context,store=fixture$store,active=function()active_state()),{
    expect_identical(selected()$stream,"s1")
    session$setInputs(stream="s1")
    expect_identical(review()$result$selected_segments$stream_line_id,c("B","T"))
    expect_s3_class(review()$result$raw_flowline,"sf")
    expect_identical(names(review()$result$smoothing_candidates),"2")
    expect_true(review()$result$flowline$smoothing_valid)
    expect_equal(nrow(selected_reaches()$flowlines),1L)
    expect_equal(review()$result$flowline$smoothing_bandwidth,2)
    expect_equal(selected_flowline()$smoothing_bandwidth,2)
    expect_match(notice(),"saved automatically")
    expect_equal(fixture$publications(),1L)
    widget <- jsonlite::fromJSON(output$map,simplifyVector=FALSE)
    calls <- widget$x$calls
    expect_equal(sum(vapply(calls,function(x)identical(x$method,"addPolylines"),logical(1))),4L)
    expect_match(output$summary$html,"Complete paths compared",fixed=TRUE)
    expect_match(output$summary$html,"Maximum smoothing displacement",fixed=TRUE)
    expect_match(output$summary$html,"Reach one",fixed=TRUE)
    expect_false(grepl("type=\"checkbox\"|type=\"radio\"|<select",
      output$summary$html,ignore.case=TRUE))
    original <- review()$result$raw_flowline
    session$setInputs(bandwidth="5")
    expect_equal(selected_flowline()$smoothing_bandwidth,5)
    expect_setequal(names(review()$result$smoothing_candidates),c("2","5"))
    expect_identical(review()$result$raw_flowline,original)
    expect_equal(review()$saved$smoothing_bandwidth,5)
    expect_equal(fixture$publications(),2L)
    expect_match(output$summary$html,"5 metre bandwidth",fixed=TRUE)
    prepared_reads <- fixture$segment_reads()
    active_state(FALSE);session$flushReact();active_state(TRUE);session$flushReact()
    expect_equal(fixture$segment_reads(),prepared_reads)
  })
})

test_that("Stream map bounds use the saved Stream feature with a DEM fallback",{
  stream <- sf::st_sf(stream_id="target",geometry=sf::st_sfc(
    sf::st_polygon(list(matrix(c(500000,4400000,500100,4400000,
      500100,4400100,500000,4400100,500000,4400000),ncol=2,byrow=TRUE))),
    crs=26915))
  bounds <- stream_map_bounds(list(streams=stream),"target",c(1,2,3,4))
  expected <- unname(sf::st_bbox(sf::st_transform(stream,4326))[
    c("xmin","ymin","xmax","ymax")])
  expect_equal(bounds,expected)
  expect_identical(stream_map_bounds(list(streams=stream),"missing",
    c(1,2,3,4)),c(1,2,3,4))
  expect_identical(stream_map_bounds(list(streams=data.frame(stream_id="target")),
    "target",c(1,2,3,4)),c(1,2,3,4))
})

test_that("Flowline review needs no separate save control", {
  html <- as.character(flowline_review_ui("flowline"))
  expect_false(grepl("Save Reach Flowlines",html,fixed=TRUE))
  expect_match(html,"automatically saves",fixed=TRUE)
})

test_that("saved Flowline review reuses the published smoothing candidate", {
  fixture <- flowline_review_fixture(withr::local_tempdir())
  selection <- list(key="study",event="event",stream="s1",path=fixture$study,
    group=fixture$group,reaches=data.frame(reach_id="r1",stream_id="s1",
      reach_name="Reach one"))
  prepared <- load_flowline_review(fixture$store,selection)
  saved <- list(smoothing_bandwidth=2,
    raw_flowline=prepared$result$raw_flowline,
    stream_flowline=prepared$result$smoothing_candidates[["2"]],
    flowlines=prepared$result$reach_candidates[["2"]]$flowlines,
    boundaries=prepared$result$reach_candidates[["2"]]$boundaries,
    selected_segments=prepared$result$selected_segments)
  fixture$store$flowline_read <- function(...) saved
  reopened <- load_flowline_review(fixture$store,selection)
  expect_true(reopened$result$reopened)
  expect_null(reopened$result$candidates)
  expect_identical(names(reopened$result$smoothing_candidates),"2")
  expect_identical(reopened$result$smoothing_candidates[["2"]],saved$stream_flowline)
})

test_that("Flowline review explains missing prerequisite assets",{
  store <- list(hydro_read=function(...)NULL)
  selection <- list(key="study",event="event",stream="s1",path="study.gpkg")
  expect_error(load_flowline_review(store,selection),"Hydro DEM")

  store$hydro_read <- function(...)list(path="hydro",result=list(file="dem.tif"))
  store$stream_network_read <- function(...)NULL
  expect_error(load_flowline_review(store,selection),"synthetic network")
})
