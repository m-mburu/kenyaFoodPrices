## UI

### Review basis

Reviewed on 23 September 2026 by running `kenyaFoodPrices::run_app()`
with `/usr/bin/Rscript --vanilla`, using the installed package. The normal
project startup could not find the package in its renv library; no dependency
changes were made. The installed build was not verified as identical to the
checkout. Recommendations combine live browser observations, the supplied
Maize / Retail / KG screenshot, and inspection of the current UI source.

Visited Overview, Trends, Map, Climate, Compare and Coverage at 1440 x 1000.
Inspected Map at 390 x 844. Tested the default Bread selection and switching to
Maize, which selected 90 KG / Wholesale. No visible Shiny output errors appeared
in these checks. This was a focused review, not a complete interaction or
accessibility audit. The points below are recommendations, not implemented fixes.

### Priority 1: Make the main result easier to reach and interpret

1. **Reduce the space taken by navigation and filters.** The desktop filter
   band is approximately 310 px high. On a phone, the six navigation links form
   a tall vertical list, the filters occupy approximately 867 px, and the map
   begins around 1264 px from the top. Use a collapsible navigation menu and a
   collapsed filter summary on small screens. Keep commodity, location and
   period easy to reach; put currency, unit and calculation in an expandable
   section. Show the current unit and price type even when controls collapse.
   Reduce empty space between filter rows and retain Reset filters. Only make
   a compact summary sticky, so controls do not obscure the analysis.

2. **Repair table sizing and alignment before cosmetic changes.** The supplied
   screenshot shows table headings displaced from their body columns; the live
   desktop Map table also needs horizontal scrolling with just one row.
   Investigate DataTables width calculation when hidden tabs become visible,
   including column adjustment after tab activation and viewport changes.
   Keep scrolling inside the table panel, align numeric columns to the right,
   and allow sensible wrapping of market names. Hide pagination and the page
   length selector when every row fits. Do not solve overflow with smaller text.
   Relevant code: `datatable_compact()` in `R/app_server.R` and table rules in
   `inst/app/www/style.css`.

3. **Match price labels to the selected calculation and unit.** The default
   calculation is Balanced median, but charts, tables and map tooltips say
   "Average price"; the map legend says only "Average KES". Use "Price estimate"
   with a nearby method label, or explicit median/mean wording appropriate to
   each panel. Include the denominator, for example "KES per kg" or
   "KES per 90 kg bag", in table headings, legends and tooltips. Explain the
   aggregation stages in short help text. For the map, the balanced option is
   the median of each market's monthly estimates over the selected period;
   avoid describing it as a county-level estimate. Preserve the estimators.

4. **Make time coverage and ranking scope explicit.** "Mapped Markets" currently
   lists only the first 15 markets after sorting by descending price estimate
   (`output$map_market_table` in `R/app_server.R`). Prefer a searchable table of
   all mapped markets, or title it "15 highest market price estimates" and show
   the total mapped count. State that the map summarises the selected period,
   rather than displaying current prices. Offer a clearly labelled recent-period
   shortcut while retaining the full historical range. Show covered months and
   latest observation month beside each market estimate, and distinguish a
   monthly date from the original observation date. Flag old or sparse data in
   words; markets observed in different months are not a same-month comparison.

### Priority 2: Improve layout, readability and context

5. **Give the map useful space without stretching Kenya.** In the supplied wide
   screenshot, the geography occupies a small part of a very wide map card.
   Align filters and results to a shared maximum-width container. Try a more
   balanced map/table split, or a compact map beside a wider market table;
   stack them on phones. Fit the SVG and its frame together while preserving
   geographic aspect ratio. Increase county-boundary contrast and legend text
   size. Explain that colour represents price and marker size represents record
   count, not certainty. Consider constant-size markers with counts in tooltips
   if larger circles obscure nearby markets. Provide searchable table access
   to the same values for users who cannot hover over the map.
   Relevant code: `market_price_map()` in `R/girafe_helpers.R`, the Map layout in
   `R/app_ui.R`, and `.kfp-viz-map` in `inst/app/www/style.css`.

