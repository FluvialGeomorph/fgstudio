test_that("Stream names are explicit, trimmed and distinct", {
  expect_identical(stream_names_input(" Cole Creek \r\n\nOther Creek\n"), c("Cole Creek", "Other Creek"))
  expect_error(stream_names_input(" \n"), "at least one")
  expect_error(stream_names_input("Cole Creek\n cole creek "), "different name")
  expect_error(stream_names_input(NA_character_), "at least one")
})

test_that("initial Streams persist with stable parentage and retain the study", {
  store <- local_study_store(withr::local_tempdir())
  a <- store$create("Study", "Compare surveys")
  b <- store$save_boundary(a$key, drawn_boundary(draw_fixture()), a$path)
  hash <- tools::md5sum(b$path)
  c <- store$define_streams(b$key, c("Cole Creek", "Other Creek"), "Customer scope", b$path)
  expect_equal(c$streams, 2L)
  expect_identical(c$stream_inventory$stream_name, c("Cole Creek", "Other Creek"))
  expect_identical(c$stream_inventory$study_area_id, rep(b$study_id, 2))
  expect_equal(length(unique(c$stream_inventory$stream_id)), 2L)
  expect_false(inherits(c$stream_inventory, "sf"))
  expect_identical(c$boundary_sf, b$boundary_sf)
  expect_identical(c$purpose, b$purpose)
  expect_match(c$notes, b$notes, fixed = TRUE)
  expect_identical(tools::md5sum(b$path), hash)
  expect_identical(store$read(c$key)$stream_inventory, c$stream_inventory)
  expect_false(c$can_define_streams)
  expect_error(store$define_streams(b$key, "Stale", "Reason", b$path), "newer revision")
  expect_error(store$define_streams(c$key, "Replace", "Reason", c$path), "already exist")
  renamed <- store$rename(c$key, "Renamed study", c$path)
  expect_identical(renamed$stream_inventory, c$stream_inventory)
  expect_identical(renamed$study_id, b$study_id)
})

test_that("invalid names do not publish and names-only studies can define Streams", {
  store <- local_study_store(withr::local_tempdir())
  a <- store$create("Study")
  expect_true(a$can_define_streams)
  expect_error(store$define_streams(a$key, c("One", "one"), "Reason", a$path), "Duplicate")
  expect_identical(store$read(a$key), a)
  b <- store$define_streams(a$key, "One", "Reason", a$path)
  expect_false(b$boundary)
  expect_equal(b$streams, 1L)
  expect_equal(b$reaches, 0L)
  expect_equal(b$events, 0L)
})

test_that("Stream module validates, guards pending boundaries, saves only once", {
  store <- local_study_store(withr::local_tempdir())
  study <- store$create("Study")
  state <- new.env(); state$pending <- TRUE; state$active <- TRUE
  result <- NULL
  shiny::testServer(mod_streams_server, args = list(study = study, store = store,
    is_active = function() state$active, boundary_pending = function() state$pending,
    on_saved = function(x) result <<- x), {
    session$flushReact()
    session$setInputs(names = "One\nTwo", rationale = "Customer choice")
    expect_equal(store$read(study$key)$streams, 0L)
    session$setInputs(save = 1)
    expect_match(status(), "boundary work")
    expect_null(result)
    state$pending <- FALSE
    session$setInputs(names = "One\none", save = 2)
    expect_match(status(), "different name")
    expect_null(result)
    state$active <- FALSE
    session$setInputs(names = "One\nTwo", save = 3)
    expect_null(result)
    state$active <- TRUE
    session$setInputs(save = 4)
    expect_equal(result$streams, 2L)
    expect_match(result$notes, "Customer choice")
    saved <- result
    session$setInputs(save = 5)
    expect_identical(result, saved)
    expect_identical(store$read(study$key)$path, saved$path)
  })
})

test_that("Stream form carries unfinished text across same-study revisions", {
  store <- local_study_store(withr::local_tempdir())
  shiny::testServer(mod_study_server, args = list(store = store), {
    session$flushReact()
    session$setInputs(name = "Study", create = 1)
    session$setInputs("streams_1-names" = "Cole Creek", "streams_1-rationale" = "Customer choice")
    x <- current()
    current(store$save_boundary(x$key, drawn_boundary(draw_fixture()), x$path))
    session$flushReact()
    expect_match(output$streams_editor$html, "Cole Creek", fixed = TRUE)
    expect_match(output$streams_editor$html, "Customer choice", fixed = TRUE)
    session$setInputs("streams_2-names" = "Cole Creek", "streams_2-save" = 1)
    expect_equal(current()$streams, 1L)
    expect_match(output$streams_editor$html, "Saved Streams and Reaches", fixed = TRUE)
    expect_false(grepl("Save Streams", output$streams_editor$html, fixed = TRUE))
  })
})

test_that("explicit reopening discards unfinished initial Stream text", {
  store <- local_study_store(withr::local_tempdir())
  shiny::testServer(mod_study_server, args = list(store = store), {
    session$flushReact()
    session$setInputs(name = "Study", create = 1)
    key <- current()$key
    session$setInputs("streams_1-names" = "Unsaved Creek")
    old_editor <- output$boundary_editor$html
    session$setInputs(saved = key, open = 1)
    expect_false(grepl("Unsaved Creek", output$streams_editor$html, fixed = TRUE))
    expect_false(identical(old_editor, output$boundary_editor$html))
    expect_equal(current()$streams, 0L)
  })
})
