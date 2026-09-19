# Developer documentation: paired human and agent maintenance

Trigger: a capability, call path, adapter, state transition or backend boundary
changes. Apply ADR 0006 with reproducibleai's narrow-artifact/proportionality rules.

## Maintained inputs

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
3. Run `dev/scripts/build-docs.ps1` from PowerShell. It resolves workstation R and
   Pandoc, installs fgstudio only into `dev/check-output/doc-library`, generates
   the code map and builds the pkgdown site at `docs/index.html`.
4. Inspect articles, reference links and diagrams. Query a representative direct
   caller and the indirect Reach split boundary. Check graph freshness before use.
5. Record actual checks and limits in the feature record; do not claim measured
   context savings without comparing real navigation tasks.

The build is separate from the app/test processes. flow, pkgnet and pkgdown are
development/Suggests tools, not runtime Imports. No analyst data or public service
analysis is used to build the articles. pkgdown may fetch public documentation
metadata. `docs/` is reproducible, ignored output; no GitHub Pages deployment or
public site URL is assumed. Commit article/configuration/scripts and the small
generated navigation data, not caches or large rendered reports.

Use filenames beginning `dev-01-`, `dev-02-`, etc.; numeric-only prefixes fail R's
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
