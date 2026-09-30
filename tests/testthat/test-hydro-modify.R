test_that("cutline snapshots reopen and reject stale edits",{
  d <- withr::local_tempdir();context <- file.path(d,"study.gpkg");file.create(context)
  store <- study_hydro_store(function(key) context)
  line <- hydro_drawn_lines(list(type="FeatureCollection",features=list(list(
    geometry=list(type="LineString",coordinates=list(c(-93,40),c(-93.001,40.001)))))))
  first <- store$hydro_save("study","event","stream","dem1",line,NULL,context)
  expect_true(file.exists(file.path(first$path,"cutlines.gpkg")))
  expect_equal(store$hydro_read("study","event","stream","dem1")$lines,line)
  expect_null(store$hydro_read("study","event","stream","dem2"))
  expect_error(store$hydro_save("study","event","stream","dem1",line,NULL,context),"another session")
  empty <- hydro_drawn_lines(list(type="FeatureCollection",features=list()))
  second <- store$hydro_save("study","event","stream","dem1",empty,first$id,context)
  expect_equal(nrow(second$lines),0)
  expect_true(file.exists(file.path(first$path,"cutlines.gpkg")))
})

test_that("map drawing accepts only finite geographic polylines",{
  expect_error(hydro_drawn_lines(list(type="FeatureCollection",features=list(
    list(geometry=list(type="Polygon",coordinates=list()))))),"line tool")
  expect_error(hydro_drawn_lines(list(type="FeatureCollection",features=list(
    list(geometry=list(type="LineString",coordinates=list(c(200,40),c(201,41))))))),"coordinates")
  expect_equal(terrain_palette(8),grDevices::colorRampPalette(c("cadetblue2","khaki1",
    "chartreuse4","goldenrod1","orangered4","saddlebrown","gray70","white"))(8))
})
