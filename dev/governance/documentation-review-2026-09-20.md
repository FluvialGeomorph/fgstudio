# CRS documentation and persistence review

## Scope

Owner accepted the CRS layout and requested a documentation pass plus repairs to
vertical save feedback and apparent loss of both specifications after reload.
Changes are in the fgstudio working tree, version 0.0.0.9036, using the unchanged
isolated fluvgeo 2026.09.20.9044 backend. No release, deployment or scientific
transformation is implied. Existing unrelated changes remain uncommitted.

## Findings and repairs

- Vertical UI declared a message output but never rendered it. Both errors and
  confirmation now appear beside the buttons; success follows persisted reread
  and is associated with the saved revision.
- A fresh browser session had no current study. Create/Open now retain its opaque
  key in the tab URL, and reload reads the latest local revision once. Invalid
  keys cannot supply filesystem paths. New clears the key; independent fresh
  URLs remain empty. Unsaved forms, checks, tabs and previews are not restored.
- Horizontal reopening cleared the visible picker even when saved WKT existed.
  Both forms now display saved authority identifiers or WKT in definition mode.
- Read-only inspection found horizontal metadata in the existing study but no
  structured vertical target. Its exact failed-save cause cannot be reconstructed;
  no vertical choice is inferred or inserted into the user's data.

## Current capability boundary

| Implemented | Still needed before terrain processing |
| --- | --- |
| Planar horizontal CRS discovery, validation and immutable saved WKT | Qualified coordinate-epoch operations for dynamic horizontal frames |
| Study Area vertical target, units, epoch/evidence and intended-model metadata | Source-by-source reference reconciliation, explicit conversion/transform history and qualified exports |
| Local persistence, feedback and reload restoration | Survey Event membership and one explicit output cell size per Event |
| Original DEM acquisition, metadata and bounded tile inspection | Study Area grid anchor, hierarchical masks, joint preflight and Stream/Event mosaics |

README, lifecycle/CRS articles (now 02/08/09), agent routes, architecture, feature
records, project plan and the current checkpoint now distinguish these boundaries.
Historical verification sections remain dated. The owner has accepted the compact
CRS UI; automated browser acceptance of this repair is a separate unverified claim.
No new external geodesy guidance is asserted by this documentation pass.

## Verification

Fresh-adapter/session regression tests cover both saved references, displayed
definitions, URL replacement/clearing, preservation of unrelated query parameters,
invalid-key rejection and unchanged GeoPackage hashes. Focused editor tests cover
visible validation errors and persistent local save confirmation.

The full app suite passes 756 assertions, including 13 fresh-session/reload
assertions, and backend-function isolation checks pass. Only existing sf/Shiny
package build-version warnings remain. Local Markdown validation found no broken
targets (80 references in 64 maintained documents). Tests use synthetic studies;
the user's study was inspected read-only.

All nine developer articles and the local pkgdown site rebuilt. The code map
retains 68 nodes, 85 static edges and 19 reviewed bridges; freshness, direct/
indirect lookup and source-anchor checks pass. Rendered lifecycle and CRS articles
contain the revised persistence/feedback explanations. Browser automation still
cannot synchronize with the preview, so live browser verification is not claimed.
Logs: `dev/check-output/save-fixes-*` and `reload.log` (ignored local output).

The 9036 source package builds and checks with no errors and one existing
non-ASCII warning in R/mod_survey_collections.R. Vignettes rebuild successfully;
tests ran separately as the full suite above. The backend and shared library are
unchanged. Git whitespace validation passes with the repository's normal
line-ending settings.

The verified local preview launcher was restarted in a fresh R process. Port 8780
responds HTTP 200 with the revised reload guidance, and startup logs show only
the existing package build-version warnings. Existing study files were retained.
