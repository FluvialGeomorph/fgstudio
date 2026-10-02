test_that("candidate stream revisions remain bound to the exact Hydro DEM", {
  directory <- withr::local_tempdir()
  study <- file.path(directory,"study.gpkg");file.create(study)
  hydro_path <- file.path(directory,"hydro-revision");dir.create(hydro_path)
  record <- list(id="cutline-revision",key="study",event="event",stream="stream",
    source="dem-edition",context=study,path=hydro_path,
    result=list(output_sha256="hydro-sha",file="result/hydro-dem.tif"))
  current <- record
  adapter <- study_stream_network_store(function(key) study,
    function(...) current)

  stage <- adapter$stream_network_prepare(record)
  files <- list(routing="routing.tif",fill_depth="fill-depth.tif",
    direction="flow-direction.tif",accumulation="flow-accumulation.tif",
    fill_display="fill-changes-display.tif",stream_network="stream-network.gpkg")
  invisible(lapply(unlist(files),function(x) file.create(file.path(stage,x))))
  result <- list(schema="SYNTHETIC_STREAM_NETWORK_1",source_sha256="hydro-sha",
    threshold_ha=1,stream_lines=2,stream_length_m=10,changed_cells=3,files=files)
  outlet <- data.frame(cell=8,x=1,y=2,elevation=3)

  saved <- adapter$stream_network_publish(record,stage,result,outlet)
  expect_identical(saved$source_sha256,"hydro-sha")
  expect_identical(saved$app$hydro_cutline_revision,"cutline-revision")
  expect_identical(saved$outlet$cell,8)
  expect_identical(adapter$stream_network_read(record)$threshold_ha,1)

  changed <- record;changed$result$output_sha256 <- "different"
  expect_null(adapter$stream_network_read(changed))
})
