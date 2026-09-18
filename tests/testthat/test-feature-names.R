test_that("Stream and Reach rename preserve geometry, evidence and child identities", {
  store <- local_study_store(withr::local_tempdir()); study <- reach_test_study(store)
  sid <- study$stream_inventory$stream_id
  study <- store$save_reach(study$key,sid,"101","R1",study$path)
  study <- store$save_reach(study$key,sid,"102","R2",study$path)
  rid <- study$reach_inventory$reach_id[1]
  files <- list.files(dirname(study$path),full.names=TRUE)
  hashes <- tools::md5sum(files)
  renamed <- store$rename_feature(study$key,"stream",sid,"Renamed creek",study$path)
  expect_equal(renamed$stream_inventory$stream_name,"Renamed creek")
  expect_equal(sf::st_geometry(renamed$stream_inventory),sf::st_geometry(study$stream_inventory))
  expect_identical(renamed$reach_inventory,study$reach_inventory)
  renamed2 <- store$rename_feature(study$key,"reach",rid,"Lower reach",renamed$path)
  expect_equal(renamed2$reach_inventory$reach_name,c("Lower reach","R2"))
  expect_identical(renamed2$reach_inventory$reach_id,study$reach_inventory$reach_id)
  expect_equal(sf::st_geometry(renamed2$reach_inventory),sf::st_geometry(study$reach_inventory))
  expect_identical(tools::md5sum(files),hashes)
  expect_equal(store$rename_feature(study$key,"reach",rid,"Lower reach",renamed2$path)$path,renamed2$path)
  expect_error(store$rename_feature(study$key,"reach",rid,"r2",renamed2$path),"already exists")
  expect_error(store$rename_feature(study$key,"reach",rid,"",renamed2$path))
  expect_error(store$rename_feature(study$key,"reach","forged","New",renamed2$path),"existing identity")
  expect_error(store$rename_feature(study$key,"reach",rid,"New",study$path),"newer revision")
  # Renaming does not invalidate geometry evidence or prevent a later merge.
  view <- store$preview_reach_merge(study$key,renamed2$reach_inventory$reach_id,rid,renamed2$path)
  expect_equal(view$retain_reach_id,rid)
})

test_that("rename modal requires explicit save and reports duplicate names", {
  store <- local_study_store(withr::local_tempdir()); study <- reach_test_study(store)
  sid <- study$stream_inventory$stream_id
  study <- store$save_reach(study$key,sid,"101","R1",study$path)
  study <- store$save_reach(study$key,sid,"102","R2",study$path)
  rid <- study$reach_inventory$reach_id[1]
  shiny::testServer(mod_study_server,args=list(store=store),{
    session$flushReact(); current(study); session$flushReact()
    session$setInputs(rename_reach=1,feature_name_id=rid)
    expect_false(is.null(feature_names$target()))
    expect_match(output$feature_name_field$html,"R1")
    session$setInputs(feature_new_name="Lower")
    expect_equal(current()$path,study$path)
    session$setInputs(save_feature_name=1)
    expect_equal(current()$reach_inventory$reach_name[1],"Lower")
    session$setInputs(rename_reach=2,feature_name_id=rid,feature_new_name="R2",save_feature_name=2)
    expect_match(feature_names$problem(),"already exists")
    expect_equal(current()$reach_inventory$reach_name[1],"Lower")
  })
})
