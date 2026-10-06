test_that("Flowline candidates are immutable and bound to exact inputs", {
  directory <- withr::local_tempdir()
  study <- file.path(directory,"study.gpkg");file.create(study)
  event <- file.path(directory,"event.rds");saveRDS(list(event="e"),event)
  hydro_path <- file.path(directory,"hydro");dir.create(hydro_path)
  network_path <- file.path(directory,"network");dir.create(network_path)
  network_file <- file.path(network_path,"stream-network.gpkg")
  network <- sf::st_sf(stream_line_id="n1",geometry=sf::st_sfc(
    sf::st_linestring(matrix(c(0,0,10,0),ncol=2,byrow=TRUE)),crs=26915))
  sf::st_write(network,network_file,quiet=TRUE)
  record <- list(id="hydro-1",key="study",event="event",stream="stream",
    source="source",context=study,path=hydro_path,
    result=list(output_sha256="hydro-sha",file="hydro-dem.tif"))
  current <- record
  candidate <- list(path=network_path,files=list(stream_network="stream-network.gpkg"))
  selection <- list(key="study",event="event",stream="stream",path=study,
    group=event)
  segments <- list(sha256=paste(rep("a",64),collapse=""),
    reach_mappings=data.frame(reach_id="reach",selection_id="100",source_id="100"))
  adapter <- study_flowline_store(function(key) study,function(...) current,
    function(record) candidate)
  raw <- network;stream <- network
  flowlines <- sf::st_sf(reach_id="reach",ReachName="Reach",reach_order=1L,
    length_m=10,geometry=sf::st_geometry(network))
  boundaries <- sf::st_sf(downstream_reach_id=character(),
    upstream_reach_id=character(),geometry=sf::st_sfc(crs=26915))

  saved <- adapter$flowline_publish(record,selection,segments,2,raw,stream,
    flowlines,boundaries,network)
  expect_identical(saved$schema,"FGSTUDIO_FLOWLINE_CANDIDATE_2")
  expect_equal(nrow(saved$flowlines),1L)
  expect_true(all(c("ReachName","from_measure","to_measure") %in%
    names(saved$flowlines)))
  expect_equal(saved$flowlines$from_measure,0)
  expect_equal(saved$flowlines$to_measure,.01)
  expect_true("flowline" %in% sf::st_layers(
    file.path(saved$path,saved$files$geopackage))$name)
  expect_identical(adapter$flowline_read(record,selection,segments,2)$reach_ids,"reach")
  expect_null(adapter$flowline_read(record,selection,segments,3))

  changed <- segments;changed$reach_mappings$reach_id <- "other"
  expect_null(adapter$flowline_read(record,selection,changed))
  expect_true(dir.exists(saved$path))
})
