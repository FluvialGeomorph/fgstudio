test_that("input reopening paints progress and reuses only matching validated inputs", {
  ctx <- list(path="study.gpkg",group_path="event.gpkg",event_label="test")
  value <- list(saved=list(path="points-v1",points=data.frame(reach_id="r1")),
    bundle=list(s1=list(stream_name="Stream",flowline=list(flowlines=data.frame(reach_id="r1",ReachName="R1")))))
  counts <- new.env();counts$calls <- 0L
  testthat::with_mocked_bindings(load_flowline_points_review=function(...) {counts$calls <- counts$calls+1L;value}, {
    enabled <- shiny::reactiveVal(TRUE)
    shared <- shiny::reactiveVal(list(value=value,key=paste(ctx$path,ctx$group_path,0L,sep="\r")))
    shiny::testServer(cross_section_review_server,args=list(context=function()ctx,store=list(),events=NULL,
      active=enabled,revision=function()0L,upstream_inputs=shared),{
      session$flushReact()
      expect_match(status(),"Opening saved")
      expect_true(opening())
      expect_match(output$status$html,"<progress")
      load_review(ctx,paste(ctx$path,ctx$group_path,0L,sep="|"),load_generation,shared()$key)
      expect_identical(review(),value)
      expect_equal(counts$calls,0L)
      expect_false(opening())
      load_review(ctx,paste(ctx$path,ctx$group_path,0L,sep="|"),get("load_generation",environment(load_review)),"different revision")
      expect_match(status(),"Choose a Stream")
      changed <- value;changed$saved$path <- "points-v2"
      shared(list(value=changed,key=paste(ctx$path,ctx$group_path,0L,sep="\r")))
      session$flushReact()
      expect_true(opening());expect_null(review())
      enabled(FALSE);session$flushReact()
      expect_equal(counts$calls,1L)
    })
  },.package="fgstudio")
})

test_that("cancelled input loads cannot populate a hidden tab", {
  ctx <- list(path="study.gpkg",group_path="event.gpkg",event_label="test")
  enabled <- shiny::reactiveVal(TRUE)
  shiny::testServer(cross_section_review_server,args=list(context=function()ctx,store=list(),events=NULL,
    active=enabled,revision=function()0L),{
    session$flushReact();token <- load_generation
    enabled(FALSE);session$flushReact()
    load_review(ctx,"stale",token,"stale")
    expect_null(review());expect_false(opening())
  })
})

test_that("Reach selection survives input reopening and changes Stream safely", {
  value <- list(bundle=list(
    a=list(stream_name="A",flowline=list(flowlines=data.frame(reach_id=c("a1","a2"),ReachName=c("R1","R2")))),
    b=list(stream_name="B",flowline=list(flowlines=data.frame(reach_id="b1",ReachName="R1")))))
  shiny::testServer(cross_section_review_server,args=list(context=function()NULL,store=list(),events=NULL,
    active=function()FALSE,revision=function()0L),{
    session$flushReact();review(value);session$setInputs(stream="a",reach="a2")
    expect_match(output$selection$html,'value="a2" selected')
    changed <- value;changed$revision <- 2L;review(changed);session$flushReact()
    expect_match(output$selection$html,'value="a2" selected')
    session$setInputs(stream="b")
    expect_match(output$selection$html,'value="b1" selected')
    expect_null(job)
  })
})

test_that("worker phase feedback arrives before computation finishes", {
  job <- callr::r_bg(function() {
    cat("FGSTUDIO_PHASE:Deconflicting cross sections (stage 3 of 3)...\n")
    flush(stdout());Sys.sleep(2);TRUE
  },stdout="|",stderr=NULL)
  on.exit(if(job$is_alive())job$kill(),add=TRUE)
  messages <- character()
  for(i in seq_len(100L)) {
    messages <- c(messages,job$read_output_lines())
    if(length(messages))break
    Sys.sleep(.05)
  }
  expect_true(job$is_alive())
  expect_match(paste(messages,collapse="\n"),"FGSTUDIO_PHASE:Deconflicting")
  job$wait();expect_true(job$get_result())
})
