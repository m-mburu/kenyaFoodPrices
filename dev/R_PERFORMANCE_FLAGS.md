# R performance flags

This records the audit before optimisation. Current changes and verification
are in [R_PERFORMANCE_IMPLEMENTATION.md](R_PERFORMANCE_IMPLEMENTATION.md).
The profiling script now compares original/display geometry and Leaflet, and
checks the narrowed field contract; its dependency count is now one.

Reviewed on 3 October 2026 on `refactor/modularise-dashboard`, including the
uncommitted filters module. This flags costs and proposed follow-ups; it does
not change application behaviour.

## What the R manuals explain

- Binding another name to an object does not automatically copy its data.
  Modifying shared objects can require duplication. Explicit copies deserve
  attention when the objects are large. The manual notes that reference
  counting replaced the older NAMED mechanism.
- Temporary allocations also create garbage-collection work. Calling `gc()`
  on every filter change is not a remedy for unnecessary allocation.
- Loading and saving involve serialisation; compressed files also involve
  compression or decompression. This explains possible startup costs, but
  does not measure widget or browser performance.

Source: [R Internals, sections 1.1.2, 1.7 and 1.8](https://cran.r-project.org/doc/manuals/r-release/R-ints.html).

- Vector operations still perform work over their elements. Several separate
  filters can repeat that work and allocate several intermediate results.
- Replacement expressions conceptually call replacement functions; their
  actual copying cost depends on the object and implementation.
- Function arguments are evaluated lazily and their evaluated values are
  retained by promises. This does not cache results across separate calls.
- A loop or a small function is not, by itself, evidence of a bottleneck.

Source: [R Language Definition, sections 2.1.8 and 3.1.3–3.1.4](https://cran.r-project.org/doc/manuals/r-release/R-lang.html).

The flags below combine those mechanisms with checkout inspection and local
measurements. Shiny invalidation is a separate mechanism, described in
[Posit's reactivity overview](https://shiny.posit.co/r/articles/build/reactivity-overview/).

## Current measurements

Run from the project root:

```sh
/usr/bin/Rscript --vanilla dev/profile_performance_flags.R
```

The script loads this checkout with `pkgload`, reads packaged data, and performs
three consecutive runs per operation. It uses R 4.5.3, 25,892 price records,
the latest packaged climate month (August 2026), national extent, actual values
and no detail overlay. The Maize / Wholesale / 90 KG subset has 1,148 records.

| Operation | Elapsed seconds, three runs | Uncompressed SVG bytes |
| --- | --- | --- |
| Balanced price aggregation | 0.028, 0.036, 0.028 | Not applicable |
| Rainfall plot and widget generation | 0.428, 0.398, 0.346 | 7,793,259 |
| Vegetation plot and widget generation | 0.348, 0.355, 0.350 | 7,794,122 |

County geometry contains 322,136 coordinate rows. The two SVG strings total
15,587,381 bytes before JSON/widget overhead. These are local R timings and
uncompressed string sizes, excluding network delivery and browser rendering.
They are not production latency measurements. August NDVI includes missing
values; this benchmark tests the real latest-month rendering path.

## Flags, in priority order

### P1 — Large geometry and complete climate widget regeneration

**Measured generation cost and payload; interaction latency needs profiling.**

Locations: `R/app_data.R:25`, `R/climate_module.R:132`,
`R/climate_module.R:400`, `R/girafe_helpers.R:37` and
`R/girafe_helpers.R:134`.

`app_counties()` loads the full GADM county layer. The preparation step copies
and transforms it; both climate renderers build plots and SVG widgets from it.
County, month, measure and detail changes can invalidate these renderers.
The current county-focus implementation regenerates widgets rather than
using a viewport/layer update API. Simplified sub-county and ward layers already
exist, but the national county layer remains detailed.

Start with a separate simplified county display layer and measure the same
interactions again. Validate shared borders, all county identifiers, islands,
validity, clicks and appearance. Then assess supported widget updates for
focus and values. Preserve county/sub-county measurement meaning and focus.
Do not assume that an unsupported `girafeProxy()` function exists.

### P1 — The new selection reactive has overly broad dependencies

**Dependency propagation confirmed; full UI consequences need interaction tests.**

Locations: `R/filters_server.R:13`, `R/app_server.R:54`,
`R/app_server.R:1381` and `R/app_server.R:1465`.

`selection()` reads all nine filter fields. A consumer calling
`selection()$category` depends on that whole reactive, including currency,
calculation, county and market. The benchmark's calculation-only consumer
evaluated three times: initially, after currency changed, and after market
changed, although calculation stayed the same.

In particular, `compare_commodities_ui` reads the bundled selection and builds
checkboxes with the default top-five selection. An unrelated currency or
calculation change can therefore recreate this UI and send its default
selection again. This is a concern introduced by the recent module extraction.

Expose individual field reactives or separate contracts for data scope,
geography and calculation. A reactive that merely reads a field from the same
bundled `selection()` still inherits its broad dependency. Keep the complete
selection for the filter summary. Test that irrelevant changes preserve custom
comparison choices. The module's `base_data` already reads inputs directly
and avoids these bundled dependencies.

### P2 — Dependent controls repeatedly scan data and replace widgets

**Confirmed code path; settled interaction cost not measured.**

Locations: `R/filter_controls.R:7`, `:18`, `:32`, `:48`, `:73` and `:98`.

Six `renderUI()` controllers filter observation rows separately, extract
choices, and construct dependent controls again. Replacing controls can reset
values and require additional browser/server exchanges. R filtering time alone
does not capture that interaction cost.

Share appropriately scoped subsets or precomputed choice relationships, then
use persistent controls with update functions. Define which valid selections
should survive upstream changes before changing reset behaviour. Count updates
for one settled selection, including empty states and Reset filters.

### P2 — Copies, intermediate subsets, joins and sorts accumulate

**Operations confirmed; allocation and runtime contribution unmeasured.**

Locations: `R/filter_helpers.R:5`, `R/price_helpers.R:42`,
`R/price_helpers.R:95`, `R/app_server.R:58`, `R/app_server.R:180`,
`R/trend_helpers.R:66`, `R/trend_helpers.R:100` and
`R/climate_module.R:541`.

Filtering can be followed by explicit copies, aggregation, calendar completion,
joins, sorting and further copies for display columns. Both price panels and
Climate aggregate price records, with different scope and estimator contracts.
The measured price aggregation is currently much cheaper than map generation.

Profile allocation with `Rprofmem()` and shared-object duplication with
`tracemem()` before removing copies. Retain copies that protect process-cached
tables from `data.table` reference mutation. Select needed columns early when
safe, and reuse computations only when their scope and estimator match.
The copies of small monthly summaries are lower priority than geometry.

### P2 — Lazy loading still loads complete detail datasets into memory

**Loading scope confirmed; cold-start and memory costs unmeasured.**

Locations: `R/app_data.R:65`, `R/app_data.R:83` and
`data-raw/kenya_counties_gadm.R:163`.

Sub-county and ward datasets are cached after their first use. However,
`utils::data()` loads the complete national simplified layer; filtering for
the focused county happens afterwards. The ward comment describes county
scope more narrowly than the actual loading operation. The files use bzip2
compression, so first use includes decompression and object reconstruction.

Measure first-focus versus subsequent-focus time and resident memory. If
material, prepare versioned files partitioned by county and load only the
required partition. Existing process caching already prevents reloading the
whole dataset on every filter change.

### P3 — Small R-level loops and repeated formatting

**Potential scaling costs; no current bottleneck established.**

Locations: `R/climate_helpers.R:184`, `R/price_helpers.R:131` and
`R/girafe_helpers.R:164`.

Lag correlations build small tables for seven lags and two drivers, while
coverage labels format individual rows and maps assemble tooltip strings.
These allocate objects and execute repeated calls, but their current inputs
are small. `rbindlist()` already combines results once instead of growing a
table on every iteration. Keep these readable until profiling identifies a
material cost; replacing `lapply()` with another loop is not a demonstrated fix.

## Existing protections and verification limits

- Packaged datasets are cached per R process; ordinary filter changes do not
  download WFP, JMR or GADM data. Downloads and boundary preparation in
  `data-raw/` are build/refresh costs.
- Price aggregation is shared through a reactive rather than independently
  repeated for every price output.
- Detail geometry is already simplified during preparation. County geometry
  needs separate attention; do not repeat simplification on every interaction.
- No growing `rbind()` loop was found in the inspected runtime paths.
- No app logic or estimator changed in this review. The benchmark checked
  generation cost and a module dependency, not complete browser interactions,
  hosted concurrency, network compression or memory pressure.

Next, measure warm input-to-visible-update latency and output-event counts
before and after each focused fix. Retain hidden-output suspension and compare
the resulting values, dates, selections and labels against the baseline.
