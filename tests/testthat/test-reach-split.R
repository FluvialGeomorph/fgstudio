test_that("Reach actions expose a visible new name field before the segment inventory", {
  html <- as.character(reach_selection_ui(shiny::NS("test"),list()))
  expect_match(html,"Add new")
  expect_match(html,"Split existing")
  expect_match(html,"Combine existing")
  expect_match(html,"New Reach name")
  expect_lt(regexpr('id="test-reach_name"',html)[1],regexpr('id="test-reach_segments"',html)[1])
})

test_that("map click previews and saves two Reaches without changing their Stream", {
  store <- local_study_store(withr::local_tempdir()); study <- reach_test_study(store)
  sid <- study$stream_inventory$stream_id
  study <- store$save_reach(study$key,sid,"101","Original",study$path)
  rid <- study$reach_inventory$reach_id
  saved <- NULL
  shiny::testServer(mod_boundary_server,args=list(study=study,store=store,
    is_active=function() TRUE,on_saved=function(x) saved <<- x),{
    session$flushReact()
    session$setInputs(selection_target="reach",map_mode="reach",reach_parent=sid,
      reach_operation="split",split_reach=rid,split_keep="downstream",split_name="Upper")
    session$setInputs(map_click=list(lng=-90,lat=40.005))
    expect_false(is.null(reach_split$preview()))
    expect_match(reach_split$status(),"Gold")
    session$setInputs(split_keep="upstream")
    expect_null(reach_split$preview())
    session$setInputs(save_split=1)
    expect_match(reach_split$status(),"Preview the current")
    session$setInputs(preview_split=1)
    expect_false(is.null(reach_split$preview()))
    session$setInputs(save_split=2)
    expect_false(reach_split$has_pending())
  })
  expect_equal(saved$reaches,2L)
  expect_equal(saved$reach_inventory$reach_name,c("Original","Upper"))
  expect_equal(saved$stream_inventory,study$stream_inventory)
  source <- store$stream_segments(study$key,sid,saved$path)
  expect_true(source$piece_state)
  expect_equal(length(source$assigned_selection_ids),2L)
})
