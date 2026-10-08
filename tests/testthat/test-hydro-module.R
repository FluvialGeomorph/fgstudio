test_that("Hydro Modify binds the selected Event and restores its Stream cutlines",{
  directory <- withr::local_tempdir();path <- file.path(directory,"study.gpkg");file.create(path)
  polygon <- sf::st_as_sfc("POLYGON((-93 40,-92.99 40,-92.99 40.01,-93 40.01,-93 40))",crs=4326)
  dem <- list(saved_dem=list(id="dem1"),result=list(path="fixture.tif",resolution=c(1,1)),
    boundary=sf::st_sf(geometry=polygon))
  adapter <- study_hydro_store(function(key) path)
  store <- c(adapter,list(dem_request=function(...) list(),find_dem=function(...) dem))
  ctx <- list(key="study",path=path,group_id="event",group_path="event.gpkg",
    streams=data.frame(stream_id="s1",stream_name="Stream one"))
  shiny::testServer(hydro_modify_server,args=list(current=function() list(key="study"),
    context=function() ctx,store=store,active=function() TRUE),{
    session$setInputs(stream="s1",surface="original")
    expect_identical(source()$saved_dem$id,"dem1")
    expect_null(record())
    expect_false(draw_ready())
    expect_match(output$streams$html,"Stream one")
    session$setInputs(stream="missing")
    expect_identical(source()$saved_dem$id,"dem1")
  })
})

test_that("reopening restores saved lines without queuing a destructive map clear",{
  directory <- withr::local_tempdir();path <- file.path(directory,"study.gpkg");file.create(path)
  lines <- hydro_drawn_lines(list(type="FeatureCollection",features=list(list(
    geometry=list(type="LineString",coordinates=list(c(-93,40),c(-92.999,40.001)))))))
  dem <- list(saved_dem=list(id="dem1"),result=list(path="fixture.tif",resolution=c(1,1)))
  store <- c(study_hydro_store(function(key) path),
    list(dem_request=function(...) list(),find_dem=function(...) dem))
  saved <- store$hydro_save("study","event","s1","dem1",lines,NULL,path)
  ctx <- list(key="study",path=path,group_id="event",group_path="event.gpkg",
    streams=data.frame(stream_id="s1",stream_name="Stream one"))
  testthat::local_mocked_bindings(hydro_dem_bounds=function(...) c(-93,40,-92.99,40.01),
    .package="fgstudio")
  shiny::testServer(hydro_modify_server,args=list(current=function() list(key="study"),
    context=function() ctx,store=store),{
    messages <- list()
    root_session <- session$rootScope()
    root_session$sendCustomMessage <- function(type,message) messages[[length(messages)+1L]] <<- message
    session$setInputs(stream="s1",surface="original")
    widget <- jsonlite::fromJSON(output$map,simplifyVector=FALSE)
    expect_identical(record()$id,saved$id)
    expect_true(any(vapply(widget$x$calls,function(x) identical(x$method,"addPolylines"),logical(1))))
    calls <- unlist(lapply(messages,function(x) x$calls),recursive=FALSE)
    expect_gt(length(calls),0L)
    expect_false(any(vapply(calls,function(x)
      identical(x$method,"clearGroup") && "Cutlines" %in% unlist(x$args),logical(1))))
    expect_false(any(vapply(calls,function(x)
      identical(x$method,"removeDrawToolbar") && isTRUE(x$args[[1]]),logical(1))))
  })
})

