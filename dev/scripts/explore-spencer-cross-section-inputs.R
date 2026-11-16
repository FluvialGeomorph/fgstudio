# Read-only, bounded Spencer Creek REM/inundation exploration.
# Usage: Rscript --vanilla dev/scripts/explore-spencer-cross-section-inputs.R
#        STUDY_DIRECTORY OUTPUT_DIRECTORY [CHANNEL_DEPTH_FT] [fill|retain] [R1|R3]
# This diagnostic does not create a production cross-section dataset.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L || length(args) > 5L) stop("Supply study and output directories, optional depth, hole policy and reach.")
root <- normalizePath(args[1], mustWork = TRUE)
out <- args[2]
if (!dir.exists(out)) dir.create(out, recursive = TRUE)
out <- normalizePath(out, mustWork = TRUE)
library(sf)
library(terra)
.libPaths(c(normalizePath("dev/local-library", mustWork = TRUE), .libPaths()))
flowfiles <- list.files(root, "^flowlines[.]gpkg$", recursive = TRUE, full.names = TRUE)
flowfile <- flowfiles[grepl("a93f60dd928012777f3a25c8a2881710", flowfiles, fixed = TRUE)]
pointfile <- file.path(root, "flowline-points", "a8bbdbb44b5d1dadd7b461222217662f", "flowline-points.gpkg")
demfiles <- list.files(root, "^hydro-dem[.]tif$", recursive = TRUE, full.names = TRUE)
demfile <- demfiles[grepl("b7387008b2a5029abcadeff3dc0815c4", demfiles, fixed = TRUE)]
if (length(flowfile) != 1L || length(demfile) != 1L || !file.exists(pointfile))
  stop("Expected saved Spencer inputs were not found uniquely.")
flow <- st_read(flowfile, "reach_flowlines", quiet = TRUE)
reach_name <- if (length(args) >= 5L) args[5] else "R1"
if (!reach_name %in% c("R1", "R3")) stop("Choose R1 or R3.")
reach <- flow[flow$ReachName == reach_name, ]
pts <- st_read(pointfile, "flowline_points", quiet = TRUE)
if (nrow(reach) != 1L) stop("Reach input is incomplete.")
reach_origin <- min(pts$km_to_mouth[pts$reach_id == reach$reach_id[1]]) * 1000
if (reach_name == "R1") {
  pts <- pts[pts$reach_id == reach$reach_id[1] & pts$distance_from_reach_downstream_m <= 500, ]
  flow <- st_set_geometry(reach, lwgeom::st_linesubstring(st_geometry(reach), 0,
    min(1, 500 / as.numeric(st_length(reach)))))
} else {
  # Use 200 m of the preceding reach for real downstream context.
  prior <- flow[flow$ReachName == "R2", ]
  prior_length <- as.numeric(st_length(prior))
  a <- lwgeom::st_linesubstring(st_geometry(prior), max(0, 1 - 200 / prior_length), 1)
  b <- lwgeom::st_linesubstring(st_geometry(reach), 0, min(1, 700 / as.numeric(st_length(reach))))
  ca <- st_coordinates(a)[, 1:2, drop = FALSE]; cb <- st_coordinates(b)[, 1:2, drop = FALSE]
  if (sqrt(sum((ca[nrow(ca), ] - cb[1, ])^2)) > 0.01) stop("Adjacent reach endpoints do not coincide.")
  flow <- st_set_geometry(reach, st_sfc(st_linestring(rbind(ca, cb[-1, , drop = FALSE])), crs = st_crs(reach)))
  pts <- pts[pts$stream_name == "Spencer Creek mainstem" &
    pts$km_to_mouth * 1000 >= reach_origin - 200 & pts$km_to_mouth * 1000 <= reach_origin + 700, ]
}
if (nrow(pts) < 10L) stop("Flowline point inputs are incomplete.")
dem <- rast(demfile)
prepared <- fluvgeo::detrend(dem, flow, pts, buffer_distance = 150)
# Test levels are exploratory values in feet above the established REM baseline.
channel_depth <- if (length(args) >= 3L) as.numeric(args[3]) else 1.5
hole_policy <- if (length(args) >= 4L) args[4] else "fill"
if (!is.finite(channel_depth) || channel_depth <= 0 || !hole_policy %in% c("fill", "retain"))
  stop("Channel depth must be positive and hole policy must be fill or retain.")
