test_that("missing historical evidence is not inferred from current settings or plans", {
  trial <- list(target_vertical=list(crs_authority="EPSG:8228"),
    transform_plan=list(operation="A planned operation"),stage="international_feet")
  html <- as.character(terrain_dem_provenance_ui(trial))
  expect_match(html,"Not recorded")
  expect_match(html,"complete execution record was not captured")
  expect_false(grepl("None \\(recorded by the producer\\)",html))
  expect_false(grepl("A planned operation",html,fixed=TRUE))
})

test_that("retained and newly captured execution evidence stay distinct", {
  trial <- list(result=list(method="terra arithmetic: source metres / 0.3048",datum_operation="none"),
    unmasked_result=list(method="Recorded mosaic method"),saved_dem=list(backend="old-backend"))
  old <- as.character(terrain_dem_provenance_ui(trial))
  expect_match(old,"None \\(recorded by the producer\\)")
  expect_match(old,"old-backend")
  expect_match(old,"source metres / 0.3048",fixed=TRUE)
  expect_match(old,"complete execution record was not captured")
  trial$execution <- list(implementation="native_same_crs",software=list(fluvgeo="producer-backend",
    geospatial=list(GDAL="recorded-gdal")))
  current <- as.character(terrain_dem_provenance_ui(trial))
  expect_match(current,"producer-backend")
  expect_false(grepl("old-backend",current))
  expect_match(current,"Not used; native same-CRS")
  expect_match(current,"not evidence that an operation ran")
  expect_match(current,"Software used")
  expect_match(current,"recorded-gdal")
})
