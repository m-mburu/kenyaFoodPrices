# Modularisation implementation plan

Reviewed on 3 October 2026 against checkout `cf44513`.

## Recommendation and scope

Start by extracting calculations and presentation helpers from
`R/app_server.R`, then separate the page controllers and UI builders. Introduce
namespaced Shiny modules one page at a time after those boundaries are tested.
This gives small, understandable functions without changing every input ID in
one release.

The largest application files are `app_server.R` (2,054 lines),
`climate_module.R` (712), `app_ui.R` (548) and `style.css` (1,465).
Length identifies places to inspect; it does not by itself justify extraction.
The main issue is that calculations, markup, rendering and interaction state
share the same large server function.

The initial review proposed implementation without changing application code.
Implementation progress is recorded below; source line references in the
extraction map refer to the reviewed checkout before those moves.
The review covers package R code, data preparation, developer scripts, tests,
JavaScript, CSS, R Markdown chunks and the refresh workflow. Generated help,
binary datasets and generated `renv/activate.R` internals are not refactoring
targets. Existing project briefs remain context, not evidence of completed work.

## R language basis

I read the linked [R Language Definition](https://cran.r-project.org/doc/manuals/r-release/R-lang.html),
focusing on objects, scope, functions, evaluation and exception handling.
These language rules inform the design; the module boundaries below are project
recommendations, not requirements imposed by that manual.

- [Scope](https://cran.r-project.org/doc/manuals/r-release/R-lang.html#Scope-of-variables):
  extracted helpers need explicit arguments instead of relying on variables
  captured from `app_server()`.
- [Functions and evaluation](https://cran.r-project.org/doc/manuals/r-release/R-lang.html#Functions):
  use clear formal arguments and fully named calls. Pass reactive functions to
  controllers and evaluated values to calculation helpers. Force a loop argument
  when creating callbacks that must retain its current value.
- [Environments](https://cran.r-project.org/doc/manuals/r-release/R-lang.html#Environments):
  the package cache is shared mutable state. Keep user selections session-local.
- [Computing on the language](https://cran.r-project.org/doc/manuals/r-release/R-lang.html#Computing-on-the-language):
  preserve evaluation context when moving `data.table` expressions and Plotly
  formulas. Prefer ordinary arguments over new metaprogramming.
- [Exception handling](https://cran.r-project.org/doc/manuals/r-release/R-lang.html#Exception-handling):
  validate data contracts explicitly and put temporary-resource cleanup inside
  the owning function using `on.exit()`.

`data.table` mutation by reference is an additional package-specific concern:
use `copy()` before modifying shared input tables. Do not assume ordinary R
assignment protects a cached table.

## Existing boundaries to retain

| Area | Decision |
| --- | --- |
| `R/price_helpers.R` | Retain the shared aggregation API. Its three aggregation stages already express the estimand clearly. Extract further only when a stage needs independent reuse or validation. |
| `R/climate_helpers.R` | Retain short helpers such as `mean_or_na()`, `safe_zscore()` and `climate_condition()`. Split schema preparation into named stages. |
| `R/girafe_helpers.R` | Retain `standard_girafe()` as the widget configuration boundary. Separate plot construction from widget creation where callers need both. |
| `R/app_data.R` | Retain lazy process-level loading and the distinct county CRS fallback. Factor the repeated optional detail-layer loading only. |
| `R/golem_utils_server.R`, `R/golem_utils_ui.R` | These already contain small utilities. Check callers before removing unused scaffolding; splitting every utility into a file adds little value. |
| `R/run_app.R`, `R/app_config.R`, `app.R` | Keep the small startup/configuration entry points. Preserve `run_app()` and deployment contracts. |
| `R/doc_*.R`, `R/globals.R`, `R/_disable_autoload.R` | Maintain documentation and symbol declarations as supporting package infrastructure. No new module is needed. |
| Vignette and tests | Keep existing tests as behaviour contracts. The vignette currently has only setup chunks; it needs no extraction. |

## Proposed extraction map

Names below are proposed internal functions/files. Reuse existing functions
where they already perform the job. Keep package functions in `R/`; do not add
runtime `source()` calls or a custom loader.

### 1. Shared presentation and filter logic — first priority

| Current location | Proposed destination and responsibility |
| --- | --- |
| `app_server.R:24–90` | `R/format_helpers.R`: move `format_number()`, `format_change()`, `format_percent()` and `format_price_comparison()` together. Document which percentages are proportions. |
| `app_server.R:92–122`; `app_ui.R:87–101` | `R/ui_components.R` for `kpi_card()`, `plot_panel()` and `visualization_frame()`; `R/table_helpers.R` for `datatable_compact()`. Keep DT options and markup stable during the move. |
| `app_server.R:124–204` | `R/trend_helpers.R`: move date validation and period/quarter helpers, keeping current names and return columns. |
| `app_server.R:209–450` | `R/filter_helpers.R`: extract selection validation, unit/method labels, `filter_price_records()` and `filter_price_geography()`. Keep choice calculation distinct from widget updates. |
| `app_server.R:249–375,452–467` | `R/filters_server.R`: one controller owns dependent choices, resets and the county setter. Initially retain existing input IDs and reset behaviour. |

Use one validated selection object with named fields: category, commodity, unit,
price type, currency/price column, calculation, dates, county and market. Return
reactives for base records, geographically filtered records and labels. Also
expose a guarded county setter and reset event. Do not give every page the whole
`input` object.

Keep the filtering scopes explicit:

- Base records apply commodity, category, unit, price type and observation dates.
- Price-page records additionally apply county and market.
- Commodity comparison uses category, unit, price type and dates while allowing
  multiple commodities; it does not inherit the single-commodity restriction.
- Climate price records start from base records and apply the climate county.

Changing `renderUI()` chains to persistent inputs is a separate behaviour change.
First extract the current implementation. Afterwards, use explicit choice
helpers and selection rules to introduce updates without silently changing
defaults or reset semantics.

### 2. Price pages and their calculations — first priority

| Current location | Proposed boundary |
| --- | --- |
| `app_server.R:486–500` | `R/price_state.R`: own the shared aggregation and completed monthly series, computed once per settled selection. |
| `app_server.R:502–783` | `R/overview_server.R` plus `R/overview_helpers.R`: latest-price summary, year comparison, recent changes and ranked locations. |
| `app_server.R:785–1150` | `R/trends_server.R` and `R/trend_selection_server.R`: series preparation and one owner for reference/comparison state, clearing, chart clicks and focus restoration. |
| `app_server.R:1151–1735` | `R/trend_helpers.R` and `R/trend_plots.R`: prepare period series, annual records, seasonality and geography comparisons; build plots separately from output registration. |
| `app_server.R:1737–1810` | `R/price_map_server.R` and `R/price_map_helpers.R`: prepare market locations/estimates, map title and ranked table. |
| `app_server.R:1812–1973` | `R/compare_server.R` and `R/compare_helpers.R`: rank available choices and prepare grouped raw-record means. Share the repeated comparison plot builder. |
| `app_server.R:1975–2053` | `R/coverage_server.R` and `R/coverage_helpers.R`: prepare a single annual coverage summary used by the chart and table. |

Useful small calculation functions include:

- `summarise_latest_price(monthly)` and
  `compare_same_month_last_year(monthly, reference_date)`. Overview uses the final
  completed monthly row; Trends first excludes non-finite estimates. Keep that
  difference explicit when sharing a comparison helper.
- `summarise_location_periods(monthly, grouping, calculation)`. Reuse the
  median/record-weighted summary in top-market, top-county and map preparation,
  while keeping each panel's grouping, coverage fields and ranking limit explicit.
- `prepare_trend_series(monthly, frequency, display)` and
  `prepare_trend_changes(series)`. Preserve missing periods and the trailing
  three-period window; compare selected estimates, not smoothed values.
- `summarise_annual_records(records, price_column)`,
  `prepare_seasonality_index(records, price_column)` and
  `summarise_geography_records(records, benchmark, price_column, scope)`.
- `prepare_comparison_series(records, price_column, grouping)` and
  `comparison_price_plot(series, labels, grouping)` for county and commodity
  comparisons. Restrict supported grouping fields explicitly.
- `summarise_annual_coverage(records)` returning numeric counts and Date columns;
  format only when building the table or tooltip.

Build plot functions around prepared tables and explicit labels. Keep Shiny
validation messages in controllers and domain validation in calculation helpers.
Do not create a generic chart framework to remove a few theme lines.

### 3. UI composition and Shiny module migration — second priority

Extract `overview_page_ui()`, `trends_page_ui()`, `price_map_page_ui()`,
`compare_page_ui()` and `coverage_page_ui()` from `app_ui.R:124–500`.
Move the Trends selection panel into its own UI builder. The app shell should
compose resources, accessibility elements, navigation, filters and page builders.
Retain `climate_module_ui()` as the existing module boundary.

After plain extraction, convert a simple page such as Coverage into a
`*_module_ui(id)` / `*_module_server(id, ...)` pair. Then migrate Map, Overview,
Compare and finally Trends. Supply only each page's required reactives; return
only state or events that another component actually consumes.

Namespacing requires coordinated changes to UI output IDs, dynamically created
outputs, `update*Input()` calls, `shinyjs` targets, custom focus messages and
JavaScript selectors. In particular, `app_interactions.js:135–151` hard-codes
`trend_selection_panel` and `trend_selection_escape`. Pass namespaced identifiers
through data attributes/configuration rather than assuming global IDs. Preserve
the climate map-click routing, which already derives the module prefix from the
map output ID (`app_interactions.js:111–132`).

### 4. Climate preparation, maps and interaction state

The existing climate module is a sound starting boundary. Split its internals
by responsibility before considering nested Shiny modules.

| Current location | Proposed extraction |
| --- | --- |
| `climate_helpers.R:47–138` | `detect_jmr_schema()`, `prepare_jmr_long()`, `prepare_jmr_wide()` and `attach_climate_lookup()` behind the existing `prepare_jmr_climate()` wrapper. Preserve both source formats. |
| `climate_module.R:132–177` | `R/climate_geometry.R`: county preparation, name/P-code resolution and ADM2 value joins. Retain strict source-boundary matching. |
| `climate_module.R:315–397` | Pure helpers for focused detail, bounds and county map values. Keep boundary loading separate from joining monthly measurements. |
| `climate_module.R:400–436`; `girafe_helpers.R:130–277` | `R/climate_map_helpers.R`: explicit indicator configuration, tooltip/value preparation, reference outlines and plot construction. Retain `render_climate_map()` or its replacement as a thin controller. |
| `climate_module.R:375–384,448–495` | `R/climate_focus_server.R`: one owner for county selection, clicks, reset and global-selector synchronisation. Preserve unchanged-value guards. |
| `climate_module.R:497–610` | `R/climate_series_helpers.R`: county/national climate summaries, balanced monthly prices, consecutive log changes and aligned series; small KPI/trend builders. |
| `climate_module.R:611–710` | Small lag-plot, table and methods UI builders. Retain `lagged_climate_correlations()` as the statistical boundary. |

Protect these analytical contracts during extraction:

- County climate values are unweighted ADM2 means with deliberate missing-value
  handling. Focused sub-county values come from matching JMR/COD ADM2 records.
  GADM ward outlines remain reference geometry.
- The climate price series explicitly uses `balanced_median`, independent of
  the global calculation selector and market filter. Preserve and document it.
- Climate price changes are `100 * diff(log(price))` for positive prices in
  consecutive months. Other price panels use ordinary relative changes.
- Wide-schema z-scores use ADM2/calendar-month groups; legacy long-schema
  indicator values retain their source meaning. Keep the existing baseline and
  constant-series handling.
- Lag correlations use Spearman correlation and require at least 12 complete
  pairs. Missing calendar months must remain aligned before shifting values.

Modularisation alone does not fix SVG payload size. County focus currently still
renders full widgets. Keep widget replacement, client viewport updates,
simplification changes and caching optimisation as separately measured work.
Do not claim the performance targets in `AGENTS.md` are achieved by extraction.

### 5. Data loading, preparation and developer tooling

| Area | Plan and guardrail |
| --- | --- |
| `app_data.R:63–99` | Share optional GADM detail loading through `load_optional_detail_layer()`. Distinguish unavailable optional data from malformed data; retain process caching. Keep the more complex county fallback separate. |
| County-name helpers | Review `normalise_county_name()` versus `county_name_key()` and README's local `county_key()`. They are not equivalent: suffix stripping and whitespace differ. Test aliases and crosswalks before adopting one policy. |
| `data-raw/my_dataset.R` | Create a short driver around download, `prepare_food_prices()`, coordinate identifiers, county assignment and save. Pass a reference date and maximum age explicitly to the stale-commodity rule. Preserve dropped rows and join checks in an audit summary. |
| `data-raw/climate_dataset.R` | Keep existing download/read helpers. Split `build_kenya_climate()` into preparation, county aggregation, lookup/model metadata and saving stages. Retain source provenance and both schemas. |
| `data-raw/kenya_counties_gadm.R` | Retain `prepare_level()` and `simplify_boundaries()`. Separate download/skip policy and level orchestration from geometry transformations. Preserve versions and parent IDs; validate geometry and shared borders if simplification changes. |
| `data-raw/kenya_subcounties_cod.R` | Extract source reading, ADM1/ADM2 crosswalk validation, geometry preparation and saving. Preserve the JMR-compatible P-code contract. |
| `dev/*.R`, refresh workflow | Keep startup scaffolding separate from reusable preparation. Local dependency installation and CI's pinned workflow installation have different contracts. Extract repeated build/deployment steps only after comparing arguments and library paths. |
| `dev/windows_check_install.ps1` | Keep the platform-specific entry point; share package manifests only if local and workflow requirements truly match. |
| `R/html_functions.R` | Check internal callers, exports and documentation before retaining, relocating or deprecating legacy plotting/time/colour helpers. Do not remove functions merely because the current server does not call them. |
| `README.Rmd` | Reuse a documented plotting/preparation helper only when namespace access and document build requirements are settled. Edit the source, render `README.md` and inspect figures; leave generated output out of manual refactoring. |

Place reusable preparation functions in `R/` when runtime and preparation share
them; otherwise use a clearly named helper file under `data-raw/` sourced only
by preparation drivers. Extracted helper files must not download, install, save
or deploy merely when sourced. Keep those actions in explicit drivers.

Do not execute refresh or deployment scripts to test an extraction. Use small
local fixtures and temporary output directories first.

Before moving `create_unique_ids()`, test both its returned object and its
by-reference changes: the current caller assigns its result back to the price
table. Also separate saving and caller-environment assignment from
`prepare_level()` so the geometry transformation can return an object directly.

### 6. JavaScript and CSS

`app_interactions.js` already has named functions for table adjustment,
remembered disclosure state, resizing and focus messages. At 201 lines it does
not need a new build system. Extract the climate click and Trends keyboard
handlers from `bindDocumentEvents()` into focused functions; keep registration
central and idempotent. Split files only when a behaviour becomes substantial,
and verify `bundle_resources()` loading/order rather than assuming it.

Organise CSS into documented sections for tokens/base, navigation/filters,
shared panels/tables, price pages, climate and responsive adjustments. Repeated
selectors can be intentional overrides. Consolidate them with computed-style
and screenshot checks; moving rules can change the cascade. Start with sections
inside the existing stylesheet. Separate CSS files only when resource order is
explicit and verified.

## Function size and commenting standard

- Give each function one meaningful responsibility. Aim for roughly 15–50 lines
  of logic; use longer functions when a cohesive transformation or layout is
  clearer together. This is a review guide, not a hard limit.
- Keep related small functions in one responsibility-focused file. Avoid a file
  per trivial wrapper and avoid extracting every conditional.
- Document purpose, required columns/classes, return columns, unit of analysis,
  units, missing values, estimator and side effects. Use roxygen for reusable
  internal interfaces, with `@noRd` where help pages are unnecessary.
- Comment why a step exists: completing calendar gaps, weighting markets,
  preserving source missingness, copying shared data or ignoring repeated clicks.
  Do not repeat the syntax in comments.
- Follow snake_case, `<-`, explicit package calls, British English and an
  80-character limit for R code/comments. Preserve existing APIs during migration.
- Keep numeric estimates and dates typed until presentation. State explicitly
  whether a change value is a proportion, percentage points or a log change.

## Implementation sequence and acceptance gates

| Stage | Deliverable | Verification before moving on |
| --- | --- | --- |
| 0. Baseline | Record representative filter states, outputs, HTML IDs and screenshots from the current checkout. | Existing tests; both estimators; sparse/empty data; county and market scope. |
| 1. Shared helpers | Move format/UI/table/period helpers; extract pure summaries with old callers retained. | Existing tests plus focused fixtures for ranking, coverage, year comparisons and input non-mutation. |
| 2. Price composition | Extract filters, shared price state, page UI builders and plain page controllers. | Identical settled filter states and numeric tables; dependent choices, resets and Trends selection; no duplicate output registration. |
| 3. Shiny modules | Migrate one page per change, starting with Coverage and ending with Trends. | `shiny::testServer()` for state/events; browser checks for namespaced IDs, focus, map clicks and keyboard flows. |
| 4. Climate internals | Extract schema, geometry, focus and series helpers behind existing entry points. | Both JMR formats; ADM2 joins; missing NDVI; county-to-national reset; repeated clicks; climate values and price estimands unchanged. |
| 5. Preparation/assets | Extract preparation drivers and browser handlers; consolidate CSS cautiously. | Offline fixtures, temporary saves, document rendering and screenshots; no downloads/deployments on helper load. |
| 6. Package integration | Update roxygen imports, `NAMESPACE`, global symbols, caller references and developer documentation. | Full tests and package check in the project environment; inspect all six tabs and changed rendered documents. |

For browser verification, cover 1440 px desktop, tablet, 390 px and 320 px phones,
200% zoom, visible keyboard focus, collapsed filters, table headings after tab
changes/resizing, map details, loading/no-data states and hidden-output
suspension. Count map/output events when evaluating reactive changes; retain
county focus through month/measure changes.

Use exact numeric comparisons for unchanged calculations with suitable floating
point tolerance. Test different market record counts, missing months, partial
quarters, zero denominators and unmatched identifiers. Test two sessions to
confirm state isolation and that helpers do not mutate cached datasets.
Maintain the current 10-location Overview and 15-market Map ranking limits
unless a separately requested product change alters them.

Each stage should be a small reviewable change with its own acceptance gate.
Retain wrappers until callers are migrated, and revert the individual stage if
its behaviour cannot be verified. Avoid changing estimates, UI design, dependency
versions and module boundaries in the same change.

## Checks performed for this plan

- Parsed all 39 standalone R files across `R/`, `data-raw/`, `dev/`, tests and
  `app.R` successfully with `/usr/bin/Rscript --vanilla`.
- Loaded the checkout with `pkgload::load_all()` and ran
  `testthat::test_local(".", reporter = "summary")`: all seven test files passed.
  Startup emitted a sandbox-related `timedatectl` warning; no test failures
  were reported. The interpreter was R 4.5.3.
- Reviewed source interfaces, existing helper tests and the JavaScript ID
  contracts. Existing tests do not include `testServer()` coverage for the large
  page controllers; add that coverage during the relevant extraction stages.
- No browser session, document rendering, refresh, deployment or new performance
  benchmark was performed for this planning task.

## Implementation progress

### First change — shared helpers and Trends series

Started on 3 October 2026 on branch `refactor/modularise-dashboard`, based on
`dashboard-polish` at `cf44513`.

- Moved 13 existing helpers into `R/format_helpers.R`, `R/ui_components.R`,
  `R/table_helpers.R` and `R/trend_helpers.R`. Kept names, arguments, classes,
  DT settings and calculation behaviour. Added comments explaining units,
  missing values, shared-data copying and coverage.
- Extracted `prepare_trend_series()` from the Trends reactive. It receives a
  monthly table and explicit frequency/display choices, completes calendar gaps
  and optionally computes the trailing three-period mean. The server retains
  input validation and reactive ownership. Input tables are copied before use.
- Added focused tests for missing months, absent/partial quarters, smoothing
  over periods and source-table preservation.
- All eight test files passed. The 13 moved helper signatures and parsed bodies
  match the baseline, allowing for explicit `shiny::` qualification. Full UI
  markup matches after normalising Shiny's generated tabset IDs.
- Sixteen real-data comparisons against the original Trends reactive matched:
  both currencies, both estimators, monthly/quarterly and raw/smoothed views,
  using packaged Maize / Wholesale / 90 KG records.
- New R files and tests meet the 80-character limit; parsing and whitespace
  checks passed. The existing sandbox `timedatectl` warning remains unrelated
  to the extraction. No browser check or deployment was performed.

This completes the initial shared-helper extraction and the first pure series
calculation. Filters, page controllers, namespacing and the remaining stages are
still pending. Next, extract filter calculations and shared price state while
preserving dependent-input reset behaviour.

### Filter layout follow-up

Moved Category into the main filter row before Commodity, followed by Price
type, County and Date range. Market, Unit, Currency and Calculation remain in
More filters. Existing IDs and dependent-filter logic are retained.

The [Posit module guide](https://shiny.posit.co/r/articles/improve/modules/)
supports the planned distinction: use ordinary UI functions for shared markup
and `NS()`/`moduleServer()` pairs for components that own reactive behaviour.
Shared builders already include `kpi_card()`, `plot_panel()` and
`visualization_frame()`. The filters module returns selection/data
reactives through an explicit interface rather than reading other modules'
inputs. Each repeated module instance needs a unique namespace.

### Filters module

Implemented `filters_module_ui()` in `R/filters_ui.R` and
`filters_module_server()` in `R/filters_server.R`. The app uses the `filters`
namespace; each additional instance can use its own ID and price-record input.

Use the same namespace in the UI and server. Pass returned data reactives to
page controllers; `base_data` contains observation-level prices before county
and market restrictions, while `data` contains the full price-page selection.

```r
# In the app UI
filters_module_ui("filters")

# In the app server
filters <- filters_module_server("filters")
```

- `R/filter_controls.R` registers the dependent commodity, unit, price type,
  date, county and market controls. Their existing recreation/default behaviour
  is retained. Changing this to persistent controls remains separate work.
- `R/filter_helpers.R` separates geography filtering, reactive labels and
  filter-summary markup. Shared source records are copied before geography
  filtering; no estimator is changed.
- The server returns current selection, validated dates, base and geographical
  data, labels, a county reactive/setter and reset event. Transient selection
  fields can be NULL while dependent controls initialise; data reactives require
  valid inputs. Base records retain observation dates and exclude county/market
  restrictions, preserving the Climate scope.
- Price-page consumers use the returned selection/data rather than global
  filter inputs. Climate receives the module's county setter and reset event.
  Its balanced-median price series and other calculation contracts are retained.
- All static/dynamic filter IDs and disclosure IDs are namespaced. JavaScript
  uses disclosure role attributes so phone collapse and remembered state work
  for any module ID. Page output IDs and Trends keyboard handlers are unchanged.
- Added `testServer()` coverage for filtering scope, missing geography,
  non-mutation, labels, invalid date ranges and dynamic control namespaces,
  plus captured setter/reset messages and two-instance state isolation.
  All nine test files passed, including 85 filter-module assertions.
  An additional parent-server check verified Overview/Trends markup, Map,
  Compare and Coverage rendering, currency/county propagation, unchanged
  initial monthly estimates and Trends clearing on a filter reset.
  Fresh 1440 px and 390 px browser screenshots show the unchanged initial price
  result and layout, with the phone filters collapsed.

The browser interaction automation stalled after initialisation; its attempted
currency/category/reset sequence is not counted as a passed browser check.
Use the module tests for verified server behaviour, and retain a manual browser
interaction check before release.

### Performance follow-up implemented, 3 October 2026

The filters now expose independent field reactives and persistent controls.
Climate maps use validated simplified display geometry and Leaflet proxy
updates. Browser interaction checks now pass, including comparison-selection
retention, Reset filters, county synchronisation and phone layouts; the earlier
automation limitation above has been resolved. All 11 test files pass.
See [performance implementation](R_PERFORMANCE_IMPLEMENTATION.md) for measured
costs, geometry provenance, verification and the decision to retain cached
whole-detail loading and protective copies.
