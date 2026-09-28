# Terrain execution qualification

The standing processing requirements are in `dev/workflows/r-spatial.md`.
Current source acquisition, inspection, masks and DEM assembly are described in
their feature records and developer articles. This record retains bounded
qualification evidence; it is not a remediation checklist or execution plan.

## Measured mask workload

An isolated-backend 9053 diagnostic used R 4.6.0, terra 1.9.46 and GDAL 3.12.1 to
prepare masks for one saved Event at 1 m spacing in temporary directories.

| Stream grid | Creation | Sampled peak worker RSS | Reopening |
| --- | --- | --- | --- |
| 8,974 x 10,688 | 27.80 s | 1,681 MiB | 9.88 s |
| 5,631 x 3,764 | 15.87 s | 979 MiB | 10.15 s |
| 4,525 x 3,551 | 13.64 s | 949 MiB | 9.44 s |

Timings include worker startup. Input checksums were unchanged; outputs were
temporary and not published. These are single-worker measurements, not concurrency
or arbitrary-size guarantees. DEM assembly measurements are in `dem-mosaic-design.md`.

## Verification boundaries

Focused backend tests cover native mask generation, metadata reads, horizontal
warp controls, source discovery and transfer. App tests cover worker lifecycle,
cache invalidation/reuse, saved selections and automatic masks. Integrity refresh
is distinct from metadata-only reopening. Directory-symlink cases require Windows
permissions unavailable in the recorded environment.

Initial grid placement, unsupported warp profiles and broader vertical operations
remain explicit design questions. Working source and tests establish implemented
behavior; author-approved requirements establish scientific intent. Refer to the
mosaic design for current limits rather than reconstructing development history.
