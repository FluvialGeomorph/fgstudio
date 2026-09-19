# Agent instructions

## Identity and scope

`fgstudio` is the current repository. Treat its code, tests, configuration, and maintained documentation as the authoritative evidence for repository-local behavior.

## Always-applicable rules

- Inspect repository and Git evidence before making consequential changes.
- Keep this file concise; route detailed knowledge into maintained artifacts under `dev/`.
- Preserve unrelated user changes and keep work within the requested repository scope.
- Distinguish verified evidence, reasonable inference, and unknowns.

## Conditional context routes

- Goals, scope, or success criteria: `dev/goals/`
- Current owner-approved slice and next review: `dev/goals/project-plan.md`
- Function-call navigation: `dev/architecture/agent-routes.md`; human explanations: `vignettes/dev-01-application-lifecycle.Rmd` through the numbered series.
- Developer-documentation changes: `dev/workflows/developer-documentation.md` and `dev/decisions/adr-0006-dual-mode-developer-documentation.md`.
- Shiny/session/storage boundaries: `dev/architecture/design.md`
- Architecture, dependencies, or ownership boundaries: `dev/architecture/`
- Consequential and durable choices: `dev/decisions/`
- Governance or artifact lifecycle: `dev/governance/`
- Repeatable development procedures: `dev/workflows/`
- Exact structural contracts: `dev/schemas/`
- Cohesive user-visible capabilities: `dev/features/`
- Resumable unfinished work: `dev/checkpoints/current/`
- R package API, implementation, documentation, or tests: `DESCRIPTION`, `NAMESPACE`, `R/`, `man/`, `tests/testthat/`, and `dev/workflows/r-package-development.md`

Full session transcripts are not normal context sources. Use maintained durable artifacts and concise checkpoints.

## Completion governance

Before declaring meaningful work complete, determine whether it changed goals, architecture, a durable decision, a schema or interface, a repeatable workflow, feature behavior, or resumable state. Update the applicable durable artifact. Create a checkpoint only when useful unfinished state remains.

Maintain human developer articles and agent routes together when call paths or
capabilities change. Generated graphs are navigation aids, not authority; inspect
source and verify freshness before relying on them. Human-only maintenance must
remain practical without recovering intent from chat history.

## Verification and information governance

Run checks proportionate to the change, inspect Git status and diff, and confirm the change boundary. Never record secrets, credentials, PII, restricted data, or unnecessarily large logs in agentic-context artifacts.
