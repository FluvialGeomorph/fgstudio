test_that("layer choices contain only available overlays for the active task", {
  x <- sf::st_sf(geometry=sf::st_sfc(sf::st_point(c(0,0)),crs=4326))
  state <- list(clicked=x,located=list(flowline=x),result=list(layers=list(upstream=x)))
  expect_equal(context_layer_groups("view","view",TRUE,TRUE,state,x,list(),x,list()),
    c("boundary","Saved Streams"))
  expect_equal(context_layer_groups("draw","boundary"),character())
  groups <- context_layer_groups("explore","stream",TRUE,state=state,polygons=x,channels=x,
    stream_preview=list(clipped=TRUE))
  expect_true(all(c("Stream candidates","Stream preview","Unclipped buffer","Selected location") %in% groups))
  expect_false(any(c("HUC12","Boundary candidates","Upstream channels","Downstream path") %in% groups))
  groups <- context_layer_groups("explore","boundary",TRUE,state=state,polygons=x,channels=x)
  expect_true(all(c("Boundary candidates","Upstream channels") %in% groups))
  expect_false(any(c("Stream candidates","Boundary preview","Downstream path") %in% groups))
})
