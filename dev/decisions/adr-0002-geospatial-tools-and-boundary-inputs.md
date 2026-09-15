# ADR-0002: Geospatial tool selection and boundary entry

- Status: Accepted user requirements, 2026-09-14.

Support three Study Area boundary entry paths: draw, import and select watershed
units. Implement drawing first; other paths await bounded implementation approval.

Prioritize open source, sustained support, trusted development teams and high
throughput; prefer tidyverse compatibility where practical. Use established
geospatial representations rather than bespoke geometry formats or algorithms.
Performance claims must be backed by relevant workloads, not popularity alone.

For this increment, select leaflet, leaflet.extras and sf: existing installed,
documented R spatial tools with Shiny drawing and standard sf integration.
Leaflet's R documentation credits Posit/contributors; leaflet.extras documents
its maintainers and drawing API. See the linked primary sources in the app
architecture. They support this bounded choice, not blanket approval for every
future analysis dependency or a claim of unlimited throughput.

Capture drawn boundaries as WGS 84 polygons; do not derive analysis CRS, clip
terrain or infer scientific acceptance. Use existing fluvgeo revision validation.
Keep UI-specific GeoJSON conversion here and reusable science in fluvgeo.
