# App-owned storage adapter. Scientific identity/schema validation stays in fluvgeo.
local_study_store <- function(data_dir) {
  if (!is.character(data_dir) || length(data_dir) != 1L || is.na(data_dir) ||
      !nzchar(trimws(data_dir))) stop("Supply a local data directory.", call. = FALSE)
  if (!dir.exists(data_dir) && !dir.create(data_dir, recursive = TRUE))
    stop("Cannot create the local data directory.", call. = FALSE)
  root <- normalizePath(data_dir, winslash = "/", mustWork = TRUE)
  valid_key <- function(key) {
    is.character(key) && length(key) == 1L && !is.na(key) &&
      grepl("^[0-9a-f]{32}$", key)
  }
  context_path <- function(key) {
    if (!valid_key(key)) stop("Choose a saved Study Area.", call. = FALSE)
    folder <- file.path(root, key)
    revisions <- sort(list.files(folder, pattern = "^revision-[0-9]{6}\\.gpkg$"))
    path <- file.path(folder, if (length(revisions)) utils::tail(revisions, 1L) else "study.gpkg")
    resolved <- normalizePath(path, winslash = "/", mustWork = TRUE)
    if (!startsWith(tolower(resolved), paste0(tolower(root), "/")))
      stop("The saved study is outside this workspace.", call. = FALSE)
    resolved
  }
  read <- function(key) {
    path <- context_path(key)
    context <- fluvgeo::read_study_context(path)
    if (is.null(context$study_area) || nrow(context$study_area) != 1L)
      stop("The saved file must contain one Study Area.", call. = FALSE)
    purpose <- context$study_area$study_area_purpose
    if (is.null(purpose)) {
      # Earlier FG Studio drafts used only the original creation notes as Purpose.
      # Never parse later appended provenance or rewrite an old snapshot on read.
      original <- fluvgeo::read_study_context(file.path(dirname(path), "study.gpkg"))
      purpose <- original$analyst_notes
    }
    list(key = key, path = path, vertical_reference = context$vertical_reference,
      analysis_crs = {
        ref <- context$analysis_reference
        row <- if (is.null(ref)) integer() else which(ref$component == "horizontal" & ref$basis == "PROJECT_RECORD")
        if (length(row) == 1L && startsWith(ref$value[row], "PROJCRS["))
          tryCatch(fluvgeo::validate_study_analysis_crs(ref$value[row],
            if (inherits(context$study_area, "sf")) context$study_area else NULL), error = function(e) NULL) else NULL
      },
      study_id = context$study_area$study_area_id[[1]],
      name = context$study_area$study_area_name[[1]],
      notes = context$analyst_notes,
      purpose = purpose,
      boundary = inherits(context$study_area, "sf"),
      boundary_sf = if (inherits(context$study_area, "sf")) context$study_area else NULL,
      streams = if (is.null(context$streams)) 0L else nrow(context$streams),
      stream_inventory = context$streams,
      can_define_streams = all(vapply(context[c("streams", "reaches", "survey_events", "network")], is.null, logical(1))),
      reaches = if (is.null(context$reaches)) 0L else nrow(context$reaches),
      reach_inventory = context$reaches,
      event_inventory = context$survey_events,
      events = if (is.null(context$survey_events)) 0L else nrow(context$survey_events))
  }
  create <- function(name, notes = "") {
    if (!is.character(name) || length(name) != 1L || is.na(name) ||
        !nzchar(trimws(name))) stop("Enter a Study Area name.", call. = FALSE)
    if (!is.character(notes) || length(notes) != 1L || is.na(notes))
      stop("Purpose must be text.", call. = FALSE)
    name <- trimws(name)
    notes <- if (nzchar(trimws(notes))) trimws(notes) else NA_character_
    key <- paste(format(openssl::rand_bytes(16)), collapse = "")
    folder <- file.path(root, key)
    if (!dir.create(folder)) stop("Cannot create a study folder.", call. = FALSE)
    fluvgeo::start_study_context(file.path(folder, "study.gpkg"),
      study_area_name = name, study_area_purpose = notes)
    read(key) # Present persisted values, not an optimistic copy of form inputs.
  }
  catalog <- function() {
    keys <- list.dirs(root, full.names = FALSE, recursive = FALSE)
    keys <- keys[vapply(keys, valid_key, logical(1))]
    entries <- lapply(keys, function(key) tryCatch(read(key), error = function(e) NULL))
    bad <- sum(vapply(entries, is.null, logical(1)))
    entries <- Filter(Negate(is.null), entries)
    choices <- stats::setNames(
      vapply(entries, `[[`, character(1), "key"),
      vapply(entries, function(x) paste0(x$name, " (", substr(x$key, 1, 8), ")"), character(1)))
    list(choices = choices, unreadable = bad)
  }
  revise <- function(key, expected_path, ..., writer = fluvgeo::revise_study_context) {
    source <- context_path(key)
    if (!identical(source, expected_path))
      stop("This study has a newer revision. Reopen it before saving.", call. = FALSE)
    revision <- if (basename(source) == "study.gpkg") 1L else
      as.integer(sub("^revision-([0-9]+)\\.gpkg$", "\\1", basename(source))) + 1L
    if (revision > 999999L) stop("Revision limit reached.", call. = FALSE)
    destination <- file.path(dirname(source), sprintf("revision-%06d.gpkg", revision))
    writer(source, destination, report_purpose = "definition", ...)
    read(key)
  }
  save_boundary <- function(key, boundary, expected_path) {
    check_boundary(key, boundary, expected_path)
    revise(key, expected_path, study_area_boundary = boundary,
      add_note = paste("Drawn and explicitly saved by the user in FG Studio as the working",
        "Study Area extent. Browser coordinates are WGS 84 longitude/latitude;",
        "this does not establish the terrain analysis CRS or authorize clipping."))
  }
  check_boundary <- function(key, boundary, expected_path) {
    if (!identical(context_path(key), expected_path))
      stop("This study has a newer revision. Reopen it before saving.", call. = FALSE)
    context <- fluvgeo::read_study_context(expected_path)
    check <- fluvgeo::check_study_area_containment(boundary, context$streams, context$reaches)
    outside <- check[check$status == "outside", ]
    if (nrow(outside)) stop(paste("Boundary would exclude saved areas:",
      paste(paste(outside$level, outside$name), collapse = "; "),
      ". Enlarge the boundary; child areas were not changed."), call. = FALSE)
    invisible(check)
  }
  rename <- function(key, name, expected_path) {
    if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(trimws(name)))
      stop("Enter a Study Area name.", call. = FALSE)
    current <- read(key)
    if (!identical(current$path, expected_path))
      stop("This study has a newer revision. Reopen it before saving.", call. = FALSE)
    if (identical(current$name, trimws(name))) return(current)
    revise(key, expected_path, study_area_name = trimws(name))
  }
  save_selected_boundary <- function(key, sources, expected_path, rationale = "") {
    if (!identical(context_path(key), expected_path))
      stop("This study has a newer revision. Reopen it before saving.", call. = FALSE)
    required <- c("candidate_key", "source_type", "source_id", "name", "retrieved_at", "source_description")
    if (!inherits(sources, "sf") || !all(required %in% names(sources)) ||
        anyDuplicated(sources$candidate_key)) stop("Supply the reviewed source polygons.", call. = FALSE)
    if (!is.character(rationale) || length(rationale) != 1L || is.na(rationale))
      stop("Rationale must be text.", call. = FALSE)
    combined <- fluvgeo::combine_study_area_polygons(sources)
    check_boundary(key, combined$boundary, expected_path)
    sources$selected_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
    # Publish evidence first. A later context failure may leave an unreferenced
    # evidence file, but cannot change prior revisions or falsely claim a save.
    evidence <- file.path(dirname(expected_path), paste0("boundary-selection-",
      paste(format(openssl::rand_bytes(16)), collapse = ""), ".gpkg"))
    if (file.exists(evidence)) stop("Evidence destination already exists.", call. = FALSE)
    sf::st_write(sources, evidence, layer = "selected_polygons", quiet = TRUE, append = FALSE)
    retained <- sf::st_read(evidence, layer = "selected_polygons", quiet = TRUE)
    if (nrow(retained) != nrow(sources) || !identical(retained$candidate_key, sources$candidate_key))
      stop("Source evidence could not be verified; boundary was not saved.", call. = FALSE)
    equal <- sf::st_equals(retained, sources)
    if (!all(vapply(seq_len(nrow(sources)), function(i) i %in% equal[[i]], logical(1))))
      stop("Source geometry changed during storage; boundary was not saved.", call. = FALSE)
    digest <- local({ con <- file(evidence, "rb"); on.exit(close(con)); unclass(as.character(openssl::sha256(con))) })
    revise(key, expected_path, study_area_boundary = combined$boundary,
      add_note = paste0("Explicitly selected and reviewed in FG Studio: spherical union of ",
        nrow(sources), " reference polygons, retaining holes and disconnected parts. ",
        "Source geometry and identifiers: ", basename(evidence), " / selected_polygons; SHA256 ", digest,
        ". No buffering, repair, clipping or analysis CRS assignment. ", trimws(rationale)))
  }
  set_purpose <- function(key, purpose, expected_path) {
    if (!is.character(purpose) || length(purpose) != 1L || is.na(purpose))
      stop("Purpose must be text.", call. = FALSE)
    purpose <- if (nzchar(trimws(purpose))) trimws(purpose) else NA_character_
    current <- read(key)
    if (!identical(current$path, expected_path))
      stop("This study has a newer revision. Reopen it before saving.", call. = FALSE)
    if (identical(current$purpose, purpose)) return(current)
    revise(key, expected_path, study_area_purpose = purpose)
  }
  define_streams <- function(key, names, rationale, expected_path) {
    revise(key, expected_path, streams = data.frame(stream_name = names),
      add_note = rationale, writer = fluvgeo::define_study_streams)
  }
  set_analysis_crs <- function(key, crs, evidence, analyst, expected_path) {
    revise(key, expected_path, crs = crs, evidence = evidence, analyst = analyst,
      writer = fluvgeo::set_study_analysis_crs)
  }
  set_vertical_reference <- function(key, specification, expected_path) {
    revise(key, expected_path, specification = specification, writer = fluvgeo::set_study_vertical_reference)
  }
  save_stream <- function(key, lines, name, distance, unit, rationale, expected_path, stream_id = NULL) {
    revise(key, expected_path, lines = lines, stream_name = name, distance = distance,
      unit = unit, add_note = rationale, stream_id = stream_id,
      writer = fluvgeo::add_study_stream_corridor)
  }
  stream_segments <- function(key, stream_id, expected_path) {
    if (!identical(context_path(key), expected_path))
      stop("This study has a newer revision. Reopen it before defining Reaches.", call. = FALSE)
    fluvgeo::read_study_stream_segments(expected_path, stream_id)
  }
  preview_reach <- function(key, stream_id, source_id, expected_path) {
    stream_segments(key, stream_id, expected_path)
    fluvgeo::preview_study_reach_corridor(expected_path, stream_id, source_id)
  }
  save_reach <- function(key, stream_id, source_id, name, expected_path) {
    revise(key, expected_path, stream_id = stream_id, source_id = source_id,
      reach_name = name, writer = fluvgeo::add_study_reach_corridor)
  }
  preview_reach_merge <- function(key, reach_ids, retain_reach_id, expected_path) {
    if (!identical(context_path(key), expected_path))
      stop("This study has a newer revision. Reopen it before combining Reaches.", call. = FALSE)
    fluvgeo::preview_study_reach_merge(expected_path, reach_ids, retain_reach_id)
  }
  merge_reaches <- function(key, reach_ids, retain_reach_id, name, expected_path) {
    revise(key, expected_path, reach_ids = reach_ids, retain_reach_id = retain_reach_id,
      reach_name = name, writer = fluvgeo::merge_study_reaches)
  }
  rename_feature <- function(key, level, id, name, expected_path) {
    x <- read(key)
    if (!identical(x$path, expected_path))
      stop("This study has a newer revision. Reopen it before saving.", call. = FALSE)
    if (!is.character(level) || length(level) != 1L || !level %in% c("stream","reach"))
      stop("Choose Stream or Reach.", call. = FALSE)
    inventory <- x[[paste0(level,"_inventory")]]
    j <- match(id, inventory[[paste0(level,"_id")]])
    if (is.character(name) && length(name) == 1L && !is.na(name) &&
        length(j) == 1L && !is.na(j) && identical(trimws(name), inventory[[paste0(level,"_name")]][j])) return(x)
    revise(key, expected_path, level = level, feature_id = id, name = name,
      writer = fluvgeo::rename_study_feature)
  }
  preview_reach_split <- function(key,reach_id,point,keep_side,expected_path) {
    if (!identical(context_path(key),expected_path)) stop("This study has a newer revision. Reopen it before splitting.",call.=FALSE)
    fluvgeo::preview_study_reach_split(expected_path,reach_id,point,keep_side)
  }
  split_reach <- function(key,reach_id,point,name,keep_side,expected_path) {
    revise(key,expected_path,reach_id=reach_id,point=point,new_reach_name=name,keep_side=keep_side,
      writer=fluvgeo::split_study_reach)
  }
  survey_collections <- function(key) {
    folder <- dirname(context_path(key))
    files <- sort(list.files(folder,pattern="^survey-selection-[0-9]{6}\\.gpkg$",full.names=TRUE))
    path <- if(length(files)) utils::tail(files,1L) else NULL
    list(path=path,discovery=if(is.null(path)) NULL else fluvgeo::read_survey_collection_selection(path))
  }
  save_survey_collections <- function(key,discovery,selected,expected_path,expected_selection) {
    if(!identical(context_path(key),expected_path) || !identical(survey_collections(key)$path,expected_selection))
      stop("This study or selection has a newer revision. Refresh the browser and reopen before saving.",call.=FALSE)
    x <- read(key)
    if(!identical(x$study_id,discovery$study_area$study_area_id[[1]]) || !isTRUE(x$boundary) ||
        !lengths(sf::st_equals(x$boundary_sf,sf::st_transform(discovery$study_area,sf::st_crs(x$boundary_sf))))[1])
      stop("Study Area boundary changed. Search the saved boundary again before saving.",call.=FALSE)
    n <- if(is.null(expected_selection)) 1L else as.integer(sub("^survey-selection-([0-9]+)\\.gpkg$","\\1",basename(expected_selection)))+1L
    if(n > 999999L) stop("Selection revision limit reached.")
    destination <- file.path(dirname(expected_path),sprintf("survey-selection-%06d.gpkg",n))
    fluvgeo::write_survey_collection_selection(discovery,selected,destination)
    destination
  }
  acquisition_groups <- function(key) {
    files <- sort(list.files(dirname(context_path(key)),pattern="^acquisition-group-[0-9]{6}\\.gpkg$",full.names=TRUE))
    groups <- list()
    for(path in files) {
      g <- fluvgeo::read_survey_acquisition_group(path); g$path <- path
      groups[[g$settings$group_id]] <- g
    }
    list(path=if(length(files)) utils::tail(files,1L) else NULL,groups=groups)
  }
  save_acquisition_group <- function(key,members,stream_ids,year,month,cell_size,rationale,
      event_ids,group_id,expected_path,expected_selection,expected_groups) {
    saved <- acquisition_groups(key)
    if(!identical(context_path(key),expected_path) ||
        !identical(survey_collections(key)$path,expected_selection) || !identical(saved$path,expected_groups))
      stop("Study, selection or Event settings changed. Reopen before saving.")
    if(is.null(expected_selection)) stop("Save Survey Collection selections first.")
    previous <- NULL
    if(!is.null(group_id)) {
      previous <- saved$groups[[group_id]]$path
      if(is.null(previous)) stop("Choose an existing acquisition group.")
    }
    # An existing Reach Event has one spacing, never competing local groups.
    others <- saved$groups[setdiff(names(saved$groups),group_id)]
    if(any(vapply(others,function(g) any(event_ids %in% g$event_links$survey_event_id),logical(1))))
      stop("A Reach Event is already linked to another group.")
    n <- if(is.null(saved$path)) 1L else as.integer(sub(".*-([0-9]{6})\\.gpkg$","\\1",saved$path))+1L
    if(n>999999L) stop("Group revision limit reached.")
    destination <- file.path(dirname(expected_path),sprintf("acquisition-group-%06d.gpkg",n))
    fluvgeo::write_survey_acquisition_group(expected_path,expected_selection,members,stream_ids,
      year,month,cell_size,rationale,destination,previous,event_ids)
    acquisition_groups(key)
  }
  dem_prefix <- function(stream_id,candidate_key) {
    paste0("dem-files-",as.character(openssl::sha256(charToRaw(paste(stream_id,candidate_key,sep="\n")))),"-")
  }
  dem_files <- function(key,stream_id,candidate_key) {
    prefix <- dem_prefix(stream_id,candidate_key)
    files <- sort(list.files(dirname(context_path(key)),pattern=paste0("^",prefix,"[0-9]{6}\\.gpkg$"),full.names=TRUE))
    path <- if(length(files)) utils::tail(files,1L) else NULL
    list(path=path,result=if(is.null(path)) NULL else fluvgeo::read_stream_dem_selection(path))
  }
  check_dem_files <- function(key,inventory,expected_path,expected_files) {
    sid <- inventory$stream$stream_id; cid <- inventory$collection$candidate_key
    if(length(sid)!=1L || length(cid)!=1L) stop("Choose one Stream and collection.")
    if(!identical(context_path(key),expected_path) || !identical(dem_files(key,sid,cid)$path,expected_files))
      stop("A newer study or file selection exists. Reopen before saving.",call.=FALSE)
    x <- read(key); s <- x$stream_inventory
    if(!inherits(s,"sf")) stop("Save the Stream polygon first.")
    s <- s[s$stream_id %in% sid,]
    if(nrow(s)!=1L || !isTRUE(lengths(sf::st_equals(s,sf::st_transform(inventory$stream,sf::st_crs(s))))[1]==1L))
      stop("Stream changed; search again.",call.=FALSE)
    d <- survey_collections(key)$discovery
    if(is.null(d) || !cid %in% d$selected || !any(d$acquisition_plan$candidate_key==cid & d$acquisition_plan$product=="DEM"))
      stop("Save the collection's DEM acquisition plan first.",call.=FALSE)
    c <- d$records[d$records$candidate_key==cid,]
    if(nrow(c)!=1L || !identical(c$snapshot_id,inventory$collection$snapshot_id) ||
        !identical(c$raw_metadata,inventory$collection$raw_metadata)) stop("Collection evidence changed; search again.",call.=FALSE)
    invisible(TRUE)
  }
  save_dem_files <- function(key,inventory,selected,expected_path,expected_files) {
    check_dem_files(key,inventory,expected_path,expected_files)
    sid <- inventory$stream$stream_id; cid <- inventory$collection$candidate_key
    n <- if(is.null(expected_files)) 1L else as.integer(sub(".*-([0-9]{6})\\.gpkg$","\\1",expected_files))+1L
    if(n>999999L) stop("File selection revision limit reached.")
    path <- file.path(dirname(expected_path),paste0(dem_prefix(sid,cid),sprintf("%06d.gpkg",n)))
    fluvgeo::write_stream_dem_selection(inventory,selected,path,basename(expected_path))
    path
  }
  dem_destination <- function(key) {
    parent <- dirname(context_path(key))
    path <- file.path(parent,"source-dem")
    # Resolve existing filesystem links before accepting the study-local directory.
    resolved_parent <- as.character(fs::path_real(parent))
    if(dir.exists(path) && !startsWith(tolower(as.character(fs::path_real(path))),paste0(tolower(resolved_parent),"/")))
      stop("Source DEM storage is outside this study.")
    path
  }
  prepare_dem_download <- function(key,expected_path,expected_files,selected) {
    if(is.null(expected_files)) stop("Save file choices before downloading.")
    inventory <- fluvgeo::read_stream_dem_selection(expected_files)
    if(!identical(inventory$context_revision,basename(expected_path))) stop("Saved file choices use an older study revision.")
    check_dem_files(key,inventory,expected_path,expected_files)
    if(!length(selected) || !setequal(selected,inventory$selected)) stop("Save the current nonempty file choices before downloading.")
    fluvgeo::prepare_stream_dem_download(expected_files,dem_destination(key))
  }
  dem_download <- function(key,stream_id,candidate_key) {
    saved_files <- dem_files(key,stream_id,candidate_key)
    latest <- saved_files$path
    if(is.null(latest)) return(NULL)
    # Metadata-only study revisions do not invalidate original downloads. Still
    # require the current Stream geometry and saved Collection evidence to match.
    compatible <- tryCatch({
      check_dem_files(key,saved_files$result,context_path(key),latest); TRUE
    }, error=function(e) FALSE)
    if(!compatible) return(NULL)
    root <- dem_destination(key)
    attempts <- file.path(root,"attempts")
    if(!dir.exists(attempts)) return(NULL)
    if(!startsWith(tolower(as.character(fs::path_real(attempts))),paste0(tolower(as.character(fs::path_real(root))),"/")))
      stop("Download attempts are outside this study.")
    paths <- list.files(attempts,pattern="^[0-9a-f]{32}$",full.names=TRUE)
    paths <- paths[order(file.info(file.path(paths,"request.json"))$mtime,decreasing=TRUE)]
    for(path in paths) {
      if(!startsWith(tolower(as.character(fs::path_real(path))),paste0(tolower(as.character(fs::path_real(attempts))),"/")))
        stop("Download attempt is outside this study.")
      manifest <- tryCatch(suppressWarnings(jsonlite::read_json(file.path(path,"request.json"),simplifyVector=TRUE)),error=function(e) NULL)
      if(!is.null(manifest) && identical(manifest$selection_file,basename(latest)) &&
          identical(manifest$context_revision,saved_files$result$context_revision) &&
          identical(manifest$stream_id,stream_id) && identical(manifest$candidate_key,candidate_key)) return(path)
    }
    NULL
  }
  dem_download_history <- function(key,stream_id,candidate_key) {
    # Asset history is independent of active selection/geometry revisions.
    root <- dem_destination(key)
    attempts <- file.path(root,"attempts")
    if(!dir.exists(attempts)) return(character())
    inside <- function(p) startsWith(tolower(as.character(fs::path_real(p))),
      paste0(tolower(as.character(fs::path_real(root))),"/"))
    if(!inside(attempts)) stop("Download attempts are outside this study.")
    paths <- list.files(attempts,pattern="^[0-9a-f]{32}$",full.names=TRUE)
    paths <- paths[order(file.info(file.path(paths,"request.json"))$mtime,decreasing=TRUE)]
    paths[vapply(paths,function(path) {
      if(!inside(path)) stop("Download attempt is outside this study.")
      m <- tryCatch(jsonlite::read_json(file.path(path,"request.json"),simplifyVector=TRUE),error=function(e) NULL)
      !is.null(m) && identical(m$schema,"STREAM_DEM_DOWNLOAD_1") &&
        identical(m$stream_id,stream_id) && identical(m$candidate_key,candidate_key)
    },logical(1))]
  }
  dem_preflight_request <- function(key,group_id,stream_id,expected_path,expected_selection,expected_group) {
    groups <- acquisition_groups(key)
    g <- groups$groups[[group_id]]
    if(is.null(g) || !identical(context_path(key),expected_path) ||
        !identical(survey_collections(key)$path,expected_selection) || !identical(g$path,expected_group))
      stop("Study or Event settings changed. Reopen before preflight.")
    members <- g$members$candidate_key
    rows <- lapply(members,function(k) {
      files <- dem_files(key,stream_id,k)$path
      attempt <- dem_download(key,stream_id,k)
      data.frame(candidate_key=k,selection_path=if(is.null(files)) NA_character_ else files,
        attempt=if(is.null(attempt)) NA_character_ else attempt)
    })
    list(context=expected_path,selection=expected_selection,group=expected_group,stream_id=stream_id,
      sources=do.call(rbind,rows))
  }
  review_folder <- function(key,group_id,stream_id,create=FALSE) {
    parent <- dirname(context_path(key))
    id <- as.character(openssl::sha256(serialize(list(group_id,stream_id),NULL,version=2)))
    path <- file.path(parent,"terrain-reviews",id)
    for(p in c(dirname(path),path)) {
      if(dir.exists(p) && !startsWith(tolower(as.character(fs::path_real(p))),
          paste0(tolower(as.character(fs::path_real(parent))),"/"))) stop("Review storage is outside this study.")
      if(create && !dir.exists(p) && !dir.create(p)) stop("Cannot create review storage.")
    }
    path
  }
  terrain_review <- function(key,group_id,stream_id,binding) {
    terrain_review_latest(review_folder(key,group_id,stream_id),binding)
  }
  save_terrain_review <- function(key,group_id,binding,rows,overlap,expected) {
    request <- binding$evidence$request
    current <- dem_preflight_request(key,group_id,request$stream_id,request$context,request$selection,request$group)
    if(!identical(request,current)) stop("Saved source choices changed. Run preflight again.")
    hash <- function(path) {con <- file(path,"rb");on.exit(close(con));unclass(as.character(openssl::sha256(con)))}
    for(n in c("context","selection","group"))
      if(!identical(hash(request[[n]]),binding$evidence$inputs[[n]])) stop("Study or Event evidence changed. Run preflight again.")
    for(i in seq_len(nrow(request$sources)))
      if(!identical(hash(request$sources$selection_path[i]),
          binding$evidence$source_selection_hashes[[request$sources$candidate_key[i]]]))
        stop("Source file choices changed. Run preflight again.")
    target <- read(key)$vertical_reference
    matches <- rows$assessment=="matches_target"
    if(any(matches) && (is.null(target) || target$elevation_unit=="unknown" ||
        any(rows$elevation_unit[matches]!=target$elevation_unit)))
      stop("A target match needs the same known elevation unit as the saved Study Area target.")
    terrain_review_write(review_folder(key,group_id,request$stream_id,TRUE),binding,rows,overlap,expected)
  }
  mask_request <- function(key,group_id,stream_id,expected_path,expected_selection,expected_group) {
    g <- acquisition_groups(key)$groups[[group_id]]
    if(is.null(g) || !identical(context_path(key),expected_path) ||
        !identical(survey_collections(key)$path,expected_selection) || !identical(g$path,expected_group) ||
        length(stream_id)!=1L || !stream_id %in% g$streams$stream_id)
      stop("Study or Event settings changed. Reopen before creating masks.")
    list(context=expected_path,selection=expected_selection,group=expected_group,stream_id=stream_id)
  }
  mask_folder <- function(key,kind) {
    parent <- dirname(context_path(key))
    path <- file.path(parent,"event-masks",kind)
    # Check every existing ancestor before creating folders or following links.
    for(p in c(dirname(path),path)) {
      if(dir.exists(p) && !startsWith(tolower(as.character(fs::path_real(p))),
          paste0(tolower(as.character(fs::path_real(parent))),"/"))) stop("Mask storage is outside this study.")
      if(!dir.exists(p) && !dir.create(p)) stop("Cannot create mask storage.")
    }
    path
  }
  prepare_masks <- function(key) {
    folder <- mask_folder(key,"staging")
    # Reclaim only our recorded jobs after both owning processes have exited.
    # Unknown legacy staging is never guessed to be abandoned by its age.
    for(record in list.files(folder,pattern="^[0-9a-f]{32}\\.json$",full.names=TRUE)) {
      owner <- tryCatch(jsonlite::read_json(record,simplifyVector=TRUE),error=function(e) NULL)
      path <- sub("\\.json$","",record)
      alive <- function(pid) {
        if(is.null(pid)) return(FALSE)
        if(!is.numeric(pid) || length(pid)!=1L || !is.finite(pid) || pid<1) return(TRUE)
        tryCatch(pid %in% ps::ps_pids(),error=function(e) TRUE)
      }
      if(!is.null(owner) && identical(owner$schema,"FGSTUDIO_MASK_JOB_1") &&
          !is.null(owner$owner_pid) && !alive(owner$owner_pid) &&
          ((!is.null(owner$worker_pid) && !alive(owner$worker_pid)) || !dir.exists(path)))
        discard_masks(key,path)
    }
    path <- file.path(folder,paste(format(openssl::rand_bytes(16)),collapse=""))
    jsonlite::write_json(list(schema="FGSTUDIO_MASK_JOB_1",owner_pid=Sys.getpid(),worker_pid=NULL),
      paste0(path,".json"),auto_unbox=TRUE,null="null")
    path
  }
  discard_masks <- function(key,directory) {
    if(is.null(directory)) return(invisible(NULL))
    stage <- as.character(fs::path_real(mask_folder(key,"staging")))
    target <- if(dir.exists(directory)) as.character(fs::path_real(directory)) else
      as.character(fs::path(as.character(fs::path_real(dirname(directory))),basename(directory)))
    if(!grepl("^[0-9a-f]{32}$",basename(target)) ||
        !identical(tolower(as.character(fs::path_dir(target))),tolower(stage)))
      stop("Invalid mask staging cleanup directory.")
    unlink(target,recursive=TRUE)
    unlink(paste0(target,".json"))
    invisible(NULL)
  }
  find_masks <- function(key,request) {
    folder <- mask_folder(key,"editions")
    paths <- list.dirs(folder,recursive=FALSE,full.names=TRUE)
    paths <- paths[order(file.info(paths)$mtime,decreasing=TRUE)]
    hash <- function(path) {con<-file(path,"rb");on.exit(close(con));unclass(as.character(openssl::sha256(con)))}
    expected <- lapply(request[c("context","selection","group")],hash)
    recipe <- NULL
    for(path in paths) {
      m <- tryCatch(jsonlite::read_json(file.path(path,"verified.json"),simplifyVector=TRUE),error=function(e) NULL)
      if(!is.null(m) && identical(m$schema,"EVENT_MASKS_1") && identical(m$stream_id,request$stream_id) &&
          identical(m$boundary_rule,"terra rasterize touches=FALSE (native cell-center rule)") &&
          (if(is.null(m$recipe_key)) identical(m$inputs,expected) else {
            if(is.null(recipe)) recipe <- do.call(fluvgeo::event_mask_key,request)
            identical(m$recipe_key,recipe)
          })) return(path)
    }
    NULL
  }
  publish_masks <- function(key,group_id,request,directory,manifest) {
    current <- mask_request(key,group_id,request$stream_id,request$context,request$selection,request$group)
    if(!identical(current,request)) stop("Mask setup changed.")
    stage <- mask_folder(key,"staging")
    id <- basename(directory)
    if(!grepl("^[0-9a-f]{32}$",id) || !identical(as.character(fs::path_real(dirname(directory))),as.character(fs::path_real(stage))) ||
        !startsWith(tolower(as.character(fs::path_real(directory))),paste0(tolower(as.character(fs::path_real(stage))),"/")))
      stop("Invalid mask staging directory.")
    saved <- jsonlite::read_json(file.path(directory,"verified.json"),simplifyVector=TRUE)
    hash <- function(path) { con <- file(path,"rb"); on.exit(close(con)); unclass(as.character(openssl::sha256(con))) }
    hashes <- lapply(request[c("context","selection","group")],hash)
    if(!identical(saved$schema,"EVENT_MASKS_1") || !identical(saved$inputs,hashes) ||
        !identical(saved$group_id,group_id) || !identical(saved$stream_id,request$stream_id) ||
        !identical(manifest$inputs,hashes)) stop("Verified masks do not match current inputs.")
    path <- file.path(mask_folder(key,"editions"),id)
    if(file.exists(path) || !file.rename(directory,path)) stop("Could not publish mask edition.")
    discard_masks(key,directory)
    list(path=path,manifest=manifest)
  }
  list(create = create, read = read, catalog = catalog, save_boundary = save_boundary,
    dem_destination=dem_destination,prepare_dem_download=prepare_dem_download,dem_download=dem_download,
    dem_files=dem_files,save_dem_files=save_dem_files,check_dem_files=check_dem_files,
    survey_collections=survey_collections,save_survey_collections=save_survey_collections,
    acquisition_groups=acquisition_groups,save_acquisition_group=save_acquisition_group,
    dem_preflight_request=dem_preflight_request,
    terrain_review=terrain_review,save_terrain_review=save_terrain_review,
    mask_request=mask_request,prepare_masks=prepare_masks,publish_masks=publish_masks,find_masks=find_masks,
    discard_masks=discard_masks,
    dem_download_history=dem_download_history,
    rename = rename, set_purpose = set_purpose, set_analysis_crs = set_analysis_crs,
    set_vertical_reference = set_vertical_reference, define_streams = define_streams,
    save_selected_boundary = save_selected_boundary, save_stream = save_stream,
    stream_segments = stream_segments, preview_reach = preview_reach, save_reach = save_reach,
    preview_reach_merge = preview_reach_merge, merge_reaches = merge_reaches,
    rename_feature = rename_feature,preview_reach_split=preview_reach_split,split_reach=split_reach)
}
