test_that("module saves once, resets explicitly and opens saved records", {
  store <- local_study_store(withr::local_tempdir())
  shiny::testServer(mod_study_server, args = list(store = store), {
    session$flushReact()
    session$setInputs(name = " ", notes = "", create = 1)
    expect_null(current())
    expect_match(notice()$text, "Enter a Study Area")
    session$setInputs(name = "Papillion", notes = "A question", create = 2)
    saved <- current()
    expect_identical(saved$name, "Papillion")
    session$setInputs(create = 3)
    expect_length(store$catalog()$choices, 1)
    expect_identical(current()$study_id, saved$study_id)
    session$setInputs(another = 1)
    expect_null(current())
    session$setInputs(saved = saved$key, open = 1)
    expect_identical(current(), saved)
    session$setInputs(saved = "../../outside", open = 2)
    expect_identical(current(), saved)
    expect_identical(notice()$kind, "danger")
  })
})

test_that("a fresh session does not inherit another session's active study", {
  store <- local_study_store(withr::local_tempdir())
  store$create("First session")
  shiny::testServer(mod_study_server, args = list(store = store), {
    session$flushReact()
    expect_null(current())
    expect_length(catalog_state()$choices, 1)
  })
})

test_that("UI escapes study content and shows a clear next step", {
  store <- local_study_store(withr::local_tempdir())
  shiny::testServer(mod_study_server, args = list(store = store), {
    session$flushReact()
    session$setInputs(name = "<script>bad()</script>", notes = "<b>not html</b>", create = 1)
    html <- output$summary$html
    expect_match(html, "&lt;script&gt;", fixed = TRUE)
    expect_false(grepl("<script>bad", html, fixed = TRUE))
    expect_match(html, "What comes next", fixed = TRUE)
    expect_match(html, "not implemented", fixed = TRUE)
  })
  expect_s3_class(fgstudio_app(withr::local_tempdir()), "shiny.appobj")
})
