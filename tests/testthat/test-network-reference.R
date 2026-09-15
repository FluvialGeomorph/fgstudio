test_that("reference uses matching viewport tiles, not full feature downloads", {
  x <- add_network_reference(leaflet::leaflet(), TRUE)
  expect_true(any(vapply(x$dependencies,function(d) identical(d$name,"fgstudio-protomaps"),logical(1))))
  hook <- x$jsHooks$render[[1]]
  expect_match(hook$data$url,"nhdflowline_network/tiles/WebMercatorQuad/{z}/{y}/{x}",fixed=TRUE)
  expect_false(grepl("/items",hook$data$url,fixed=TRUE))
  expect_true(hook$data$enabled)
  expect_match(hook$code,"pointerEvents = 'none'",fixed=TRUE)
})

test_that("worker distinguishes HTTP failure from distance and unknown responses", {
  testthat::local_mocked_bindings(locate_drainage_stream = function(...) {
    warning("Failed to get features: HTTP 502 Bad Gateway.")
    stop("No usable features returned")
  }, .package="fluvgeo")
  e <- tryCatch(drainage_request("locate",NULL),error=identity)
  expect_s3_class(e,"fgstudio_drainage_error")
  expect_equal(e$code,"service_unavailable")
  expect_match(e$details,"502")
  expect_match(conditionMessage(e),"without moving")
  testthat::local_mocked_bindings(locate_drainage_stream = function(...) {
    stop("No stream snap within 200 metres. Zoom in.")
  }, .package="fluvgeo")
  e <- tryCatch(drainage_request("locate",NULL),error=identity)
  expect_equal(e$code,"outside_snap_distance")
  testthat::local_mocked_bindings(locate_drainage_stream = function(...) {
    stop("No usable features returned")
  }, .package="fluvgeo")
  e <- tryCatch(drainage_request("locate",NULL),error=identity)
  expect_equal(e$code,"unresolved")
  expect_match(conditionMessage(e),"does not establish")
  expect_equal(unserialize(serialize(e,NULL))$details,e$details)
})
