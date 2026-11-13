flowline_points_review_fixture <- function(directory) {
  study <- file.path(directory,"study.gpkg");file.create(study)
  event <- file.path(directory,"event.rds");saveRDS(list(event="e"),event)
  hydro <- file.path(directory,"hydro");dir.create(hydro)
  dem_path <- file.path(hydro,"hydro-dem.tif")
  dem <- terra::init(terra::rast(ncols=12,nrows=2,xmin=-1,xmax=11,
    ymin=-1,ymax=1,crs="EPSG:26915"),"x")
  terra::writeRaster(dem,dem_path)
  flowline_path <- file.path(directory,"flowline");dir.create(flowline_path)
  gpkg <- file.path(flowline_path,"flowlines.gpkg")
  lines <- sf::st_sf(reach_id="r1",ReachName="Reach one",reach_order=1L,
    from_measure=0,to_measure=.01,geometry=sf::st_sfc(
      sf::st_linestring(matrix(c(0,0,10,0),ncol=2,byrow=TRUE)),crs=26915))
  sf::st_write(lines,gpkg,layer="flowline",quiet=TRUE)
  record <- list(id="hydro-1",key="study",event="event",stream="s1",source="source",
    path=hydro,result=list(file="hydro-dem.tif",output_sha256="hydro-sha"))
  flowline <- list(path=flowline_path,files=list(geopackage="flowlines.gpkg"),
    flowlines=lines)
  saved <- NULL
  store <- list(hydro_read=function(...)record,
    stream_segments=function(...)list(reach_mappings=data.frame(reach_id="r1")),
    flowline_read=function(...)flowline,
    flowline_points_read=function(...)saved,
    flowline_points_publish=function(context,bundle,spacing,points,connections) {
      saved <<- list(schema="FGSTUDIO_FLOWLINE_POINTS_CANDIDATE_2",
        station_distance_m=spacing,point_count=nrow(points),stream_count=1,
        points=points,connections=connections,
        path=directory,files=list(geopackage="flowline-points.gpkg"))
      saved
    })
  context <- list(key="study",path=study,group_id="event",group_path=event,
    event_label="2019-12",streams=sf::st_sf(stream_id="s1",stream_name="Stream one",
      geometry=sf::st_buffer(sf::st_sfc(sf::st_linestring(matrix(
        c(0,0,10,0),ncol=2,byrow=TRUE)),crs=26915),1)),
    reaches=data.frame(reach_id="r1",stream_id="s1",reach_name="Reach one"))
  list(store=store,context=context)
}

test_that("Flowline Points review creates the one-meter compatible profile", {
  fixture <- flowline_points_review_fixture(withr::local_tempdir())
  active <- shiny::reactiveVal(TRUE)
  shiny::testServer(flowline_points_review_server,args=list(current=function()
    list(path=fixture$context$path),context=function()fixture$context,
    store=fixture$store,active=active),{
    session$setInputs(stream="s1",station_distance=1)
    session$flushReact()
    expect_match(output$status$html,"Opening this Survey Event",fixed=TRUE)
    expect_match(output$status$html,"<progress",fixed=TRUE)
    Sys.sleep(.06);later::run_now(.1);session$flushReact()
    expect_gt(nrow(points()),10)
    expect_equal(unique(points()$station_distance_m),1)
    expect_true(all(c("POINT_M_uncalibrated","calibration_diff","km_to_mouth") %in%
      names(points())))
    expect_match(output$status$html,"Saved",fixed=TRUE)
    expect_match(output$summary$html,"1 m",fixed=TRUE)
    expect_match(output$summary$html,"Stream one",fixed=TRUE)
    session$setInputs(station_distance=2,create=1)
    session$flushReact()
    expect_equal(unique(points()$station_distance_m),2)
    expect_match(output$status$html,"2 m",fixed=TRUE)
  })
})

