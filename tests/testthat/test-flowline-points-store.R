test_that("Flowline Points candidates are immutable and bound to saved Flowlines", {
  directory <- withr::local_tempdir()
  study <- file.path(directory,"study.gpkg");file.create(study)
  event <- file.path(directory,"event.rds");saveRDS(list(event="e"),event)
  hydro_path <- file.path(directory,"hydro");dir.create(hydro_path)
  dem_path <- file.path(hydro_path,"hydro-dem.tif")
  dem <- terra::init(terra::rast(ncols=12,nrows=2,xmin=-1,xmax=11,
    ymin=-1,ymax=1,crs="EPSG:26915"),"x")
  terra::writeRaster(dem,dem_path)
  flowline_path <- file.path(directory,"flowline");dir.create(flowline_path)
  geopackage <- file.path(flowline_path,"flowlines.gpkg")
  lines <- sf::st_sf(reach_id="reach",ReachName="Reach",reach_order=1L,
    from_measure=0,to_measure=.01,geometry=sf::st_sfc(
      sf::st_linestring(matrix(c(0,0,10,0),ncol=2,byrow=TRUE)),crs=26915))
  sf::st_write(lines,geopackage,layer="flowline",quiet=TRUE)
  record <- list(id="hydro-1",key="study",event="event",stream="stream",
    source="source",context=study,path=hydro_path,
    result=list(output_sha256="hydro-sha",file="hydro-dem.tif"))
  selection <- list(key="study",event="event",stream="stream",path=study,group=event)
  segments <- list(reach_mappings=data.frame(reach_id="reach"))
  flowline <- list(path=flowline_path,files=list(geopackage="flowlines.gpkg"),
    flowlines=lines)
  context <- list(key="study",group_id="event",path=study,group_path=event,
    streams=sf::st_sf(stream_id="stream",stream_name="Stream",
      geometry=sf::st_buffer(sf::st_sfc(sf::st_linestring(matrix(
        c(0,0,10,0),ncol=2,byrow=TRUE)),crs=26915),1)))
  bundle <- list(stream=list(stream_id="stream",stream_name="Stream",
    selection=selection,record=record,segments=segments,flowline=flowline,
    dem=dem_path))
  adapter <- study_flowline_points_store(function(key) study,function(...) record,
    function(...) flowline)
  generated <- fluvgeo::study_area_flowline_points(list(stream=lines),
    list(stream=dem),context$streams)

  saved <- adapter$flowline_points_publish(context,bundle,1,generated$points,
    generated$connections)

  expect_identical(saved$schema,"FGSTUDIO_FLOWLINE_POINTS_CANDIDATE_2")
  expect_equal(saved$point_count,nrow(generated$points))
  expect_equal(saved$stream_count,1)
  expect_equal(saved$station_distance_m,1)
  expect_true(all(c("flowline_points","stream_connections") %in% sf::st_layers(
    file.path(saved$path,saved$files$geopackage))$name))
  expect_equal(adapter$flowline_points_read(context,bundle,1)$point_count,
    nrow(generated$points))
  expect_null(adapter$flowline_points_read(context,bundle,2))

  writeLines("changed",study)
  expect_null(adapter$flowline_points_read(context,bundle))
  expect_true(dir.exists(saved$path))
})
