reach_test_study <- function(store) {
  study <- store$create("Reach workflow")
  study <- store$save_boundary(study$key,stream_test_parent(),study$path)
  lines <- stream_test_context()$layers$upstream
  lines$source_id <- lines$nhdplus_comid
  store$save_stream(study$key,lines,"Creek",1000,"ft","Synthetic",study$path)
}
