study_vertical_reference_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::p("Specify the Study Area's intended vertical reference. Saving metadata does not convert elevations or certify source DEM compatibility."),
    shiny::uiOutput(ns("status")),
    bslib::layout_columns(col_widths=c(4,4,4),
      shiny::selectInput(ns("kind"),"Reference type",choices=c("Vertical height CRS"="vertical_crs",
        "Ellipsoidal height (3D geographic CRS)"="ellipsoidal","Declared / future reference"="declared",
        "Local reference"="local","Unknown"="unknown")),
      shiny::tagList(shiny::conditionalPanel("input.kind == 'vertical_crs' || input.kind == 'declared'",ns=ns,
        shiny::selectInput(ns("height_type"),"Height type",choices=c("Unknown"="unknown","Orthometric"="orthometric",
          "Normal"="normal","Tidal"="tidal","Ellipsoidal"="ellipsoidal","Local"="local","Other"="other"))),
        shiny::uiOutput(ns("fixed_height"))),
      shiny::selectInput(ns("elevation_unit"),"Target elevation unit",choices=c("Unknown"="unknown","Metres"="metre",
        "International feet"="international_foot","U.S. survey feet (legacy)"="us_survey_foot"))),
    shiny::conditionalPanel("input.kind == 'vertical_crs'",ns=ns,
      shiny::selectizeInput(ns("candidate"),"Search vertical EPSG systems",choices=c("Choose a reference"=""),options=crs_selectize_options()),
      shiny::div(class="d-flex flex-wrap gap-4",
        shiny::checkboxInput(ns("partial"),"Include partial area coverage",FALSE),
        shiny::checkboxInput(ns("advanced"),"Enter an authoritative definition",FALSE)),
      shiny::uiOutput(ns("catalog_note"))),
    shiny::conditionalPanel("input.kind != 'unknown' && (input.kind != 'vertical_crs' || input.advanced)",ns=ns,
      shiny::textAreaInput(ns("definition"),"EPSG / WKT for resolved references, or name for local / declared references",rows=2)),
    shiny::tags$details(class="mb-2",shiny::tags$summary("Coordinate epoch and intended model (optional)"),
      shiny::p(class="small","Coordinate epoch is when coordinates are valid, not the Survey Event acquisition date. Leave unknown when not established."),
      bslib::layout_columns(col_widths=c(4,8),
        shiny::selectInput(ns("epoch_status"),"Coordinate epoch",choices=c("Unknown"="unknown","Known"="known","Not applicable"="not_applicable")),
        shiny::conditionalPanel("input.epoch_status == 'known'",ns=ns,
          shiny::numericInput(ns("coordinate_epoch"),"Decimal year",value=NA_real_),
          shiny::textInput(ns("epoch_evidence"),"Epoch source / document reference"))),
      bslib::layout_columns(col_widths=c(4,3,5),
        shiny::textInput(ns("model_name"),"Intended model name"),shiny::textInput(ns("model_version"),"Version"),
        shiny::textInput(ns("model_reference"),"Model source / reference"))),
    shiny::div(class="d-flex flex-wrap gap-2 mb-2",
      shiny::actionButton(ns("check"),"Check specification",class="btn-outline-primary btn-sm"),
      shiny::actionButton(ns("save"),"Save vertical specification",class="btn-primary btn-sm")),
    shiny::uiOutput(ns("review")),shiny::uiOutput(ns("message")),
    shiny::tags$details(class="small",shiny::tags$summary("References and limitations"),
      shiny::p("Output elevation units are independent of horizontal units and of the CRS's native axis unit. No unit, datum or epoch conversion is performed here. Model entries describe an intended target, not a model already applied to source data."),
      shiny::p("Local, unknown and unresolved references remain unqualified. Ellipsoidal heights require a 3D geographic CRS. Future / unavailable datums can be recorded by name without inventing an EPSG code."),
      shiny::tags$a("NGS preparation guidance",href="https://www.ngs.noaa.gov/datums/newdatums/GetPrepared.shtml",target="_blank",rel="noopener noreferrer")))
}