channel_level <- 100 + channel_depth
floodplain_level <- 100 + 2 * channel_depth
if (!is.finite(channel_level) || !is.finite(floodplain_level) ||
    channel_level >= floodplain_level)
  stop("Channel REM elevation must be less than floodplain REM elevation.")
channel <- fluvgeo::water_surface_poly(prepared$rem, channel_level, flow)
floodplain <- fluvgeo::water_surface_poly(prepared$rem, floodplain_level, flow)
raw_extent <- function(level) {
  x <- terra::ifel(prepared$rem <= level, 1, NA) |>
    terra::as.polygons() |>
    terra::disagg() |>
    sf::st_as_sf()
  x[lengths(sf::st_intersects(x, flow)) > 0, ]
}
raw_channel <- raw_extent(100 + channel_depth)
raw_floodplain <- raw_extent(100 + 2 * channel_depth)
# For layout use the outer footprint: fill interior holes in each selected
# polygon without joining disconnected components. Preserve the original
# extents separately for the nesting diagnostic.
fill_holes <- function(x) {
  polygons <- suppressWarnings(st_cast(st_geometry(x), "POLYGON"))
  filled <- st_sfc(lapply(polygons, function(p) st_polygon(list(p[[1]]))),
                   crs = st_crs(x))
  st_sf(geometry = filled)
}
raw_channel_layout <- if (hole_policy == "fill") fill_holes(raw_channel) else raw_channel
raw_floodplain_layout <- if (hole_policy == "fill") fill_holes(raw_floodplain) else raw_floodplain
# A cross-valley slice midpoint is an exploratory approximation to each side's
# corridor centerline, not a hydraulic flow calculation. Internal missing
# samples are interpolated below; outside observed support they remain missing.
coords <- st_coordinates(pts)
order_index <- order(pts$km_to_mouth)
coords <- coords[order_index, , drop = FALSE]
measures <- pts$km_to_mouth[order_index] * 1000 - reach_origin
sample_index <- unique(vapply(seq(30, min(470, max(measures) - 30), by = 20),
  function(m) which.min(abs(measures - m)), integer(1)))
