# App-owned analyst review records. These never authorize raster processing.
terrain_review_binding <- function(request,preflight) {
  s <- preflight$sources
  if(!is.data.frame(s) || !nrow(s) ||
      !all(c("collection","file_id","sha256") %in% names(s)) ||
      anyNA(s[c("collection","file_id","sha256")]) ||
      any(!nzchar(s$file_id)) || any(!grepl("^[0-9a-f]{64}$",s$sha256)))
    stop("Resolve missing downloads or failed source checks, then run preflight again.")
  ids <- paste(s$collection,s$file_id,sep="/")
  if(anyDuplicated(ids)) stop("Source identities are not unique.")
  evidence <- list(request=request,inputs=preflight$inputs,
    source_selection_hashes=preflight$source_selection_hashes,
    sources=s[c("collection","file_id","sha256")])
  list(fingerprint=unclass(as.character(openssl::sha256(serialize(evidence,NULL,version=2)))),
    source_ids=ids,evidence=evidence)
}

terrain_review_rows <- function(binding,rows) {
  fields <- c("source_id","assessment","elevation_unit","evidence","prior_operations")
  if(!is.data.frame(rows) || !all(fields %in% names(rows)) ||
      anyNA(rows[fields]) || anyDuplicated(rows$source_id) ||
      !setequal(rows$source_id,binding$source_ids) || nrow(rows)!=length(binding$source_ids))
    stop("Review must contain every checked source exactly once.")
  rows <- rows[fields]
  if(any(!rows$assessment %in% c("unresolved","matches_target","conversion_required")) ||
      any(!rows$elevation_unit %in% c("unknown","metre","international_foot","us_survey_foot")))
    stop("Choose a supported assessment and elevation unit.")
  reviewed <- rows$assessment!="unresolved"
  if(any(reviewed & (!nzchar(trimws(rows$evidence)) | !nzchar(trimws(rows$prior_operations)))))
    stop("Reviewed sources need evidence and prior-operation history; state unknown when unresolved.")
  if(any(rows$assessment=="matches_target" & rows$elevation_unit=="unknown"))
    stop("Specify the source elevation unit before recording a target match.")
  rows
}

terrain_review_latest <- function(folder,binding) {
  files <- sort(list.files(folder,pattern="^review-[0-9]{6}-[0-9a-f]{32}\\.json$",full.names=TRUE),decreasing=TRUE)
  if(!length(files)) return(NULL)
  path <- files[1]
  if(!startsWith(tolower(as.character(fs::path_real(path))),
      paste0(tolower(as.character(fs::path_real(folder))),"/"))) stop("Review is outside study storage.")
  record <- jsonlite::read_json(path,simplifyVector=TRUE)
  if(!identical(record$schema,"FGSTUDIO_TERRAIN_REVIEW_1") ||
      !identical(record$processing_authorized,FALSE)) stop("Invalid source-review record.")
  current <- identical(record$fingerprint,binding$fingerprint)
  if(current) {
    record$rows <- terrain_review_rows(binding,record$rows)
    if(!record$overlap %in% c("first_valid","last_valid")) stop("Invalid saved overlap rule.")
  }
  list(path=path,record=record,current=current)
}

terrain_review_write <- function(folder,binding,rows,overlap,expected=NULL) {
  rows <- terrain_review_rows(binding,rows)
  if(length(overlap)!=1L || !overlap %in% c("first_valid","last_valid")) stop("Choose an overlap rule.")
  lock <- file.path(folder,".write-lock")
  if(!dir.create(lock,showWarnings=FALSE)) stop("Another review is being saved. Reload and retry.")
  on.exit(unlink(lock,recursive=TRUE),add=TRUE)
  latest <- terrain_review_latest(folder,binding)
  if(!identical(latest$path,expected)) stop("A newer review exists. Reload before saving.")
  revision <- if(is.null(latest)) 1L else as.integer(substr(basename(latest$path),8,13))+1L
  if(revision>999999L) stop("Review revision limit reached.")
  record <- list(schema="FGSTUDIO_TERRAIN_REVIEW_1",created_at=format(Sys.time(),tz="UTC",usetz=TRUE),
    fingerprint=binding$fingerprint,source_snapshot=binding$evidence,rows=rows,
    overlap=overlap,output_type="Float32",processing_authorized=FALSE)
  id <- paste(format(openssl::rand_bytes(16)),collapse="")
  staging <- file.path(folder,paste0("pending-",id,".json"))
  path <- file.path(folder,sprintf("review-%06d-%s.json",revision,id))
  jsonlite::write_json(record,staging,auto_unbox=TRUE,pretty=TRUE,na="null",digits=NA)
  if(!file.rename(staging,path)) stop("Could not save source review.")
  list(path=path,record=record,current=TRUE)
}

