# Documentation audiences

README and the site home explain purpose and audience routes. The project overview
locates FG Studio within FluvialGeomorph. The analyst guide owns operating
instructions. Numbered developer articles describe the functioning workflow;
unmounted diagnostics and standalone tools have a separate reference article.

Agent routes identify source/test entry points and backend boundaries. They use
the same human articles rather than a duplicate explanation. Generated call maps
are navigation aids, not scientific authority or complete runtime graphs.

The pkgdown build derives its home from README, renders article/reference pages
and exports Markdown/llms text. `_pkgdown.yml` owns navigation. The developer
workflow owns regeneration, source-map freshness and local link checks. Local
build success does not imply public hosting or browser interaction coverage.