interval <- function(line, polygon, origin, normal) {
  cut <- suppressWarnings(st_intersection(line, st_union(polygon)))
  if (!length(cut) || all(st_is_empty(cut))) return(NULL)
  if (any(st_geometry_type(cut) == "GEOMETRYCOLLECTION"))
    cut <- suppressWarnings(st_collection_extract(cut, "LINESTRING"))
  cut <- cut[st_geometry_type(cut) %in% c("LINESTRING", "MULTILINESTRING")]
  if (!length(cut)) return(NULL)
  pieces <- suppressWarnings(st_cast(cut, "LINESTRING"))
  candidates <- lapply(seq_along(pieces), function(i) {
    xy <- st_coordinates(pieces[i])[, 1:2, drop = FALSE]
    range(drop((xy - matrix(origin, nrow(xy), 2, byrow = TRUE)) %*% normal))
  })
  containing <- Filter(function(x) x[1] <= 0 && x[2] >= 0, candidates)
  if (length(containing) != 1L) return(NULL)
  containing[[1]]
}
samples <- lapply(sample_index, function(i) {
  before <- which.min(abs(measures - (measures[i] - 20)))
  after <- which.min(abs(measures - (measures[i] + 20)))
  direction <- coords[after, 1:2] - coords[before, 1:2]
  norm <- sqrt(sum(direction^2))
  if (!is.finite(norm) || norm == 0) return(NULL)
  normal <- c(-direction[2], direction[1]) / norm
  origin <- coords[i, 1:2]
  line <- st_sfc(st_linestring(rbind(origin - 200 * normal, origin + 200 * normal)), crs = st_crs(flow))
  ch <- interval(line, raw_channel_layout, origin, normal)
  fp <- interval(line, raw_floodplain_layout, origin, normal)
  if (is.null(ch) || is.null(fp)) return(NULL)
  sides <- lapply(1:2, function(side) {
    if ((side == 1 && fp[1] >= ch[1]) || (side == 2 && fp[2] <= ch[2])) return(NULL)
    origin + normal * ((fp[side] + ch[side]) / 2)
  })
  list(origin = origin, normal = normal, channel = ch, sides = sides)
})
side_points <- function(side) {
  xy <- lapply(samples, function(x) if (is.null(x)) NULL else x$sides[[side]])
  xy <- Filter(Negate(is.null), xy)
  if (!length(xy)) return(st_sfc(crs = st_crs(flow)))
  st_sfc(lapply(xy, st_point), crs = st_crs(flow))
}
side_a <- side_points(1); side_b <- side_points(2)
# Estimate local overbank tangents from neighboring slice midpoints. Interpolate
# only within observed support; missing end support is reported, not invented.
sample_m <- measures[sample_index]
side_matrix <- function(side) {
  m <- matrix(NA_real_, length(samples), 2)
  for (i in seq_along(samples)) {
    if (!is.null(samples[[i]]) && !is.null(samples[[i]]$sides[[side]]))
      m[i, ] <- samples[[i]]$sides[[side]]
  }
  for (axis in 1:2) {
    good <- which(is.finite(m[, axis]))
    if (length(good) >= 2L)
      m[, axis] <- approx(sample_m[good], m[good, axis], xout = sample_m,
                          rule = 1, ties = "ordered")$y
  }
  m
}
paths <- list(side_matrix(1), side_matrix(2))
outer_end <- function(bank, direction) {
  ray <- st_sfc(st_linestring(rbind(bank, bank + 250 * direction)), crs = st_crs(flow))
  cut <- interval(ray, raw_floodplain_layout, bank, direction)
  if (is.null(cut) || cut[2] <= 0.1 || cut[2] >= 249.9) return(NULL)
  bank + cut[2] * direction
}
candidate_indices <- seq(2, length(samples) - 1)
failure_reason <- rep(NA_character_, length(samples))
candidate <- lapply(candidate_indices, function(i) {
  sample <- samples[[i]]
  if (is.null(sample)) { failure_reason[i] <<- "no channel/floodplain interval"; return(NULL) }
  banks <- lapply(1:2, function(side)
    sample$origin + sample$channel[side] * sample$normal)
  ends <- lapply(1:2, function(side) {
    path <- paths[[side]]
    tangent <- path[i + 1, ] - path[i - 1, ]
    len <- sqrt(sum(tangent^2))
    if (!is.finite(len) || len <= 0) return(NULL)
    normal <- c(-tangent[2], tangent[1]) / len
    desired <- if (side == 1) -sample$normal else sample$normal
    if (sum(normal * desired) < 0) normal <- -normal
    outer_end(banks[[side]], normal)
  })
  if (any(vapply(ends, is.null, logical(1)))) {
    failed <- which(vapply(ends, is.null, logical(1)))
    failure_reason[i] <<- paste("overbank endpoint unavailable:", paste(c("left", "right")[failed], collapse = ", "))
    return(NULL)
  }
  xy <- rbind(ends[[1]], banks[[1]], banks[[2]], ends[[2]])
  # normal points right when looking downstream: the channel flowline is
  # directed upstream, so a positive end-to-start dot product is left-to-right.
  list(geometry = st_linestring(xy), seq = i - 1L, station_m = sample_m[i],
       oriented = sum((xy[4, ] - xy[1, ]) * sample$normal) > 0)
})
candidate <- Filter(Negate(is.null), candidate)
orientation_ok <- vapply(candidate, `[[`, logical(1), "oriented")
candidate_seq <- vapply(candidate, `[[`, integer(1), "seq")
candidate_station <- vapply(candidate, `[[`, numeric(1), "station_m")
candidate <- st_sfc(lapply(candidate, `[[`, "geometry"), crs = st_crs(flow))
conflicts <- if (length(candidate)) st_intersects(candidate) else list()
conflict_pairs <- sum(pmax(0, lengths(conflicts) - 1L)) / 2
# Experimental conservative resolver: shrink both overbank legs of involved
# sections simultaneously. It never alters the channel. Stop and report any
# unresolved collisions; shrinking can lose required floodplain coverage.
resolved <- candidate
iterations <- 0L
if (length(candidate)) for (iteration in seq_len(100L)) {
  hits <- st_intersects(resolved)
  affected <- which(lengths(hits) > 1L)
  if (!length(affected)) break
  updated <- lapply(seq_along(resolved), function(i) {
    xy <- st_coordinates(resolved[i])[, 1:2, drop = FALSE]
    if (i %in% affected) {
      for (pair in list(c(1L, 2L), c(4L, 3L))) {
        delta <- xy[pair[1], ] - xy[pair[2], ]
        len <- sqrt(sum(delta^2))
        if (len > 1) xy[pair[1], ] <- xy[pair[2], ] + delta * max(1 / len, .9)
      }
    }
    st_linestring(xy)
  })
  resolved <- st_sfc(updated, crs = st_crs(flow))
  iterations <- iteration
}
remaining_pairs <- if (length(resolved)) sum(pmax(0, lengths(st_intersects(resolved)) - 1L)) / 2 else 0
leg_lengths <- function(lines) {
  if (!length(lines)) return(matrix(numeric(), ncol = 2))
  t(vapply(seq_along(lines), function(i) {
    xy <- st_coordinates(lines[i])[, 1:2, drop = FALSE]
    c(sqrt(sum((xy[1, ] - xy[2, ])^2)), sqrt(sum((xy[4, ] - xy[3, ])^2)))
  }, numeric(2)))
}
before_lengths <- leg_lengths(candidate)
after_lengths <- leg_lengths(resolved)
ratios <- after_lengths / before_lengths
section_evidence <- do.call(rbind, lapply(seq_along(candidate), function(i) {
  before <- st_coordinates(candidate[i])[, 1:2, drop = FALSE]
  after <- st_coordinates(resolved[i])[, 1:2, drop = FALSE]
  k <- candidate_seq[i] + 1L
  tangent_left <- paths[[1]][k + 1, ] - paths[[1]][k - 1, ]
  tangent_right <- paths[[2]][k + 1, ] - paths[[2]][k - 1, ]
  data.frame(section = candidate_seq[i], station_m = candidate_station[i],
    left_original_m = before_lengths[i, 1], left_final_m = after_lengths[i, 1],
    right_original_m = before_lengths[i, 2], right_final_m = after_lengths[i, 2],
    left_path_dx = tangent_left[1], left_path_dy = tangent_left[2],
    right_path_dx = tangent_right[1], right_path_dy = tangent_right[2],
    left_end_x = before[1, 1], left_end_y = before[1, 2],
    left_bank_x = before[2, 1], left_bank_y = before[2, 2],
    right_bank_x = before[3, 1], right_bank_y = before[3, 2],
    right_end_x = before[4, 1], right_end_y = before[4, 2])
}))
writeRaster(prepared$rem, file.path(out, "rem.tif"), overwrite = TRUE)
st_write(flow, file.path(out, "inputs.gpkg"), layer = "flowline", quiet = TRUE, delete_layer = TRUE)
st_write(channel, file.path(out, "inputs.gpkg"), layer = "channel", quiet = TRUE, delete_layer = TRUE)
st_write(floodplain, file.path(out, "inputs.gpkg"), layer = "floodplain", quiet = TRUE, delete_layer = TRUE)
st_write(raw_channel_layout, file.path(out, "inputs.gpkg"), layer = "channel_outer_extent", quiet = TRUE, delete_layer = TRUE)
st_write(raw_floodplain_layout, file.path(out, "inputs.gpkg"), layer = "floodplain_outer_extent", quiet = TRUE, delete_layer = TRUE)
right_observed <- vapply(samples, function(x) !is.null(x) && !is.null(x$sides[[2]]), logical(1))
left_observed <- vapply(samples, function(x) !is.null(x) && !is.null(x$sides[[1]]), logical(1))
diagnostic <- data.frame(sample = seq_along(samples), station_m = sample_m,
  left_observed = left_observed, left_x = paths[[1]][, 1], left_y = paths[[1]][, 2],
  right_observed = right_observed, right_x = paths[[2]][, 1], right_y = paths[[2]][, 2],
  section_number = ifelse(seq_along(samples) %in% candidate_indices,
                          seq_along(samples) - 1L, NA_integer_))
