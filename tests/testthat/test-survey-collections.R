collection_test_study <- function(store) {
  x <- store$create("Catalog test")
  b <- sf::st_sf(geometry=sf::st_sfc(sf::st_polygon(list(rbind(c(-90,40),c(-89.99,40),
    c(-89.99,40.01),c(-90,40.01),c(-90,40)))),crs=4326))
  store$save_boundary(x$key,b,x$path)
}
collection_test_discovery <- function(x) {
  rows <- sf::st_sf(candidate_key="USIEI:1",catalog="USIEI",record_id="1",snapshot_id="test",retrieved_at="2026-09-19",
    title="Synthetic planned lidar",date_label="2027",status="Planned/Funded",availability="Unknown",
    metadata_url="https://example.org",access_url="Unknown",raw_metadata="{}",coverage="Covers Study Area",
    geometry=sf::st_geometry(x$boundary_sf))
  list(study_area=x$boundary_sf,records=rows,searches=data.frame(catalog="USIEI",snapshot_id="test",outcome="COMPLETE",
    returned=1L,message="Synthetic fixture"))
}

test_that("opening saved collections permits EPSG 6344 save before visiting their panel", {
  store <- local_study_store(withr::local_tempdir())
  x <- collection_test_study(store)
  store$save_survey_collections(x$key,collection_test_discovery(x),"USIEI:1",x$path,NULL)
  before <- tools::md5sum(x$path)
  shiny::testServer(mod_study_server,args=list(store=store),{
    session$flushReact()
    session$setInputs(saved=x$key,open=1)
    expect_false(collections$has_pending())
    session$setInputs(`analysis_crs-mode`="advanced",`analysis_crs-definition`="6344",`analysis_crs-validate`=1)
    session$setInputs(`analysis_crs-save`=1)
    expect_equal(current()$analysis_crs$epsg,6344)
    expect_match(notice()$text,"Analysis CRS saved",fixed=TRUE)
    expect_identical(store$survey_collections(x$key)$discovery$selected,"USIEI:1")
  })
  expect_identical(tools::md5sum(x$path),before)
})

test_that("product intent saves, reopens and follows collection deselection", {
  store <- local_study_store(withr::local_tempdir()); x <- collection_test_study(store)
  store$save_survey_collections(x$key,collection_test_discovery(x),"USIEI:1",x$path,NULL)
  shiny::testServer(mod_survey_collections_server,args=list(current=function() x,store=store),{
    session$flushReact()
    expect_identical(chosen(),"USIEI:1")
    expect_false(session$returned$has_pending())
    session$setInputs(chosen="USIEI:1",plan_collection="USIEI:1",plan_products=c("DEM","POINT_CLOUD"),apply_plan=1)
    expect_equal(nrow(plan()),2L)
    session$setInputs(save=1)
    expect_equal(nrow(store$survey_collections(x$key)$discovery$acquisition_plan),2L)
    expect_identical(store$read(x$key)$events,0L)
    session$setInputs(chosen=character())
    expect_true(session$returned$has_pending())
    session$setInputs(save=2)
    expect_equal(nrow(store$survey_collections(x$key)$discovery$acquisition_plan),0L)
  })
})

test_that("shared map visibility is independent of inclusion and product intent", {
  store <- local_study_store(withr::local_tempdir()); x <- collection_test_study(store)
  store$save_survey_collections(x$key,collection_test_discovery(x),"USIEI:1",x$path,NULL)
  shiny::testServer(mod_survey_collections_server,args=list(current=function() x,store=store),{
    session$flushReact()
    session$setInputs(chosen="USIEI:1",focus="USIEI:1",map_mode="focus")
    expect_identical(visible_keys(),"USIEI:1")
    session$setInputs(map_mode="custom",visible=character())
    expect_length(visible_keys(),0L)
    expect_identical(chosen(),"USIEI:1")
    expect_equal(nrow(plan()),0L)
    session$setInputs(map_mode="included")
    expect_identical(visible_keys(),"USIEI:1")
    expect_true(grepl("Shared coverage map",as.character(mod_survey_collections_ui("fixture")),fixed=TRUE))
  })
})

