selection_context <- function(id="111111111111", shift=0) {
  ring <- rbind(c(-90+shift,40),c(-89+shift,40),c(-89+shift,41),c(-90+shift,41),c(-90+shift,40))
  area <- sf::st_sf(huc12=id,name=paste("Watershed",id),geometry=sf::st_sfc(sf::st_polygon(list(ring)),crs=4326))
  list(layers=list(huc12=area,basin=NULL),location=list(comid="123"),retrieved_at="Test UTC",
    status=data.frame(layer=c("huc12","basin"),status=c("available","unavailable"),
      outcome=c("available","unresolved"),detail=c("Returned", "Test empty client")))
}

test_that("selection accumulates, toggles by map/list, previews explicitly and guards saving", {
  context <- shiny::reactiveVal(NULL)
  state <- new.env(); state$active <- TRUE; state$saves <- 0L
  writer <- list(save_selected_boundary=function(key,sources,path,rationale) {
    state$saves <- state$saves+1L; state$sources <- sources; list(key=key)
  })
  host <- function(id) shiny::moduleServer(id,function(input,output,session) {
    p <- polygon_selection(input,output,session,list(result=context),list(key="test",path="test"),writer,
      function() state$active,function(x) NULL)
  })
  shiny::testServer(host, {
    session$flushReact()
    session$setInputs(map_mode="explore",polygon_action="select")
    context(selection_context()); session$flushReact()
    first <- p$pool()$candidate_key
    session$setInputs(chosen_huc12=first)
    expect_identical(p$selected(),first)
    session$setInputs(save_selection=1)
    expect_equal(state$saves,0L)
    expect_match(p$status(),"Preview")
    context(NULL); session$flushReact()
    expect_identical(p$selected(),first)
    context(selection_context("222222222222",1)); session$flushReact()
    expect_equal(nrow(p$pool()),2)
    second <- setdiff(p$pool()$candidate_key,first)
    session$setInputs(map_shape_click=list(id=second))
    expect_setequal(p$selected(),c(first,second))
    session$setInputs(preview_selection=1)
    expect_equal(p$preview()$polygon_parts,1)
    session$setInputs(chosen_huc12=first)
    expect_null(p$preview())
    session$setInputs(undo_selection=1)
    expect_length(p$selected(),2)
    session$setInputs(chosen_huc12="forged-id")
    expect_length(p$selected(),2)
    session$setInputs(preview_selection=2,save_selection=2)
    expect_equal(state$saves,1L)
    expect_equal(nrow(state$sources),2)
    expect_false(p$has_pending())
    session$setInputs(save_selection=3)
    expect_equal(state$saves,1L)
    state$active <- FALSE
    session$setInputs(chosen_huc12=first,preview_selection=3,save_selection=4)
    expect_equal(state$saves,1L)
    p$destroy()
  })
})

test_that("saved boundary retains source evidence, prior identity, children and stale guards", {
  store <- local_study_store(withr::local_tempdir())
  study <- store$create("Study", "Purpose")
  study <- store$define_streams(study$key,"Stream","Selected",study$path)
  old_hash <- tools::md5sum(study$path)
  sources <- polygon_candidates(selection_context())
  saved <- store$save_selected_boundary(study$key,sources,study$path,"Customer scope")
  expect_identical(saved$study_id,study$study_id)
  expect_equal(saved$streams,1)
  expect_equal(saved$purpose,"Purpose")
  expect_true(saved$boundary)
  expect_identical(tools::md5sum(study$path),old_hash)
  evidence <- list.files(dirname(study$path),pattern="^boundary-selection-",full.names=TRUE)
  expect_length(evidence,1)
  expect_equal(sf::st_read(evidence,quiet=TRUE)$source_id,sources$source_id)
  expect_match(saved$notes,"SHA256")
  expect_match(saved$notes,"Customer scope")
  expect_error(store$save_selected_boundary(study$key,sources,study$path),"newer revision")
  expect_length(list.files(dirname(study$path),pattern="^boundary-selection-"),1)
})

test_that("pre-study selection carries to creation but not another opened study", {
  store <- local_study_store(withr::local_tempdir())
  other <- store$create("Other")
  sources <- polygon_candidates(selection_context())
  shiny::testServer(mod_study_server,args=list(store=store), {
    session$flushReact()
    # Inject the pre-creation editor's public draft seam; no service dependency.
    module_env <- environment(refresh)
    stub <- get("editor", module_env)
    stub$selection_state <- function() list(pool=sources,selected=sources$candidate_key)
    assign("editor", stub, module_env)
    session$setInputs(name="New study",notes="",create=1)
    expect_identical(get("editor", module_env)$selection_state()$selected,sources$candidate_key)
    expect_false(current()$boundary)
    session$setInputs(saved=other$key,open=1)
    expect_length(get("editor", module_env)$selection_state()$selected,0)
  })
})
