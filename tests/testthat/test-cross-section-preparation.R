test_that("precomputed REMs persist across reads and reject changed outputs", {
  root<-withr::local_tempdir();key<-paste(rep("a",64),collapse="")
  request<-list(key=key,directory=file.path(root,key),inputs=list(source="immutable-input"),
    recipe=list(buffer_distance=150,display_max_cells=250000,display_crs="EPSG:3857"))
  raster<-terra::rast(nrows=8,ncols=8,xmin=500000,xmax=500080,ymin=4700000,ymax=4700080,crs="EPSG:26915")
  terra::values(raster)<-100:163
  dem<-file.path(root,"dem.tif");terra::writeRaster(raster,dem)
  calls<-0L
  testthat::with_mocked_bindings({
    expect_null(cross_section_rem_artifact(request))
    first<-cross_section_rem_artifact(request,dem=dem,line=NULL,points=NULL)
    second<-cross_section_rem_artifact(request,dem=dem,line=NULL,points=NULL)
    expect_equal(calls,1L)
    expect_true(file.exists(first$path))
    expect_true(second$precomputed)
    expect_identical(first$path,second$path)
    expect_equal(as.vector(terra::values(terra::rast(first$path))),100:163)
    expect_true(file.exists(file.path(request$directory,"preparation.json")))
    writeLines("changed",second$display)
    expect_null(cross_section_rem_artifact(request))
  },detrend=function(...) {calls<<-calls+1L;list(rem=raster)},.package="fluvgeo")
})

test_that("section numbers stay at the channel for polylines with extra floodplain vertices", {
  f<-cross_section_review_fixture();s<-f$layout$sections[3,]
  xy<-sf::st_coordinates(s)[,1:2]
  sf::st_geometry(s)[[1]]<-sf::st_linestring(rbind(xy[1,],c(46,-22),c(48,-15),xy[2:3,],xy[4,]))
  s$left_bank_vertex<-4L;s$right_bank_vertex<-5L
  points<-cross_section_number_points(s)
  expect_identical(points$Seq,3L)
  expect_equal(unname(sf::st_coordinates(points)[1,]),c(50,0),tolerance=1)
  expect_equal(cross_section_vertex_labels(s)[2:3],paste("Left floodplain bend",1:2))
})