test_that("Apply publishes a completed worker result and exposes its saved surface",{
  directory <- withr::local_tempdir();path <- file.path(directory,"study.gpkg");file.create(path)
  shape <- sf::st_as_sfc("POLYGON((-93 40,-92.99 40,-92.99 40.01,-93 40.01,-93 40))",crs=4326)
  dem <- list(saved_dem=list(id="dem1"),result=list(path="fixture.tif",resolution=c(1,1)),
    boundary=sf::st_sf(geometry=shape))
  store <- c(study_hydro_store(function(key) path),
    list(dem_request=function(...) list(),find_dem=function(...) dem))
  lines <- hydro_drawn_lines(list(type="FeatureCollection",features=list(list(
    geometry=list(type="LineString",coordinates=list(c(-93,40),c(-92.999,40.001)))))))
  store$hydro_save("study","event","s1","dem1",lines,NULL,path)
  launch <- function(source,lines,filename) {
    writeBin(as.raw(1:9),filename)
    list(is_alive=function() FALSE,get_result=function() list(path=filename,method="fixture"))
  }
  ctx <- list(key="study",path=path,group_id="event",group_path="event.gpkg",
    streams=data.frame(stream_id="s1",stream_name="Stream one"))
  shiny::testServer(hydro_modify_server,args=list(current=function() list(key="study"),
    context=function() ctx,store=store,active=function() TRUE,launch_burn=launch),{
    session$setInputs(stream="s1",surface="original")
    expect_match(output$apply_control$html,"Apply 1 saved cutline to DEM",fixed=TRUE)
    session$setInputs(apply=1)
    # A newly available edition must not invalidate cuts made on the displayed DEM.
    store$find_dem <- function(...) list(saved_dem=list(id="newer-edition"))
    poll()
    expect_identical(record()$result$source_edition,"dem1")
    session$setInputs(surface="hydro")
    expect_true(file.exists(surface()))
    expect_match(notice(),"saved")
    expect_null(output$apply_control)
  })
})

test_that("extraction carries an unchanged DEM forward when no cutlines are needed",{
  directory <- withr::local_tempdir();path <- file.path(directory,"study.gpkg");file.create(path)
  source_path <- file.path(directory,"source.tif")
  raster <- terra::rast(matrix(9:1,nrow=3),extent=terra::ext(0,3,0,3),crs="EPSG:26915")
  terra::writeRaster(raster,source_path)
  dem <- list(saved_dem=list(id="dem1"),result=list(path=source_path,resolution=c(1,1)))
  hydro <- study_hydro_store(function(key) path)
  network_store <- study_stream_network_store(function(key) path,hydro$hydro_read)
  reference <- sf::st_sf(source_id="1",geometry=sf::st_sfc(
    sf::st_linestring(matrix(c(0,3,3,0),ncol=2,byrow=TRUE)),crs=26915))
  store <- c(hydro,network_store,list(dem_request=function(...) list(),
    find_dem=function(...) dem,stream_segments=function(...) list(lines=reference)))
  passthrough <- function(source,filename) {
    file.copy(source,filename)
    list(is_alive=function() FALSE,get_result=function() list(path=filename,
      method="unchanged_source",output_sha256="same-sha",
      skipped_nodata_cutlines=integer()))
  }
  extraction_calls <- 0L
  extraction <- function(...) {
    extraction_calls <<- extraction_calls+1L
    list(is_alive=function() TRUE,kill=function() NULL)
  }
  ctx <- list(key="study",path=path,group_id="event",group_path="event.gpkg",
    streams=data.frame(stream_id="s1",stream_name="Stream one"))
  shiny::testServer(hydro_modify_server,args=list(current=function() list(key="study"),
    context=function() ctx,store=store,active=function() TRUE,
    launch_passthrough=passthrough,launch_extract=extraction),{
    session$setInputs(stream="s1",surface="original",threshold_ha=1)
    expect_null(record())
    expect_null(output$apply_control)
    session$setInputs(extract_stream=1)
    poll()
    expect_identical(record()$result$method,"unchanged_source")
    expect_equal(nrow(record()$lines),0L)
    expect_equal(extraction_calls,1L)
    expect_true(stream_busy())
  })
})

