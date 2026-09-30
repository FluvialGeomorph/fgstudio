test_that("group revisions retain identity, evidence, cell units and original assets", {
  f <- event_test_setup(); s <- f$store; x <- f$x
  withr::defer(unlink(dirname(dirname(x$path)),recursive=TRUE))
  before <- tools::md5sum(c(x$path,f$selection))
  save <- function(size=1,year=2020,month=2,members="USIEI:1",group=NULL,expected=NULL,events=character())
    s$save_acquisition_group(x$key,members,x$stream_inventory$stream_id,year,month,size,"Reviewed provider acquisition dates",
      events,group,x$path,f$selection,expected)
  for(size in c(NA,Inf,0,-1)) expect_error(save(size=size),"positive finite")
  expect_error(save(year=NA_real_),"known acquisition year")
  expect_error(save(month=13),"Month")
  expect_error(save(members="forged"),"selected collections")
  expect_error(save(events="forged"),"Reach Events")
  a <- save(); g <- a$groups[[1]]
  expect_equal(g$settings$cell_size,1)
  expect_match(g$settings$unit,"met")
  expect_equal(c(g$settings$anchor_x,g$settings$anchor_y),c(0,0))
  expect_identical(g$members$raw_metadata,'{"collectiondate":"2020-02-01"}')
  expect_equal(nrow(g$streams),2L)
  expect_error(save(),"changed")
  b <- save(size=2.5,group=g$settings$group_id,expected=a$path)
  expect_identical(names(b$groups),names(a$groups))
  expect_equal(b$groups[[1]]$settings$cell_size,2.5)
  expect_equal(fluvgeo::read_survey_acquisition_group(a$path)$settings$cell_size,1)
  c <- save(size=.5,month=NA_integer_,expected=b$path)
  expect_length(c$groups,2L)
  expect_identical(tools::md5sum(c(x$path,f$selection)),before)
  expect_equal(s$read(x$key)$events,0L)
})

test_that("Event context defaults before its dropdown renders and preserves explicit selection", {
  local_mocked_bindings(event_masks_server=function(...) list(),
    terrain_transform_review_server=function(...) NULL,survey_event_dems_server=function(...) NULL)
  f <- event_test_setup(); x <- f$x
  withr::defer(unlink(dirname(dirname(x$path)),recursive=TRUE))
  a <- f$store$save_acquisition_group(x$key,"USIEI:1",x$stream_inventory$stream_id,
    2020,2,1,"",character(),NULL,x$path,f$selection,NULL)
  b <- f$store$save_acquisition_group(x$key,"USIEI:1",x$stream_inventory$stream_id,
    2021,3,1,"",character(),NULL,x$path,f$selection,a$path)
  pending <- shiny::reactiveVal(FALSE)
  shiny::testServer(survey_event_settings_server,args=list(current=function() x,store=f$store,
    selection_path=function() f$selection,selection_pending=pending),{
    session$flushReact()
    ids <- names(saved()$groups)
    expect_null(input$group)
    expect_identical(session$returned$context()$group_id,ids[[1]])
    expect_match(session$returned$context()$event_label,"202[01]-0[23]")
    session$setInputs(group=ids[[2]])
    expect_identical(session$returned$context()$group_id,ids[[2]])
    reload();session$flushReact()
    expect_identical(session$returned$context()$group_id,ids[[2]])
    pending(TRUE);session$flushReact();expect_null(session$returned$context())
    pending(FALSE);session$setInputs(group="unavailable")
    expect_identical(session$returned$context()$group_id,ids[[1]])
    saved(list(path=NULL,groups=list()));session$flushReact()
    expect_null(session$returned$context())
  })
})

test_that("Event editor requires explicit spacing, saves and reopens reviewed groups", {
  local_mocked_bindings(event_masks_server=function(...) list())
  f <- event_test_setup(); x <- f$x
  withr::defer(unlink(dirname(dirname(x$path)),recursive=TRUE))
  shiny::testServer(survey_event_settings_server,args=list(current=function() x,store=f$store,
    selection_path=function() f$selection,selection_pending=function() FALSE),{
    session$flushReact(); expect_false(session$returned$has_pending())
    expect_match(output$event_choices$html,"No Survey Events")
    expect_match(output$definition_choices$html,"2020-02")
    expect_match(output$definition_choices$html,"Acquisition")
    expect_false(grepl("selectize",output$definition_choices$html,fixed=TRUE))
    expect_identical(definition_options()[[1]]$members,"USIEI:1")
    session$setInputs(new=1); expect_true(session$returned$has_pending())
    session$setInputs(members="USIEI:1",streams=x$stream_inventory$stream_id,year=2020,month="2",save=1)
    expect_match(status(),"not saved")
    expect_null(saved()$path)
    session$setInputs(cell_size=1,save=2)
    expect_match(status(),"settings saved")
    expect_false(session$returned$has_pending())
    expect_length(saved()$groups,1L)
    expect_identical(saved()$groups[[1]]$settings$rationale, "")
    reload(); expect_length(saved()$groups,1L)
    expect_match(output$event_choices$html,"Survey Event date")
    expect_match(output$event_choices$html,"2020-02</option>")
    session$setInputs(group=names(saved()$groups)[1],edit=1)
    session$setInputs(cell_size=2,save=3)
    expect_equal(saved()$groups[[1]]$settings$cell_size,2)
    session$setInputs(new=2,discard=1)
    expect_false(session$returned$has_pending())
  })
})
