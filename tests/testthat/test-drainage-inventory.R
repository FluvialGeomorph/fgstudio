test_that("feature lists preserve names, IDs, duplicates and source row links", {
  x <- sf::st_sf(GNIS_NAME = c("Cole Creek", "", "Cole Creek", "<b>Stream</b>"),
    COMID = c("100", "200", "300", "400"),
    geometry = sf::st_sfc(lapply(1:4, function(i) sf::st_linestring(rbind(c(0,0),c(0,i)))), crs=4326))
  a <- drainage_feature_inventory(x, "upstream", "100")
  expect_equal(nrow(a), 4)
  expect_equal(sum(a$name == "Cole Creek"), 2)
  expect_equal(a$source_id[match(1:4, a$feature_row)], x$COMID)
  expect_true("Channel (name not supplied) - 200" %in% a$label)
  result <- list(layers = list(huc12=NULL,basin=NULL,upstream=x,downstream=NULL),
    location=list(comid="100"), distance_km=50, retrieved_at="Test",sources="Synthetic",
    status=data.frame(layer=names(drainage_groups),status=c("unavailable","unavailable","available","unavailable"),
      outcome=c("no_features","service_unavailable","available","unresolved"),detail="Test",features=c(0,0,4,0)))
  html <- gsub("[[:space:]]+", " ", as.character(drainage_result_ui(result)))
  expect_match(html, "HUC12</strong> - No matches", fixed=TRUE)
  expect_match(html, "Upstream basin</strong> - Request failed", fixed=TRUE)
  expect_match(html, "Upstream channels</strong> (4)", fixed=TRUE)
  expect_match(html, "Downstream path</strong> - Unresolved", fixed=TRUE)
  expect_match(html, "&lt;b&gt;Stream&lt;/b&gt;", fixed=TRUE)
  expect_false(grepl("<b>Stream</b>", html, fixed=TRUE))
  expect_match(html, "overflow-y: auto", fixed=TRUE)
})

test_that("watersheds have honest labels when services omit names or identity", {
  x <- sf::st_sf(huc12="012345678901",name="Test watershed",
    geometry=sf::st_sfc(sf::st_point(c(0,0)),crs=4326))
  expect_equal(drainage_feature_inventory(x,"huc12","1")$label, "Test watershed - 012345678901")
  x$name <- x$huc12 <- NULL
  a <- drainage_feature_inventory(x,"basin","123")
  expect_match(a$label, "Upstream basin of stream 123")
  expect_match(a$label, "source ID not supplied")
  expect_true(is.na(a$source_id))
})

test_that("map and controls use responsive columns instead of a vertical sequence", {
  html <- as.character(mod_boundary_ui("test", TRUE))
  expect_match(html, "height:72vh", fixed=TRUE)
  expect_match(html, "min-height:360px", fixed=TRUE)
  expect_false(grepl("620px",html,fixed=TRUE))
  expect_match(html,"aria-label=\"Expand card\"",fixed=TRUE)
  expect_match(html, "bslib-grid", fixed=TRUE)
  expect_match(html, "Public USGS queries", fixed=TRUE)
})

test_that("channel inventories use direction and connectivity instead of names", {
  x <- stream_test_context()$layers$upstream
  x$gnis_name <- c("Z first", "A second")
  down <- drainage_feature_inventory(x,"downstream","101")
  expect_equal(down$source_id,c("102","101"))
  expect_equal(down$navigation_order,1:2)
  up <- drainage_feature_inventory(x,"upstream","102")
  expect_equal(up$source_id,c("102","101"))
})
