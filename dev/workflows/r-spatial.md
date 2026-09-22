# R spatial processing

Status: first draft for project-author review, 2026-09-22. The governing
principles reflect the owner's direction; the technical guidance below does not
retroactively approve existing implementations or their scientific assumptions.

## Purpose and trigger

Read this workflow before designing, changing, reviewing, or testing raster
processing used by FG Studio, including work delegated to its shared R backend.
Read the backend repository's own instructions before editing that repository.
Use this alongside [R package development](r-package-development.md).

**Implement the project authors' established scientific methods using mature GIS
operations. Do not invent scientific requirements, custom algorithms, processing
restrictions, or analyst approval steps without demonstrated need and explicit
authority.** Large rasters are an expected workload, not an exceptional input.

## 1. Establish authority before implementation

Start with the authors' requirements, accepted scientific methods, and reference
results. Locate established project implementations that express those methods.
Use relevant published methods and standards for scientific questions, and
official package documentation for API behavior. Consult:

- [Spatial Data Science with R and terra](https://rspatial.org/) for spatial
  methods and worked examples.
- [terra reference](https://rspatial.github.io/terra/reference/index.html) and
  [maintainer R-universe package page](https://rspatial.r-universe.dev/terra) for
  functions, source, and package information.
- [GDAL documentation](https://gdal.org/en/stable/) for the underlying raster
  formats, drivers, and supported processing behavior.

Check the installed package versions and applicable local help. Online examples
may describe newer APIs; they do not authorize a dependency upgrade.

Existing code and tests establish what the software does. They do not, by their
existence, establish scientific correctness. Agent-written code, schemas, ADRs,
tests, and earlier explanations must not become authority through repetition.
Identify whether a consequential requirement is author-directed, documented by a
method, verified from software behavior, or still a proposal. Resolve conflicts
with the authors' method before adding another implementation layer.

## 2. Use standard GIS operations first

Preserve rasters as georeferenced arrays. Use terra and its native processing
facilities, including GDAL where applicable. Choose the operation that expresses
the spatial method directly:

| Intended operation | Starting point in terra |
| --- | --- |
| Burn vector attributes or membership onto an established grid | `rasterize()` |
| Restrict spatial extent or apply membership/NoData | `crop()`, `mask()` |
| Reclassify values or perform raster algebra | `classify()`, raster arithmetic and logical operators |
| Transform CRS or align to an approved target grid | `project()`, `resample()` |
| Combine overlapping rasters using an established overlap rule | `mosaic()` |
| Obtain raster-wide summaries | Supported native summaries through `global()` |
| Apply calculations across layers | `app()`, `lapp()` |
| Summarize groups of layers | `tapp()` |
| Apply a neighborhood operation | `focal()` |

These are starting points, not interchangeable recipes. Verify the selected
function's arguments and semantics. Prefer native implementations of supported
summary functions over R wrappers that force custom evaluation. `app()` operates
across cell values in layers; `lapp()` passes layers of a `SpatRaster`, or
subdatasets of a `SpatRasterDataset`, as function arguments. Do not assume that
`lapp()` accepts a `SpatRasterCollection`. See the official
[app](https://rspatial.github.io/terra/reference/app.html) and
[lapp](https://rspatial.github.io/terra/reference/lapp.html) references.

Do not recreate rasterization with per-cell point-in-polygon calls, convert every
cell to a vector feature, or introduce custom grid traversal to make a standard
operation appear more explicit. A documented capability gap is required before
writing a replacement algorithm.

## 3. Keep large data file-backed

Use file-backed `SpatRaster` objects and provide output filenames for substantial
operations. Let terra manage supported block processing. A `SpatRaster` can also
contain in-memory values: its class alone does not establish bounded memory use.

Never materialize a complete large raster in native R with `values()`,
`as.matrix()`, `as.array()`, `as.data.frame()`, or equivalent extraction and
assignment. Do not use `apply()` or cell-by-cell R loops on those extractions.
Compressed file size is not a reliable memory estimate; do not define this rule
by an arbitrary 1 GB threshold. Small test fixtures, bounded samples, and bounded
custom processing chunks are legitimate uses of R arrays.

Use terra for new raster processing. Do not introduce `raster::raster()` or
`raster::brick()` as an alternative processing stack. A narrow compatibility
adapter requires an actual unsupported interface, not a copied legacy example.

Custom block processing is an advanced exception when native operations cannot
express the required method. Use terra's documented
[read/write lifecycle](https://rspatial.github.io/terra/reference/readwrite.html):
open inputs with `readStart()`, initialize output with `writeStart()`, use its
block plan with `readValues()` and `writeValues()`, and close with `readStop()` and
`writeStop()`. Account for temporary copies in the block plan. Arrange cleanup on
error and cancellation, protect source files, and never publish partial output.
Do not substitute manually constructed cell-index matrices. A custom loop must
also handle any method-specific neighborhood overlap and edge behavior.

## 4. Separate scientific choices from execution choices

Scientific choices include output resolution, grid placement, inclusion rules,
interpolation, overlap treatment, NoData meaning, and horizontal or vertical
transformations. Establish these from the accepted method. A package default is
API behavior, not proof that it is the appropriate scientific choice.

Compression, temporary storage, chunk sizes, and worker scheduling are generally
engineering choices, provided they preserve the required numerical result.
Do not enlarge output cells, shrink the study extent, or change a boundary rule
to accommodate an inefficient implementation. Ask the authors when a scientific
decision remains unresolved; answer routine API questions from documentation.

## 5. Define the spatial and numerical contract

Before combining data, identify the required horizontal CRS, vertical reference,
coordinate and elevation units, grid resolution, origin, extent, dimensions,
layer meanings, value domain, and NoData representation. Reuse saved project
definitions rather than asking the analyst to supply them again.

Check grid compatibility with
[compareGeom](https://rspatial.github.io/terra/reference/compareGeom.html) and
the applicable geometry properties. CRS and extent alone are insufficient;
resolution, dimensions, and alignment matter. Assigning a CRS label does not
transform coordinates. A horizontal projection does not establish a vertical
datum transformation. Perform `project()` or `resample()` only toward the
approved target, with a method appropriate to continuous or categorical data.

Make polygon inclusion, holes, parent-mask intersection, zero versus NoData,
and all-NoData behavior explicit where relevant. Do not introduce a custom
boundary predicate as a presumed improvement over native rasterization.

Choose storage type from required precision and value range. Do not require
Float64 simply because R calculations use doubles. Float32 elevation storage and
integer mask storage should remain available where they satisfy the contract.
Check NoData encoding, rounding, and possible overflow. Establish meaningful
tolerances for transformed continuous values; use exact comparisons where the
discrete contract warrants them. See
[writeRaster](https://rspatial.github.io/terra/reference/writeRaster.html).

## 6. Plan execution for large rasters

Use suitable scratch storage, file-backed outputs, and memory/thread settings
appropriate to the deployed machine and concurrent jobs. See
[terraOptions](https://rspatial.github.io/terra/reference/terraOptions.html).
Coordinate worker concurrency and native threads to avoid oversubscription;
more workers or threads do not automatically improve throughput. Memory settings
guide execution but are not a universal guarantee for arbitrary R callbacks.

Do not impose arbitrary cell-count, row-width, file-size, or elapsed-time limits
on scientifically valid analyses. Execution resource budgets should determine
chunking or scheduling, not eligibility. Treat documented library/format limits
and actual resource failures accurately; do not disguise an invented application
limit as a GIS requirement. Estimates may inform scheduling and diagnostics but
must not become speculative hard rejection rules.

Minimize repeated reads, copies, reprojections, resampling, statistics scans, and
hashes. Crop early only when it preserves the required support, including any
neighborhood or interpolation margin. Consider virtual datasets or overviews
where suitable. Reuse completed results when their inputs and processing recipe
still match; do not repeat full raster validation on every reactive redraw.

## 7. Manage durable output and temporary files

Choose format, tiling, compression, BigTIFF behavior, datatype, and NoData options
for the actual product and expected scale. Preserve original inputs. Write into
job-owned staging locations, close outputs, perform proportionate verification,
then publish complete results through the existing storage contract.

Separate durable study products from temporary processing and display products.
Record enough input identity, method parameters, and software-version evidence
to reproduce results. Avoid recording sensitive paths or unnecessary large logs.
Clean incomplete output after failure without deleting valid saved products.

## 8. Keep Shiny responsive and isolate jobs

Keep spatial computation in backend functions with explicit inputs and outputs,
outside UI/server logic. These functions must be independently testable; file
writing is an explicit side effect, not a claim of functional purity. Keep the
workflow open-source and reproducible with the project's R/testthat toolchain.

Dispatch expensive work through the established background-worker mechanism.
Snapshot paths and serializable settings; construct `SpatRaster` objects inside
the worker and return output paths and compact status metadata. Do not export
live external pointers between R processes. Within one process, a file-backed
raster in a reactive value is not inherently a copy of all its cells; manage its
file lifetime deliberately rather than relying on that misconception.

`withProgress()` and progress updates do not make synchronous work non-blocking.
A hand-written chunk loop in a reactive expression still occupies the main R
process. Worker progress must reach the UI through the app's supported status
channel; workers must not access live session or reactive objects. Posit's
[non-blocking operations guide](https://shiny.posit.co/r/articles/improve/nonblocking/)
documents `ExtendedTask` with asynchronous execution. It is an available pattern,
not a requirement to replace an established working worker architecture.

Give every job a unique owned temporary directory, associated with its session
and study. A session token can help name a directory; it is not an access-control
mechanism. Shiny's [resource publishing API](https://shiny.posit.co/r/reference/shiny/1.6.0/resourcepaths.html),
including `resourcePaths()`, concerns web resource mappings, not temporary file
isolation. Do not expose raw study/scratch directories as static resources.
Configure worker scratch paths without changing process-wide settings for other
active sessions. Stop or coordinate workers before removing their files, handle
session termination, and provide cleanup for abandoned jobs after crashes.

Avoid duplicate dispatch on unrelated reactive invalidation. Bind results to the
input revision used by the job so an older completion cannot replace newer work.

## 9. Separate map display from analysis

Serve a suitable overview, reduced display raster, or tile representation to web
maps. Preserve the full-resolution analytical product. Select display resampling
according to data meaning: averaging may suit continuous elevation but can
misrepresent categorical values and masks. Account for NoData and empty outputs.

Choose display budgets from rendering requirements, not as processing limits.
The example value of 500,000 pixels is not a universal standard or a memory
guarantee. Creating a display raster can itself be expensive; prepare/cache it
outside the main reactive loop when necessary.

Current Leaflet
[addRasterImage](https://rstudio.github.io/leaflet/reference/addRasterImage.html)
accepts `SpatRaster` directly. Check the installed version before introducing a
legacy conversion. Display reprojection must not redefine the analysis CRS.

## 10. Verify independently and proportionately

Use testthat with small analytical fixtures and author-approved reference results
to test the scientific contract. Exercise relevant alignment, boundary, hole,
NoData, datatype, and transformation cases. Expected results must follow from the
method or independent evidence, not merely duplicate the new implementation.
Explain legitimate numerical differences between implementations.

Distinguish calculation from verification: a raster operation may necessarily
visit every cell internally. That does not justify an additional R-level
per-cell audit. Use metadata checks, native summaries, targeted samples, and
reference comparisons according to the actual failure risk. Run full scans only
when their scientific or integrity purpose is established, and reuse the result
when the underlying artifact has not changed.

Validate consequential processing changes on representative large data through
the actual worker, storage, reopening, and reuse path. Record dimensions,
datatype, storage context, software versions, runtime, and observed resource use
needed to interpret the result. Small unit tests alone do not establish large
raster readiness. Distinguish measured performance from estimates.

Run the affected tests first. Broaden checks when changed interfaces or observed
failures justify it; do not repeatedly run unrelated suites, package builds, or
documentation builds without a reason. Keep large integration data out of routine
unit tests and repositories unless explicitly approved.

## 11. Present analyst decisions and results

Use established FluvialGeomorph terminology. Reuse known study and Survey Event
inputs and run necessary dependent backend steps automatically. The UI need not
mirror each backend function, validation, or saved intermediate artifact.

Present useful visual results and meaningful choices. Do not add diagnostic
tables, approval gates, free-text identifiers, stream selection, or save/run
buttons when the workflow already determines the answer. Failures should explain
what happened and identify the relevant input editor or actionable recovery.
Do not tell users to change scientifically valid inputs to bypass invented limits.

For implementation turns that change app behavior, provide a current UI result
for review each turn and disclose anything not yet visible or exercised. A
backend test pass is not a substitute for reviewing the actual analyst workflow.

## 12. Exceptions and completion

Before introducing a custom algorithm or departing from an established method,
record the requirement and its authority, the native operation considered, the
demonstrated deficiency, the proposed numerical and performance effects, and an
independent acceptance check. Keep this evidence in the existing owning artifact.
Seek author clarification for unresolved scientific choices; do not turn routine
engineering work into a new approval process.

`pkgnet` and `flow` support development navigation and documentation. They do not
offload raster computation or substitute for terra/GDAL. Follow the
[developer-documentation workflow](developer-documentation.md) when their actual
documentation use is relevant.

For each change, the durable outcome is the established method implemented with
appropriate native operations, reproducible output, relevant verification
evidence, and an updated owning contract or workflow. Report remaining scientific
uncertainty and untested execution paths plainly. Do not describe a proposal,
synthetic test pass, or unreviewed UI as authoritative scientific completion.
