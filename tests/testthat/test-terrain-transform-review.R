# Small UI/storage records, not scientific transformation fixtures.
transform_review_fixture <- function() {
  catalog <- list(source=list(name="Source reference"),target=list(name="Study target"),aoi=c(-94,41,-90,43),
    candidates=list(list(key="available",description="Available operation",definition="exact pipeline",
      accuracy=0.2,selectable=TRUE,reason="",grids=list()),
      list(key="missing",description="Missing-grid operation",definition="unavailable pipeline",
        accuracy=0.1,selectable=FALSE,reason="Required grid is unavailable.",grids=list())))
  list(fingerprint="catalog-v1",groups=list(list(key="pair",source_indices=c(1,2),
    requires_choice=TRUE,explanation="Review this reference pair.",catalog=catalog)))
}

test_that("saved Study references supply the real transformation review", {
  fixture <- Sys.getenv("FGSTUDIO_REAL_MOSAIC_RESULT")
  skip_if(!nzchar(fixture),"Provide the existing real Reach result")
  t <- readRDS(fixture)
  s <- local_study_store(dirname(dirname(t$context_path))); x <- s$read(t$key)
  g <- s$acquisition_groups(t$key)$groups[[t$group_id]]
  request <- s$transform_request(t$key,t$group_id,x$path,g$path)
  expect_identical(request$args$target_vertical,x$vertical_reference$crs_wkt)
  review <- do.call(fluvgeo::review_terrain_transformations,request$args)
  expect_gt(nrow(review$sources),0L)
  expect_true(all(vapply(review$groups,function(g) !g$requires_choice,logical(1))))
  expect_error(s$transform_request(t$key,t$group_id,"stale",g$path),"changed")
})

test_that("selection is explicit and unavailable operations cannot be saved", {
  r <- transform_review_fixture()
  expect_error(terrain_transform_choices(r,list()),"Choose")
  expect_error(terrain_transform_choices(r,list(pair="missing")),"Choose")
  expect_error(terrain_transform_choices(r,list(pair="forged")),"Choose")
  chosen <- terrain_transform_choices(r,list(pair="available"))
  expect_identical(chosen[[1]]$operation$definition,"exact pipeline")
  r$groups[[1]]$requires_choice <- FALSE
  expect_identical(terrain_transform_choices(r,list())[[1]]$kind,"no_datum_change")
})

test_that("plans retain immutable evidence and reject stale saves", {
  root <- withr::local_tempdir();context <- file.path(root,"study.gpkg");file.create(context)
  request <- list(key="study",group_id="event",context=context,group="event.gpkg",args=list())
  r <- transform_review_fixture()
  local_mocked_bindings(review_terrain_transformations=function(...) r,.package="fluvgeo")
  adapter <- study_transform_store(function(...) request,function(...) context)
  expect_null(adapter$transform_plan(request,r))
  first <- adapter$save_transform_plan(request,r,list(pair="available"))
  expect_true(first$current)
  expect_identical(first$record$selections[[1]]$operation$definition,"exact pipeline")
  expect_false(first$record$execution_enabled)
  expect_length(first$record$review$groups[[1]]$catalog$candidates,2)
  expect_error(adapter$save_transform_plan(request,r,list(pair="available")),"newer")
  second <- adapter$save_transform_plan(request,r,list(pair="available"),first$path)
  expect_true(file.exists(first$path))
  expect_false(identical(first$path,second$path))
  changed <- r;changed$fingerprint <- "changed resources"
  expect_false(adapter$transform_plan(request,changed)$current)
  expect_error(adapter$save_transform_plan(request,changed,list(pair="available"),second$path),"resources changed")
  stale <- request;stale$group <- "changed"
  expect_error(adapter$save_transform_plan(stale,r,list(pair="available"),second$path),"selections changed")
})

test_that("UI does not preselect the sole feasible candidate and restores saved choices", {
  r <- transform_review_fixture();writes <- 0L;previous <- NULL
  req <- list(key="study",group_id="event",context="study.gpkg",group="event.gpkg",args=list())
  store <- list(transform_request=function(...) req,transform_plan=function(...) previous,
    save_transform_plan=function(request,review,choices,expected,checked=NULL) {
      selected <- terrain_transform_choices(review,choices);writes <<- writes+1L
      list(current=TRUE,path="saved.json",record=list(selections=selected))
    })
  launch <- function(args) list(is_alive=function() FALSE,get_result=function() r,kill=function() NULL)
  shiny::testServer(terrain_transform_review_server,args=list(
    current=function() list(key="study",path="study.gpkg"),
    context=function() list(group_id="event",group_path="event.gpkg"),store=store,launch=launch),{
    session$flushReact();session$setInputs(discover=1);session$flushReact()
    html <- output$candidates$html
    expect_match(html,'value="" selected')
    expect_match(html,"Missing-grid operation")
    expect_false(grepl('<option value="missing"',html,fixed=TRUE))
    session$setInputs(save=1);expect_equal(writes,0L)
    expect_match(status(),"Choose")
    session$setInputs(choice_pair="available",save=2)
    expect_equal(writes,1L)
    expect_match(status(),"plan saved")
    expect_match(output$candidates$html,'value="available" selected')
  })
})

test_that("automatic reference checks hide all transform controls for matching datums", {
  r <- transform_review_fixture();r$groups[[1L]]$requires_choice <- FALSE
  fixture <- new.env();fixture$review <- r
  req <- list(key="study",group_id="event",context="study.gpkg",group="event.gpkg",args=list())
  calls <- 0L
  store <- list(transform_request=function(...) req,transform_plan=function(...) NULL)
  launch <- function(args) {calls <<- calls+1L;list(is_alive=function() FALSE,get_result=function() fixture$review,kill=function() NULL)}
  ctx <- shiny::reactiveVal(list(group_id="event",group_path="event.gpkg"))
  shiny::testServer(terrain_transform_review_server,args=list(
    current=function() list(key="study",path="study.gpkg"),context=ctx,store=store,launch=launch),{
    session$flushReact()
    expect_equal(calls,1L)
    expect_null(output$panel)
    expect_null(output$candidates)
    fixture$review$groups[[1L]]$requires_choice <- TRUE
    session$setInputs(discover=1);session$flushReact()
    expect_match(output$panel$html,"Datum transformations")
    expect_match(output$candidates$html,"Choose an operation")
    fixture$review$groups[[1L]]$requires_choice <- FALSE
    session$setInputs(discover=2);session$flushReact()
    expect_null(output$panel)
    ctx(NULL);session$flushReact();expect_null(output$panel)
  })
})