6. **Use consistent, readable typography and controls.** The current serif body
   text contrasts with sans-serif labels and headings; many labels and table
   headings are only 12 px. Use one system sans-serif family, sentence case,
   approximately 16 px body text and at least 14 px table/control text. Make
   numeric columns easy to scan with consistent precision and tabular numerals.
   Reduce the all-capital navigation title. Retain clear focus indicators and
   provide approximately 44 px touch targets. Check text contrast on teal active
   controls; pair colour with visible selection, trend and missing-data labels.

7. **Bring interpretation and freshness close to the result.** The initial Bread
   view ends in December 2020 and represents one market in one county, while
   Trends describes the location as "Kenya". Say "Available markets in Kenya"
   and show actual coverage prominently. Consider a starting commodity with
   broad, recent coverage, selected by an explicit rule rather than alphabetical
   order. When a commodity change resets unit or price type, make that change
   clear. On Climate, retain the existing filter-scope explanation and bring
   short definitions beside the KPIs: a dekad is roughly ten days, and NDVI
   describes vegetation greenness. Identify the reference period for "normal"
   and distinguish latest data month from refresh date. Keep sources and methods
   one click away. Explain that lag relationships describe associations and do
   not establish that climate caused price changes.

### Verification when implementing

- Check 1440 px and wide desktop layouts, tablet width, and 390 px and 320 px
  phones. Ensure there is no page-level horizontal scrolling, clipped legend,
  displaced table heading or inaccessible pagination.
- Verify that the main result appears in the first phone viewport with filters
  collapsed. Keep the selected commodity, price type, unit and period visible.
- Test tab changes, resizing, table sorting/search, dependent filter updates,
  Reset filters, both calculations, empty selections and sparse coverage.
- Check the Map table against the plotted market count and ensure every price
  label identifies the correct method, currency, unit and time scope.
- Check keyboard navigation, visible focus, 200% zoom, touch access to map
  details, colour contrast, and loading/no-data states. Preserve the existing
  skip link, live status region and actionable validation messages.
- Capture before/after screenshots with the same filters. Review Overview,
  Trends, Climate, Compare and Coverage as well as Map after shared CSS changes.

## Climate filtering performance

### Review scope and conclusion

Investigated on 23 September 2026 against checkout `f26db64`, using
`/usr/bin/Rscript --vanilla` and `pkgload::load_all(".")`. Unlike the earlier UI
review, local profiling used the current checkout. Only this document was
changed; the performance experiments ran in temporary files.

**Start by reducing the climate maps' geometry and avoiding full map redraws
for county selection.** The strongest measured contributor is two large SVG
maps being rebuilt when climate controls change. This adds R drawing work,
serialization, transfer and browser parsing/drawing. The local price aggregation
is much cheaper. Hosting constraints may amplify the delay, but CPU saturation,
insufficient RAM and worker contention have not been established from account
metrics or server logs.

### Findings supported by code and measurements

1. **The displayed boundaries are unnecessarily detailed for these map cards.**
   `prepare_climate_geometry()` in `R/climate_module.R` transforms the original
   county geometry but does not simplify it. The 47 counties contain 393,104
   coordinate rows. `climate_map_plot()` in `R/girafe_helpers.R` passes these
   boundaries to `geom_sf_interactive()`, and `standard_girafe()` serializes a
   complete SVG for each map. Reducing CSS width does not reduce this geometry.

   Local benchmarks used July 2026, actual map values, and three runs per step:

   | Operation | Elapsed time per run | Output size |
   | --- | --- | --- |
   | Prepare county geometry | 0.055-0.060 s | 393,104 coordinate rows |
   | Maize / Wholesale / 90 KG price aggregation | 0.025-0.034 s | 1,153 input records |
   | National climate monthly series | 0.004 s | 9,353 county-month input rows |
   | Rainfall SVG generation | 0.375-0.445 s | 9,500,959 bytes |
   | Vegetation SVG generation | 0.383-0.407 s | 9,499,959 bytes |

   The two SVG strings total about 19 MB before widget/JSON overhead. These are
   uncompressed string sizes, not measured network traffic. Local timings exclude
   network delivery and browser rendering and are not shinyapps.io CPU timings.
   R profiling places most measured map time within `ggiraph::girafe()` and its
   ggplot/grid drawing calls. The package has 27,701 price rows overall, so this
   is not evidence that a large price dataset is overwhelming the server.

