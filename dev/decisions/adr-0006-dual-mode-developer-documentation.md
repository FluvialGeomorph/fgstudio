# ADR 0006: Human and agent development must remain interchangeable

Status: Accepted owner requirement, 2026-09-19.

## Decision

FG Studio must remain understandable, debuggable and extendable by a human
developer without an agent. Growing AI-assisted implementation must not create a
system whose call relationships only an agent can untangle. Maintain human
developer articles alongside compact agent navigation, using the same source
and evidence boundaries. Neither mode is a second-class maintenance path.

Use pkgdown for the local package reference and sequential R Markdown developer
articles. Use flow for selected code/dependency diagrams and evaluate pkgnet's
actual function network against known indirect paths. Generated outputs aid
navigation; they do not replace human explanations or prove graph completeness.
Keep documentation tools in development/Suggests dependencies, not app Imports.

## Completion boundary

A capability is not ready for handoff if its entry events, important direct and
indirect calls, state/persistence effects and failure/test routes cannot be traced
by a human through maintained documentation. Update an existing article for small
changes; add a numbered article for a cohesive new capability, not every function.
Update the matching agent route and regenerate affected graph evidence together.

Avoid duplicate prose, transcript archives and manually maintained giant graphs.
An unclear design should prompt simplification or a design discussion, not merely
more documentation. Scientific and architectural choices remain with the owner.

## Adoption

This is repository-local application of reproducibleai's artifact lifecycle and
lean human-agent governance. It does not change that package's scaffolding or
impose an ecosystem-wide graph standard. Promote methods to shared guidance only
after evidence shows they improve routing. No hosted publication is authorized
by the local pkgdown build.
