# Developer documentation and navigation

Owner-approved scope: FG Studio, 2026-09-19. See
[ADR 0006](../decisions/adr-0006-dual-mode-developer-documentation.md) for the
human/agent interchangeability requirement and the
[maintenance workflow](../workflows/developer-documentation.md) for regeneration.

## Delivered

Four sequential vignettes explain application/session/storage lifecycle,
discovery and Streams, Reach editing, and code navigation. pkgdown combines these
with the public function reference in a local site. The fourth article embeds
flow's native HTML diagrams; it does not rely on the workstation's failing
webshot PNG path. Documentation dependencies are Suggests, not runtime Imports.

Agent routes identify first source/test files and fluvgeo boundaries. The generated
JSON network records source hashes, static dependencies and separately labeled
reviewed indirect bridges. It is a bounded navigation index, not a complete
runtime or multi-repository graph. Reuse pkgdown's generated text access instead
of maintaining duplicate article prose for agents.

## Verified evaluation

With flow 0.2.0, pkgnet 0.6.1 and pkgdown 2.2.1, the local site and four articles
built. Both flow diagrams are embedded as HTML widgets. pkgnet identified 49
package-level functions and 63 static relationships; it did not identify the
list-held `split_reach` storage closure. Seven reviewed bridges cover selected
important indirect boundaries. Freshness, direct/indirect lookup, missing-input
and missing/ambiguous-anchor safeguards are checked by the development scripts.

Final verification: `R CMD build` and `R CMD check --no-manual`, including vignette
rebuilds, completed with **Status: OK**. The test suite reported 537 passes,
zero failures, two warnings and zero skips. Strict reproducibleai context
validation returned valid, with expected repository-owned seeded-content
warnings. Generated local HTML href checks passed after correcting the README
workflow link. No PDF manual build or browser visual acceptance is claimed.

The [navigation pilot](../governance/navigation-pilot-2026-09-19.md) found correct
core answers in both source-only and documentation-assisted runs. The latter
inspected more test evidence but did not demonstrate lower context cost or faster
work. It used routes/articles, not the graph. Small backend-test routing and
merge-guard clarifications were applied. No measured agent-context savings or
complete runtime coverage is claimed.
Browser visual acceptance remains a human review; successful rendering and link
checks are not that acceptance. No app behavior, saved studies, shared backend
installation, public hosting or upstream reproducibleai templates were changed.

## Maintenance boundary

Capability changes require paired article/route updates and regeneration of the
affected index. Human explanations must cover callbacks, state and persistence,
not merely list functions. Extend this series when the owner approves subsequent
capabilities; do not make a giant graph a substitute for comprehensible design.
