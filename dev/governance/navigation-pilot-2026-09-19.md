# Agent navigation pilot — 2026-09-19

## Conclusion

Both source-only and documentation-assisted agents answered the three questions
correctly at the core level. The assisted agent inspected more test evidence;
this pilot does **not** establish faster work or lower context consumption.
The useful demonstrated aid was the route table plus two articles, not the
generated graph, which the assisted agent did not use. Keep the lightweight
documentation, correct the small routing gaps, and return to owner-directed
functional development. Do not expand a workspace graph or promote shared
reproducibleai templates on this evidence alone.

## Method and limits

Two independent fresh-context agents received the same three read-only questions
and source-citation requirement. Both read workspace and repository safety
instructions. The baseline excluded the new route/article/graph aids; the assisted
run began with them and verified against source/tests. Each answered all three
questions in one context, so this is one paired run, not three independent trials.
Neither executed tests, queried external services or changed files. The parent
independently checked the decisive source and test passages before adjudicating.
Documentation corrections below were made only after both runs finished.

Snapshot: fgstudio HEAD `60842339aa9900c6e5a350a211a7af57b2231599`, with the
previously built documentation still uncommitted; fluvgeo HEAD
`96e288833a4040d7044646584f192af03611b324`, clean. App/backend code was not
changed during the comparison. Agents did not receive the conversation history
or each other's answers. Existing AGENTS routing text remained visible to both;
the baseline is ordinary source search, not an instruction-free control.

## Results

| Question | Source-only | Documentation-assisted | Independent source check |
| --- | --- | --- | --- |
| Reach split: click to saved revision to refreshed editor | Correct core chain, including injected writer and reread | Correct same chain; also inspected click/save test | fgstudio `R/reach_split.R:44`, `R/study_store.R:73`, `R/study_store.R:199`, `R/mod_study.R:53`; fluvgeo `R/split_study_reach.R:103` |
| Stream clipping ownership and protective tests | Correct backend ownership and clip/buffer/clip order; tests identified through search matches | Correct ownership/order; inspected backend and UI test bodies | fluvgeo `R/study_stream_corridor.R:72`, `:225`, `tests/testthat/test_study_stream_corridor.R:7`; fgstudio `tests/testthat/test-stream-selection.R:38` |
| Saved-Reach merge blockers | Correct direct guards and Survey Event exception; did not locate dedicated merge tests | Correct guards, context-wide scope and event exception; inspected merge tests | fluvgeo `R/study_reach_merge.R:12`, `:20`, `:33`, `:97`; `tests/testthat/test_study_reach_corridor.R:34` |

In particular, Survey Events do not inherently prevent merging: retired parent
Reach IDs are reassigned. Any non-null context `network` or `folder_manifest`
blocks merging pending reconciliation. The code does not first prove that those
references belong to the selected Reaches. Both agents distinguished this from
split restrictions. Neither answer claimed exhaustive transitive validation.

## Measurements, not efficiency claims

| Self-reported measure | Source-only | Documentation-assisted |
| --- | ---: | ---: |
| Shell tool calls | 7 | 6 |
| Unique files read in full or bounded excerpts | 12 | 16 |
| Of those: safety instructions | 3 | 3 |
| Of those: new documentation aids | 0 | 3 |
| Of those: source/test files | 9 | 10 |
| Additional search-only file count | Not recorded | 4 |

One fewer shell call is not proof of efficiency: commands can return very
different amounts of content. Baseline tests were search-only; assisted test
bodies were read, so file totals do not measure equivalent depth. Both runs had
failed path/wildcard attempts. Irrelevant-file counts and actual token consumption
were not measured. The baseline measured a 55-second partial interval excluding
initial work; assisted total wall time was not instrumented. These times cannot
be compared. No speedup, percentage saving or causal quality improvement is claimed.

## Small corrections applied

- Agent routes now name the backend source/test files for corridor, merge and
  split work, rather than stopping at exported backend symbols.
- The discovery/Reach articles (now 03/04) include those backend test routes; article 04 makes the merge
  guard's context-wide scope explicit.
- Routes now recommend source/test first and articles on demand for intent or
  indirection, rather than requiring an article read for every lookup.

The corrections were not rerun as another comparison. Generated JSON, Mermaid,
flow diagrams and pkgdown text exports have no demonstrated marginal benefit in
this trial. Their value remains a separate question; no new graph machinery was
added. Runtime correctness remains governed by tests, not this navigation pilot.

Code-map freshness/lookup checks and strict reproducibleai context validation
passed after the documentation corrections. No runtime code was edited and no
package test rerun is represented by these checks.
