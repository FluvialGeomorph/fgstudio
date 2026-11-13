test_that("OpenTopoMap is the default project basemap", {
  widget <- add_opentopomap(leaflet::leaflet())
  calls <- widget$x$calls
  providers <- Filter(function(x) identical(x$method,"addProviderTiles"),calls)
  hidden <- Filter(function(x) identical(x$method,"hideGroup"),calls)
  expect_identical(providers[[1]]$args[[3]],"OpenTopoMap")
  expect_true(all(c("Street map","Imagery") %in%
    vapply(hidden,function(x)x$args[[1]],character(1))))
  expect_false("OpenTopoMap" %in% vapply(hidden,function(x)x$args[[1]],character(1)))
})

test_that("project maps use the scale-conscious canvas renderer", {
  widget <- fg_leaflet()
  expect_true(widget$x$options$preferCanvas)
  expect_identical(widget$x$options$maxZoom,23)
})

test_that("Street map can be the explicit footprint-review default", {
  widget <- add_opentopomap(leaflet::leaflet(),default="Street map")
  hidden <- Filter(function(x) identical(x$method,"hideGroup"),widget$x$calls)
  groups <- vapply(hidden,function(x)x$args[[1]],character(1))
  expect_true(all(c("OpenTopoMap","Imagery") %in% groups))
  expect_false("Street map" %in% groups)
  expect_error(add_opentopomap(leaflet::leaflet(),default="Unknown"),"Basemap default")
})
