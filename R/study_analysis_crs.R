# Study-level CRS workflow; scientific validation lives in fluvgeo.
crs_selectize_options <- function() list(placeholder="Type a name or EPSG code",maxOptions=500,
  dropdownParent="body",
  onInitialize=I("function() {
    var control=this;
    control.$dropdown.css('z-index',2000);
    var closeOnScroll=function(event) {
      if(control.isOpen && !control.$dropdown[0].contains(event.target)) control.close();
    };
    document.addEventListener('scroll',closeOnScroll,true);
    var closeOnResize=function() { if(control.isOpen) control.close(); };
    window.addEventListener('resize',closeOnResize);
    var destroy=control.destroy;
    control.destroy=function() { document.removeEventListener('scroll',closeOnScroll,true); window.removeEventListener('resize',closeOnResize); return destroy.apply(control,arguments); };
  }"),
  onLoad=I("function() { if(this.isOpen) this.settings.onDropdownOpen.call(this); }"),
  onDropdownOpen=I("function() {
    var box=this.$control[0].getBoundingClientRect();
    var below=window.innerHeight-box.bottom-12, above=box.top-12;
    var upward=below<180 && above>below;
    var height=Math.max(40,Math.min(260,(upward?above:below)-12));
    this.$dropdown_content.css({'max-height':height+'px','overflow-y':'auto'});
    this.$dropdown.css('top', (window.scrollY+(upward?box.top-this.$dropdown.outerHeight():box.bottom))+'px');
  }"))

study_analysis_crs_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::p("Choose the planar horizontal CRS used by all analysis in this Study Area. Required before DEM mosaicking."),
    shiny::uiOutput(ns("status")),
    shiny::radioButtons(ns("mode"), "Choose a CRS", choices=c("Search applicable EPSG systems"="picker",
      "Advanced definition"="advanced"),selected="picker",inline=TRUE),
    shiny::conditionalPanel("input.mode == 'picker'",ns=ns,
      bslib::layout_columns(col_widths=c(3,9),
      shiny::selectInput(ns("unit"),"Horizontal units",choices=c("All units"="all")),
      shiny::selectizeInput(ns("candidate"),"Search by CRS name, datum or EPSG code",choices=c("Choose a CRS"=""),
        options=crs_selectize_options())),
      shiny::div(class="d-flex flex-wrap gap-4",
        shiny::checkboxInput(ns("partial"),"Include partial area coverage",FALSE),
        shiny::checkboxInput(ns("other"),"Include other mapping purposes",FALSE)),
      shiny::uiOutput(ns("candidate_details"))),
    shiny::conditionalPanel("input.mode == 'advanced'",ns=ns,
      shiny::p("Use an authoritative definition for a system outside the shortlist. Local validation is still required."),
      shiny::textAreaInput(ns("definition"), "EPSG code or projected WKT",rows=2)),
    shiny::div(class="d-flex flex-wrap gap-2 mb-2",
      shiny::actionButton(ns("validate"), "Check CRS", class = "btn-outline-primary btn-sm"),
      shiny::actionButton(ns("save"), "Save analysis CRS", class = "btn-primary btn-sm")),
    shiny::uiOutput(ns("review")),
    shiny::uiOutput(ns("message")),
    shiny::tags$details(class="small mt-2",shiny::tags$summary("Background, sources and modernization"),
      shiny::uiOutput(ns("resources"))))
}