test_that("selection intent reopens without modifying hierarchy and rejects stale writes", {
  store <- local_study_store(withr::local_tempdir()); x <- collection_test_study(store)
  r <- collection_test_discovery(x); before <- tools::md5sum(x$path)
  path <- store$save_survey_collections(x$key,r,"USIEI:1",x$path,NULL)
  expect_identical(store$survey_collections(x$key)$discovery$selected,"USIEI:1")
  expect_identical(store$read(x$key)$events,0L)
  expect_identical(tools::md5sum(x$path),before)
  expect_error(store$save_survey_collections(x$key,r,character(),x$path,NULL),"newer revision")
  expect_error(store$save_survey_collections(x$key,r,"forged",x$path,path),"reviewed discovery")
  next_path <- store$save_survey_collections(x$key,r,character(),x$path,path)
  expect_length(store$survey_collections(x$key)$discovery$selected,0L)
  expect_true(file.exists(path)); expect_false(identical(path,next_path))
  reopened <- store$survey_collections(x$key)
  again <- store$save_survey_collections(x$key,reopened$discovery,"USIEI:1",x$path,reopened$path)
  expect_true(file.exists(again))
  changed <- r; sf::st_geometry(changed$study_area) <- sf::st_geometry(changed$study_area)+c(.01,0)
  sf::st_crs(changed$study_area) <- 4326
  expect_error(store$save_survey_collections(x$key,changed,"USIEI:1",x$path,again),"boundary changed")
  y <- store$create("Other")
  expect_error(store$save_survey_collections(y$key,r,character(),y$path,NULL),"boundary changed")
})

test_that("collection UI searches, selects and saves through injected worker", {
  store <- local_study_store(withr::local_tempdir()); x <- collection_test_study(store)
  r <- collection_test_discovery(x); killed <- FALSE
  launch <- function(...) list(is_alive=function() FALSE,get_result=function() r,kill=function() {killed <<- TRUE})
  shiny::testServer(mod_survey_collections_server,args=list(current=function() x,store=store,launch=launch),{
    session$flushReact(); session$setInputs(search=1); poll(); session$flushReact()
    expect_equal(nrow(result()$records),1L)
    session$setInputs(chosen="USIEI:1",save=1)
    expect_match(status(),"selections saved")
    expect_identical(store$survey_collections(x$key)$discovery$selected,"USIEI:1")
    session$setInputs(chosen=character(),search=2)
    expect_match(status(),"Save your selections")
    session$setInputs(chosen="USIEI:1",search=3); poll(); session$flushReact()
    expect_equal(nrow(result()$records),1L)
  })
  expect_true(killed)
})

test_that("worker failures and cancellation preserve reopened selections", {
  store <- local_study_store(withr::local_tempdir()); x <- collection_test_study(store)
  store$save_survey_collections(x$key,collection_test_discovery(x),"USIEI:1",x$path,NULL)
  launch <- function(...) list(is_alive=function() FALSE,get_result=function() stop("timeout"),kill=function() TRUE)
  shiny::testServer(mod_survey_collections_server,args=list(current=function() x,store=store,launch=launch),{
    session$flushReact(); session$setInputs(chosen="USIEI:1",search=1); poll()
    expect_match(status(),"Search failed")
    expect_equal(nrow(result()$records),1L)
    session$setInputs(cancel=1); expect_match(status(),"cancelled")
  })
})

test_that("same-study revisions keep selection drafts but another study clears them", {
  store <- local_study_store(withr::local_tempdir()); x <- collection_test_study(store)
  active <- shiny::reactiveVal(x); r <- collection_test_discovery(x)
  launch <- function(...) list(is_alive=function() FALSE,get_result=function() r,kill=function() TRUE)
  shiny::testServer(mod_survey_collections_server,args=list(current=active,store=store,launch=launch),{
    session$flushReact(); session$setInputs(search=1); poll(); session$setInputs(chosen="USIEI:1")
    active(store$rename(x$key,"Renamed",x$path)); session$flushReact()
    expect_equal(nrow(result()$records),1L)
    expect_identical(chosen(),"USIEI:1")
    active(store$create("Another study")); session$flushReact()
    expect_null(result())
  })
})
