terrain_review_fixture <- function() {
  s <- data.frame(collection=c("collection","collection"),file_id=c("north","south"),
    sha256=c(paste(rep("a",64),collapse=""),paste(rep("b",64),collapse="")),
    band_unit="metre",grid_screen="PASS",issues="")
  list(key="study",group_id="group",target="NAVD88 | orthometric | metre",
    request=list(context="context",selection="selection",group="group",stream_id="stream"),
    preflight=list(sources=s,inputs=list(context="hash"),source_selection_hashes=list(),
      observations=list("collection/north"=list(title="North survey tile"),
        "collection/south"=list(title="South survey tile"))))
}

test_that("source review editions preserve order, evidence and stale boundaries", {
  root <- withr::local_tempdir();x <- terrain_review_fixture();b <- terrain_review_binding(x$request,x$preflight)
  rows <- data.frame(source_id=rev(b$source_ids),assessment="unresolved",elevation_unit="unknown",evidence="",prior_operations="")
  first <- terrain_review_write(root,b,rows,"last_valid")
  loaded <- terrain_review_latest(root,b)
  expect_true(loaded$current);expect_identical(loaded$record$rows,rows)
  expect_identical(loaded$record$overlap,"last_valid");expect_false(loaded$record$processing_authorized)
  expect_identical(loaded$record$output_type,"Float32")
  before <- tools::md5sum(first$path)
  expect_error(terrain_review_write(root,b,rows,"first_valid"),"newer review")
  second <- terrain_review_write(root,b,rows,"first_valid",first$path)
  expect_identical(terrain_review_latest(root,b)$path,second$path)
  expect_identical(tools::md5sum(first$path),before)
  x$preflight$sources$sha256[1] <- paste(rep("c",64),collapse="")
  expect_false(terrain_review_latest(root,terrain_review_binding(x$request,x$preflight))$current)
  rows$assessment[1] <- "matches_target"
  expect_error(terrain_review_rows(b,rows),"evidence")
  rows$evidence[1] <- "Vendor report";rows$prior_operations[1] <- "None documented"
  expect_error(terrain_review_rows(b,rows),"elevation unit")
  rows$elevation_unit[1] <- "metre"
  expect_identical(terrain_review_rows(b,rows),rows)
  expect_error(terrain_review_rows(b,rows[1,,drop=FALSE]),"every checked source")
  x$preflight$sources$sha256[1] <- NA_character_
  expect_error(terrain_review_binding(x$request,x$preflight),"missing downloads")
})

test_that("analysts can edit, reorder, save and reopen reviews in the module", {
  x <- terrain_review_fixture();root <- withr::local_tempdir();saved <- NULL;pending_edits <- FALSE
  store <- list(terrain_review=function(key,group_id,stream_id,binding) terrain_review_latest(root,binding),
    save_terrain_review=function(key,group_id,binding,rows,overlap,expected) {
      saved <<- terrain_review_write(root,binding,rows,overlap,expected);saved
    })
  shiny::testServer(terrain_source_review_server,args=list(context=function() x,store=store,pending=function() pending_edits),{
    session$flushReact();expect_equal(nrow(rows()),2)
    expect_match(output$workspace$html,"North survey tile")
    session$setInputs(source="collection/south",earlier=1)
    expect_identical(rows()$source_id,c("collection/south","collection/north"))
    session$setInputs(edit=1)
    session$setInputs(assessment="matches_target",unit="metre",evidence="Vendor report section 3",
      prior="None documented",apply=1)
    expect_identical(rows()$assessment[1],"matches_target");expect_true(dirty())
    session$setInputs(overlap="last_valid",save=1)
    expect_false(dirty());expect_identical(saved$record$overlap,"last_valid")
    session$setInputs(later=1);expect_true(dirty())
    session$setInputs(reload=1)
    expect_false(dirty());expect_identical(rows()$source_id[1],"collection/south")
    expect_match(status(),"reopened")
    pending_edits <<- TRUE;session$setInputs(save=2)
    expect_match(status(),"pending Event")
  })
})

test_that("changed or unavailable preflight cannot keep a current review draft", {
  x <- terrain_review_fixture();current <- shiny::reactiveVal(x)
  store <- list(terrain_review=function(...) NULL)
  shiny::testServer(terrain_source_review_server,args=list(context=current,store=store),{
    session$flushReact();expect_equal(nrow(rows()),2)
    current(NULL);session$flushReact();expect_null(rows())
    session$setInputs(save=1);expect_match(status(),"Inputs changed")
    x$preflight$sources$sha256[1] <- NA_character_;current(x);session$flushReact()
    expect_null(rows());expect_match(status(),"missing downloads")
  })
})

test_that("study storage refuses a review when saved study revisions changed", {
  f <- event_test_setup();s <- f$store;x <- f$x
  withr::defer(unlink(dirname(dirname(x$path)),recursive=TRUE))
  groups <- s$save_acquisition_group(x$key,"USIEI:1",x$stream_inventory$stream_id,2020,2,1,"Reviewed",
    character(),NULL,x$path,f$selection,NULL)
  g <- groups$groups[[1]];id <- g$settings$group_id
  request <- s$dem_preflight_request(x$key,id,x$stream_inventory$stream_id[1],x$path,f$selection,g$path)
  p <- terrain_review_fixture()$preflight;b <- terrain_review_binding(request,p)
  expect_null(s$terrain_review(x$key,id,request$stream_id,b))
  x <- s$rename(x$key,"Changed study",x$path)
  expect_error(s$save_terrain_review(x$key,id,b,data.frame(),"first_valid",NULL),"changed")
  expect_false(dir.exists(file.path(dirname(x$path),"terrain-reviews")))
})
