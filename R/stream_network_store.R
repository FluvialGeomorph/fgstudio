# Local candidate-network preparation assets. Governed FGDB publication remains
# a separate contract.
study_stream_network_store <- function(context_path,hydro_read) {
  root <- function(record) {
    if(is.null(record$result)) stop("Apply and save the Hydro DEM first.")
    path <- file.path(record$path,"stream-network")
    fs::dir_create(path)
    path
  }
  read <- function(record) {
    path <- root(record)
    dirs <- list.dirs(path,recursive=FALSE,full.names=TRUE)
    dirs <- dirs[grepl("^[0-9a-f]{32}$",basename(dirs))]
    dirs <- dirs[order(file.info(dirs)$mtime,decreasing=TRUE)]
    for(directory in dirs) {
      result <- tryCatch(readRDS(file.path(directory,"result.rds")),error=function(e) NULL)
      outlet <- tryCatch(readRDS(file.path(directory,"outlet.rds")),error=function(e) NULL)
      if(is.null(result) || is.null(outlet) ||
         !identical(result$source_sha256,record$result$output_sha256)) next
      required <- file.path(directory,unlist(result$files,use.names=FALSE))
      if(any(!file.exists(required))) stop("Saved stream extraction is incomplete.")
      result$path <- directory;result$outlet <- outlet
      return(result)
    }
    NULL
  }
  prepare <- function(record) {
    current <- hydro_read(record$key,record$event,record$stream,record$source)
    if(!identical(current$id,record$id) || is.null(current$result))
      stop("Hydro DEM changed; reopen this Stream.")
    directory <- file.path(root(current),paste0("processing-",
      paste(format(openssl::rand_bytes(16)),collapse="")))
    if(!dir.create(directory)) stop("Cannot prepare stream-extraction storage.")
    directory
  }
  discard <- function(directory) {
    if(!is.null(directory) && dir.exists(directory) &&
       grepl("^processing-[0-9a-f]{32}$",basename(directory)))
      unlink(directory,recursive=TRUE)
    invisible(NULL)
  }
  publish <- function(record,directory,result,outlet) {
    current <- hydro_read(record$key,record$event,record$stream,record$source)
    if(!identical(current$id,record$id) || is.null(current$result) ||
       !identical(context_path(record$key),record$context) ||
       !identical(result$source_sha256,current$result$output_sha256))
      stop("Inputs changed; stream extraction was not published.")
    parent <- root(current)
    if(!identical(normalizePath(dirname(directory),winslash="/",mustWork=TRUE),
      normalizePath(parent,winslash="/",mustWork=TRUE)) ||
      !grepl("^processing-[0-9a-f]{32}$",basename(directory)))
      stop("Invalid stream-extraction staging directory.")
    required <- file.path(directory,unlist(result$files,use.names=FALSE))
    if(any(!file.exists(required))) stop("Stream-extraction output is incomplete.")
    saveRDS(outlet,file.path(directory,"outlet.rds"))
    result$app <- list(schema="FGSTUDIO_SYNTHETIC_STREAM_1",key=record$key,
      event=record$event,stream=record$stream,context=record$context,
      hydro_cutline_revision=record$id,hydro_result_sha256=current$result$output_sha256)
    saveRDS(result,file.path(directory,"result.rds"))
    portable <- result;portable$route <- NULL;portable$path <- NULL;portable$outlet <- NULL
    jsonlite::write_json(portable,file.path(directory,"provenance.json"),
      auto_unbox=TRUE,pretty=TRUE,null="null")
    id <- paste(format(openssl::rand_bytes(16)),collapse="")
    if(!file.rename(directory,file.path(parent,id)))
      stop("Could not publish the candidate stream network.")
    read(current)
  }
  list(stream_network_read=read,stream_network_prepare=prepare,
    stream_network_discard=discard,stream_network_publish=publish)
}
