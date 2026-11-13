test_that("workspace separates create and open forms without duplicating inputs", {
  html <- as.character(mod_study_ui("study"))
  expect_match(html, 'data-value="new"', fixed = TRUE)
  expect_match(html, 'data-value="open"', fixed = TRUE)
  expect_match(html, "Purpose / customer question (optional)", fixed = TRUE)
  expect_equal(length(gregexpr('id="study-name"', html, fixed=TRUE)[[1]]), 1L)
  expect_match(html,"study-hydro-events",fixed=TRUE)
  expect_match(html,"study-flowline-events",fixed=TRUE)
  expect_match(html,"study-flowline_points-events",fixed=TRUE)
  expect_match(html,"fg-open-study",fixed=TRUE)
  expect_match(html,'data-value="Study overview"',fixed=TRUE)
  expect_match(html,'data-value="Study structure"',fixed=TRUE)
  expect_match(html,'data-value="Analysis CRS"',fixed=TRUE)
})

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
    session$setInputs(workspace_task = "new")
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

test_that("UI escapes study content and separates review from the next definition step", {
  store <- local_study_store(withr::local_tempdir())
  shiny::testServer(mod_study_server, args = list(store = store), {
    session$flushReact()
    session$setInputs(name = "<script>bad()</script>", notes = "<b>not html</b>", create = 1)
    html <- output$summary$html
    expect_match(html, "&lt;script&gt;", fixed = TRUE)
    expect_false(grepl("<script>bad", html, fixed = TRUE))
    expect_match(html, "Saved locally", fixed = TRUE)
    overview <- output$overview$html
    expect_match(overview, "Review this Study", fixed = TRUE)
    expect_match(overview, "Saved definition", fixed = TRUE)
    expect_match(overview, "Continue defining Study Structure", fixed = TRUE)
    expect_match(html, "Change names or purpose", fixed = TRUE)
  })
  expect_s3_class(fgstudio_app(withr::local_tempdir()), "shiny.appobj")
})

test_that("saved Study overview renders its boundary map", {
  store <- local_study_store(withr::local_tempdir())
  x <- store$create("Mapped study")
  boundary <- sf::st_sf(geometry=sf::st_sfc(sf::st_polygon(list(rbind(
    c(-90,40),c(-89.99,40),c(-89.99,40.01),c(-90,40.01),c(-90,40)))),crs=4326))
  x <- store$save_boundary(x$key,boundary,x$path)
  shiny::testServer(mod_study_server,args=list(store=store),{
    session$flushReact();session$setInputs(saved=x$key,open=1);session$flushReact()
    widget <- jsonlite::fromJSON(output$overview_map,simplifyVector=FALSE)
    methods <- vapply(widget$x$calls,`[[`,character(1),"method")
    expect_true(all(c("addProviderTiles","addPolygons","addLayersControl") %in% methods))
    expect_length(widget$x$fitBounds,5L)
  })
})

test_that("the app limits delayed blocking feedback to opening a saved study",{
  rendered <- htmltools::renderTags(fg_working_overlay())
  html <- paste(rendered$head,rendered$html)
  expect_match(html,"fg-working-overlay",fixed=TRUE)
  expect_match(html,"fg-working-detail",fixed=TRUE)
  expect_match(html,"<progress",fixed=TRUE)
  expect_match(html,"shiny:busy",fixed=TRUE)
  expect_match(html,"closest('.fg-open-study')",fixed=TRUE)
  expect_match(html,"pendingOpen || initialRestore",fixed=TRUE)
  expect_match(html,"Opening the saved Study Area",fixed=TRUE)
  expect_false(grepl("activeContext",html,fixed=TRUE))
  expect_false(grepl("Opening the terrain-derived Flowline review",html,fixed=TRUE))
})
