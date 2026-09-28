# Read execution evidence only. A current Study setting or a saved transformation
# plan cannot establish what happened when an older DEM was produced.
terrain_dem_provenance_ui <- function(trial) {
  execution <- trial$execution
  source <- trial$result$source$internal_compound$wkt
  target <- trial$result$crs
  datum <- trial$result$datum_operation
  method <- trial$result$method
  text <- function(x) if(is.null(x) || !length(x) || is.na(x[1L]) || !nzchar(x[1L])) "Not recorded" else x[1L]
  reference <- function(wkt) {
    if(is.null(wkt) || !length(wkt) || is.na(wkt[1L]) || !nzchar(wkt[1L])) return("Not recorded")
    tryCatch(text(sf::st_crs(wkt)$Name),error=function(e) "Recorded definition could not be read")
  }
  item <- function(label,value) shiny::tagList(shiny::tags$dt(class="col-sm-3",label),
    shiny::tags$dd(class="col-sm-9",value))
  software <- unlist(execution$software)
  shiny::tags$details(class="mt-3",
    shiny::tags$summary(class="fw-semibold","Coordinate-operation provenance"),
    shiny::p(class="small mt-2",if(is.null(execution))
      "Evidence retained with this DEM. A complete execution record was not captured by its producer." else
      "Execution evidence recorded when this DEM was produced."),
    shiny::tags$dl(class="row small",
      item("Edition saved (UTC)",text(trial$saved_dem$created)),
      item("Execution completed (UTC)",text(execution$completed_at)),
      item("Input to elevation conversion",reference(source)),
      item("DEM coordinate system",reference(target)),
      item("Datum operation",if(identical(datum,"none")) "None (recorded by the producer)" else text(datum)),
      item("Elevation conversion",text(method)),
      item("Horizontal processing",text(trial$unmasked_result$method)),
      item("Selected PROJ pipeline",if(!is.null(execution) && identical(execution$implementation,"native_same_crs"))
        "Not used; native same-CRS processing and explicit elevation-unit conversion." else "Not recorded"),
      item("Backend version",text(if(is.null(execution)) trial$saved_dem$backend else execution$software$fluvgeo))),
    shiny::p(class="small text-body-secondary","Transformation plans are separate records and are not evidence that an operation ran."),
    shiny::tags$details(shiny::tags$summary("Software used"),
      if(!length(software)) shiny::p("Not recorded by this producer.") else
        shiny::tags$dl(class="row small mt-2",lapply(seq_along(software),function(i)
          item(sub("^geospatial\\.","",names(software)[i]),as.character(software[i]))))),
    shiny::tags$details(shiny::tags$summary("Recorded coordinate-system definitions"),
      shiny::p("Input to elevation conversion"),shiny::pre(style="white-space:pre-wrap",text(source)),
      shiny::p("DEM output"),shiny::pre(style="white-space:pre-wrap",text(target))))
}
