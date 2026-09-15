test_that("Photon results are bounded, labeled and coordinate-checked", {
  feature <- list(geometry = list(type = "Point", coordinates = list(-96, 41)),
    properties = list(name = "Omaha", city = "Omaha", state = "Nebraska"))
  body <- list(type = "FeatureCollection", features = list(feature))
  expect_equal(photon_places(body), data.frame(label = "Omaha, Nebraska", lon = -96, lat = 41))
  body$features <- rep(list(feature), 8)
  expect_equal(nrow(photon_places(body)), 5L)
  feature$geometry$coordinates <- list(500, 41)
  body$features <- list(feature)
  expect_equal(nrow(photon_places(body)), 0L)
  body$features <- list()
  expect_equal(nrow(photon_places(body)), 0L)
  expect_error(photon_places(NULL), "Invalid")
  expect_error(search_places(""), "Enter a place")
  expect_error(search_places(NA_character_), "Enter a place")
})

test_that("compact search preserves drawings and saved context", {
  store <- local_study_store(withr::local_tempdir())
  study <- store$create("Study")
  hash <- tools::md5sum(study$path)
  calls <- character()
  fake_search <- function(query) {
    calls <<- c(calls, query)
    if (query == "fail") stop("Service unavailable")
    if (query == "empty") return(data.frame(label = character(), lon = numeric(), lat = numeric()))
    data.frame(label = "Omaha, Nebraska", lon = -96, lat = 41)
  }
  shiny::testServer(mod_boundary_server, args = list(study = study, store = store,
    is_active = function() TRUE, on_saved = function(x) stop("Must not save"), search = fake_search), {
    session$flushReact()
    session$setInputs(map_draw_all_features = draw_fixture())
    before <- candidate()
    expect_match(output$map, "addSearchOSM", fixed = TRUE)
    expect_match(output$map, "fgPlaceResults", fixed = TRUE)
    expect_length(calls, 0)
    session$setInputs(map_place_query = list(text = "Omaha", token = 1))
    expect_identical(calls, "Omaha")
    expect_identical(candidate(), before)
    expect_identical(tools::md5sum(study$path), hash)
    expect_false(store$read(study$key)$boundary)
    session$setInputs(map_place_query = list(text = "empty", token = 2))
    expect_identical(tail(calls, 1), "empty")
    expect_identical(candidate(), before)
    session$setInputs(map_place_query = list(text = "fail", token = 3))
    expect_identical(tail(calls, 1), "fail")
    expect_identical(candidate(), before)
  })
})

test_that("search control is collapsed and the separate form is gone", {
  map <- add_place_search(leaflet::leaflet())
  options <- map$x$calls[[1]]$args[[1]]
  expect_true(options$collapsed)
  expect_true(options$autoCollapse)
  expect_equal(options$delayType, 1200)
  expect_match(as.character(options$buildTip), "textContent", fixed = TRUE)
  expect_false(grepl("Search map", as.character(mod_boundary_ui("test")), fixed = TRUE))
})
