# Immutable local draft sets. The standard feature-table name is cross_section;
# run parameters and lineage are table metadata, never encoded in that name.
study_cross_section_store <- function(context_path,current_group_path=NULL) {
  hash <- function(path) {
    con <- file(path,"rb");on.exit(close(con))
    unclass(as.character(openssl::sha256(con)))
  }
  fingerprint <- function(context,points,reach_id) {
    path <- file.path(points$path,points$files$geopackage)
    if(!file.exists(path)) stop("The saved Flowline Points input is unavailable.")
    list(schema="FGSTUDIO_CROSS_SECTION_INPUTS_5",method="polygon-centerline-v6",study=context$key,
      context_file=basename(context$path),context_sha256=hash(context$path),event=context$group_id,
      event_file=basename(context$group_path),event_sha256=hash(context$group_path),reach_id=as.character(reach_id),
      points_revision=basename(points$path),points_sha256=hash(path),points_inputs=points$inputs)
  }
  root <- function(context) file.path(dirname(context$path),"cross-sections")
  rem_request <- function(context,points,reach_id) {
    inputs<-fingerprint(context,points,reach_id)
    inputs$schema<-"FGSTUDIO_CROSS_SECTION_REM_INPUTS_1";inputs$method<-NULL
    recipe<-list(method="fluvgeo::detrend",buffer_distance=150,rem_reference=100,
      fluvgeo=as.character(utils::packageVersion("fluvgeo")),
      display_max_cells=250000,display_crs="EPSG:3857")
    key<-as.character(openssl::sha256(serialize(list(inputs,recipe),NULL,version=3)))
    list(key=key,inputs=inputs,recipe=recipe,
      directory=file.path(dirname(context$path),"cross-section-preparation",key))
  }
  read <- function(context,points,reach_id,settings=NULL) {
    expected <- fingerprint(context,points,reach_id)
    directories <- list.dirs(root(context),recursive=FALSE,full.names=TRUE)
    directories <- directories[!file.exists(file.path(directories,"PENDING"))]
    directories <- directories[order(file.info(directories)$mtime,decreasing=TRUE)]
    for(directory in directories) {
      result <- tryCatch(readRDS(file.path(directory,"result.rds")),error=function(e)NULL)
      if(is.null(result) || !identical(result$inputs,expected) ||
          (!is.null(settings) && !identical(result$settings,settings))) next
      path <- file.path(directory,"cross-sections.gpkg")
      if(!file.exists(path) || !identical(hash(path),result$output_sha256))
        stop("The saved cross-section draft is incomplete or changed.")
      result$sections <- sf::st_read(path,"cross_section",quiet=TRUE)
      fluvgeo::check_cross_section_layout(result$sections,profile="candidate_table")
      result$path <- directory
      return(result)
    }
    NULL
  }
  publish <- function(context,points,reach_id,settings,candidate,footprints,expected_inputs) {
    if(!identical(candidate$parameters$method,expected_inputs$method))
      stop("Layout method does not match the current input contract; regenerate the layout.")
    if(!is.null(candidate$boundary_anchors)) {
      if(anyNA(candidate$boundary_anchors$candidate_id) ||
          any(!candidate$boundary_anchors$candidate_id %in% candidate$sections$candidate_id))
        stop("Boundary anchors must reference current candidate identities.")
      candidate$boundary_anchors$Seq <- candidate$sections$Seq[
        match(candidate$boundary_anchors$candidate_id,candidate$sections$candidate_id)]
    }
    if(!identical(context_path(context$key),context$path) ||
        (!is.null(current_group_path) && !identical(current_group_path(context$key,context$group_id),context$group_path)) ||
        !identical(fingerprint(context,points,reach_id),expected_inputs))
      stop("Inputs changed; reopen Cross Sections before saving.")
    sections <- fluvgeo::cross_section_layout_review(candidate$sections,footprints$floodplain_outer,boundary_chains=candidate$boundary_chains)
    if(!nrow(sections)) stop("There are no cross sections to save.")
    sections$layout_spacing_m <- as.numeric(settings$spacing_m)
    # Retain the retired column as typed missing metadata, never repurpose it.
    sections$layout_direction_window_m <- NA_real_
    sections$layout_tangent_distance_m <- as.numeric(settings$tangent_distance_m)
    sections$layout_centerline_spacing_m <- as.numeric(candidate$parameters$centerline_spacing_m)
    sections$layout_smoothing_refinements <- as.integer(settings$smoothing_refinements)
    sections$layout_overbank_angle_limit_deg <- as.numeric(candidate$parameters$overbank_angle_limit_deg)
    sections$layout_allow_overbank_bends <- isTRUE(settings$allow_overbank_bends)
    sections$layout_width_mode <- "floodplain_extent"
    sections$channel_rem_elevation <- as.numeric(settings$channel)
    sections$floodplain_rem_elevation <- as.numeric(settings$floodplain)
    sections$rem_reference_elevation <- 100
    sections$rem_elevation_units <- "ft"
    sections$layout_method <- candidate$parameters$method
    fluvgeo::check_cross_section_layout(sections,profile="candidate_table")
    fs::dir_create(root(context))
    directory <- file.path(root(context),paste(format(openssl::rand_bytes(16)),collapse=""))
    if(!dir.create(directory)) stop("Cannot create cross-section draft storage.")
    pending <- file.path(directory,"PENDING");file.create(pending)
    complete <- FALSE
    on.exit(if(!complete)unlink(directory,recursive=TRUE),add=TRUE)
    path <- file.path(directory,"cross-sections.gpkg")
    sf::st_write(sections,path,"cross_section",quiet=TRUE)
    sf::st_write(footprints$channel_outer,path,"channel_outer",quiet=TRUE)
    sf::st_write(footprints$floodplain_outer,path,"floodplain_outer",quiet=TRUE)
    sf::st_write(candidate$region_polygons,path,"hydraulic_regions",quiet=TRUE)
    sf::st_write(candidate$regions,path,"region_components",quiet=TRUE)
    if(nrow(candidate$paths)) sf::st_write(candidate$paths,path,"centerline",quiet=TRUE)
    if(nrow(candidate$raw_centerlines))sf::st_write(candidate$raw_centerlines,path,"centerline_raw",quiet=TRUE)
    if(nrow(candidate$skeletons))sf::st_write(candidate$skeletons,path,"centerline_skeleton",quiet=TRUE)
    if(!is.null(candidate$boundary_chains) && nrow(candidate$boundary_chains))
      sf::st_write(candidate$boundary_chains,path,"boundary_chains",quiet=TRUE)
    if(!is.null(candidate$boundary_anchors) && nrow(candidate$boundary_anchors))
      sf::st_write(candidate$boundary_anchors,path,"boundary_anchors",quiet=TRUE)
    sf::st_write(candidate$region_diagnostics,path,"region_diagnostics",quiet=TRUE)
    if(!is.null(footprints$channel))sf::st_write(footprints$channel,path,"channel_inundation",quiet=TRUE)
    if(!is.null(footprints$floodplain))sf::st_write(footprints$floodplain,path,"floodplain_inundation",quiet=TRUE)
    sf::st_write(candidate$samples,path,"side_support",quiet=TRUE)
    metadata <- data.frame(schema="FGSTUDIO_CROSS_SECTION_DRAFT_5",
      review_state="draft",reach_id=as.character(reach_id),
      inputs_json=as.character(jsonlite::toJSON(expected_inputs,auto_unbox=TRUE,null="null",digits=NA)),
      settings_json=as.character(jsonlite::toJSON(settings,auto_unbox=TRUE,digits=NA)),
      parameters_json=as.character(jsonlite::toJSON(candidate$parameters,auto_unbox=TRUE,digits=NA)),
      software_json=as.character(jsonlite::toJSON(list(fgstudio=as.character(utils::packageVersion("fgstudio")),
        fluvgeo=as.character(utils::packageVersion("fluvgeo")),sf=as.character(utils::packageVersion("sf")),
        terra=as.character(utils::packageVersion("terra")),centerline=as.character(utils::packageVersion("centerline")),
        smoothr=as.character(utils::packageVersion("smoothr")),R=R.version.string),auto_unbox=TRUE)),
      created_at=format(Sys.time(),"%Y-%m-%dT%H:%M:%SZ",tz="UTC"))
    sf::st_write(metadata,path,"layout_metadata",quiet=TRUE)
    result <- list(schema=metadata$schema,inputs=expected_inputs,settings=settings,
      parameters=candidate$parameters,failures=candidate$failures,
      output_sha256=hash(path),review_state="draft",created_at=metadata$created_at)
    saveRDS(result,file.path(directory,"result.rds"))
    jsonlite::write_json(result,file.path(directory,"provenance.json"),auto_unbox=TRUE,
      pretty=TRUE,null="null",digits=NA)
    if(unlink(pending)!=0L)stop("Could not publish the cross-section draft.")
    complete <- TRUE
    result$sections <- sections;result$path <- directory
    result
  }
  reopen <- function(record) {
    path <- file.path(record$path,"cross-sections.gpkg")
    list(sections=record$sections,parameters=record$parameters,failures=record$failures,
      footprints=list(channel_outer=sf::st_read(path,"channel_outer",quiet=TRUE),
        floodplain_outer=sf::st_read(path,"floodplain_outer",quiet=TRUE)),
      paths=if("centerline" %in% sf::st_layers(path)$name)sf::st_read(path,"centerline",quiet=TRUE) else
        sf::st_sf(region=character(),side=character(),region_id=character(),smoothing_rejected=logical(),geometry=sf::st_sfc(crs=sf::st_crs(record$sections))),
      region_polygons=sf::st_read(path,"hydraulic_regions",quiet=TRUE),
      regions=sf::st_read(path,"region_components",quiet=TRUE),
      raw_centerlines=if("centerline_raw" %in% sf::st_layers(path)$name)sf::st_read(path,"centerline_raw",quiet=TRUE) else NULL,
      skeletons=if("centerline_skeleton" %in% sf::st_layers(path)$name)sf::st_read(path,"centerline_skeleton",quiet=TRUE) else NULL,
      boundary_chains=if("boundary_chains" %in% sf::st_layers(path)$name)sf::st_read(path,"boundary_chains",quiet=TRUE) else NULL,
      boundary_anchors=if("boundary_anchors" %in% sf::st_layers(path)$name)sf::st_read(path,"boundary_anchors",quiet=TRUE) else NULL,
      region_diagnostics=sf::st_read(path,"region_diagnostics",quiet=TRUE),
      samples=sf::st_read(path,"side_support",quiet=TRUE))
  }
  list(cross_section_inputs=fingerprint,cross_section_read=read,cross_section_rem_request=rem_request,
    cross_section_publish=publish,cross_section_reopen=reopen)
}
