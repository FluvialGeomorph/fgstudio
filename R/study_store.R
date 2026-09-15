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
    list(key = key, path = path,
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
    digest <- local({ con <- file(evidence, "rb"); on.exit(close(con)); as.character(openssl::sha256(con)) })
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
  save_stream <- function(key, lines, name, distance, unit, rationale, expected_path, stream_id = NULL) {
    revise(key, expected_path, lines = lines, stream_name = name, distance = distance,
      unit = unit, add_note = rationale, stream_id = stream_id,
      writer = fluvgeo::add_study_stream_corridor)
  }
  list(create = create, read = read, catalog = catalog, save_boundary = save_boundary,
    rename = rename, set_purpose = set_purpose, define_streams = define_streams,
    save_selected_boundary = save_selected_boundary, save_stream = save_stream)
}
