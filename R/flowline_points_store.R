# Immutable Study-wide Flowline Points candidate revisions. Governed FGDB
# reference-frame acceptance remains a later workflow boundary.
study_flowline_points_store <- function(context_path, hydro_read, flowline_read) {
  file_hash <- function(path) {
    con <- file(path,"rb");on.exit(close(con))
    unclass(as.character(openssl::sha256(con)))
  }
  flowline_file <- function(flowline) {
    path <- file.path(flowline$path,flowline$files$geopackage)
    if(!file.exists(path)) stop("The saved Reach Flowlines are unavailable.")
    path
  }
  inputs <- function(context,bundle,station_distance) {
    if(!file.exists(context$path) || !file.exists(context$group_path))
      stop("The saved Study or Survey Event revision is unavailable.")
    stream_inputs <- lapply(bundle,function(x) list(
      stream_id=x$selection$stream,
      stream_name=x$stream_name,
      hydro_revision=x$record$id,
      hydro_sha256=x$record$result$output_sha256,
      flowline_revision=basename(x$flowline$path),
      flowline_sha256=file_hash(flowline_file(x$flowline))))
    list(schema="FGSTUDIO_FLOWLINE_POINTS_INPUTS_2",key=context$key,
      event=context$group_id,
      context_file=basename(context$path),context_sha256=file_hash(context$path),
      event_file=basename(context$group_path),
      event_sha256=file_hash(context$group_path),
      streams=unname(stream_inputs),station_distance_m=as.numeric(station_distance))
  }
  root <- function(context) {
    path <- file.path(dirname(context$path),"flowline-points")
    fs::dir_create(path);path
  }
  load_revision <- function(directory,result) {
    path <- file.path(directory,result$files$geopackage)
    if(!file.exists(path) || !identical(file_hash(path),result$files$sha256))
      stop("A saved Flowline Points candidate is incomplete or changed.")
    if(!all(c("flowline_points","stream_connections") %in%
        sf::st_layers(path)$name))
      stop("A saved Flowline Points candidate is missing its required layers.")
    result$path <- directory
    result$points <- sf::st_read(path,layer="flowline_points",quiet=TRUE)
    result$connections <- sf::st_read(path,layer="stream_connections",quiet=TRUE)
    fluvgeo::check_flowline_points(result$points,"fgstudio_replacement")
    result
  }
  read <- function(context,bundle,station_distance=NULL) {
    spacing <- if(is.null(station_distance)) 1 else station_distance
    current <- inputs(context,bundle,spacing)
    directories <- list.dirs(root(context),recursive=FALSE,full.names=TRUE)
    directories <- directories[grepl("^[0-9a-f]{32}$",basename(directories))]
    directories <- directories[!file.exists(file.path(directories,"PENDING"))]
    directories <- directories[order(file.info(directories)$mtime,decreasing=TRUE)]
    for(directory in directories) {
      result <- tryCatch(readRDS(file.path(directory,"result.rds")),
        error=function(e) NULL)
      if(is.null(result) || !is.list(result$inputs)) next
      expected <- current;observed <- result$inputs
      if(is.null(station_distance)) {
        expected$station_distance_m <- NULL;observed$station_distance_m <- NULL
      }
      if(identical(observed,expected)) return(load_revision(directory,result))
    }
    NULL
  }
  publish <- function(context,bundle,station_distance,points,connections) {
    if(!identical(context_path(context$key),context$path))
      stop("Inputs changed; reopen Flowline Points before saving.")
    for(x in bundle) {
      current_hydro <- hydro_read(context$key,context$group_id,
        x$selection$stream,NULL)
      current_flowline <- if(is.null(current_hydro)) NULL else
        flowline_read(current_hydro,x$selection,x$segments)
      if(is.null(current_hydro) || is.null(current_hydro$result) ||
         !identical(current_hydro$id,x$record$id) || is.null(current_flowline) ||
         !identical(normalizePath(current_flowline$path),
           normalizePath(x$flowline$path)))
        stop("Inputs changed; reopen Flowline Points before saving.")
    }
    fluvgeo::check_flowline_points(points,"fgstudio_replacement")
    fingerprint <- inputs(context,bundle,station_distance)
    directory <- file.path(root(context),
      paste(format(openssl::rand_bytes(16)),collapse=""))
    if(!dir.create(directory)) stop("Cannot prepare Flowline Points storage.")
    pending <- file.path(directory,"PENDING")
    if(!file.create(pending)) stop("Cannot protect incomplete Flowline Points storage.")
    complete <- FALSE
    on.exit(if(!complete && dir.exists(directory)) unlink(directory,recursive=TRUE),add=TRUE)
    path <- file.path(directory,"flowline-points.gpkg")
    sf::st_write(points,path,layer="flowline_points",quiet=TRUE)
    sf::st_write(connections,path,layer="stream_connections",quiet=TRUE)
    result <- list(schema="FGSTUDIO_FLOWLINE_POINTS_CANDIDATE_2",inputs=fingerprint,
      station_distance_m=as.numeric(station_distance),point_count=nrow(points),
      stream_count=length(unique(points$stream_id)),
      reach_ids=unique(as.character(points$reach_id)),
      created_at=format(Sys.time(),"%Y-%m-%dT%H:%M:%SZ",tz="UTC"),
      files=list(geopackage=basename(path),sha256=file_hash(path)))
    saveRDS(result,file.path(directory,"result.rds"))
    jsonlite::write_json(result,file.path(directory,"provenance.json"),
      auto_unbox=TRUE,pretty=TRUE,null="null",digits=NA)
    if(unlink(pending)!=0L)
      stop("Could not publish the local Flowline Points candidate revision.")
    complete <- TRUE
    load_revision(directory,result)
  }
  list(flowline_points_read=read,flowline_points_publish=publish)
}