study_vertical_reference_server <- function(id,current,store,on_saved,has_pending) {
  shiny::moduleServer(id,function(input,output,session) {
    unit_labels <- c(metre="metres",international_foot="international feet",us_survey_foot="U.S. survey feet",unknown="unknown units")
    status_labels <- c(INCOMPLETE_OR_UNQUALIFIED="Reference, height type or units still need qualification",
      EPOCH_WORKFLOW_REQUIRED="Epoch-dependent processing is not yet supported",
      SPECIFIED_NOT_TRANSFORMED="Target specified; no conversion performed")
    catalog <- shiny::reactiveVal(NULL); catalog_error <- shiny::reactiveVal(NULL)
    checked <- shiny::reactiveVal(NULL); notice <- shiny::reactiveVal(NULL)
    saved_path <- shiny::reactiveVal(NULL)
    shown <- shiny::reactive({
      rows <- catalog()
      if (!is.null(rows) && !isTRUE(input$partial)) rows <- rows[rows$coverage=="Full bounds",,drop=FALSE]
      rows
    })
    shiny::observe({
      rows <- shown(); old <- shiny::isolate(input$candidate)
      choices <- c("Choose a reference"="",if (!is.null(rows)) stats::setNames(rows$code,paste0("EPSG:",rows$code," - ",rows$name," [",rows$unit,"]")))
      shiny::updateSelectizeInput(session,"candidate",choices=choices,selected=if (!is.null(old) && old %in% choices) old else "",server=TRUE)
    })
    shiny::observeEvent(current(),{
      x <- current(); checked(NULL); notice(NULL); catalog(NULL); catalog_error(NULL)
      if (!is.null(x) && isTRUE(x$boundary)) tryCatch(catalog(fluvgeo::study_vertical_crs_candidates(x$boundary_sf)),error=function(e) catalog_error(conditionMessage(e)))
      v <- x$vertical_reference
      defaults <- list(kind="vertical_crs",height_type="unknown",elevation_unit="unknown",epoch_status="unknown")
      for (k in names(defaults)) shiny::updateSelectInput(session,k,selected=if (is.null(v)) defaults[[k]] else v[[k]])
      shiny::updateCheckboxInput(session,"partial",value=FALSE)
      shiny::updateCheckboxInput(session,"advanced",value=!is.null(v) && v$kind=="vertical_crs")
      shiny::updateSelectizeInput(session,"candidate",selected="")
      shiny::updateTextAreaInput(session,"definition",value=if (is.null(v) || v$kind=="unknown") "" else
        if (nzchar(v$crs_authority)) v$crs_authority else if (nzchar(v$crs_wkt)) v$crs_wkt else v$reference_name)
      shiny::updateNumericInput(session,"coordinate_epoch",value=if (is.null(v)) NA_real_ else v$coordinate_epoch)
      for (k in c("epoch_evidence","model_name","model_version","model_reference")) shiny::updateTextInput(session,k,value=if (is.null(v)) "" else v[[k]])
    },ignoreNULL=FALSE)
    shiny::observeEvent(input$kind,{
      if (input$kind %in% c("ellipsoidal","local","unknown")) shiny::updateSelectInput(session,"height_type",selected=input$kind)
    })
    parameters <- shiny::reactive({
      text <- function(x) if (is.null(x)) "" else x
      kind <- if (is.null(input$kind)) "vertical_crs" else input$kind
      definition <- text(input$definition)
      if (kind=="unknown") definition <- ""
      if (kind=="vertical_crs" && !isTRUE(input$advanced)) {
        rows <- shown()
        definition <- if (!is.null(rows) && length(input$candidate)==1L && input$candidate %in% rows$code) paste0("EPSG:",input$candidate) else ""
      }
      epoch <- if (is.null(input$epoch_status)) "unknown" else input$epoch_status
      list(kind=kind,definition=definition,
        height_type=if (kind %in% c("ellipsoidal","local","unknown")) kind else if (is.null(input$height_type)) "unknown" else input$height_type,
        elevation_unit=if (is.null(input$elevation_unit)) "unknown" else input$elevation_unit,
        epoch_status=epoch,coordinate_epoch=if (epoch=="known" && !is.null(input$coordinate_epoch)) input$coordinate_epoch else NA_real_,
        epoch_evidence=if (epoch=="known") text(input$epoch_evidence) else "",
        model_name=text(input$model_name),model_version=text(input$model_version),model_reference=text(input$model_reference))
    })
    output$status <- shiny::renderUI({
      x <- current(); v <- x$vertical_reference
      shiny::p(if (is.null(v)) "No structured vertical target has been saved. Legacy source declarations are retained separately." else
        paste("Saved target:",v$reference_name,"|",v$height_type,"|",unit_labels[v$elevation_unit],"|",status_labels[v$support_status]))
    })
    output$fixed_height <- shiny::renderUI({
      if (length(input$kind)==1L && input$kind %in% c("ellipsoidal","local","unknown"))
        shiny::p(shiny::strong("Height type: "),input$kind)
    })
    output$catalog_note <- shiny::renderUI({
      rows <- shown()
      if (!is.null(catalog_error())) return(shiny::p(role="alert",catalog_error()))
      row <- if (!is.null(rows)) rows[rows$code %in% input$candidate,,drop=FALSE] else NULL
      if (!is.null(row) && nrow(row)==1L) shiny::tagList(shiny::p(class="small",paste(row$datum,"|",row$coverage)," | ",
        shiny::tags$a("CRS reference",href=paste0("https://spatialreference.org/ref/epsg/",row$code,"/"),target="_blank",rel="noopener noreferrer")),
        shiny::tags$details(class="small mb-2",shiny::tags$summary("Area, scope and native CRS unit"),
          compact_table(data.frame(Item=c("Area of use","Scope","Native CRS axis unit"),Value=c(row$area,row$scope,row$unit)))))
      else shiny::p(class="small","Area-of-use bounds are a coarse screen, not a qualification of vertical transformations.")
    })
    shiny::observeEvent(input$check,{
      checked(NULL); notice(NULL); x <- current()
      if (is.null(x) || !isTRUE(x$boundary)) {notice("Save the Study Area boundary first.");return()}
      tryCatch({
        p <- parameters(); spec <- do.call(fluvgeo::validate_study_vertical_reference,p)
        checked(list(spec=spec,parameters=p,path=x$path))
      },error=function(e) notice(conditionMessage(e)))
    },ignoreInit=TRUE)
    valid_check <- shiny::reactive({v <- checked(); x <- current(); !is.null(v) && !is.null(x) && identical(v$path,x$path) && identical(v$parameters,parameters())})
    output$review <- shiny::renderUI({
      if (!valid_check()) return(NULL)
      v <- checked()$spec
      shiny::tagList(shiny::p(paste(v$reference_name,"|",v$height_type,"| target unit:",unit_labels[v$elevation_unit])),
        shiny::p(paste(status_labels[v$support_status],". Saving changes metadata only.")),
        shiny::tags$details(shiny::tags$summary("Epoch / unit details"),compact_table(data.frame(
          Item=c("Coordinate epoch status","Coordinate epoch","Frame reference epoch","Metres per target elevation unit"),
          Value=c(v$epoch_status,as.character(v$coordinate_epoch),as.character(v$frame_epoch),as.character(v$unit_to_metre))))))
    })
    shiny::observeEvent(input$save,{
      if (!valid_check()) {notice("Check the current vertical specification before saving.");return()}
      if (has_pending()) {notice("Save or discard pending geometry and acquisition edits first.");return()}
      tryCatch({
        x <- current()
        saved <- store$set_vertical_reference(x$key,checked()$spec,x$path)
        on_saved(saved)
        saved_path(saved$path)
      },
        error=function(e) notice(paste("Vertical specification was not saved:",conditionMessage(e))))
    },ignoreInit=TRUE)
    output$message <- shiny::renderUI({
      if (!is.null(notice())) return(shiny::div(class="alert alert-warning",role="alert",notice()))
      if (!is.null(saved_path()) && identical(saved_path(),current()$path))
        shiny::div(class="alert alert-success",role="status","Vertical specification saved to local storage. Elevations and source references are unchanged.")
    })
  })
}