2. **Selecting a county rebuilds both maps merely to change their highlight.**
   `render_climate_map()` reads `input$county` when setting `selected`, so both
   `renderGirafe()` outputs depend on county selection as well as month and map
   measure. An isolated `shiny::testServer()` run with a traced
   `standard_girafe()` recorded:

   | Change | Calls to generate a map widget |
   | --- | --- |
   | Initial valid climate inputs | 2 |
   | Focus county: All to KE001 | 2 |
   | Climate month: July to June 2026 | 2 |
   | Map values: actual to condition | 2 |
   | Change the supplied price records alone | 0 |

   In the reviewed implementation, county selection changes the highlight,
   KPIs and county series but leaves the national map extent unchanged. The
   requested county-focus behaviour below extends this interaction. Rebuilding
   all national polygon paths for the existing highlight alone is redundant.
   This map work is a
   confirmed dependency, not a claim of an infinite reactive loop. The isolated
   module test does not reproduce browser/server input round trips or hidden-tab
   suspension. Map clicks also call `set_global_county()`, and the parent county
   observer sends a county update back; count actual redraws during browser tests
   before attributing additional work to that synchronisation.

3. **Top-level filter changes have a separate possible delay mechanism.**
   In `R/app_server.R`, `commodity_ui`, `unit_ui`, `pricetype_ui`,
   `page_year_ui`, `page1_county_ui` and `page1_market_ui` use chained `renderUI()`
   calls. Changing commodity can replace dependent inputs, reset dates/county,
   and require several client/server round trips. Resetting the global county
   can indirectly trigger the expensive climate maps. The chain exists in code;
   its contribution to production latency has not been timed independently.
   Do not claim that every commodity change directly redraws climate maps:
   their renderers do not directly depend on commodity or price records.

4. **Repeated raw-data downloads are not the filter path in this checkout.**
   `R/app_data.R` loads packaged data into a process-local cache. The climate
   module uses that data; it does not request World Bank/WFP data on each filter
   change. Geometry preparation occurs once per module session, not on every
   county/month change. Ordinary reactive expressions already reuse their current
   result until invalidated, but there is no explicit cache of past map results.

5. **Filter meaning must remain correct during optimisation.** The climate
   module receives `base_filtered_data`, which excludes the global county/market
   filters; county is applied separately through the climate focus control.
   `price_series()` explicitly uses `balanced_median`, irrespective of the global
   calculation radio button. The market filter and calculation selector therefore
   do not change this climate price series in the same way as the other price
   panels. Label the scope or decide an explicit shared contract; do not silently
   change the estimator as part of a performance fix. Preserve consecutive-month
   checks, missing values, z-score definitions and calendar alignment.

### Public deployment check