test_that("Synthetic Stream publishes and restores a Hydro-bound candidate",{
  directory <- withr::local_tempdir();path <- file.path(directory,"study.gpkg");file.create(path)
  source_path <- file.path(directory,"source.tif")
  raster <- terra::rast(matrix(9:1,nrow=3),extent=terra::ext(0,3,0,3),crs="EPSG:26915")
  terra::writeRaster(raster,source_path)
  dem <- list(saved_dem=list(id="dem1"),result=list(path=source_path,resolution=c(1,1)))
  hydro <- study_hydro_store(function(key) path)
  network_store <- study_stream_network_store(function(key) path,hydro$hydro_read)
  lines <- sf::st_sf(source_id="1",geometry=sf::st_sfc(
    sf::st_linestring(matrix(c(0,3,3,0),ncol=2,byrow=TRUE)),crs=26915))
  cuts <- hydro_drawn_lines(list(type="FeatureCollection",features=list(list(
    geometry=list(type="LineString",coordinates=list(c(0,0),c(.001,.001)))))))
  drawing <- hydro$hydro_save("study","event","s1","dem1",cuts,NULL,path)
  stage <- hydro$hydro_prepare(drawing);hydro_file <- file.path(stage,"hydro-dem.tif")
  terra::writeRaster(raster,hydro_file)
  drawing <- hydro$hydro_publish(drawing,stage,list(path=hydro_file,
    output_sha256="hydro-sha",method="fixture"))
  store <- c(hydro,network_store,list(dem_request=function(...) list(),
    find_dem=function(...) dem,stream_segments=function(...) list(lines=lines)))
  launch <- function(source,reference_lines,directory,threshold_ha,memory_budget_mb) {
    for(name in c("routing.tif","fill-depth.tif","flow-direction.tif",
      "flow-accumulation.tif","fill-changes-display.tif"))
      terra::writeRaster(raster,file.path(directory,name))
    vector <- sf::st_sf(stream_line_id="SN00001",geometry=sf::st_sfc(
      sf::st_linestring(matrix(c(0,3,3,0),ncol=2,byrow=TRUE)),crs=26915))
    sf::st_write(vector,file.path(directory,"stream-network.gpkg"),quiet=TRUE)
    result <- list(schema="SYNTHETIC_STREAM_NETWORK_1",source_sha256="hydro-sha",
      threshold_ha=threshold_ha,stream_lines=1,stream_length_m=4,changed_cells=2,
      files=list(routing="routing.tif",fill_depth="fill-depth.tif",
        direction="flow-direction.tif",accumulation="flow-accumulation.tif",
        fill_display="fill-changes-display.tif",stream_network="stream-network.gpkg"))
    saveRDS(result,file.path(directory,"result.rds"))
    list(is_alive=function() FALSE,get_result=function()
      list(result=result,outlet=data.frame(cell=9,x=2.5,y=.5,elevation=1)))
  }
  ctx <- list(key="study",path=path,group_id="event",group_path="event.gpkg",
    streams=data.frame(stream_id="s1",stream_name="Stream one"))
  shiny::testServer(hydro_modify_server,args=list(current=function() list(key="study"),
    context=function() ctx,store=store,launch_extract=launch),{
    session$setInputs(stream="s1",surface="hydro",threshold_ha=1)
    expect_null(network())
    session$setInputs(extract_stream=1)
    expect_match(output$stream_status$html,"<progress",fixed=TRUE)
    poll()
    session$flushReact()
    expect_identical(network()$threshold_ha,1)
    expect_match(stream_notice(),"Candidate saved")
    expect_false(grepl("<progress",output$stream_status$html,fixed=TRUE))
    expect_identical(store$stream_network_read(record())$app$hydro_cutline_revision,drawing$id)
  })
})

test_that("a threshold update reuses routing outputs and replaces only the network",{
  directory <- withr::local_tempdir()
  original <- file.path(directory,"original");dir.create(original)
  stage <- file.path(directory,"stage");dir.create(stage)
  source <- file.path(directory,"dem.tif")
  dem <- terra::rast(matrix(9:1,nrow=3,byrow=TRUE),
    extent=terra::ext(0,3,0,3),crs="EPSG:26915")
  terra::writeRaster(dem,source)
  candidate <- fluvgeo::extract_synthetic_stream_network(source,9,original,
    threshold_ha=.0001,memory_budget_mb=2048)
  candidate$path <- original
  candidate$outlet <- data.frame(cell=9,x=2.5,y=.5,elevation=1)
  direction_before <- unname(tools::md5sum(file.path(original,candidate$files$direction)))

  updated <- reuse_stream_network_threshold(candidate,stage,.0002)

  expect_equal(updated$result$threshold_cells,2)
  expect_equal(updated$result$threshold_ha,.0002)
  expect_identical(unname(tools::md5sum(file.path(stage,candidate$files$direction))),
    direction_before)
  expect_true(file.exists(file.path(stage,updated$result$files$stream_network)))
  expect_identical(updated$outlet,candidate$outlet)
})
