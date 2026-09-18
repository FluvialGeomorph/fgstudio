test_that("Reach UI inherits width and adds two Reaches without reopening", {
  store <- local_study_store(withr::local_tempdir())
  study <- reach_test_study(store)
  parent <- study$stream_inventory$stream_id
  html <- as.character(reach_selection_ui(shiny::NS("test"),study))
  expect_match(html,"Parent Stream")
  expect_false(grepl('type="number"',html,fixed=TRUE))
  shiny::testServer(mod_study_server,args=list(store=store),{
    session$flushReact(); current(study); session$flushReact()
    live_editor <- function() get("editor",environment(refresh))
    send <- function(...) {
      values <- list(...)
      names(values) <- paste0("boundary_",get("generation",environment(refresh)),"-",names(values))
      do.call(session$setInputs,values)
    }
    for (i in 1:2) {
      send(selection_target="reach",map_mode="reach",reach_parent=parent)
      child <- get("reach_selection",environment(live_editor()$selection_state))
      expect_equal(child$source()$distance,1000)
      expect_equal(child$source()$unit,"ft")
      send(map_shape_click=list(id=paste0("reach-source-",100+i),lng=-90,lat=40.005))
      expect_equal(child$selected(),as.character(100+i))
      send(reach_name=paste0("R",i),preview_reach=1)
      expect_equal(child$preview()$distance_m,304.8)
      send(save_reach=1)
      expect_equal(current()$reaches,i)
      expect_equal(current()$streams,1L)
      expect_equal(current()$stream_inventory,study$stream_inventory)
      draft <- live_editor()$selection_state()
      expect_equal(boundary_initial_target(current(),FALSE,list(target="reach",map_mode="reach")),"reach")
    }
    expect_equal(store$read(study$key)$reach_inventory$reach_name,c("R1","R2"))
    expect_equal(store$read(study$key)$reach_inventory$stream_id,rep(parent,2))
  })
})

test_that("checkbox and map toggles combine segments, invalidate preview and handle no available segments", {
  store <- local_study_store(withr::local_tempdir()); study <- reach_test_study(store)
  parent <- study$stream_inventory$stream_id
  saved <- NULL
  shiny::testServer(mod_boundary_server,args=list(study=study,store=store,
    is_active=function() TRUE,on_saved=function(x) saved <<- x),{
    session$flushReact()
    session$setInputs(selection_target="reach",map_mode="reach",reach_parent=parent)
    expect_match(output$reach_segments$html,'type="checkbox"',fixed=TRUE)
    session$setInputs(reach_segment="101",reach_name="My combined Reach",preview_reach=1)
    expect_false(is.null(reach_selection$preview()))
    session$setInputs(map_shape_click=list(id="reach-source-102"))
    expect_setequal(reach_selection$selected(),c("101","102"))
    expect_null(reach_selection$preview())
    expect_equal(input$reach_name,"My combined Reach")
    session$setInputs(map_shape_click=list(id="reach-source-101"))
    expect_equal(reach_selection$selected(),"102")
    session$setInputs(reach_segment=character())
    expect_length(reach_selection$selected(),0L)
    expect_false(reach_selection$has_pending())
    session$setInputs(reach_segment=c("101","102"),preview_reach=2)
    expect_equal(reach_selection$preview()$selected_features,2L)
    session$setInputs(save_reach=1)
  })
  expect_equal(saved$reaches,1L)
  expect_equal(saved$reach_inventory$reach_name,"My combined Reach")
  shiny::testServer(mod_boundary_server,args=list(study=saved,store=store,
    is_active=function() TRUE,on_saved=function(x) NULL),{
    session$flushReact()
    session$setInputs(selection_target="reach",map_mode="reach",reach_parent=parent)
    expect_match(reach_selection$status(),"already have Reaches")
    expect_false(is.null(output$reach_segments$html))
    expect_false(grepl('type="checkbox"',output$reach_segments$html,fixed=TRUE))
  })
})

test_that("Reach selection guards preview, stale revisions and task changes", {
  store <- local_study_store(withr::local_tempdir()); study <- reach_test_study(store)
  parent <- study$stream_inventory$stream_id
  shiny::testServer(mod_boundary_server,args=list(study=study,store=store,
    is_active=function() TRUE,on_saved=function(x) stop("Unexpected save")),{
    session$flushReact()
    session$setInputs(selection_target="reach",map_mode="reach",reach_parent=parent)
    session$setInputs(reach_segment="101",reach_name="R1",save_reach=1)
    expect_match(reach_selection$status(),"Preview this Reach")
    session$setInputs(selection_target="stream")
    expect_match(output$task_status$html,"selected Reach")
    session$setInputs(selection_target="reach",preview_reach=1)
    expect_false(is.null(reach_selection$preview()))
    # Another revision invalidates this editor; the existing saved study survives.
    store$rename(study$key,"Updated elsewhere",study$path)
    session$setInputs(save_reach=2)
    expect_match(reach_selection$status(),"newer revision")
    expect_equal(store$read(study$key)$reaches,0L)
    expect_true(reach_selection$has_pending())
    session$setInputs(clear_reach=1)
    expect_false(reach_selection$has_pending())
  })
})

test_that("saved Reaches combine through reviewed identity selection without reopening", {
  store <- local_study_store(withr::local_tempdir()); study <- reach_test_study(store)
  parent <- study$stream_inventory$stream_id
  study <- store$save_reach(study$key,parent,"101","R1",study$path)
  study <- store$save_reach(study$key,parent,"102","R2",study$path)
  ids <- study$reach_inventory$reach_id
  shiny::testServer(mod_study_server,args=list(store=store),{
    session$flushReact(); current(study); session$flushReact()
    live_editor <- function() get("editor",environment(refresh))
    send <- function(...) {
      values <- list(...)
      names(values) <- paste0("boundary_",get("generation",environment(refresh)),"-",names(values))
      do.call(session$setInputs,values)
    }
    send(selection_target="reach",map_mode="reach",reach_parent=parent,reach_operation="merge")
    merge <- get("reach_merge",environment(live_editor()$selection_state))
    send(merge_ids=ids,merge_keep=ids[1],merge_name="Combined",save_merge=1)
    expect_match(merge$status(),"Preview the current")
    send(preview_merge=1)
    expect_equal(merge$preview()$retain_reach_id,ids[1])
    expect_equal(merge$preview()$source_id,c("101","102"))
    send(merge_ids=ids[1])
    expect_null(merge$preview())
    send(merge_ids=ids,preview_merge=2)
    send(save_merge=2)
    expect_equal(current()$reaches,1L)
    expect_equal(current()$reach_inventory$reach_id,ids[1])
    expect_equal(current()$reach_inventory$reach_name,"Combined")
    expect_equal(current()$stream_inventory,study$stream_inventory)
    expect_equal(fluvgeo::read_study_context(study$path)$reaches$reach_id,ids)
    # testServer does not send initial browser inputs for the rebuilt editor.
    draft <- get("selection_draft", environment(live_editor()$selection_state))
    expect_equal(boundary_initial_target(current(),FALSE,draft),"reach")
    expect_equal(draft$reach$operation,"merge")
  })
})