Opened one ordinary browser session on
[the public app](https://mmburu.shinyapps.io/kenyaFoodPrices/) and measured
`shiny:value` events for both map outputs after changing controls. The session
was already connected, with Maize / Wholesale / 90 KG selected. These timings
run from input change to receipt of the second map output, not final screen
paint, and include server/network/browser message processing:

| Interaction | Time to receive both map outputs |
| --- | --- |
| Map values: actual to condition, June 2026, Mombasa | 17.42 s |
| Focus county: Mombasa to All Kenya, June 2026 | 14.66 s |
| Climate month: June to July 2026, All Kenya | 9.44 s |

Both map outputs arrived for every measured change. The rendered rainfall and
vegetation SVGs each contained approximately 9.5 million characters, consistent
with the local payload finding. Shiny input values and the county/month summary
were checked to confirm that selections took effect. There were no reported
Shiny output errors. Only one observation per interaction was collected: these
are evidence of delay, not an estimate of normal latency or a benchmark under
concurrent load. Early idle-polling timings were discarded because they did not
reliably wait for the new output events.

The deployed month selector extended to August 2026, while the locally profiled
climate data ended in July. The deployed build/data therefore should not be
assumed identical to the checkout. Account CPU/RAM metrics, deployment logs,
compressed wire bytes and a final-paint browser trace were not obtained. The
measurements establish slow hosted updates and large displayed SVGs; they do
not assign all 9-17 seconds to server CPU or prove a particular hosting limit.

### Recommended fixes, in order

1. **Prepare a lightweight display boundary once, before deployment.** Keep
   the original geometry for analytical work. Build a separate map geometry with
   a method that preserves shared county borders. Select simplification strength
   by visual checks at desktop and phone sizes, not by vertex count alone.
   Retain all 47 county codes, valid/non-empty polygons, islands and correct click
   targets. Check adjacent counties for gaps and overlaps.

   A scratch experiment repaired validity, projected to EPSG:6933, simplified
   with a 1,000 m tolerance, repaired validity again, extracted polygons and
   transformed back to EPSG:4326. It reduced coordinates to 4,006 and one rainfall
   SVG to 176,334 bytes, with render times of 0.137-0.151 s: approximately 98%
   fewer SVG bytes. This establishes the potential benefit, not a production
   geometry choice. The first naive simplification produced invalid/mixed
   geometry; the repaired version had no empty geometries and passed individual
   validity checks, but shared-border consistency and visual fidelity were not
   validated. Do not copy that tolerance blindly into production.

2. **Separate map values, county focus and boundary loading.** Selecting a
   county, either through a selector or a map click, must zoom both climate maps
   to that county and update the highlight, KPIs and series. Use the county-focus
   contract below. Month and map measure should update fills, legends and
   tooltips while retaining the selected extent. Update the viewport and
   selection on the client; send only any newly needed county detail rather
   than retransmitting all national polygon paths. Evaluate a map widget with a
   supported viewport/layer update API. The installed ggiraph 0.9.6 exports no
   obvious proxy/update function; do not assume that `girafeProxy()` exists.
   Avoid simply isolating `input$county`, which would leave selection stale.
   Retain two-way selection and guard synchronisation observers against sending
   unchanged values.

3. **Stabilise dependent filters.** Prefer persistent controls updated with
   `updateSelectInput()`/`updateDateRangeInput()` over repeatedly replacing input
   widgets. Preserve valid selections and use `freezeReactiveValue()` where
   appropriate while updating dependent inputs. Compute choices from a shared
   filtered subset. Verify one settled input state causes one necessary update
   per visible output. If multiple simultaneous choices remain costly, offer
   an Apply filters button; debounce only genuinely rapid input events. These
   measures reduce repeated work but do not remove large map payloads.

4. **Cache measured expensive reusable results after reducing payloads.** Cache
   prepared display geometry per R process and consider bounded caching of pure
   map preparation/rendering stages by data version, geometry version, month,
   variable and map measure. Include any other input that changes the result;
   include county if selection remains part of the cached result. Keep widget
   IDs and selection state session-safe. Verify compatibility before wrapping
   `renderGirafe()` directly in `bindCache()`. Caching can reduce repeated CPU
   work but will not make a 19 MB pair of SVGs small. Avoid eagerly storing every
   month/measure/county combination in RAM. See
   [Posit's caching guidance](https://shiny.posit.co/r/articles/improve/caching/).

5. **Use hosting evidence before changing instance or worker settings.** During
   slow interactions, inspect CPU, memory, connections, worker counts and network
   metrics in the application dashboard, plus restart/OOM messages in logs.
   Distinguish cold startup from repeated filtering in an already running session.
   More RAM is justified by memory pressure, not by latency alone; more workers
   may help simultaneous sessions but consume additional memory and do not remove
   the work required by a single interaction. Posit does not guarantee CPU core
   count or speed for shinyapps.io instances. See the official
   [metrics documentation](https://docs.posit.co/shinyapps.io/guide/metrics/index.html)
   and [application settings](https://docs.posit.co/shinyapps.io/guide/applications/).

### County focus and GADM detail: requested behaviour

- **Use the same action for selection and clicking.** Changing Focus county or
  the global County selector, or clicking a county on either climate map, must
  select that county and fit both maps to its bounds with modest padding.
  Synchronise selectors, map highlights, titles, KPIs and trends through one
  canonical county identifier. For example, choosing or clicking Mombasa should
  show Mombasa at a useful scale in both rainfall and vegetation maps.
- **Make the national view easy to recover.** Provide an "All Kenya" or
  "Back to Kenya" control that resets both extents, county selection and any
  county-only detail layers. Preserve the chosen month, map measure and valid
  commodity settings. Selecting the current county again must not start another
  expensive redraw or an observer feedback loop.
- **Add GADM level-3 boundaries inside the focused county.** Use simplified
  county boundaries for the national view. When a county is selected, load only
  its level-3 units as internal outlines, with names available on hover/tap.
  GADM lists Kenya's counties at level 1 and provides third-level subdivisions,
  for example the five units within Westlands. Confirm unit types, coverage and
  identifiers in the chosen release before labelling them as wards. Record the
  boundary version and build an explicit crosswalk from GADM parent county IDs
  to the app's county codes; do not assume the identifiers match. Sources:
  [GADM Kenya level 1](https://gadm.org/maps/KEN_1.html) and
  [GADM Westlands level 3](https://gadm.org/maps/KEN/nairobi/westlands_3.html).
- **Keep geographic detail separate from measurement detail.** The current
  climate display uses county-month estimates. Level-3 outlines provide location
  context; they do not create level-3 rainfall or vegetation measurements. Keep
  the county estimate clearly labelled and do not colour individual units as
  though their values were separately observed. Display finer-level estimates
  only after a compatible data source and valid aggregation method are added.
  Where detail is unavailable, retain the county view with a short explanation.
- **Protect the performance improvement.** Prepare and simplify detail geometry
  before deployment, partition it by county, and cache it by county and boundary
  version. Do not download GADM or transmit all Kenyan level-3 polygons on every
  click. Prefer a widget supporting bounds and layer updates; first implement
  county zoom with existing boundaries, then add the local detail layer. Keep
  the selected focus during month/measure changes and ignore stale responses
  if users switch counties quickly. If a county has no matching price records,
  show that absence in the price panel while keeping its climate map focused.
- **Acceptance checks.** Dropdown selection and clicking either map must produce
  the same county, extents and values. Test returning to Kenya, switching between
  counties, repeated clicks, missing price data, detail-loading failure, phone
  layouts and keyboard selection. Verify only the selected county's level-3 units
  appear, parent IDs match, and county-level estimates remain unchanged. Measure
  first-load and cached county-focus latency separately; confirm that a focus
  change does not resend the full national geometry.

### Follow-up measurement and acceptance criteria

- Original symptom: Climate filtering feels slow on shinyapps.io.
- Best-supported contributor: full, detailed SVG regeneration for both climate
  maps, including changes that only updated a highlight in the reviewed app.
  The requested county-focus behaviour should avoid that same overhead. The exact
  production split between R work, transfer, browser drawing and queueing remains
  to be measured.
- First practical action: build and validate simplified display geometry, then
  repeat identical interactions. This directly reduces drawing and payload cost
  without changing the climate or price estimates.
- After deployment, review a week of use, or a controlled before/after session if
  traffic is low. Record median and 95th-percentile input-to-visible-update time
  separately for month, county, map measure and commodity changes. Use at least
  20 warm interactions per control on the same browser/network; record cold
  startup separately. Aim initially for an 80% reduction in map payload size and
  a clear reduction in warm interaction latency, then set a realistic latency
  target from the hosted baseline. These are targets, not achieved results.
- Count actual map output events. County changes should update the viewport
  and selected county layer without resending complete national map SVGs. A
  settled month or measure change should update each map once and retain county
  focus. Verify climate values, dates, legends, county selection and price-series
  results remain correct.
- Inspect browser network output and a performance trace alongside R timings.
  If payload shrinks but server time remains high, profile that render path;
  if R completes quickly but the browser remains busy, investigate transfer and
  drawing. Preserve hidden-output suspension; do not force hidden lag/method
  panels to render in an attempt to accelerate the visible tab.