diagnostic$section_created <- diagnostic$section_number %in% candidate_seq
diagnostic$failure_reason <- failure_reason
write.csv(diagnostic, file.path(out, "right-path-diagnostics.csv"), row.names = FALSE)
write.csv(section_evidence, file.path(out, "section-geometry-diagnostics.csv"), row.names = FALSE)
png(file.path(out, "inundation-review.png"), width = 1400, height = 1000, res = 140)
topo <- grDevices::colorRampPalette(c("cadetblue2", "khaki1", "chartreuse4",
  "goldenrod1", "orangered4", "saddlebrown", "gray70", "white"), space = "Lab")
plot(prepared$rem, col = topo(256), main = paste("Spencer Creek", reach_name, ": exploratory REM and inundation"))
plot(st_geometry(raw_floodplain_layout), add = TRUE, border = "#d66101", lwd = 2)
plot(st_geometry(raw_channel_layout), add = TRUE, border = "#0571b0", lwd = 2)
plot(st_geometry(flow), add = TRUE, col = "black", lwd = 2)
if (length(side_a)) plot(side_a, add = TRUE, col = "#d01c8b", pch = 16, cex = .6)
if (length(side_b)) plot(side_b, add = TRUE, col = "#4dac26", pch = 16, cex = .6)
for (side in 1:2) {
  xy <- paths[[side]]
  xy <- xy[stats::complete.cases(xy), , drop = FALSE]
  if (nrow(xy) >= 2) plot(st_sfc(st_linestring(xy), crs = st_crs(flow)),
                            add = TRUE, col = c("#d01c8b", "#4dac26")[side], lty = 2, lwd = 2)
}
if (length(resolved)) plot(resolved, add = TRUE, col = "white", lwd = 2)
if (length(resolved)) {
  centers <- t(vapply(candidate_seq + 1L, function(i) samples[[i]]$origin, numeric(2)))
  points(centers[, 1], centers[, 2], pch = 21, bg = "white", col = "black", cex = 1.5)
  text(centers[, 1], centers[, 2], labels = candidate_seq, cex = .65, font = 2)
}
title(sub = "Black: flowline | blue/orange: extents | dots: midpoints | white: candidate sections", cex.sub = .8)
dev.off()
cat("Channel polygons:", nrow(channel), "flood-prone polygons:", nrow(floodplain), "\n")
cat("Channel depth (feet):", channel_depth, "; hole policy:", hole_policy, "\n")
cat("Channel outside flood-prone area (square map units):",
    sum(as.numeric(st_area(st_difference(st_union(channel), st_union(floodplain))))), "\n")
cat("Unsmoothed channel outside flood-prone area (square map units):",
    sum(as.numeric(st_area(st_difference(st_union(raw_channel), st_union(raw_floodplain))))), "\n")
cat("Slice midpoint evidence: ", length(side_a), " / ", length(sample_index),
    " on side A; ", length(side_b), " / ", length(sample_index), " on side B.\n", sep = "")
cat("Candidate sections:", length(candidate), "of", length(candidate_indices),
    "; intersecting pairs:", conflict_pairs, "\n")
if (conflict_pairs > 0) for (i in seq_along(conflicts))
  for (j in conflicts[[i]][conflicts[[i]] > i])
    cat("Initial collision: sections", candidate_seq[i], "and", candidate_seq[j], "\n")
cat("Correct left-to-right orientations:", sum(orientation_ok), "of", length(orientation_ok), "\n")
cat("Experimental collision resolution iterations:", iterations,
    "; remaining intersecting pairs:", remaining_pairs, "\n")
if (length(ratios)) cat("Legs shortened:", sum(ratios < .999999),
  "; minimum retained leg fraction:", round(min(ratios), 3), "\n")