study_analysis_crs_server <- function(id, current, store, on_saved, has_pending) {
  shiny::moduleServer(id, function(input, output, session) {
    checked <- shiny::reactiveVal(NULL)
    notice <- shiny::reactiveVal(NULL)
    saved_path <- shiny::reactiveVal(NULL)
    catalog <- shiny::reactiveVal(NULL)
    catalog_error <- shiny::reactiveVal(NULL)
    shown <- shiny::reactive({
      c <- catalog()
      if (is.null(c)) return(NULL)
      rows <- c$candidates
      if (!isTRUE(input$other)) rows <- rows[grepl("engineering|topographic",rows$scope,ignore.case=TRUE) |
        grepl(" / UTM zone ",rows$name,fixed=TRUE),,drop=FALSE]
      if (!isTRUE(input$partial)) rows <- rows[rows$coverage=="Full bounds",,drop=FALSE]
      if (!is.null(input$unit) && input$unit != "all") rows <- rows[rows$unit==input$unit,,drop=FALSE]
      rows
    })
    definition <- shiny::reactive({
      if (identical(input$mode,"advanced")) return(input$definition)
      rows <- shown()
      if (is.null(rows) || is.null(input$candidate) || !input$candidate %in% rows$code) return("")
      paste0("EPSG:",input$candidate)
    })
    shiny::observe({
      rows <- shown()
      choices <- c("Choose a CRS"="",if (!is.null(rows)) stats::setNames(rows$code,
        paste0("EPSG:",rows$code," - ",rows$name," [",rows$unit,"; ",rows$datum,"]")))
      old <- shiny::isolate(input$candidate)
      shiny::updateSelectizeInput(session,"candidate",choices=choices,
        selected=if (!is.null(old) && old %in% choices) old else "",server=TRUE)
    })
    shiny::observeEvent(current(), {
      checked(NULL); notice(NULL)
      x <- current()
      catalog(NULL); catalog_error(NULL)
      if (!is.null(x) && isTRUE(x$boundary)) tryCatch({
        catalog(fluvgeo::study_crs_candidates(x$boundary_sf))
      },error=function(e) catalog_error(conditionMessage(e)))
      units <- if (is.null(catalog())) character() else sort(unique(catalog()$candidates$unit))
      shiny::updateSelectInput(session,"unit",choices=c("All units"="all",stats::setNames(units,units)),selected="all")
      shiny::updateCheckboxInput(session,"partial",value=FALSE)
      shiny::updateCheckboxInput(session,"other",value=FALSE)
      shiny::updateSelectizeInput(session,"candidate",selected="")
      shiny::updateRadioButtons(session,"mode",selected=if (is.null(x$analysis_crs)) "picker" else "advanced")
      shiny::updateTextAreaInput(session, "definition", value = if (is.null(x$analysis_crs)) "" else
        if (length(x$analysis_crs$epsg)==1L && !is.na(x$analysis_crs$epsg)) paste0("EPSG:",x$analysis_crs$epsg) else x$analysis_crs$wkt)
    }, ignoreNULL = FALSE)
    output$resources <- shiny::renderUI({
      c <- catalog()
      link <- function(label,url) shiny::tags$a(label,href=url,target="_blank",rel="noopener noreferrer")
      shiny::tagList(
        shiny::p(link(if (is.null(c)) "Explore SpatialReference.org" else "Explore this Study Area on SpatialReference.org",
          if (is.null(c)) "https://spatialreference.org/explorer.html" else c$explorer_url),
          " | ",link("NGS NSRS modernization","https://www.ngs.noaa.gov/datums/newdatums/")),
        shiny::p("Selecting a horizontal CRS does not change elevation units or vertical datum. Epoch-dependent reference frames require a separate qualified workflow before they can be saved."),
        if (!is.null(catalog_error())) shiny::p(role="alert",catalog_error()),
        if (!is.null(c)) shiny::tags$details(shiny::tags$summary("Catalog and modernization availability"),
          shiny::p(paste(nrow(c$candidates),"locally installed projected EPSG systems overlap the Study Area;",
            sum(c$candidates$nsrs2022),"have NATRF2022 / related 2022 frame or SPCS2022 names.")),
          shiny::p("Catalog presence does not establish transformation accuracy, required grids, epoch support or official release status. No substitute is selected for an unavailable system."),
          shiny::p(paste("PROJ",unname(c$software["PROJ"]),"/ GDAL",unname(c$software["GDAL"]),
            "/ EPSG catalog",c$metadata$value[c$metadata$key=="EPSG.VERSION"],
            "dated",c$metadata$value[c$metadata$key=="EPSG.DATE"]))),
        shiny::p("The list screens area-of-use bounds, not engineering distortion. Partial coverage requires additional review; no system is selected automatically."))
    })
    output$candidate_details <- shiny::renderUI({
      rows <- shown()
      if (!is.null(rows) && !nrow(rows)) return(shiny::p("No systems match these filters. Review other mapping purposes, partial coverage, or an authoritative advanced definition."))
      if (is.null(rows) || is.null(input$candidate) || !input$candidate %in% rows$code) return(NULL)
      row <- rows[match(input$candidate,rows$code),]
      shiny::tagList(shiny::p(class="small mb-2",paste(row$datum,"|",row$unit,"|",row$coverage)),
        if (row$epoch_required) shiny::p(role="alert","Explore only: coordinate-epoch handling is required and is not yet implemented for saving this frame."),
        shiny::tags$details(class="small mb-2",shiny::tags$summary("CRS details and reference"),
        compact_table(data.frame(Item=c("Datum / frame","Horizontal unit","Projection","Area of use","Coverage","Scope","Frame reference epoch"),
        Value=c(row$datum,row$unit,row$method,row$area,row$coverage,row$scope,
          if (is.na(row$frame_epoch)) "Not specified by this catalog entry" else as.character(row$frame_epoch)))),
        shiny::tags$a("View this CRS on SpatialReference.org",href=row$url,target="_blank",rel="noopener noreferrer")))
    })
    output$status <- shiny::renderUI({
      x <- current()
      if (is.null(x)) return(shiny::p("Open a Study Area first."))
      if (is.null(x$analysis_crs)) return(shiny::p("Analysis CRS has not been defined and validated."))
      shiny::p(paste("Saved:", x$analysis_crs$name, "- horizontal units:", x$analysis_crs$unit))
    })
    shiny::observeEvent(input$validate, {
      checked(NULL); notice(NULL)
      x <- current()
      if (is.null(x) || !isTRUE(x$boundary)) { notice("Save the Study Area boundary first."); return() }
      tryCatch({
        if (is.null(definition()) || !nzchar(trimws(definition()))) stop("Choose a CRS from the list or enter an advanced definition.")
        choice <- fluvgeo::validate_study_analysis_crs(definition(), x$boundary_sf)
        checked(list(choice = choice, definition = definition(), path = x$path, mode=input$mode))
      }, error = function(e) notice(conditionMessage(e)))
    }, ignoreInit = TRUE)
    output$review <- shiny::renderUI({
      v <- checked(); x <- current()
      if (is.null(v) || is.null(x) || !identical(v$definition, definition()) || !identical(v$mode,input$mode) || !identical(v$path, x$path)) return(NULL)
      shiny::tagList(shiny::p(paste(v$choice$name, "- horizontal units:", v$choice$unit)),
        shiny::p("The saved boundary transforms successfully. Confirm this projection is appropriate for your analysis area. Elevation units and vertical datum are unchanged."))
    })
    shiny::observeEvent(input$save, {
      x <- current(); v <- checked()
      if (is.null(x) || is.null(v) || !identical(v$definition, definition()) || !identical(v$mode,input$mode) || !identical(v$path, x$path)) {
        notice("Check the current CRS before saving."); return()
      }
      if (has_pending()) { notice("Save or discard pending geometry and acquisition edits before saving the analysis CRS."); return() }
      tryCatch({
        evidence <- "User selected this horizontal analysis CRS in FG Studio. Projected 2D definition and complete boundary transformation checked; engineering distortion is not certified. No vertical conversion performed."
        if (identical(input$mode,"picker")) {
          c <- catalog(); row <- shown()[match(input$candidate,shown()$code),]
          evidence <- paste(evidence,paste0("Selected EPSG:",row$code," from local EPSG catalog ",
            c$metadata$value[c$metadata$key=="EPSG.VERSION"]," (",c$metadata$value[c$metadata$key=="EPSG.DATE"],
            "); PROJ ",unname(c$software["PROJ"]),"; coverage screen: ",row$coverage,
            ". Reference: ",row$url,". No vertical conversion performed."),sep="\n\n")
        }
        saved <- store$set_analysis_crs(x$key, v$choice$wkt, evidence,
          "FG Studio user action (identity not collected)", x$path)
        on_saved(saved)
        saved_path(saved$path)
      }, error = function(e) notice("CRS could not be saved. Reopen the study and check the CRS again; existing revisions were retained."))
    }, ignoreInit = TRUE)
    output$message <- shiny::renderUI({
      if (!is.null(notice())) return(shiny::div(class="alert alert-warning",role="alert",notice()))
      if (!is.null(saved_path()) && identical(saved_path(),current()$path))
        shiny::div(class="alert alert-success",role="status","Analysis CRS saved to local storage. Earlier revisions were retained.")
    })
  })
}
