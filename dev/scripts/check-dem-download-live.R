# Opt-in, bounded public-service qualification. Never reads analyst studies.
# Downloads at most one <=16 MiB reported USGS source for a synthetic Omaha AOI.
# Outputs stay under ignored dev/check-output for evidence, never .local-data.
.libPaths(c(normalizePath("dev/local-library"),.libPaths()))
pkgload::load_all(".",quiet=TRUE)
b <- sf::st_sf(study_area_id="synthetic-download-area",geometry=sf::st_as_sfc(sf::st_bbox(
  c(xmin=-96.10,ymin=41.335,xmax=-96.09,ymax=41.34),crs=4326)))
d <- fluvgeo::discover_survey_collections(b)
collections <- d$records[d$records$catalog=="USGS 3DEP",]
if(!nrow(collections)) stop("No USGS synthetic fixture collection; inspect service availability.")
s <- sf::st_sf(stream_id="synthetic-download-stream",geometry=sf::st_geometry(b))
r <- fluvgeo::discover_stream_dem_files(s,collections[1,])
eligible <- which(is.finite(r$files$size_bytes) & r$files$size_bytes>0 & r$files$size_bytes<=16*1024^2)
if(!r$outcome %in% c("COMPLETE","PARTIAL") || !length(eligible))
  stop("No supported <=16 MiB reported source for the synthetic fixture; no download attempted.")
dir.create("dev/check-output",showWarnings=FALSE)
folder <- tempfile("dem-live-",tmpdir=normalizePath("dev/check-output"));dir.create(folder)
selection <- file.path(folder,"selection.gpkg")
fluvgeo::write_stream_dem_selection(r,r$files$file_id[eligible[1]],selection,"synthetic-revision")
limits <- list(file_bytes=16*1024^2,attempt_bytes=16*1024^2,idle_seconds=30,file_seconds=120,attempt_seconds=180)
attempt <- fluvgeo::prepare_stream_dem_download(selection,file.path(folder,"source-dem"),limits)
worker <- fgstudio:::launch_stream_dem_download_job(attempt)
worker$wait(timeout=190000)
if(worker$is_alive()) {
  worker$kill();worker$wait(timeout=2000)
  if(!worker$is_alive()) fluvgeo::cancel_stream_dem_download(attempt)
  stop("Synthetic download worker exceeded its outer qualification timeout.")
}
result <- worker$get_result()
print(result$files[c("outcome","bytes","message")],row.names=FALSE)
stopifnot(identical(result$files$outcome,"DOWNLOADED"))
again <- fluvgeo::prepare_stream_dem_download(selection,file.path(folder,"source-dem"),limits)
reused <- fluvgeo::run_stream_dem_download(again)
stopifnot(identical(reused$files$outcome,"REUSED"))
cat("Live synthetic source transfer, worker, offline checksum and reuse passed. Evidence:",folder,"\n")
