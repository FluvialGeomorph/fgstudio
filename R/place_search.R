# Navigation only: never infer a boundary or persist geocoder results as science.
photon_places <- function(body) {
  empty <- data.frame(label = character(), lon = numeric(), lat = numeric())
  if (!is.list(body) || !identical(body$type, "FeatureCollection") ||
      !is.list(body$features)) stop("Invalid place search response.", call. = FALSE)
  rows <- lapply(utils::head(body$features, 5L), function(feature) {
    xy <- unlist(feature$geometry$coordinates, use.names = FALSE)
    if (!identical(feature$geometry$type, "Point") || !is.numeric(xy) ||
        length(xy) != 2L || any(!is.finite(xy)) || abs(xy[1]) > 180 || abs(xy[2]) > 90)
      return(NULL)
    p <- feature$properties
    parts <- unlist(p[c("name", "street", "city", "county", "state", "country")], use.names = FALSE)
    parts <- unique(parts[!is.na(parts) & nzchar(parts)])
    if (!length(parts)) return(NULL)
    data.frame(label = paste(parts, collapse = ", "), lon = xy[1], lat = xy[2])
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows)) do.call(rbind, rows) else empty
}

# Shared, bounded in-memory cache and rate guard for this single-process preview.
search_places <- local({
  cache <- list()
  last_request <- -Inf
  function(query) {
    if (!is.character(query) || length(query) != 1L || is.na(query) ||
        nchar(trimws(query)) < 3L || nchar(query) > 200L)
      stop("Enter a place and state (3 to 200 characters).", call. = FALSE)
    query <- trimws(query)
    endpoint <- getOption("fgstudio.photon_url", "https://photon.komoot.io/api/")
    key <- paste(endpoint, tolower(query), sep = "\n")
    if (!is.null(cache[[key]])) return(cache[[key]])
    now <- unname(proc.time()[["elapsed"]])
    if (now - last_request < 1) stop("Please wait a moment before searching again.", call. = FALSE)
    last_request <<- now
    result <- tryCatch({
      response <- httr2::request(endpoint) |>
        httr2::req_url_query(q = query, limit = 5, lang = "en") |>
        httr2::req_user_agent("fgstudio (https://github.com/FluvialGeomorph/fgstudio)") |>
        httr2::req_timeout(10) |>
        httr2::req_perform()
      photon_places(httr2::resp_body_json(response))
    }, error = function(e) stop("Place search is unavailable. Try again later or zoom the map manually.", call. = FALSE))
    if (length(cache) >= 100L) cache <<- cache[-1L]
    cache[[key]] <<- result
    result
  }
})
