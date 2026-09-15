# Explicit reproduction using a saved boundary and a public NLDI COMID.
# Reads active data only; writes test outputs into a separate check-output folder.
# Arguments: study key, COMID, per-side distance, unit (m or ft), optional cached
# sf RDS (public NLDI features with nhdplus_comid/comid). Without a cache: live query.
.libPaths(c(normalizePath("dev/local-library"),.libPaths()))
pkgload::load_all(".",quiet=TRUE)
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args) %in% c(4L,5L),grepl("^[0-9]+$",args[2]))
distance <- as.numeric(args[3]); unit <- args[4]
store <- local_study_store(".local-data")
study <- store$read(args[1])
hash <- tools::md5sum(study$path)
if (length(args)==5L) {
  features <- readRDS(args[5])
  id <- intersect(c("nhdplus_comid","comid"),names(features))[1]
  stopifnot(inherits(features,"sf"),!is.na(id))
  line <- features[as.character(features[[id]])==args[2],]
  stopifnot(nrow(line)==1L)
} else line <- fluvgeo:::drainage_feature_service(args[2])
line$source_id <- args[2]
root <- tempfile("saved-boundary-corridor-",tmpdir="dev/check-output")
dir.create(root)
saveRDS(list(line=line,boundary=study$boundary_sf),file.path(root,"geometry.rds"))
print(list(evidence=root,line_crs=sf::st_crs(line)$input))
preview <- fluvgeo::preview_stream_corridor(line,distance,unit,boundary=study$boundary_sf)
preview$area$stream_name <- "Corridor diagnostic"
print(list(comid=line$source_id,buffer_m=preview$distance_m,clipped=preview$clipped,
  line_lengths=preview$line_lengths,method=preview$method,
  containment=fluvgeo::check_study_area_containment(study$boundary_sf,preview$area)$status))
copy <- file.path(root,"source.gpkg")
stopifnot(file.copy(study$path,copy))
result <- fluvgeo::add_study_stream_corridor(copy,file.path(root,"stream.gpkg"),line,
  "Corridor diagnostic",distance,unit,add_note="Developer qualification, not an analyst selection")
saved <- fluvgeo::read_study_context(result$context)
stopifnot(fluvgeo::check_study_area_containment(saved$study_area,saved$streams)$status=="inside",
  identical(hash,tools::md5sum(study$path)),identical(store$read(study$key)$path,study$path))
ui_store <- local_study_store(file.path(root,"ui-store"))
ui_study <- ui_store$create("Corridor UI diagnostic")
ui_study <- ui_store$save_boundary(ui_study$key,study$boundary_sf,ui_study$path)
ui_saved <- NULL
shiny::testServer(mod_boundary_server,args=list(study=ui_study,store=ui_store,
  is_active=function() TRUE,on_saved=function(x) ui_saved <<- x),{
  session$flushReact()
  session$setInputs(selection_target="stream",map_mode="explore",stream_action="select")
  exploring$result(list(layers=list(upstream=line),location=list(comid=args[2]),retrieved_at="Cached public NLDI"))
  session$flushReact()
  session$setInputs(lines_upstream=paste0("c",args[2]),stream_name="Corridor diagnostic",
    buffer_distance=distance,buffer_unit=unit)
  session$setInputs(preview_stream=1)
  stopifnot(stream_selection$preview()$containment=="inside")
  session$setInputs(save_stream=1)
  stopifnot(!is.null(ui_saved),ui_saved$streams==1L)
})
stopifnot(ui_store$read(ui_study$key)$streams==1L,
  identical(hash,tools::md5sum(study$path)),identical(store$read(study$key)$path,study$path))
cat("Shiny preview/save and local-adapter reopen passed in a separate test store.\n")
cat("Real boundary / public flowline save-reopen passed; active study unchanged. Evidence:",root,"\n")
