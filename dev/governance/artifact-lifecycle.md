# Agentic-context artifact lifecycle

1. Route standing instructions through `AGENTS.md`.
2. Maintain each standing rule or procedure in its existing, purpose-named `dev/` artifact. Dated records hold optional evidence, not instructions needed to perform the task.
3. Treat code and tests as evidence of behavior, accepted ADRs as authority for their decisions, and schemas as exact documented contracts.
4. Update affected artifacts in place before closing consequential work; remove conflicting guidance and verify the direct task route. Do not append a session narrative as a substitute for this edit.
5. Use checkpoints only for unfinished work that another session must resume.
6. Remove superseded scaffolding after its relevant content is adapted and Git records its history.

For function-call documentation, update the human article and compact agent route
in the same capability increment. Regenerate derived graphs from the reviewed
source; never hand-edit generated edges. Mark indirect reviewed connections and
unknown coverage explicitly. Test a few concrete navigation questions before
promoting a routing technique as more efficient. See ADR 0006 and the developer
documentation workflow; this adds no new routine decision-packet requirement.
