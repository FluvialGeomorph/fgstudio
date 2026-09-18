# No writes to retained studies: preview cuts at a retained line midpoint.
.libPaths(c(normalizePath("dev/local-library"),.libPaths()))
pkgload::load_all(".",quiet=TRUE)
root <- ".local-data"
files <- list.files(root,recursive=TRUE,full.names=TRUE)
hashes <- tools::md5sum(files)
store <- local_study_store(root)
passed <- 0L; blocked <- character()
for (key in unname(store$catalog()$choices)) {
  study <- store$read(key)
  if (!inherits(study$reach_inventory,"sf")) next
  for (sid in unique(study$reach_inventory$stream_id)) {
    source <- store$stream_segments(key,sid,study$path)
    for (rid in study$reach_inventory$reach_id[study$reach_inventory$stream_id==sid]) {
      outcome <- tryCatch({
        ids <- source$reach_mappings$selection_id[source$reach_mappings$reach_id==rid]
        g <- sf::st_line_merge(sf::st_cast(sf::st_geometry(source$lines[match(ids[1],source$lines$selection_id),]),"MULTILINESTRING"),directed=TRUE)
        p <- sf::st_line_interpolate(g,.5,normalized=TRUE)
        view <- store$preview_reach_split(key,rid,p,"downstream",study$path)
        stopifnot(nrow(view$areas)==2L,view$source$distance_m==source$distance_m,
          all(view$lengths_m>0))
        TRUE
      },error=function(e) conditionMessage(e))
      if (isTRUE(outcome)) passed <- passed+1L else blocked <- c(blocked,outcome)
    }
  }
}
stopifnot(identical(files,list.files(root,recursive=TRUE,full.names=TRUE)),
  identical(hashes,tools::md5sum(files)))
cat("Read-only split previews:",passed,"passed;",length(blocked),"blocked. Study files unchanged.\n")
if (length(blocked)) print(table(blocked))
