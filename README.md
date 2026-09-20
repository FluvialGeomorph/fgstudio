# FluvialGeomorph Studio

**FG Studio helps analysts turn a stream-study question into an explicit,
reusable study definition and a documented terrain foundation.** It is the
developing R Shiny browser client for FluvialGeomorph, which uses remotely sensed
terrain and shared R methods to characterize stream geometry.

The intended workflow connects Study Area, Stream and Reach definition with
survey selection, terrain development, Level 1 analysis and reviewable reports.
Today, the app implements the early study-definition and source-terrain steps.
Maps, guided choices and saved evidence make those steps accessible while
keeping consequential scientific decisions with the analyst.

## Find your starting point

| Your question | Start here |
| --- | --- |
| Why does this app exist, and how does it fit the project? | [FG Studio in FluvialGeomorph](vignettes/fgstudio.Rmd) |
| How do I define a study, obtain DEM tiles and record reference systems? | [Working with a Study Area](vignettes/guide-study-workflow.Rmd) |
| How do I trace behavior, diagnose a defect or extend the app? | [Application lifecycle](vignettes/dev-02-application-lifecycle.Rmd), then the relevant developer article |
| How are we testing better human and agent context routing? | [Code maps and dual-mode development](vignettes/dev-01-code-navigation.Rmd) |
| How do I launch an installed package from R? | `fgstudio::run_app(data_dir = "path/to/studio-data")` |

The analyst guide includes the development-workstation launch procedure and
storage details. The site also provides R API reference for the app entry points.

## A client within a shared scientific project

FG Studio owns browser interaction, workflow state and local storage orchestration.
**fluvgeo** owns reusable scientific methods, spatial validation and reporting.
Developing **QGIS** tools use that same backend through a desktop interface.
The established **ArcGIS toolbox** and **ohwm2** workflows remain separate clients;
FG Studio is an independent application and a working design path for the
open-source new-project workflow.

**FGDB** defines governed identities, relationships and eventual enterprise
persistence. The **User Manual** and **Technical Manual** provide project-wide
procedures and methods. The [project overview](vignettes/fgstudio.Rmd) explains
these relationships, the local GeoPackage/GeoTIFF direction, and why study
definition matters even when a project does not use FGDB.

## What you can do now

- Create and reopen a local Study Area; define its boundary, Streams and Reaches.
- Discover Survey Collections, record acquisition intent, select and download
  source DEM tiles, and inspect their metadata and terrain previews.
- Specify a planar horizontal analysis CRS and a separate vertical target,
  elevation units and optional epoch/model metadata.
- Retain saved revisions and source evidence as the study evolves.

The current release is a **trusted, single-analyst local development preview**.
Survey Event assembly, chosen Event cell sizes, aligned masks, Stream/Event DEM
mosaics and source-reference reconciliation are next parts of terrain development.
Level 1 execution, report delivery and FGDB access are not yet exposed by this app.
Saving a CRS specification does not transform elevations or establish data fitness.

## Documentation as part of development

This site serves analysts and maintainers. Its numbered developer articles explain
events, state, backend calls, persistence, failures and tests. Compact agent routes
and generated code maps point to the same source and contracts. Human developers
must be able to maintain the application without an agent or conversation history.

FG Studio is also a bounded testbed for improving that navigation. The first
paired pilot supported keeping concise routes and explanations, but did **not**
establish a speed or context-consumption improvement. The
[methods article](vignettes/dev-01-code-navigation.Rmd) describes the evidence,
limitations and how future comparisons should be judged. AI-assisted development
does not make AI services a requirement for using the application.

Build the local pkgdown site with `./dev/scripts/build-docs.ps1`, then open
`docs/index.html`. This builds documentation without publishing it or changing
saved studies. Repository contributors should also read `AGENTS.md` and
`dev/goals/project-plan.md` before changing a workflow.
