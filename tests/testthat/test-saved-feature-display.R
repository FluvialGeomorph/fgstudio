display_test_study <- function() {
  shape <- sf::st_geometry(stream_test_parent())
  list(name = "Study <safe>",
    stream_inventory = sf::st_sf(stream_id = c("s2", "s1"),
      stream_name = c("Zulu", "alpha"), geometry = rep(shape, 2)),
    reach_inventory = sf::st_sf(reach_id = c("r2", "r1"), stream_id = c("s2", "s2"),
      reach_name = c("Zulu reach", "alpha <reach>"), geometry = rep(shape, 2)))
}

test_that("rename choices sort by name and retain identities and parent context", {
  x <- display_test_study()
  expect_equal(unname(saved_feature_choices(x, "stream")), c("s1", "s2"))
  expect_equal(unname(saved_feature_choices(x, "reach")), c("r1", "r2"))
  expect_equal(names(saved_feature_choices(x, "reach"))[1], "Zulu / alpha <reach>")
  expect_length(saved_feature_choices(list(), "reach"), 0)
})

test_that("Reach rename choices group by Stream before sorting Reach names", {
  x <- list(stream_inventory = data.frame(stream_id = c("s2", "s1"),
    stream_name = c("Zulu", "alpha")),
    reach_inventory = data.frame(reach_id = c("r4", "r1", "r3", "r2"),
      stream_id = c("s2", "s1", "s2", "s1"),
      reach_name = c("Reach Two", "Reach One", "Reach One", "Reach Two")))
  choices <- saved_feature_choices(x, "reach")
  expect_equal(unname(choices), c("r1", "r2", "r3", "r4"))
  expect_equal(names(choices), c("alpha / Reach One", "alpha / Reach Two",
    "Zulu / Reach One", "Zulu / Reach Two"))
})

test_that("inventory includes every Reach and Streams awaiting Reaches", {
  x <- saved_hierarchy_inventory(display_test_study())
  expect_equal(x$Stream, c("alpha", "Zulu", "Zulu"))
  expect_equal(x$Reach, c("Not yet defined", "alpha <reach>", "Zulu reach"))
  expect_equal(x$`Reach area`, c("", "Recorded", "Recorded"))
  expect_null(saved_hierarchy_inventory(list()))
})

test_that("saved feature popups escape names and edit layers cannot intercept clicks", {
  x <- display_test_study()
  popup <- saved_feature_popup(x, "reach", 2)
  expect_match(popup, "alpha &lt;reach&gt;", fixed = TRUE)
  expect_match(popup, "Study &lt;safe&gt;", fixed = TRUE)
  expect_match(popup, "r1", fixed = TRUE)
  for (identify in c(FALSE, TRUE)) {
    map <- saved_feature_layers(leaflet::leaflet(), x, identify)
    calls <- Filter(function(call) call$method == "addPolygons", map$x$calls)
    expect_length(calls, 2)
    # Leaflet stores path options as a named list within the polygon arguments.
    for (call in calls) {
      options <- Filter(function(a) is.list(a) && "interactive" %in% names(a), call$args)
      expect_identical(options[[1]]$interactive, identify)
      expect_false(options[[1]]$bubblingMouseEvents)
    }
  }
})

test_that("saved selection focus uses geographic bounds and ignores absent geometry", {
  x <- display_test_study(); map <- leaflet::leaflet()
  shape <- saved_feature_shape(x, "reach", "r1")
  expect_equal(shape$reach_id, "r1")
  focused <- focus_saved_feature(map, sf::st_transform(shape, 26915))
  b <- sf::st_bbox(shape)
  expect_equal(unlist(focused$x$fitBounds[1:4]), unname(as.numeric(b[c(2,1,4,3)])), tolerance = 1e-6)
  expect_identical(focus_saved_feature(map, saved_feature_shape(x, "reach", "unknown")), map)
  expect_identical(focus_saved_feature(map, NULL), map)
})

test_that("Reach dropdowns focus the selected saved feature in each action", {
  study <- display_test_study()
  study$boundary <- TRUE
  study$boundary_sf <- stream_test_parent()
  focused <- character()
  shiny::testServer(mod_boundary_server, args = list(study = study, store = NULL,
    is_active = function() TRUE, on_saved = function(x) NULL), {
    testthat::with_mocked_bindings({
      session$flushReact()
      session$setInputs(selection_target = "reach", map_mode = "reach", reach_operation = "new", reach_parent = "s2")
      expect_equal(tail(focused, 1), "s2")
      session$setInputs(reach_operation = "split", split_reach = "r1")
      expect_equal(tail(focused, 1), "r1")
      session$setInputs(reach_operation = "merge", merge_keep = "r2")
      expect_equal(tail(focused, 1), "r2")
    }, focus_saved_feature = function(map, shape) {
      if (!is.null(shape) && nrow(shape)) focused <<- c(focused,
        if ("reach_id" %in% names(shape)) shape$reach_id else shape$stream_id)
      map
    }, .package = "fgstudio")
  })
})
