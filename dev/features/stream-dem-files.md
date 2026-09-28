# Source DEM files

Discovery targets the saved Stream polygon and a selected Survey Collection with
DEM acquisition intent. The USGS source-directory adapter reads complete catalog
paging and preserves literal file identifiers, reported sizes, resolution and
bounds. Unknown metadata stays unknown. Unsupported sources remain explicit.

Analysts review and save file choices, then acquire the saved selection. Changed
catalog evidence requires a fresh saved snapshot even if file IDs are unchanged.
The worker streams files sequentially, reports progress/outcomes and supports
cancellation. Completed assets survive failure and retries. Healthy transfers
have no application size or elapsed-duration ceiling; connection/idle recovery
handles failed transport.

Availability is resolved across compatible download attempts and metadata-only
context revisions using Stream geometry, Collection evidence and saved selection.
Reopening checks records and local file metadata. Acquisition/retry verifies
transfer integrity; cold inspection and explicit integrity refresh verify source
bytes. Receipts remain provenance, not scientific suitability approval.

The acquisition contract is `dem-download-proposal.md`; exact backend records are
in fluvgeo `dev/schemas/stream-dem-downloads.md`. Article 06 owns source discovery,
selection, worker and store call paths. Tests cover paging, stale selections,
receipt compatibility, streaming failures, cancellation and saved availability.
