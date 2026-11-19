# Opt-in real-data qualification. Run from fgstudio with its isolated library.
# Rscript dev/scripts/audit-cross-sections.R STORE STUDY_KEY EVENT_ID OUTPUT [REACH_ID ...]
# Reads saved inputs; writes only OUTPUT. Does not publish drafts or prepare REMs.
args <- commandArgs(trailingOnly=TRUE)
if(length(args)<4L)stop("Supply STORE STUDY_KEY EVENT_ID OUTPUT [REACH_ID ...].")
.libPaths(c(normalizePath('dev/local-library',mustWork=TRUE),.libPaths()))
pkgload::load_all('.',quiet=TRUE)
store <- fgstudio:::local_study_store(args[1])
study <- store$read(args[2]);groups <- store$acquisition_groups(args[2])$groups
matches <- which(vapply(groups,function(g)identical(g$settings$group_id,args[3]),logical(1)))
if(length(matches)!=1L)stop("Select one existing Survey Event ID.")
g <- groups[[matches]]
ctx <- list(key=args[2],path=study$path,group_id=args[3],group_path=g$path,
  vertical_reference=study$vertical_reference,
  streams=study$stream_inventory[study$stream_inventory$stream_id %in% g$streams$stream_id,],
  reaches=study$reach_inventory[study$reach_inventory$stream_id %in% g$streams$stream_id,])
dir.create(args[4],recursive=TRUE,showWarnings=FALSE)
out <- normalizePath(args[4],mustWork=TRUE)
utils::Rprof(file.path(out,'inputs.Rprof'),interval=.02)
input_time <- system.time(value <- fgstudio:::load_flowline_points_review(store,ctx))
utils::Rprof(NULL)
if(is.null(value$saved))stop("Save Flowline Points first.")
rows <- list()
for(bundle in value$bundle)for(i in seq_len(nrow(bundle$flowline$flowlines))) {
  line <- bundle$flowline$flowlines[i,];id <- as.character(line$reach_id[1])
  request <- store$cross_section_rem_request(ctx,value$saved,id)
  prep <- fgstudio:::cross_section_rem_artifact(request)
  row <- data.frame(stream=bundle$stream_name,reach=line$ReachName,reach_id=id,
    length_m=as.numeric(units::set_units(sf::st_length(line),'m')),
    saved_points=sum(value$saved$points$reach_id==id),rem_ready=!is.null(prep),
    input_elapsed=unname(input_time['elapsed']),sections=NA_integer_,contacts=NA_integer_,
    failures=NA_integer_,incomplete_floodplain_legs=NA_integer_,unavailable_centerlines=NA_integer_,
    matches_unedited_saved_geometry=NA,
    inundation_elapsed=NA_real_,centerlines_elapsed=NA_real_,layout_elapsed=NA_real_)
  if(id %in% args[-seq_len(4L)]) {
    if(is.null(prep))stop("Precompute the selected Reach REM in the app first: ",id)
    directory <- file.path(out,id);dir.create(directory,showWarnings=FALSE)
    result <- fgstudio:::cross_section_layout_job(prep$path,line,103,109,20,20,2L,2,30,TRUE,
      directory,profile=TRUE)
    saveRDS(result,file.path(directory,'result.rds'))
    if(!is.null(result$layout_error))stop(result$layout_error)
    row$sections <- nrow(result$layout$sections)
    row$contacts <- sum(result$layout$sections$conflict)
    row$failures <- nrow(result$layout$failures)
    sections <- result$layout$sections
    row$incomplete_floodplain_legs <- sum(!sections$left_supported & sections$left_leg_status!='no_floodplain')+
      sum(!sections$right_supported & sections$right_leg_status!='no_floodplain')
    row$unavailable_centerlines <- sum(!result$layout$region_diagnostics$centerline_available)
    settings <- list(channel=103,floodplain=109,spacing_m=20,tangent_distance_m=20,
      smoothing_refinements=2L,centerline_spacing_m=2,overbank_angle_limit_deg=30,allow_overbank_bends=TRUE)
    saved <- store$cross_section_read(ctx,value$saved,id,settings)
    if(!is.null(saved) && !any(saved$sections$edited))
      row$matches_unedited_saved_geometry <- identical(sf::st_as_binary(sf::st_geometry(saved$sections)),
        sf::st_as_binary(sf::st_geometry(result$layout$sections)))
    row[,c('inundation_elapsed','centerlines_elapsed','layout_elapsed')] <- as.list(result$timings[c('inundation','centerlines','layout')])
  }
  rows[[length(rows)+1L]] <- row
  utils::write.csv(do.call(rbind,rows),file.path(out,'reaches.csv'),row.names=FALSE)
}
print(do.call(rbind,rows),row.names=FALSE)
cat('Profile with summaryRprof(); elapsed seconds include profiler overhead. No Study data changed.\n')
