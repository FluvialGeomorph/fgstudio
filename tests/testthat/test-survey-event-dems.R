test_that('Stream queue reuses, serializes, retains failures and pauses remaining work', {
 fixture<-Sys.getenv('FGSTUDIO_REAL_MOSAIC_RESULT');skip_if(!nzchar(fixture),'Provide the real Reach fixture')
 t<-readRDS(fixture);t$use_saved_sources<-FALSE;t$scope<-'stream'
 root<-tempfile();dir.create(root);withr::defer(unlink(root,recursive=TRUE))
 ctx<-shiny::reactiveVal(list(path=t$context_path,group_path=t$group_path,group_id=t$group_id,
   streams=data.frame(stream_id=c('a','b','c'),stream_name=c('A','B','C'))))
 make<-function(id){z<-t;z$stream_id<-id;z}
 calls<-character();handles<-list();fail<-TRUE
 stop_handle<-function(i) {h<-handles[[i]];h$alive<-FALSE}
 store<-list(dem_request=function(...) list(),
   find_dem=function(binding,recipe=NULL,...) if(!is.null(recipe)&&identical(recipe$stream_id,'a')) {
     z<-make('a');z$saved_dem<-list(scope='stream');z
   } else NULL,
   prepare_dem=function(...) {p<-tempfile(tmpdir=root);dir.create(p);p},
   discard_dem=function(key,p) unlink(p,recursive=TRUE),
   publish_dem=function(binding,recipe,directory,trial){trial$saved_dem<-list(scope='stream');trial})
 launch<-function(trial,directory){
   expect_false(any(vapply(handles,function(h) h$alive,logical(1))))
   calls<<-c(calls,trial$stream_id);h<-new.env();h$alive<-TRUE;handles[[length(handles)+1L]]<<-h
   list(is_alive=function() h$alive,kill=function() h$alive<-FALSE,wait=function(...) NULL,
    get_result=function(){if(trial$stream_id=='c'&&fail) stop('source issue');trial})
 }
 local_mocked_bindings(terrain_dem_request=function(store,current,context,stream_id) make(stream_id),
   terrain_mosaic_trial_server=function(...) NULL)
 shiny::testServer(survey_event_dems_server,args=list(current=function() list(key=t$key),context=ctx,
    store=store,ready=function() TRUE,launch=launch),{
   session$flushReact();expect_identical(calls,'b');expect_identical(states()$a$status,'Ready')
   expect_match(output$overview$html,'B - Building DEM')
   expect_false(grepl('Ready|Waiting',output$overview$html))
   stop_handle(1);task$poll();session$flushReact()
   expect_identical(calls,c('b','c'));expect_identical(states()$b$status,'Ready')
   stop_handle(2);task$poll();session$flushReact()
   expect_null(active());expect_identical(states()$c$status,'Needs attention')
   expect_match(output$queue_controls$html,'Resume Unfinished DEMs')
   fail<<-FALSE;session$setInputs(retry_queue=1);session$flushReact()
   expect_identical(calls,c('b','c','c'))
   session$setInputs(cancel_dem=1);session$flushReact()
   expect_null(active());expect_identical(states()$c$status,'Paused')
   expect_false(handles[[3]]$alive)
 })
})
