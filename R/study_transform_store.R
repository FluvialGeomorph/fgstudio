# App-owned, immutable planning records. No DEM execution is enabled by this store.
study_transform_store <- function(request_builder,context_path) {
  fingerprint <- function(x) unclass(as.character(openssl::sha256(serialize(x,NULL,version=2))))
  folder <- function(request,create=FALSE) {
    parent <- as.character(fs::path_real(dirname(context_path(request$key))))
    path <- file.path(parent,"terrain-transformations",fingerprint(request$group_id))
    for(p in c(dirname(path),path)) {
      if(dir.exists(p) && !startsWith(tolower(as.character(fs::path_real(p))),paste0(tolower(parent),"/")))
        stop("Transformation storage is outside this Study.")
      if(create && !dir.exists(p) && !dir.create(p)) stop("Cannot create transformation storage.")
    }
    path
  }
  latest <- function(request,review) {
    files <- sort(list.files(folder(request),pattern="^plan-[0-9]{6,}-[0-9a-f]{32}\\.json$",full.names=TRUE),decreasing=TRUE)
    if(!length(files)) return(NULL)
    path <- files[1L]
    if(!startsWith(tolower(as.character(fs::path_real(path))),
        paste0(tolower(as.character(fs::path_real(dirname(path)))),"/"))) stop("Invalid plan path.")
    record <- jsonlite::read_json(path,simplifyVector=FALSE)
    if(!identical(record$schema,"FGSTUDIO_TRANSFORM_PLAN_1") || !identical(record$execution_enabled,FALSE))
      stop("Invalid transformation plan.")
    list(path=path,record=record,current=identical(record$request_fingerprint,fingerprint(request)) &&
      identical(record$review$fingerprint,review$fingerprint))
  }
  save <- function(request,review,choices,expected=NULL,checked=NULL) {
    fresh <- request_builder(request$key,request$group_id,request$context,request$group)
    if(!identical(fresh,request)) stop("Study, Event or source selections changed. Review candidates again.")
    if(is.null(checked)) checked <- do.call(fluvgeo::review_terrain_transformations,fresh$args)
    if(!identical(checked$fingerprint,review$fingerprint))
      stop("Source references or operation resources changed. Review candidates again.")
    selections <- terrain_transform_choices(checked,choices)
    root <- folder(request,TRUE); lock <- file.path(root,".write-lock")
    if(!dir.create(lock,showWarnings=FALSE)) stop("Another transformation plan is being saved. Retry after reloading.")
    on.exit(unlink(lock,recursive=TRUE),add=TRUE)
    previous <- latest(request,review)
    if(!identical(previous$path,expected)) stop("A newer transformation plan exists. Review again before saving.")
    revision <- if(is.null(previous)) 1 else previous$record$revision+1
    id <- paste(format(openssl::rand_bytes(16)),collapse="")
    record <- list(schema="FGSTUDIO_TRANSFORM_PLAN_1",revision=revision,
      created_at=format(Sys.time(),tz="UTC",usetz=TRUE),actor=NULL,
      request_fingerprint=fingerprint(request),binding=request[c("key","group_id","context","group","selections")],
      review=checked,selections=selections,execution_enabled=FALSE)
    pending <- file.path(root,paste0("pending-",id,".json"))
    on.exit(unlink(pending),add=TRUE)
    path <- file.path(root,sprintf("plan-%06d-%s.json",as.integer(revision),id))
    jsonlite::write_json(record,pending,auto_unbox=TRUE,pretty=TRUE,null="null",na="null",digits=NA)
    if(!file.rename(pending,path)) stop("Cannot publish transformation plan.")
    latest(request,review)
  }
  list(transform_request=request_builder,transform_plan=latest,save_transform_plan=save)
}
