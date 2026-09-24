# Build a processing request from saved Study records, never from a raster fixture.
# Optional extent is a developer test window in the saved Event CRS.
terrain_dem_request <- function(store, current, context, reach_id = NULL, extent = NULL, stream_id = NULL) {
  if (is.null(current) || is.null(context)) return(NULL)
  if (is.null(reach_id) == is.null(stream_id)) stop("Configure one Reach or Stream target.")
  level <- if(is.null(reach_id)) "Stream" else "Reach"
  reach <- NULL
  if(level == "Reach") {
    reach <- current$reach_inventory[current$reach_inventory$reach_id == reach_id, , drop=FALSE]
    if (nrow(reach) != 1L) stop("The configured Reach is not in this Study.")
    stream_id <- reach$stream_id
    boundary <- reach
  } else {
    boundary <- current$stream_inventory[current$stream_inventory$stream_id == stream_id, , drop=FALSE]
    if(nrow(boundary)!=1L) stop("The configured Stream is not in this Study.")
  }
  if (!stream_id %in% context$streams$stream_id) return(NULL)
  target <- current$vertical_reference
  if (is.null(target) || !identical(target$crs_authority,"EPSG:8228"))
    stop("This DEM pipeline requires the saved NAVD88 international-foot target. Review Analysis.")
  selection <- terrain_dem_sources(store,current$key,context$group_id,stream_id,
    current$path,context$group_path)
  request <- store$mask_request(current$key,context$group_id,stream_id,current$path,
    store$survey_collections(current$key)$path,context$group_path)
  directory <- store$find_masks(current$key,request)
  if (is.null(directory)) return(NULL)
  manifest <- fluvgeo::read_event_masks(directory,verify=FALSE)
  target_id <- if(level == "Reach") reach_id else stream_id
  products <- Filter(function(p) identical(p$level,level) && identical(p$id,target_id),manifest$products)
  if (length(products)!=1L) stop(paste("The saved Event mask does not contain this",level))
  mask <- file.path(directory,products[[1]]$file)
  grid <- terra::rast(mask)
  settings <- store$acquisition_groups(current$key)$groups[[context$group_id]]$settings
  if (!isTRUE(all.equal(terra::res(grid),rep(settings$cell_size,2))))
    stop("The saved mask does not match Event cell spacing. Review Event Settings.")
  list(key=current$key,group_id=context$group_id,context_path=current$path,
    group_path=context$group_path,reach=reach,stream_id=stream_id,boundary=boundary,level=level,
    stream_name=current$stream_inventory$stream_name[match(stream_id,current$stream_inventory$stream_id)],
    event_label=paste0(settings$year,if(!is.na(settings$month)) sprintf("-%02d",settings$month) else " (month unknown)"),
    sources=unique(selection$path),source_selection=selection,use_saved_sources=TRUE,
    source_extent=if(is.null(extent)) as.vector(terra::ext(grid)) else extent,
    source_crs=current$analysis_crs$wkt,horizontal_unit=current$analysis_crs$unit,source_unit="metre",
    mask_file=mask,mask_original=mask,target_vertical=target,
    scope=paste0(tolower(level),if(!is.null(extent)) "_portion" else ""),
    unmasked_result=list(overlap="first"),stage="pending",seconds=0)
}
