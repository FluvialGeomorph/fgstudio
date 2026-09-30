# Local preparation assets; this is not the FGDB portable delivery binding.
study_hydro_store <- function(context_path) {
  root <- function(key, event, stream) {
    parent <- dirname(context_path(key))
    token <- function(x) as.character(openssl::md5(charToRaw(x)))
    path <- file.path(parent,"hydro-modify",token(event),token(stream))
    fs::dir_create(path)
    if (!startsWith(tolower(as.character(fs::path_real(path))),
                    paste0(tolower(as.character(fs::path_real(parent))),"/")))
      stop("Hydro modification storage is outside this Study.")
    path
  }
  read <- function(key,event,stream,source) {
    path <- root(key,event,stream)
    dirs <- list.dirs(path,recursive=FALSE,full.names=TRUE)
    dirs <- dirs[grepl("^[0-9a-f]{32}$",basename(dirs))]
    dirs <- dirs[order(file.info(dirs)$mtime,decreasing=TRUE)]
    for (p in dirs) {
      record <- tryCatch(readRDS(file.path(p,"cutlines.rds")),error=function(e) NULL)
      if (!is.null(record) && (is.null(source) || identical(record$source,source))) {
        record$path <- p
        record$result <- if(file.exists(file.path(p,"result","result.rds"))) readRDS(file.path(p,"result","result.rds")) else NULL
        if(!is.null(record$result) && (!file.exists(file.path(p,record$result$file)) ||
          !identical(unname(file.info(file.path(p,record$result$file))$size),record$result$bytes)))
          stop("Saved hydro DEM is missing or incomplete.")
        return(record)
      }
    }
    NULL
  }
  save <- function(key,event,stream,source,lines,expected,context) {
    if (!identical(context_path(key),context)) stop("Study changed; reopen Hydro Modify.")
    path <- root(key,event,stream)
    lock <- file.path(path,"write.lock")
    if (!dir.create(lock,showWarnings=FALSE)) stop("Cutlines are being saved. Try again.")
    on.exit(unlink(lock,recursive=TRUE),add=TRUE)
    previous <- read(key,event,stream,source)
    if (!identical(previous$id,expected)) stop("Cutlines changed in another session. Reopen this Stream.")
    id <- paste(format(openssl::rand_bytes(16)),collapse="")
    stage <- file.path(path,paste0("staging-",id));dir.create(stage)
    on.exit(unlink(stage,recursive=TRUE),add=TRUE)
    if(nrow(lines)) sf::st_write(lines,file.path(stage,"cutlines.gpkg"),layer="cutlines",quiet=TRUE)
    record <- list(schema="FGSTUDIO_HYDRO_CUTLINES_1",id=id,source=source,
      key=key,event=event,stream=stream,context=context,lines=lines,
      created=format(Sys.time(),"%Y-%m-%dT%H:%M:%SZ",tz="UTC"))
    saveRDS(record,file.path(stage,"cutlines.rds"))
    if(!file.rename(stage,file.path(path,id))) stop("Could not save cutlines.")
    read(key,event,stream,source)
  }
  prepare <- function(record) {
    current <- read(record$key,record$event,record$stream,record$source)
    if(!identical(current$id,record$id)) stop("Cutlines changed; reopen this Stream.")
    directory <- file.path(current$path,paste0("processing-",paste(format(openssl::rand_bytes(16)),collapse="")))
    if(!dir.create(directory)) stop("Cannot prepare hydro DEM storage.")
    directory
  }
  publish <- function(record,directory,result) {
    lock <- file.path(root(record$key,record$event,record$stream),"write.lock")
    if(!dir.create(lock,showWarnings=FALSE)) stop("Cutlines are being saved. Try again.")
    on.exit(unlink(lock,recursive=TRUE),add=TRUE)
    current <- read(record$key,record$event,record$stream,record$source)
    if(!identical(current$id,record$id) || !identical(context_path(record$key),record$context))
      stop("Inputs changed; hydro DEM was not published.")
    if(!is.null(current$result)) return(current)
    if(!identical(normalizePath(dirname(directory),winslash="/",mustWork=TRUE),
                  normalizePath(current$path,winslash="/",mustWork=TRUE)) ||
       !grepl("^processing-[0-9a-f]{32}$",basename(directory))) stop("Invalid hydro staging directory.")
    raster <- file.path(directory,"hydro-dem.tif")
    if(!identical(normalizePath(result$path,winslash="/",mustWork=TRUE),
      normalizePath(raster,winslash="/",mustWork=TRUE))) stop("Hydro output does not match this job.")
    result$path <- NULL;result$file <- "result/hydro-dem.tif"
    result$source_edition <- record$source;result$cutline_revision <- record$id
    result$bytes <- unname(file.info(raster)$size)
    result$schema <- "FGSTUDIO_HYDRO_RESULT_1"
    # Publish the payload and completion record together, retaining prior drafts.
    jsonlite::write_json(result,file.path(directory,"provenance.json"),auto_unbox=TRUE,pretty=TRUE,null="null")
    saveRDS(result,file.path(directory,"result.rds"))
    if(!file.rename(directory,file.path(current$path,"result"))) stop("Could not publish hydro DEM.")
    read(record$key,record$event,record$stream,record$source)
  }
  list(hydro_read=read,hydro_save=save,hydro_prepare=prepare,hydro_publish=publish)
}

hydro_drawn_lines <- function(features) {
  if(!is.list(features) || !identical(features$type,"FeatureCollection")) stop("Invalid cutline drawing.")
  geometries <- lapply(features$features,function(f) {
    if(!identical(f$geometry$type,"LineString")) stop("Draw cutlines with the line tool.")
    xy <- do.call(rbind,lapply(f$geometry$coordinates,unlist))
    if(!is.matrix(xy) || nrow(xy)<2 || ncol(xy)!=2 || any(!is.finite(xy)) ||
       any(abs(xy[,1])>180) || any(abs(xy[,2])>90)) stop("Invalid cutline coordinates.")
    sf::st_linestring(xy)
  })
  sf::st_sf(cutline_id=seq_along(geometries),geometry=sf::st_sfc(geometries,crs=4326))
}
