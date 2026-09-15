# Project plan

## Goal

Let a browser user define a study and progress to desktop-equivalent L1 analysis
with less installation and conceptual overhead. Work backward from the L1 Report;
reuse fluvgeo, identify actual gaps and design QGIS views alongside the new UI.

## Current slice

The owner saved one Stream each in two studies and now approved drainage
exploration to inform geographic scope before defining geometry. A map click
snaps to the nearest mapped stream; the user reviews it and retrieves reference
HUC12, basin and upstream/downstream channel alternatives. Shared methods live
in fluvgeo; fgstudio presents them without writing or assigning project records.
See [the current slice](../features/drainage-exploration.md).

Owner accepted discovery functionality and metadata. Current follow-up adds
lightweight matching NHDPlusV2 vector-tile guidance and actionable service-failure
feedback before the next review of adopting/combining candidate geometries.

## Next

Owner confirmed drawing and reopening two projects after refresh worked as expected.
The owner accepted compact map search and the define/update/search interface.
Current increment: explore and compare drainage candidates. Owner reviews the
working map, then guides adoption/combination into Study Area and Stream geometry.
Appending/editing saved Streams and the remaining Study Area boundary entry
methods remain future bounded increments, not implicit replacements of identity.
Do not automatically advance into terrain or L1 processing. The app is local-only;
Enterprise support remains a goal.
