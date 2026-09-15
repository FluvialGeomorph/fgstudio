# ADR-0001: Independent, local-first FG Studio

- Date: 2026-09-14
- Status: Accepted direction from the owner; implementation remains developmental.

Create fgstudio as a new application, not an ohwm2 fork. Use the latter only as
an interaction/backend reference. Keep science and schema validation in fluvgeo;
build a modular, tested UI and storage orchestration in this R package. Start
with local data and preserve an explicit storage boundary for later FGDB access.

The owner approved concrete, reviewable increments, beginning with a saved Study
Area draft. Progress is governed by use and owner feedback, not an agent-selected
sequence of ArcPy replacements. Existing applications/toolboxes are unchanged.

Local means the app host, not the browser device. This first version is a trusted
single-analyst workstation app, not an authenticated service. Shared deployment,
Enterprise protocols and credentials need separate design and approval.
