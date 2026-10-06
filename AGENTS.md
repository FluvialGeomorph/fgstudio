# Agent instructions

## Identity and scope

`fgstudio` is the current repository. Treat its code, tests, configuration, and maintained documentation as evidence for repository-local behavior; their existence does not establish scientific correctness or author approval.

## Always-applicable rules

- Inspect repository and Git evidence before making consequential changes.
- Keep this file concise; route detailed knowledge into maintained artifacts under `dev/`.
- Preserve unrelated user changes and keep work within the requested repository scope.
- Distinguish verified evidence, reasonable inference, and unknowns.
- Treat `fgstudio` as the implementation-first proving ground for open-source
  `fluvgeo` replacements of legacy `FluvialGeomorph-toolbox` ArcPy tools. Any
  historically produced vector output must preserve its legacy entity/layer and
  field contract while remaining aligned with FGDB roll-up. Additions are
  allowed; removal, renaming, repurposing, capitalization changes, or unit
  changes require an explicit reviewed migration decision.
- FGDB guidance and FG Studio implementation inform each other. Follow accepted
  FGDB invariants, but route grounded GeoPackage/interoperability requirements
  discovered in FG Studio back to the owning FGDB contract. Never assume a draft
  FGDB physical schema is complete, and never promote a local app choice without
  that reconciliation.
- Before implementation, read the workflow named by the matching route and use it to choose the change; finding or linking it is not sufficient.
- For every development task, read `dev/workflows/complete-development-task.md`. Deliver a usable outcome within the authorized scope; routine implementation, integration and verification steps are not separate owner handoffs.

## Conditional context routes

- Goals, scope, or success criteria: `dev/goals/`
- Project role/audiences and analyst guidance: `vignettes/fgstudio.Rmd`, `vignettes/guide-study-workflow.Rmd`
- Current owner-approved slice and next review: `dev/goals/project-plan.md`
- Function-call navigation: `dev/architecture/agent-routes.md`; human orientation: `vignettes/dev-01-code-navigation.Rmd`, followed by the workflow articles.
- Developer-documentation changes: `dev/workflows/developer-documentation.md` and `dev/decisions/adr-0006-dual-mode-developer-documentation.md`.
- Shiny/session/storage boundaries: `dev/architecture/design.md`
- Data entities, ownership, persistence or function inputs/outputs: `dev/architecture/storage.md` and the function/data maintenance requirements in `dev/workflows/developer-documentation.md`.
- New or changed derived vector feature classes: first read the workspace legacy-
  replacement rule, `dev/workflows/legacy-derived-feature-compatibility.md`, the
  applicable FGDB compatibility profile, the legacy ArcPy producer, and the
  Technical Manual data dictionary. Verify the matching `fluvgeo::check_*`
  contract and downstream consumers before implementation.
- Raster processing design, implementation, review, or testing: read `dev/workflows/r-spatial.md` for scientific authority, native GIS operations, large-data execution, and Shiny integration.
- Architecture, dependencies, or ownership boundaries: `dev/architecture/`
- Consequential and durable choices: `dev/decisions/`
- Governance or artifact lifecycle: `dev/governance/`
- Repeatable development procedures: `dev/workflows/`
- Exact structural contracts: `dev/schemas/`
- Cohesive user-visible capabilities: `dev/features/`
- Resumable unfinished work: `dev/checkpoints/current/`
- R package code, dependencies, tests, documentation, build/check tooling or development automation: read `dev/workflows/r-package-development.md` before choosing tools or editing; inspect the relevant package sources and metadata.

Full session transcripts are not normal context sources. Use maintained durable artifacts and concise checkpoints.

## Completion governance

Before declaring meaningful work complete, update the existing artifact that owns the changed goal, design, contract, workflow or behavior. Keep current instructions there; remove conflicting or superseded guidance. Dated records may retain necessary evidence, but must not be required reading for standing instructions. Check that the task route leads directly to the current procedure. Create a checkpoint only when useful unfinished state remains; do not add a completion report by default.

Maintain human developer articles and agent routes together when call paths or
capabilities change. Include the affected function-to-data mappings when entities,
ownership, inputs/outputs or physical storage change; follow the developer-documentation
workflow's completion check. Generated graphs are navigation aids, not authority; inspect
source and verify freshness before relying on them. Human-only maintenance must
remain practical without recovering intent from chat history.

## Verification and information governance

Run checks proportionate to the change, inspect Git status and diff, and confirm the change boundary. Never record secrets, credentials, PII, restricted data, or unnecessarily large logs in agentic-context artifacts.
