# Local terrain transformation plans

`FGSTUDIO_TRANSFORM_PLAN_1` is an app-owned planning record associated with the
Study and its Survey Event. It is not a governed FGDB product or an executed
operation record. `execution_enabled` is FALSE. Selected-pipeline execution and
linking its verified execution evidence into DEM editions remain the next step.

`local_study_store()$transform_request()` resolves all assigned Streams' saved
source selections and receipts, deduplicates file paths, and reads the saved
horizontal/vertical targets and Study boundary. `terrain_transform_review_server()`
runs `fluvgeo::review_terrain_transformations()` in a background process. Changes
to context cancel discovery and start a fresh automatic reference check. The
controls remain hidden when no datum choice is needed. During discovery a brief
checking message provides feedback; failures show a compact
reference-check message with retry. Only pairs requiring a choice are displayed.
References are grouped by
full source definition, so the analyst need not choose separately for each tile.

The UI separates locally available candidates from unavailable operations and
does not preselect one. Each required pair must have an explicitly chosen
selectable candidate. Matching horizontal and vertical datums, including changes
of projection, raster grid or units, record `no_datum_change`, with their
explanation; no invented datum choice
is required. Saving records a plan, not authorization to run unimplemented
transformations. Previous same-CRS DEMs remain reusable independently of plans.

`study_transform_store()` persists immutable JSON revisions under
`terrain-transformations/<Event-key-hash>/plan-<revision>-<random-id>.json` in the
Study folder. Records retain creation time, actor NULL when unknown, request
fingerprint, Study/Event/source-selection bindings, complete backend review,
selected candidate payloads and the planning-only status. The backend review
contains full reference definitions, pipeline strings, area screening, accuracy,
epochs, grid metadata/checksums and software/database identity. Neither a display
name nor the ordinal position of a candidate is used as operation identity.

Before saving, the UI reruns candidate discovery in its worker, then the store
rebuilds the input request and compares the returned evidence. Direct store calls
without worker evidence rerun discovery themselves.
Changed references, input stamps, area, epochs, candidate definitions or resources
reject the save and require another review. A write lock plus expected latest
path prevents stale clients from overwriting a newer decision. Staging is renamed
only after complete JSON serialization. Earlier revisions remain intact. Opening
the review restores a choice only when both request and backend fingerprints
match. Path resolution guards keep storage inside the owning Study.

Source pixel hashes are not recomputed during this metadata-only review; input
paths/stamps, original reference observations and saved acquisition receipt links
bind the plan. Existing publication checks and stronger execution/resource
verification must be retained when the selected pipeline is integrated. No
automatic operation substitution is permitted. Complete coupled horizontal and
vertical pipelines must be executed in their recorded order.

Tests: `test-terrain-transform-review.R` covers explicit choice, unavailable
candidate rejection, restored selection, real Study reference requests, immutable
revision history, changed resources and stale-client saves. The owning scientific
contract is ADR 0009; backend catalog details live in fluvgeo's
`dev/schemas/terrain-transform-candidates.md`.
