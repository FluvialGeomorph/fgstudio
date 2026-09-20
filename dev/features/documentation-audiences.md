# Project orientation, analyst guidance and developer navigation

Owner request, 2026-09-20: put pkgdown's functional documentation in the wider
FluvialGeomorph context while retaining its human/agent development role.

## Maintained structure

- README/site home explains purpose, current utility and audience routes.
  The build derives ignored `pkgdown/index.md` to translate source-vignette links
  into local article links, keeping one authored landing-page text.
- `vignettes/fgstudio.Rmd` explains the prospective-study workflow, backend/client/
  FGDB/manual responsibilities, open-source direction and implemented/planned limits.
- `vignettes/guide-study-workflow.Rmd` is the single home for the analyst procedures
  previously in README, preserving local launch, storage and service-use details.
- The nine numbered developer articles remain. Article 01 provides task routing,
  navigation-pilot findings and a proportionate future evaluation method for
  human and agent maintenance; its generated examples remain bounded.
- `_pkgdown.yml` exposes Project overview, Analyst guide, Developer guide and API
  reference. The route table and documentation workflow describe the same layers.

## Evidence and authority

Owner refinement: context-routing methods now open the developer series as 01;
lifecycle, discovery/Streams and Reach editing are 02, 03 and 04. Articles 05-09
retain their numbers. Filenames, titles, menus, links and agent routes follow the
new order. The same review classifies test/tool placement in article 01 and the
script/workflow documentation; it makes no runtime/test migration. The reordered
site rebuilt successfully and 264 local page/anchor links passed validation,
including the nine correctly ordered developer menu entries. Superseded generated
article HTML/Markdown files were removed so they do not remain in the search index.
Runtime tests were not rerun for this documentation-only refinement.

Context was read from FG-architecture's system overview and ADRs 0006/0008,
fluvgeo's backend ecosystem and reporting intent, FGDB's initiative brief, and
fg-qgis-toolbox's README. Current app status comes from this repository. Older
organization implementation snapshots do not override newer member source/tests.
Only fgstudio documentation and package descriptive metadata change in this pass.

The 2026-09-19 navigation pilot is summarized with its limitations: an agent-only
paired run, correct core answers, different test-reading depth and no comparable
time/token measurements. No efficiency improvement or human trial is claimed.
No new experiment, runtime capability, schema, sibling edit or deployment is
implied by the documentation reorganization.

## Verification

The local site builds all eleven articles successfully. Validation resolves 263
local page/anchor links across the home, article index and eleven articles. It
checks the three audience routes, all nine developer menu entries, removal of
source-vignette links from the rendered home, and article Markdown/llms exports.
The code-map freshness, direct/indirect lookup and anchor checks pass (68 nodes,
85 static edges, 19 reviewed bridges). Every pre-existing analyst procedure line
was verified present after relocation; the only section-heading change organizes
acquisition/reference setup after study geometry.

An R source-package build succeeds, including creation of all eleven vignettes
and DESCRIPTION validation. Runtime code and tests are unchanged, so the full
runtime suite was not repeated. Existing workstation package build-version
warnings remain. Git whitespace validation passes. The running app, user data
and sibling repositories are unchanged; no hosted publication was performed.

Local ignored evidence: `dev/check-output/project-docs-final.log`,
`project-docs-links.log`, `project-docs-package.log`, and `check-project-docs.R`.
Rendered structure/links were checked; interactive browser visual acceptance is
not claimed. Navbar and home generation follow pkgdown's documented
[article configuration](https://pkgdown.r-lib.org/reference/build_articles.html)
and [home-page source precedence](https://pkgdown.r-lib.org/reference/build_home.html).
