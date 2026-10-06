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
