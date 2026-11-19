# File-backed preparation assets, independent of water levels and cross-section settings.
# Self-contained worker; callr uses ordinary arguments and its stdout pipe for phases.
cross_section_layout_job <- function(path,line,channel,floodplain,spacing,window,smoothing,
                                     boundary_spacing,overbank_angle,overbank_bends,
                                     region_directory,profile=FALSE) {
  phase <- function(label) {cat("FGSTUDIO_PHASE:",label,"\n",sep="");flush(stdout())}
  timings <- numeric();started <- proc.time()[["elapsed"]]
  phase("Preparing inundation polygons (stage 1 of 3)...")
  footprints <- fluvgeo::water_surface_extents(terra::rast(path),line,channel,floodplain)
  timings["inundation"] <- proc.time()[["elapsed"]]-started
  candidate <- tryCatch({
    key <- paste(format(openssl::sha256(serialize(list(channel,floodplain,boundary_spacing,smoothing,"polygon-centerline-v4"),NULL))),collapse="")
    cached <- file.path(region_directory,paste0("regions-",key,".rds"))
    started <- proc.time()[["elapsed"]]
    phase("Building polygon centerlines (stage 2 of 3)...")
    artifacts <- if(file.exists(cached))readRDS(cached) else NULL
    if(is.null(artifacts)) {
      artifacts <- fluvgeo::cross_section_regions(line,footprints$channel_outer,footprints$floodplain_outer,
        centerline_spacing_m=boundary_spacing,smoothing_refinements=smoothing)
      pending <- paste0(cached,".pending");saveRDS(artifacts,pending)
      if(!file.rename(pending,cached))stop("Could not retain the centerline review cache.")
    }
    timings["centerlines"] <- proc.time()[["elapsed"]]-started
    phase("Deconflicting cross sections (stage 3 of 3)...")
    started <- proc.time()[["elapsed"]]
    if(profile) {
      utils::Rprof(file.path(region_directory,"layout.Rprof"),interval=.02)
      on.exit(utils::Rprof(NULL),add=TRUE)
    }
    result <- fluvgeo::cross_section_layout(line,footprints$channel_outer,footprints$floodplain_outer,
      spacing_m=spacing,tangent_distance_m=window,centerline_spacing_m=boundary_spacing,
      smoothing_refinements=smoothing,region_artifacts=artifacts,
      overbank_angle_limit_deg=overbank_angle,allow_overbank_bends=overbank_bends)
    timings["layout"] <- proc.time()[["elapsed"]]-started
    footprints$channel_outer_raw <- footprints$channel_outer
    footprints$channel_outer <- result$channel_footprint
    result
  },error=function(e)list(error=conditionMessage(e)))
  list(footprints=footprints,layout=if(is.null(candidate$error))candidate else NULL,
    layout_error=candidate$error,timings=timings)
}

# This worker is self-contained so callr can run it without a development namespace.
cross_section_rem_artifact <- function(request,dem=NULL,line=NULL,points=NULL) {
  hash <- function(path) {con<-file(path,"rb");on.exit(close(con));as.character(openssl::sha256(con))}
  directory <- request$directory
  if(!grepl("^[0-9a-f]{64}$",request$key) || basename(directory)!=request$key)
    stop("Invalid REM preparation destination.")
  read_ready <- function() {
    index<-file.path(directory,"preparation.rds")
    if(!file.exists(index))return(NULL)
    record <- tryCatch(readRDS(index),error=function(e)NULL)
    if(!is.null(record) && identical(record$inputs,request$inputs) && identical(record$recipe,request$recipe)) {
    paths <- file.path(directory,c("rem.tif","display.tif"))
    if(all(file.exists(paths)) && identical(vapply(paths,hash,character(1),USE.NAMES=FALSE),record$sha256))
      return(list(path=paths[1],display=paths[2],limits=record$limits,key=request$key,precomputed=TRUE))
    }
    NULL
  }
  ready<-tryCatch(read_ready(),error=function(e)NULL)
  if(!is.null(ready))return(ready)
  if(is.null(dem))return(NULL)
  fs::dir_create(dirname(directory))
  staging <- tempfile(paste0(request$key,"-pending-"),tmpdir=dirname(directory));dir.create(staging)
  root<-normalizePath(dirname(directory),winslash="/",mustWork=TRUE)
  if(tolower(dirname(normalizePath(staging,winslash="/",mustWork=TRUE)))!=tolower(root))
    stop("REM staging must remain inside its preparation directory.")
  on.exit(unlink(staging,recursive=TRUE),add=TRUE)
  result <- fluvgeo::detrend(terra::rast(dem),line,points,buffer_distance=request$recipe$buffer_distance)
  terra::writeRaster(result$rem,file.path(staging,"rem.tif"))
  factor <- max(1L,ceiling(sqrt(terra::ncell(result$rem)/request$recipe$display_max_cells)))
  display <- if(factor>1L)terra::aggregate(result$rem,fact=factor,fun="mean",na.rm=TRUE) else result$rem
  display <- terra::project(display,request$recipe$display_crs)
  terra::writeRaster(display,file.path(staging,"display.tif"))
  record <- list(schema="FGSTUDIO_CROSS_SECTION_REM_1",inputs=request$inputs,recipe=request$recipe,
    limits=as.numeric(terra::global(display,range,na.rm=TRUE)[1,]),
    sha256=vapply(file.path(staging,c("rem.tif","display.tif")),hash,character(1),USE.NAMES=FALSE))
  saveRDS(record,file.path(staging,"preparation.rds"))
  jsonlite::write_json(record,file.path(staging,"preparation.json"),auto_unbox=TRUE,pretty=TRUE,digits=NA)
  # Publish the complete directory. A failed/cancelled preparation is never reusable.
  if(dir.exists(directory)) {
    ready<-tryCatch(read_ready(),error=function(e)NULL)
    if(!is.null(ready))return(ready)
    # Preserve an invalid previous artifact for inspection rather than overwrite it.
    archived <- tempfile(paste0(request$key,"-superseded-"),tmpdir=dirname(directory))
    if(tolower(dirname(normalizePath(directory,winslash="/",mustWork=TRUE)))!=tolower(root) ||
        tolower(dirname(normalizePath(archived,winslash="/",mustWork=FALSE)))!=tolower(root))
      stop("REM replacement must remain inside its preparation directory.")
    if(!file.rename(directory,archived))stop("Cannot replace an invalid REM preparation.")
  }
  if(!file.rename(staging,directory))stop("Cannot publish the REM preparation.")
  list(path=file.path(directory,"rem.tif"),display=file.path(directory,"display.tif"),
    limits=record$limits,key=request$key,precomputed=FALSE)
}

cross_section_rem_queue <- function(store,value) {
  if(is.null(value$saved) || !is.function(store$cross_section_rem_request))return(list())
  result <- list()
  for(bundle in value$bundle)for(i in seq_len(nrow(bundle$flowline$flowlines))) {
    line <- bundle$flowline$flowlines[i,,drop=FALSE];id<-line$reach_id[1]
    request <- store$cross_section_rem_request(value$context,value$saved,id)
    if(is.null(tryCatch(cross_section_rem_artifact(request),error=function(e)NULL)))
      result[[length(result)+1L]] <- list(request=request,dem=bundle$dem,line=line,
        points=value$saved$points[value$saved$points$reach_id==id,,drop=FALSE])
  }
  result
}
