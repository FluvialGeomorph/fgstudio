# Read-only qualification against an explicitly supplied existing test attempt.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args) %in% c(1L,2L))
with_preview <- length(args)==2L && identical(args[[2L]],"--preview")
.libPaths(c(normalizePath("dev/local-library"),.libPaths()))
pkgload::load_all(".",quiet=TRUE)
attempt <- normalizePath(args[[1L]],mustWork=TRUE)
files <- fluvgeo::read_stream_dem_download(attempt,verify=FALSE)$files
source_file_id <- files$file_id[which(files$outcome=="RECORDED")[1L]]
stopifnot(length(source_file_id)==1L,!is.na(source_file_id))
job <- fgstudio:::launch_stream_dem_inspection_job(attempt,source_file_id,preview=with_preview)
on.exit(if(job$is_alive()) job$kill())
job$wait(timeout=120000)
stopifnot(!job$is_alive())
x <- job$get_result()
stopifnot(identical(x$file_id,source_file_id),nchar(x$sha256)==64L)
print(x$observation$internal_compound$grid)
if(with_preview) {
  stopifnot(is.matrix(x$preview$values),all(dim(x$preview$values)<=512))
  grDevices::png("dev/check-output/dem-preview.png",width=1000,height=700)
  fgstudio:::draw_dem_preview(x$preview)
  grDevices::dev.off()
  detail_job <- fgstudio:::launch_stream_dem_inspection_job(attempt,source_file_id,preview=TRUE,
    window=c(0,0,pmin(256,x$preview$source_size)))
  detail_job$wait(timeout=120000)
  if(detail_job$is_alive()) {detail_job$kill();stop("Detail worker timed out")}
  detail <- detail_job$get_result()
  stopifnot(isTRUE(detail$preview$native),all(dim(detail$preview$values)<=256))
  grDevices::png("dev/check-output/dem-detail.png",width=900,height=700)
  fgstudio:::draw_dem_preview(detail$preview)
  grDevices::dev.off()
}
shiny::testServer(fgstudio:::stream_dem_inspection_server,args=list(
  context=function() list(attempt=attempt,files=files[,c("file_id","title")]),
  launch=function(...) list(is_alive=function() FALSE,get_result=function() x)),{
  session$flushReact();session$setInputs(file=source_file_id,inspect=1);poll();session$flushReact()
  if(is.null(result())) stop(paste("Inspection UI:",message()))
  stopifnot(!is.null(result()),grepl("Verified SHA-256",output$result$html,fixed=TRUE),
    grepl("terrain suitability remains unreviewed",message(),fixed=TRUE))
  if(with_preview) stopifnot(grepl("Source-grid elevation overview",output$preview_panel$html,fixed=TRUE))
})
cat("Real worker and successful inspection UI rendering passed; no downloads or source writes.\n")