test_that("Flowline Points review requires a saved Flowline", {
  store <- list(hydro_read=function(...)list(id="h",path="hydro",
    result=list(file="dem.tif")),stream_segments=function(...)list(),
    flowline_read=function(...)NULL)
  context <- list(key="study",group_id="event",group_path="event.rds",
    path="study.gpkg",streams=data.frame(stream_id="s1",stream_name="Stream one"),
    reaches=data.frame(stream_id="s1"))
  expect_error(load_flowline_points_review(store,context),"Flowline tab.*Reach Flowlines")
})

test_that("Flowline Points clears another Event before a prerequisite failure", {
  fixture <- flowline_points_review_fixture(withr::local_tempdir())
  original_hydro_read <- fixture$store$hydro_read
  fixture$store$hydro_read <- function(key,event,...)
    if(identical(event,"missing")) NULL else original_hydro_read()
  context <- shiny::reactiveVal(fixture$context)
  shiny::testServer(flowline_points_review_server,args=list(current=function()
    list(path=context()$path),context=context,store=fixture$store,
    active=function()TRUE),{
    session$setInputs(stream="s1",station_distance=1)
    session$flushReact();Sys.sleep(.06);later::run_now(.1);session$flushReact()
    expect_gt(nrow(points()),10)
    next_context <- context();next_context$group_id <- "missing"
    next_context$group_path <- paste0(next_context$group_path,"-missing")
    context(next_context);session$flushReact()
    expect_match(output$status$html,"Opening this Survey Event",fixed=TRUE)
    expect_match(output$status$html,"<progress",fixed=TRUE)
    Sys.sleep(.06);later::run_now(.1);session$flushReact()
    expect_null(review())
    expect_null(points())
    expect_match(notice(),"Hydro DEM",fixed=TRUE)
    expect_identical(view_notice(),"")
  })
})

test_that("Flowline Points review keeps only spacing overrides in Advanced controls", {
  html <- as.character(flowline_points_review_ui("points"))
  expect_false(grepl("Create Study Area Flowline Points",html,fixed=TRUE))
  expect_match(html,"Recreate Flowline Points",fixed=TRUE)
  expect_false(grepl("Return to Stream",html,fixed=TRUE))
  expect_match(html,"Advanced spacing",fixed=TRUE)
  expect_match(html,"shared profile",fixed=TRUE)
  expect_match(html,"Stream (select a tab to change the map)",fixed=TRUE)
  expect_match(html,"zoom to inspection scale",fixed=TRUE)
  expect_match(html,"(?s)<details[^>]*>.*Recreate Flowline Points.*</details>",perl=TRUE)
  expect_lt(regexpr("points-map",html,fixed=TRUE)[1],
    regexpr("Advanced spacing",html,fixed=TRUE)[1])
})

test_that("Flowline Points map uses a bounded display sample", {
  points <- sf::st_as_sf(data.frame(id=seq_len(2500),x=seq_len(2500),y=0),
    coords=c("x","y"),crs=26915)
  shown <- flowline_points_display_sample(points)
  expect_equal(nrow(shown),1000)
  expect_equal(shown$id[c(1,nrow(shown))],c(1,2500))
  expect_equal(flowline_points_display_sample(points[1:900,]),points[1:900,])
})

test_that("Flowline Points load only inside an inspection-scale viewport", {
  points <- sf::st_as_sf(data.frame(id=seq_len(2500),
    x=seq(500000,502499),y=4450000),coords=c("x","y"),crs=26915)
  geographic <- sf::st_bbox(sf::st_transform(points,4326))
  bounds <- list(west=geographic[["xmin"]],south=geographic[["ymin"]]-.001,
    east=mean(geographic[c("xmin","xmax")]),north=geographic[["ymax"]]+.001)
  expect_equal(nrow(flowline_points_in_view(points,bounds,16)),0)
  shown <- flowline_points_in_view(points,bounds,18)
  expect_gt(nrow(shown),0)
  expect_lte(nrow(shown),1000)
  expect_true(max(shown$id)<2500)
})
