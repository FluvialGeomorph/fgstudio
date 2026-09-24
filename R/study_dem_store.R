# App-owned, immutable local editions. The current producer supplies only a
# qualified Reach portion; this adapter does not assert whole-Stream coverage.
study_dem_store <- function(context_path, acquisition_groups, survey_collections) {
  folder <- function(key, kind) {
    parent <- as.character(fs::path_real(dirname(context_path(key))))
    path <- file.path(parent, "event-dems", kind)
    for (p in c(dirname(path), path)) {
      if (dir.exists(p) && !startsWith(tolower(as.character(fs::path_real(p))),
          paste0(tolower(parent), "/"))) stop("DEM storage is outside this Study.")
      if (!dir.exists(p) && !dir.create(p)) stop("Cannot create DEM storage.")
    }
    path
  }
  request <- function(key, group_id, expected_path, expected_group) {
    group <- acquisition_groups(key)$groups[[group_id]]
    if (is.null(group) || !identical(context_path(key), expected_path) ||
        !identical(group$path, expected_group)) stop("Study or Survey Event changed.")
    list(key=key, group_id=group_id, context=expected_path, group=expected_group,
      selection=survey_collections(key)$path)
  }
  check_stage <- function(key, directory) {
    stage <- as.character(fs::path_real(folder(key,"staging")))
    if (!grepl("^[0-9a-f]{32}$",basename(directory)) ||
        !identical(tolower(as.character(fs::path_real(dirname(directory)))),tolower(stage)) ||
        (dir.exists(directory) && !identical(tolower(as.character(fs::path_real(directory))),
                                            tolower(paste0(stage,"/",basename(directory))))))
      stop("Invalid DEM staging directory.")
    directory
  }
  prepare <- function(key) {
    staging <- folder(key,"staging")
    alive <- ps::ps_pids()
    for (p in list.dirs(staging,recursive=FALSE,full.names=TRUE)) {
      check_stage(key,p)
      owner <- tryCatch(jsonlite::read_json(file.path(p,"owner.json"),simplifyVector=TRUE),error=function(e) NULL)
      if (!is.null(owner) && identical(owner$schema,"FGSTUDIO_DEM_JOB_1") &&
          is.numeric(owner$app_pid) && length(owner$app_pid)==1L &&
          is.numeric(owner$worker_pid) && length(owner$worker_pid)==1L &&
          !owner$app_pid %in% alive && !owner$worker_pid %in% alive) discard(key,p)
    }
    path <- file.path(staging,paste(format(openssl::rand_bytes(16)),collapse=""))
    if (!dir.create(path)) stop("Cannot create DEM staging directory.")
    jsonlite::write_json(list(schema="FGSTUDIO_DEM_JOB_1",app_pid=Sys.getpid(),worker_pid=NULL),
      file.path(path,"owner.json"),auto_unbox=TRUE,null="null")
    path
  }
  discard <- function(key,directory) {
    if (!is.null(directory)) unlink(check_stage(key,directory),recursive=TRUE)
    invisible(NULL)
  }
  reopen <- function(path) {
    record <- readRDS(file.path(path,"edition.rds"))
    if (!identical(record$schema,"FGSTUDIO_DEM_EDITION_1") ||
        !identical(record$scope,"reach_portion") ||
        !identical(record$trial$result$path,"dem-international-feet.tif")) stop("Invalid DEM edition.")
    raster <- file.path(path,record$trial$result$path)
    if (!file.exists(raster) || !identical(unname(file.info(raster)$size),record$bytes))
      stop("Saved DEM is missing or incomplete.")
    record$trial$result$path <- raster
    record$trial$saved_dem <- list(id=basename(path),scope=record$scope,created=record$created)
    record
  }
  find <- function(binding, recipe=NULL) {
    paths <- list.dirs(folder(binding$key,"editions"),recursive=FALSE,full.names=TRUE)
    paths <- paths[grepl("^[0-9a-f]{32}$",basename(paths))]
    paths <- paths[order(file.info(paths)$mtime,decreasing=TRUE)]
    for (p in paths) {
      # Resolve links before reading any edition data.
      if (!identical(tolower(as.character(fs::path_real(p))),tolower(gsub("\\\\","/",p)))) next
      record <- tryCatch(reopen(p),error=function(e) NULL)
      if (!is.null(record) && identical(record$binding,binding) &&
          (is.null(recipe) || identical(record$recipe,recipe))) return(record$trial)
    }
    NULL
  }
  publish <- function(binding, recipe, directory, trial) {
    current <- request(binding$key,binding$group_id,binding$context,binding$group)
    if (!identical(current,binding)) stop("Saved inputs changed; DEM was not published.")
    check_stage(binding$key,directory)
    raster <- file.path(directory,"dem-international-feet.tif")
    if (!identical(normalizePath(trial$result$path,winslash="/",mustWork=TRUE),
                   normalizePath(raster,winslash="/",mustWork=TRUE)) ||
        !identical(trial$key,binding$key) || !identical(trial$group_id,binding$group_id) ||
        !identical(trial$stage,"international_feet")) stop("DEM does not match its saved Event.")
    trial$result$path <- basename(raster)
    record <- list(schema="FGSTUDIO_DEM_EDITION_1",scope="reach_portion",binding=binding,
      recipe=recipe,created=format(Sys.time(),tz="UTC",usetz=TRUE),
      bytes=unname(file.info(raster)$size),trial=trial)
    saveRDS(record,file.path(directory,"edition.rds"))
    unlink(file.path(directory,"owner.json"))
    destination <- file.path(folder(binding$key,"editions"),basename(directory))
    if (file.exists(destination) || !file.rename(directory,destination)) stop("Could not publish DEM edition.")
    reopen(destination)$trial
  }
  list(dem_request=request,prepare_dem=prepare,discard_dem=discard,
       find_dem=find,publish_dem=publish)
}
