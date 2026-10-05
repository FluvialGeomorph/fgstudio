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
  reference <- sf::st_sf(source_id="100",geometry=sf::st_sfc(
    sf::st_linestring(matrix(c(0,1,3,1),ncol=2,byrow=TRUE)),crs=26915))
  record <- list(path=hydro_directory,result=list(file="hydro-dem.tif"))
  candidate <- list(path=network_directory,threshold_ha=1,
    files=list(stream_network="stream-network.gpkg"))
  store <- list(hydro_read=function(...)record,stream_network_read=function(...)candidate,
    stream_segments=function(...)list(lines=reference))
  list(study=study,store=store,reference=reference)
}

test_that("Flowline review automatically selects, smooths and displays one path",{
  fixture <- flowline_review_fixture(withr::local_tempdir())
  context <- list(key="study",path=fixture$study,group_id="event",group_path="event.gpkg",
    event_label="2019-12",streams=data.frame(stream_id="s1",stream_name="Stream one"))
  shiny::testServer(flowline_review_server,args=list(current=function()list(path=fixture$study),
    context=function()context,store=fixture$store,active=function()TRUE),{
    expect_identical(selected()$stream,"s1")
    session$setInputs(stream="s1")
    expect_identical(review()$result$selected_segments$stream_line_id,c("B","T"))
    expect_s3_class(review()$result$raw_flowline,"sf")
    expect_true(review()$result$flowline$smoothing_valid)
    expect_equal(review()$result$flowline$smoothing_bandwidth,2)
    expect_match(notice(),"selected and smoothed automatically")
    widget <- jsonlite::fromJSON(output$map,simplifyVector=FALSE)
    calls <- widget$x$calls
    expect_equal(sum(vapply(calls,function(x)identical(x$method,"addPolylines"),logical(1))),3L)
    expect_match(output$summary$html,"Complete paths compared",fixed=TRUE)
    expect_match(output$summary$html,"Maximum smoothing displacement",fixed=TRUE)
    expect_false(grepl("type=\"checkbox\"|type=\"radio\"|<select",
      output$summary$html,ignore.case=TRUE))
  })
})

test_that("Flowline review explains missing prerequisite assets",{
  store <- list(hydro_read=function(...)NULL)
  selection <- list(key="study",event="event",stream="s1",path="study.gpkg")
  expect_error(load_flowline_review(store,selection),"Hydro DEM")

  store$hydro_read <- function(...)list(path="hydro",result=list(file="dem.tif"))
  store$stream_network_read <- function(...)NULL
  expect_error(load_flowline_review(store,selection),"synthetic network")
})
