# Initial Stream definition

Owner-directed next functional step after accepting Study Area define/update/search.
The app now exposes existing fluvgeo initial Stream definition, without inventing
a source-network selection or polygon-delineation rule.

## User path

Open a study; enter initial names one per line under **3. Define Streams**; add
optional selection context; save the complete initial inventory. The saved list
shows names and whether areas are recorded. Refresh/reopen retains Stream UUIDs
and their parent Study Area. Empty and duplicate names cannot publish.

No Study Area polygon, DEM or survey is required to name intended Streams.
The app records explicit user selection, not acceptance, watershed inference,
flowline geometry or complete L1 inputs. Stream areas, Reach divisions, append,
rename and removal need subsequent owner-guided increments. This limitation is
visible before the first save. Existing inventory/hierarchy is never replaced.

## Verification scope

Tests cover storage round trips, unique IDs and parent links, preserved Study Area
geometry/Purpose/notes and original files, stale/repeated saves, duplicate/empty
names, inactive modules, pending-boundary protection and same-study form retention.
Tests use synthetic names/geometries in temporary folders, not user projects.
Verification completed 2026-09-14: installed-package tests passed 183 assertions,
including 44 Stream-related assertions. R CMD check --no-manual: Status OK.
The existing Shiny/R build-version warning remains inside tests. Strict
reproducibleai context validation passed. The preview restarted at port 8780 and
returned HTTP 200; browser usability acceptance is pending owner review. No
customer study records were modified by the tests. Changes are uncommitted and
confined to fgstudio; fluvgeo 9020 was reused without edits or library updates.

Explicit reopening now resets editors even when the saved revision is unchanged,
matching the existing instruction for discarding unsaved work. Stream drafts are
retained for in-place same-study revisions but intentionally not explicit reopen.
