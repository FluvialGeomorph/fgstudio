test_that("the real DEM worker resamples, masks, publishes and reuses a changed cell size", {
  fixture <- Sys.getenv("FGSTUDIO_REAL_MOSAIC_RESULT")
  skip_if(!nzchar(fixture),"Provide the real Reach result")
  trial <- readRDS(fixture)
  root <- tempfile();dir.create(root);withr::defer(unlink(root,recursive=TRUE))
  # Keep the actual saved Reach shape; only the diagnostic grid changes.
  original <- terra::rast(trial$mask_file)
  boundary <- sf::st_transform(trial$reach,terra::crs(original))
  vertices <- sf::st_coordinates(boundary)[,1:2,drop=FALSE]
  centre <- c(mean(c(terra::xmin(original),terra::xmax(original))),
    mean(c(terra::ymin(original),terra::ymax(original))))
  edge <- vertices[which.min(rowSums(sweep(vertices,2,centre,"-")^2)),]
  grid <- terra::rast(xmin=edge[1]-64,xmax=edge[1]+64,ymin=edge[2]-64,ymax=edge[2]+64,
    resolution=2,crs=terra::crs(original))
  trial$sources <- trial$originals
  # Use a correctly georeferenced coarser derivative of one actual source window.
  support <- as.vector(terra::ext(grid))+c(-8,8,-8,8)
  native_window <- terra::crop(terra::rast(trial$originals[2]),terra::ext(support),snap="out",
    filename=file.path(root,"source-window.tif"))
  coarse <- file.path(root,"source-coarse.tif")
  terra::aggregate(native_window,fact=2,fun="mean",filename=coarse,wopt=list(datatype="FLT4S"))
  trial$sources <- c(trial$originals[1],coarse)
  trial$mask_file <- file.path(root,"mask.tif")
  raw <- terra::rasterize(terra::vect(boundary),grid,field=1,background=0,touches=FALSE,
    filename=file.path(root,"mask-zero.tif"),wopt=list(datatype="INT1U"))
  terra::classify(raw,matrix(c(0,NA),ncol=2),filename=trial$mask_file,
    wopt=list(datatype="INT1U",NAflag=255))
  trial$source_extent <- as.vector(terra::ext(grid))
  trial$scope <- "reach_portion"
  trial$stream_id <- trial$reach$stream_id
  context <- file.path(root,"context.gpkg");file.copy(trial$context_path,context)
  trial$context_path <- context
  groups <- stats::setNames(list(list(path=trial$group_path)),trial$group_id)
  store <- study_dem_store(function(key) context,function(key) list(groups=groups),
    function(key) list(path="unchanged-selection"))
  binding <- store$dem_request(trial$key,trial$group_id,context,trial$group_path)
  recipe <- terrain_dem_trial_recipe(trial)
  directory <- store$prepare_dem(trial$key)
  job <- launch_terrain_dem_trial(trial,directory)
  withr::defer(if(job$is_alive()) job$kill())
  job$wait(60000)
  expect_false(job$is_alive())
  result <- job$get_result()
  out <- terra::rast(result$result$path)
  expect_equal(terra::res(out),c(2,2))
  expect_true(terra::compareGeom(out,grid,crs=FALSE))
  expect_identical(result$unmasked_result$resampling,"bilinear")
  expect_true(result$unmasked_result$mixed_source_grids)
  mask <- terra::values(terra::rast(trial$mask_file))
  expect_true(any(is.na(mask)))
  expect_true(all(is.na(terra::values(out)[is.na(mask)])))
  expect_true(any(is.finite(terra::values(out))))
  published <- store$publish_dem(binding,recipe,directory,result)
  reopened <- store$find_dem(binding,recipe)
  expect_identical(reopened$result$path,published$result$path)
  expect_true(file.exists(reopened$unmasked_result$path))
  expect_identical(reopened$unmasked_result$resampling,"bilinear")
  expect_null(store$find_dem(binding,modifyList(recipe,list(resampling="near"))))
  expect_null(store$find_dem(binding,modifyList(recipe,list(source_extent=recipe$source_extent+1))))
  withr::local_options(list(fgstudio.mosaic_trial=NULL,fgstudio.dem_trial=FALSE))
  ctx <- function() list(group_id=trial$group_id,path=context,group_path=trial$group_path)
  shiny::testServer(terrain_mosaic_trial_server,args=list(current=function() list(key=trial$key),
    event_context=ctx,store=store),{
    expect_match(output$details$html,"Bilinear interpolation")
    expect_match(output$details$html,"Source cell spacing")
    expect_match(output$details$html,"differing source grids")
    expect_false(grepl("No resampling",output$details$html))
  })
  # A supported legacy edition must match every saved input, not merely the date.
  legacy <- terrain_dem_legacy_recipe(recipe)
  expect_identical(legacy$version,1L)
  expect_identical(legacy$backend,"2026.9.24.9057")
  expect_identical(legacy$paths,recipe$paths)
  expect_identical(legacy$modified,recipe$modified)
  expect_identical(legacy$source_extent,recipe$source_extent)
})

test_that("unchanged earlier aligned and resampled editions are reused without a worker", {
  fixture <- Sys.getenv("FGSTUDIO_REAL_MOSAIC_RESULT")
  skip_if(!nzchar(fixture),"Provide the real Reach result")
  for (version in c(1L,2L,3L)) {
  trial <- readRDS(fixture)
  root <- tempfile();dir.create(root);withr::defer(unlink(root,recursive=TRUE))
  context <- file.path(root,"context.gpkg");file.copy(trial$context_path,context)
  trial$context_path <- context
  groups <- stats::setNames(list(list(path=trial$group_path)),trial$group_id)
  store <- study_dem_store(function(key) context,function(key) list(groups=groups),
    function(key) list(path="unchanged-selection"))
  binding <- store$dem_request(trial$key,trial$group_id,context,trial$group_path)
  legacy <- terrain_dem_trial_recipe(trial)
  legacy$version <- version
  legacy$backend <- switch(as.character(version),"1"="2026.9.24.9057","2"="2026.9.28.9058","3"="2026.9.28.9059")
  if(version==1L) legacy$resampling <- NULL
  if(version<3L) legacy$grid_handling <- NULL
  directory <- store$prepare_dem(trial$key)
  file.copy(trial$result$path,file.path(directory,"dem-international-feet.tif"))
  staged <- trial;staged$result$path <- file.path(directory,"dem-international-feet.tif")
  saved <- store$publish_dem(binding,legacy,directory,staged)
  withr::local_options(list(fgstudio.dem_trial=TRUE,fgstudio.dem_trial_cache=NULL))
  wrapper <- function(id) shiny::moduleServer(id,function(input,output,session) {
    task <- terrain_dem_trial_job(input,output,session,trial,
      function() list(group_id=trial$group_id,path=context,group_path=trial$group_path),
      function() list(key=trial$key),store=store,
      launch=function(...) stop("An unchanged legacy edition must not rebuild"))
  })
  shiny::testServer(wrapper,{
    session$flushReact()
    expect_match(task$notice(),"No raster processing needed")
    expect_identical(task$value()$result$path,saved$result$path)
  })
  changed <- legacy; changed$modified <- changed$modified+1
  expect_null(store$find_dem(binding,changed))
  }
})