terrain_source_review_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(open=NA,shiny::tags$summary("Review DEM sources"),
    shiny::p("Review elevation references and prior conversions, then choose source priority. These decisions are saved for later DEM assembly."),
    shiny::uiOutput(ns("status")),shiny::uiOutput(ns("workspace")))
}

terrain_source_review_server <- function(id,context,store,pending=function() FALSE) {
  shiny::moduleServer(id,function(input,output,session) {
    rows <- shiny::reactiveVal(NULL); binding <- NULL; snapshot <- NULL; expected <- NULL
    overlap <- shiny::reactiveVal("first_valid"); dirty <- shiny::reactiveVal(FALSE)
    status <- shiny::reactiveVal("Run grid and source preflight above to begin or reopen a saved review.")
    editing <- NULL
    reload <- function() {
      rows(NULL);dirty(FALSE);binding <<- NULL;snapshot <<- NULL;expected <<- NULL
      editing <<- NULL;shiny::removeModal(session=session)
      x <- context()
      if(is.null(x)) {status("Run grid and source preflight above to begin or reopen a saved review.");return()}
      tryCatch({
        b <- terrain_review_binding(x$request,x$preflight)
        saved <- store$terrain_review(x$key,x$group_id,x$request$stream_id,b)
        binding <<- b;snapshot <<- x;expected <<- saved$path
        if(!is.null(saved) && isTRUE(saved$current)) {
          rows(saved$record$rows);overlap(saved$record$overlap)
          status("Saved review reopened for these checked sources. Review is not processing approval.")
        } else {
          rows(data.frame(source_id=b$source_ids,assessment="unresolved",elevation_unit="unknown",
            evidence="",prior_operations=""));overlap("first_valid")
          status(if(is.null(saved)) "Review each source and save your choices." else
            "The saved review refers to older inputs. Review these sources again; the old edition is retained.")
        }
      },error=function(e) status(conditionMessage(e)))
    }
    shiny::observeEvent(context(),reload(),ignoreNULL=FALSE)
    assert_current <- function() {
      if(pending()) stop("Save or cancel pending Event and acquisition edits first.")
      if(is.null(snapshot) || !identical(snapshot,context())) stop("Inputs changed. Run preflight again.")
    }
    source_titles <- function(ids) {
      vapply(ids,function(id) {
        title <- snapshot$preflight$observations[[id]]$title
        if(length(title)==1L && !is.na(title) && nzchar(title)) title else id
      },character(1),USE.NAMES=FALSE)
    }
    labels <- function(r) {
      s <- snapshot$preflight$sources
      stats::setNames(r$source_id,paste(seq_len(nrow(r)),source_titles(r$source_id),sep=". "))
    }
    output$workspace <- shiny::renderUI({
      r <- rows();if(is.null(r)) return(NULL)
      ns <- session$ns
      shiny::tagList(
        shiny::p(paste("Target vertical reference:",snapshot$target)),
        shiny::selectInput(ns("source"),"Source in priority order",choices=labels(r),selected=shiny::isolate(input$source)),
        shiny::div(class="d-flex flex-wrap gap-2 mb-2",
          shiny::actionButton(ns("edit"),"Review selected source",class="btn-outline-primary btn-sm"),
          shiny::actionButton(ns("earlier"),"Move earlier",class="btn-outline-secondary btn-sm"),
          shiny::actionButton(ns("later"),"Move later",class="btn-outline-secondary btn-sm")),
        compact_table(data.frame(Priority=seq_len(nrow(r)),Source=source_titles(r$source_id),
          Assessment=gsub("_"," ",r$assessment),Unit=gsub("_"," ",r$elevation_unit))),
        shiny::selectInput(ns("overlap"),"Where valid source cells overlap",choices=c(
          "Use the first valid source in this order"="first_valid",
          "Use the last valid source in this order"="last_valid"),selected=shiny::isolate(overlap())),
        shiny::p(class="small","NoData allows another source to supply a value. Cells are not averaged. Planned DEM storage: Float32."),
        shiny::actionButton(ns("save"),"Save source review and order",class="btn-primary btn-sm"),
        shiny::actionButton(ns("reload"),"Reload saved review",class="btn-outline-secondary btn-sm"),
        shiny::p(class="small","Mosaic creation is the next step. Source notes do not resolve metadata conflicts automatically or authorize vertical conversions."))
    })
    shiny::observeEvent(input$overlap,{
      if(!identical(input$overlap,overlap())) {overlap(input$overlap);dirty(TRUE)}
    },ignoreInit=TRUE)
    move <- function(delta) {
      tryCatch({
        assert_current();r <- rows();i <- match(input$source,r$source_id);j <- i+delta
        if(length(i)!=1L || is.na(i) || j<1L || j>nrow(r)) return()
        order <- seq_len(nrow(r));order[c(i,j)] <- order[c(j,i)]
        r <- r[order,,drop=FALSE];rownames(r) <- NULL;rows(r);dirty(TRUE)
        shiny::updateSelectInput(session,"source",selected=input$source)
      },error=function(e) status(conditionMessage(e)))
    }
    shiny::observeEvent(input$earlier,move(-1L),ignoreInit=TRUE)
    shiny::observeEvent(input$later,move(1L),ignoreInit=TRUE)
    shiny::observeEvent(input$edit,{
      tryCatch({
        assert_current();r <- rows();i <- match(input$source,r$source_id)
        if(length(i)!=1L || is.na(i)) stop("Choose a source.")
        editing <<- r$source_id[i];s <- snapshot$preflight$sources[match(editing,binding$source_ids),,drop=FALSE]
        observation <- snapshot$preflight$observations[[editing]]$observation$internal_compound
        ns <- session$ns
        shiny::showModal(shiny::modalDialog(title=paste("Review",source_titles(editing)),size="l",easyClose=FALSE,
          shiny::p(paste("Target:",snapshot$target)),
          shiny::p(paste("Observed band unit:",s$band_unit,"| Grid check:",s$grid_screen)),
          shiny::p(s$issues),
          shiny::tags$details(shiny::tags$summary("Embedded source CRS evidence"),shiny::tags$pre(observation$wkt)),
          shiny::selectInput(ns("assessment"),"Your assessment",choices=c("Unresolved / needs review"="unresolved",
            "Source already matches the target vertical reference"="matches_target",
            "A conversion is required"="conversion_required"),selected=r$assessment[i]),
          shiny::selectInput(ns("unit"),"Source elevation unit (not horizontal map unit)",choices=c(
            "Unknown"="unknown","Metres"="metre","International feet"="international_foot",
            "U.S. survey feet"="us_survey_foot"),selected=r$elevation_unit[i]),
          shiny::textAreaInput(ns("evidence"),"Reference evidence / document and rationale",value=r$evidence[i],width="100%"),
          shiny::textAreaInput(ns("prior"),"Prior elevation conversions (describe, none documented, or unknown)",
            value=r$prior_operations[i],width="100%"),shiny::uiOutput(ns("editor_status")),
          footer=shiny::tagList(shiny::actionButton(ns("discard"),"Cancel"),
            shiny::actionButton(ns("apply"),"Keep source assessment",class="btn-primary"))),session=session)
        output$editor_status <- shiny::renderUI(NULL)
      },error=function(e) status(conditionMessage(e)))
    },ignoreInit=TRUE)
    shiny::observeEvent(input$discard,{editing <<- NULL;shiny::removeModal(session=session)},ignoreInit=TRUE)
    shiny::observeEvent(input$apply,{
      tryCatch({
        assert_current();r <- rows();i <- match(editing,r$source_id)
        if(length(i)!=1L || is.na(i)) stop("Choose a source to review.")
        r$assessment[i] <- input$assessment;r$elevation_unit[i] <- input$unit
        r$evidence[i] <- trimws(input$evidence);r$prior_operations[i] <- trimws(input$prior)
        rows(terrain_review_rows(binding,r));dirty(TRUE);editing <<- NULL
        shiny::removeModal(session=session);status("Assessment kept in this draft. Save the review to retain it.")
      },error=function(e) {msg <- conditionMessage(e);output$editor_status <- shiny::renderUI(shiny::p(role="alert",msg))})
    },ignoreInit=TRUE)
    shiny::observeEvent(input$save,{
      tryCatch({
        assert_current()
        saved <- store$save_terrain_review(snapshot$key,snapshot$group_id,binding,rows(),overlap(),expected)
        expected <<- saved$path;dirty(FALSE);status("Source review and priority saved. Original rasters are unchanged.")
      },error=function(e) status(conditionMessage(e)))
    },ignoreInit=TRUE)
    shiny::observeEvent(input$reload,reload(),ignoreInit=TRUE)
    output$status <- shiny::renderUI(shiny::div(role="status",status(),if(dirty()) shiny::strong(" Unsaved review changes.")))
    list(rows=rows,dirty=dirty,status=status)
  })
}
