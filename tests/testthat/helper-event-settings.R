event_test_setup <- function() {
  store <- local_study_store(tempfile("event-store-"))
  x <- store$create("Event test")
  b <- sf::st_sf(geometry=sf::st_as_sfc(sf::st_bbox(c(xmin=-94,ymin=41,xmax=-93.9,ymax=41.1),crs=4326)))
  x <- store$save_boundary(x$key,b,x$path)
  x <- store$define_streams(x$key,c("First","Second"),"Test streams",x$path)
  x <- store$set_analysis_crs(x$key,26915,"Local test CRS","Test",x$path)
  rows <- sf::st_sf(candidate_key="USIEI:1",catalog="USIEI",record_id="1",snapshot_id="s",retrieved_at="2026-09-20",
    title="Acquisition",date_label="2020-02-01",status="Complete",availability="Unknown",
    metadata_url="https://example.org",access_url="Unknown",raw_metadata='{"collectiondate":"2020-02-01"}',
    coverage="Unknown",geometry=sf::st_geometry(x$boundary_sf))
  d <- list(study_area=x$boundary_sf,records=rows,searches=data.frame(catalog="USIEI",snapshot_id="s",outcome="COMPLETE"))
  selection <- store$save_survey_collections(x$key,d,"USIEI:1",x$path,NULL)
  list(store=store,x=x,selection=selection)
}

