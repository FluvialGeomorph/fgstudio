test_that("Stream file worker uses selected AOI and invalidates on revision change", {
  s <- sf::st_sf(stream_id="stream-one",stream_name="Test Stream",geometry=sf::st_as_sfc(sf::st_bbox(
    c(xmin=-96.10,ymin=41.25,xmax=-96.09,ymax=41.26),crs=4326)))
  c <- sf::st_sf(candidate_key="catalog-one",title="Test collection",catalog="USGS 3DEP",geometry=sf::st_geometry(s))
  current <- shiny::reactiveVal(list(path="revision-one",stream_inventory=s))
  discovery <- function() list(records=c)
  plan <- function() data.frame(candidate_key="catalog-one",product="DEM")
  launch <- function(stream,collection) {
    expect_identical(stream$stream_id,"stream-one");expect_identical(collection$candidate_key,"catalog-one")
    list(is_alive=function() FALSE,kill=function() TRUE,get_result=function()
      list(outcome="COMPLETE",message="Synthetic metadata",files=sf::st_sf(file_id=c("tile","tile2"),title=c("Tile","Tile 2"),
        size_bytes=1000,pixel_size_m=1,resolution_evidence="Test only",format="GeoTIFF",publication_date="Unknown",geometry=rep(sf::st_geometry(s),2))))
  }
  shiny::testServer(stream_dem_files_server,args=list(current=current,discovery=discovery,plan=plan,
    included=function() "catalog-one",launch=launch),{
    session$flushReact();session$setInputs(stream="stream-one",collection="catalog-one");session$setInputs(find=1)
    poll();session$flushReact();expect_match(status(),"COMPLETE")
    expect_match(output$acquisition$html,"0 selected / 2 tiles",fixed=TRUE)
    expect_match(output$acquisition$html,"Select tiles to show",fixed=TRUE)
    session$setInputs(visible="tile");expect_equal(nrow(visible_files()),1L)
    expect_match(output$acquisition$html,"1 selected / 2 tiles",fixed=TRUE)
    expect_match(output$acquisition$html,"Not saved",fixed=TRUE)
    altered <- result(); altered$outcome <- "PARTIAL"
    altered$files$size_bytes <- c(1000000,NA_real_)
    altered$files$pixel_size_m <- c(2,NA_real_)
    result(altered); session$setInputs(visible=c("tile","tile2"))
    expect_match(output$acquisition$html,"1 MB known subtotal",fixed=TRUE)
    expect_match(output$acquisition$html,"1 coarser than 1 m; 1 unknown",fixed=TRUE)
    expect_match(output$acquisition$html,"Incomplete catalog result",fixed=TRUE)
    expect_match(output$acquisition$html,"cannot serve as analysis DEMs",fixed=TRUE)
    captured <- NULL
    testthat::with_mocked_bindings({
      session$setInputs(select_all=1);expect_identical(captured,c("tile","tile2"))
      session$setInputs(select_none=1);expect_length(captured,0L)
    },updateCheckboxGroupInput=function(session,inputId,...,selected) {captured <<- selected},.package="shiny")
    expect_match(output$details$html,"max-height:220px",fixed=TRUE)
    current(list(path="revision-two",stream_inventory=s));session$flushReact()
    expect_null(result())
    session$setInputs(find=2);session$setInputs(cancel=1);expect_match(status(),"cancelled")
  })
})

