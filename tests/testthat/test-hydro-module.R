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
    expect_null(source())
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
  testthat::local_mocked_bindings(hydro_dem_bounds=function(...) c(-93,40,-92.99,40.01))
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
    session$setInputs(apply=1)
    # A newly available edition must not invalidate cuts made on the displayed DEM.
    store$find_dem <- function(...) list(saved_dem=list(id="newer-edition"))
    poll()
    expect_identical(record()$result$source_edition,"dem1")
    session$setInputs(surface="hydro")
    expect_true(file.exists(surface()))
    expect_match(notice(),"saved")
    session$setInputs(apply=2)
    expect_match(notice(),"Showing the saved")
  })
})
