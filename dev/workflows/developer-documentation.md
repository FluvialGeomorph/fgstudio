# Developer documentation: paired human and agent maintenance

Trigger: a capability, call path, adapter, state transition or backend boundary
changes. Apply ADR 0006 with reproducibleai's narrow-artifact/proportionality rules.

## Maintained inputs

- `README.md`: concise project/audience landing page, rendered as the site home.
  The build derives ignored `pkgdown/index.md`, translating vignette source links
  to site article links. Edit README only; use the build helper to keep both current.
- `vignettes/fgstudio.Rmd`: project role, ecosystem responsibilities and current versus intended outcomes.
- `vignettes/guide-study-workflow.Rmd`: single maintained home for analyst procedures moved from README.

- `vignettes/dev-01-...` onward: human explanations, source/test routes and bounded flow diagrams.
- `_pkgdown.yml`: ordered article navigation and public API reference.
- `dev/architecture/agent-routes.md`: short task-to-source routing table.
- `dev/architecture/reviewed-call-bridges.json`: only important indirect connections
  missed by package-local static analysis, with verifiable source anchors.
- `R/`, tests and backend contracts: evidence of actual behavior, not generated prose.

## Procedure

1. Update the relevant article and route together. Extend an existing article for
   refinements; add the next numbered article for a new cohesive capability.
2. Explain callback/worker/writer boundaries and saved-output effects explicitly.
   If a human cannot trace them, simplify or discuss the design; do not hide it
   behind a larger graph. Avoid manually documenting every base-R dependency.
3. Use `pkgdown::build_site()` in a fresh R session with the isolated backend
   library and workstation R/Pandoc configuration. It provides temporary package
   installation and process isolation. Review changed articles and links.
   The legacy `build-docs.ps1`/`.R` pipeline also generates the code map and
   translates README source links into ignored `pkgdown/index.md`. Those additions
   remain under review; do not treat the wrapper as the standard pkgdown interface.
   Until link handling is simplified, verify the generated landing page is current
   when README changes. Use `check-docs.R` for local link checks when needed.
4. Inspect articles, reference links and diagrams. Regenerate/check the code map
   when its tracked inputs change and it is needed for the task; do not require
   graph analysis for routine prose edits. Check graph freshness before use.
5. Record actual checks and limits in the feature record; do not claim measured
   context savings without comparing real navigation tasks.

The build is separate from the app/test processes. flow, pkgnet and pkgdown are
development/Suggests tools, not runtime Imports. No analyst data or public service
analysis is used to build the articles. pkgdown may fetch public documentation
metadata. `docs/` is reproducible, ignored output; no GitHub Pages deployment or
public site URL is assumed. Commit article/configuration/scripts and the small
generated navigation data, not caches or large rendered reports.

Use filenames beginning `dev-01-`, `dev-02-`, etc. for the developer series;
purpose/analyst articles use descriptive names. Numeric-only prefixes fail R's
installed-document filename checks. Titles retain the visible sequence numbers.
pkgdown also supplies `docs/llms.txt` and article Markdown for text-based access;
reuse these instead of maintaining a second full prose corpus. A missing public
`url` site diagnostic is expected until a hosting destination is approved.

## Agent queries

From the fgstudio root with the workstation Rscript executable:

```text
Rscript --vanilla dev/scripts/query-code-map.R --check
Rscript --vanilla dev/scripts/query-code-map.R fluvgeo::split_study_reach
Rscript --vanilla dev/scripts/query-code-map.R fgstudio::fgstudio_app
```

The map labels pkgnet static edges separately from reviewed indirect bridges.
Hashes detect changes in its tracked inputs, not semantic correctness. Regeneration
does not prove a human article is up to date: review remains necessary. The scope
is FG Studio plus named backend boundaries, not every repository/function in FG.
Do not use a missing edge as evidence that a dependency is absent.

## Future improvements

The pkgdown landing page and navigation must serve analysts as well as maintainers.
Keep purpose, implemented user outcomes and planned integration distinct. Route
scientific/backend ownership to workspace authorities without duplicating their
contracts. Current analyst procedures belong in the analyst guide, and internal
call paths belong in the developer series. Update article 01 when navigation
experiments produce new evidence; do not advertise unmeasured efficiency gains.

The [first navigation pilot](../governance/navigation-pilot-2026-09-19.md) supports
keeping concise routes and shared human articles, not a claim of speed/context
savings. Start with a task route and source/tests; consult articles when intent
or indirection is unclear. Use the generated graph only for a specific dependency
question, not as mandatory context. Resume functional work rather than repeating
benchmarks routinely; compare again when a real navigation problem warrants it.

Expand the route set only when navigation tasks demonstrate a missing connection.
Compare correctness and source files required for a known task before and after
using the map. Promote successful conventions to reproducibleai only after repeated
evidence; this pilot changes no upstream templates or shared package runtime.