test_that("saved file plans reopen and guard context, collection and file revisions", {
  store <- local_study_store(withr::local_tempdir()); x <- store$create("Synthetic file plan")
  area <- sf::st_sf(geometry=sf::st_as_sfc(sf::st_bbox(c(xmin=-96.10,ymin=41.25,xmax=-96.09,ymax=41.26),crs=4326)))
  x <- store$save_boundary(x$key,area,x$path)
  lines <- sf::st_sf(source_id="synthetic-line",geometry=sf::st_sfc(sf::st_linestring(rbind(c(-96.098,41.252),c(-96.092,41.258))),crs=4326))
  x <- store$save_stream(x$key,lines,"Synthetic Stream",10,"m","Synthetic fixture",x$path)
  collection <- sf::st_sf(candidate_key="USGS 3DEP:fixture",catalog="USGS 3DEP",record_id="fixture",snapshot_id="test",
    retrieved_at="now",title="Synthetic lidar",date_label="Unknown",status="Published",availability="Unknown",metadata_url="Unknown",
    access_url="Unknown",raw_metadata="{}",coverage="Not assessed",geometry=sf::st_geometry(area))
  d <- list(study_area=x$boundary_sf,records=collection,searches=data.frame(catalog="USGS 3DEP",snapshot_id="test",outcome="COMPLETE"),
    acquisition_plan=data.frame(candidate_key=collection$candidate_key,product="DEM"))
  r <- list(stream=x$stream_inventory,collection=collection,outcome="COMPLETE",message="Synthetic",retrieved_at="now",endpoint="https://example.org",
    files=sf::st_sf(file_id="tile",title="Tile",download_url="https://example.org/tile.tif",raw_metadata="{}",size_bytes=1000,pixel_size_m=1,
      resolution_evidence="Synthetic",format="GeoTIFF",publication_date="Unknown",geometry=sf::st_geometry(area)))
  expect_error(store$save_dem_files(x$key,r,"tile",x$path,NULL),"acquisition plan first")
  store$save_survey_collections(x$key,d,collection$candidate_key,x$path,NULL)
  before <- tools::md5sum(x$path)
  path <- store$save_dem_files(x$key,r,"tile",x$path,NULL)
  old <- store$dem_files(x$key,r$stream$stream_id,collection$candidate_key)
  expect_identical(old$result$selected,"tile");expect_identical(tools::md5sum(x$path),before)
  expect_error(store$prepare_dem_download(x$key,x$path,path,character()),"nonempty")
  expect_error(store$save_dem_files(x$key,r,character(),x$path,NULL),"newer")
  forged <- r; forged$collection$snapshot_id <- "other"
  expect_error(store$save_dem_files(x$key,forged,"tile",x$path,path),"evidence changed")
  refreshed <- new.env(parent=emptyenv());refreshed$path <- path
  shiny::testServer(stream_dem_files_server,args=list(current=function() x,discovery=function() d,
    plan=function() d$acquisition_plan,included=function() collection$candidate_key,store=store,
    launch=function(...) list(is_alive=function() FALSE,kill=function() TRUE,get_result=function() r)),{
    session$flushReact();session$setInputs(stream=r$stream$stream_id,collection=collection$candidate_key)
    expect_match(status(),"reopened");expect_identical(saved_ids(),"tile")
    expect_false(session$returned$has_pending())
    session$setInputs(visible=character())
    expect_true(session$returned$has_pending())
    session$setInputs(visible="tile")
    expect_match(output$acquisition$html,"1 selected / 1 tiles; Saved",fixed=TRUE)
    session$setInputs(find=1);poll();session$flushReact()
    expect_false(saved_inventory())
    expect_match(output$acquisition$html,"Not saved",fixed=TRUE)
    expect_true(session$returned$has_pending())
    session$setInputs(save_files=1)
    expect_true(saved_inventory())
    refreshed$path <- saved_path()
  })
  path <- refreshed$path
  attempt <- store$prepare_dem_download(x$key,x$path,path,"tile")
  expect_true(file.exists(file.path(attempt,"selection.gpkg")))
  expect_identical(store$dem_download(x$key,r$stream$stream_id,collection$candidate_key),attempt)
  x <- store$set_analysis_crs(x$key,"26915","Synthetic projected test area","Test analyst",x$path)
  expect_identical(store$dem_download(x$key,r$stream$stream_id,collection$candidate_key),attempt)
  shiny::testServer(stream_dem_files_server,args=list(current=function() x,discovery=function() d,
    plan=function() d$acquisition_plan,included=function() collection$candidate_key,store=store),{
    session$flushReact();session$setInputs(stream=r$stream$stream_id,collection=collection$candidate_key)
    expect_true(saved_inventory());expect_identical(saved_ids(),"tile")
    expect_match(status(),"reopened")
  })
  next_path <- store$save_dem_files(x$key,r,character(),x$path,path)
  expect_true(file.exists(path));expect_false(identical(path,next_path))
  store$rename(x$key,"New name",x$path)
  expect_error(store$save_dem_files(x$key,r,"tile",x$path,next_path),"newer")
  expect_error(store$prepare_dem_download(x$key,x$path,path,"tile"),"older study revision")
})
