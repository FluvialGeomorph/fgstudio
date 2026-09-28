# Source DEM inspection

Selecting a saved DEM starts its preview automatically. Metadata is available
below the image; explicit integrity refresh is optional. A cold view verifies the
source checksum. Session metadata/display caches reuse unchanged inputs using
receipt identity, file/sidecar size/time and backend version as invalidation keys.

The worker returns a bounded elevation image and source metadata. A brushed area
can be inspected repeatedly at finer detail. Each view retains absolute source
row/column offsets and identifies native versus sampled values. Windows within
the 512-cell display dimension are read without source downsampling; larger
windows use nearest-neighbour samples. This is a display budget, not an analytical
raster eligibility limit. Colours are scaled for the viewed window.

Unique brush identities prevent using a stale selection against a new result.
Plot coordinates are translated to top-row raster order; nested windows retain
source offsets. Empty/outside selections and invalid windows report errors.
Inspection writes no derived analysis product or suitability decision.

Article 07 traces `stream_dem_inspection` and the backend inspection/preview APIs.
Tests cover cache reuse, refresh/invalidation, stale brushes, nested offsets,
NoData, native/sample status and unchanged source bytes. Follow the R spatial
workflow for opt-in real-data diagnostics.
