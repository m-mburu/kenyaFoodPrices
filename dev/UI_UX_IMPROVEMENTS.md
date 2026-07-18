# Kenya Food Prices Dashboard: UI/UX improvement review

Date: 18 July 2026

## Scope and method

This review compares the current Shiny application with the principles in the
25 available MIT 6.831 *User Interface Design and Implementation* lecture-note
PDFs. Lecture 26 has no notes in the downloaded course material.

The PDFs were converted to text with `pdftotext` before review:

```powershell
pdftotext -layout -enc UTF-8 -- <lecture.pdf> <lecture.txt>
```

The review also covered `R/app_ui.R`, `R/app_server.R`,
`R/climate_module.R`, `R/girafe_helpers.R`, `R/climate_helpers.R`,
`inst/app/www/style.css`, the packaged data, documentation, and tests.

Important limitation: this is an expert review, not a substitute for observing
real users. The task-analysis, prototyping, user-testing, and heuristic-
evaluation lectures all recommend validating design assumptions with target
users.

## What already works well

- The app has a consistent visual language and reusable panel/KPI components.
- Active price filters are summarized in a visible context line, and a reset
  control is available.
- Interactive plots provide useful tooltips, while most outputs have explicit
  empty-data messages.
- The Trends view fills missing periods before plotting, so gaps are not
  silently connected.
- The Climate view uses progressive disclosure: overview maps first, then
  trends, lag relationships, and methodology on demand.
- Climate limitations and provenance are unusually clear. The interface says
  that lag correlations are exploratory rather than causal and explains what
  NDVI does and does not measure.
- Clicking a climate map can select a county, which is a good direct-
  manipulation pattern.
- The automated test suite passes under R 4.6.1 with `--vanilla`, and the most
  recent stored `R CMD check` result is `Status: OK`.

These are strong foundations. The main need is to make the data comparisons,
control scope, and accessibility as careful as the climate methodology.

## Priority 0: fix before adding more features

### 1. Make price aggregation statistically fair and explicit

**Problem**

Most price summaries use a raw mean of all matching records. This affects the
overview trend, KPIs, top-county and top-market lists, geographic comparison,
map, and comparison charts (`R/app_server.R`). A market with many observations
therefore has more influence than one with few observations.

The packaged data confirms that this is material:

- market record counts range from 5 to 1,755;
- county record counts range from 6 to 7,441;
- only 25 counties and 225 markets appear in the price data.

Consequently, “Highest Average Prices by County” can partly mean “highest
average among the particular dates and markets sampled most often.” It is not
necessarily a like-for-like county price comparison.

**Improve it**

1. Define one documented default estimator. A defensible option is:
   market-month median -> county-month median -> national monthly median.
2. Add a small `Calculation` control with plain-language choices such as
   `Balanced median` and `Record-weighted mean`; default to the balanced view.
3. Put the estimator in chart subtitles/tooltips and beside each “average” KPI.
4. For county/market rankings, require a minimum record/month threshold and
   show the number of covered months, not only total records.
5. Offer an indexed or inflation-adjusted view for the 2006-2026 time span.
   Comparing nominal KES levels across two decades without this option can be
   misleading.
6. Use the same aggregation contract throughout the app. The Climate module
   already uses county-month medians, so it currently disagrees with most other
   price views.

**Acceptance criteria**

- Two locations with identical monthly prices receive equal weight regardless
  of their raw row counts.
- Every displayed statistic states its estimator and coverage.
- Changing the estimator updates all related KPIs, charts, tables, and maps.

**MIT connection:** task analysis, output design, information visualization,
experiment analysis, and heuristic evaluation (Lectures 7, 11, 15, 19, 23).

### 2. Correct the meaning of “month change”

**Problem**

The Overview KPI compares the latest row with the previous *available* row
(`R/app_server.R:338-343`). If one or more months are absent, it still labels
the result “Month change.” The recent-change tables use the same assumption.

This is a visibility and correctness problem: the interface can present a
multi-month change as a one-month change.

**Improve it**

- Complete the monthly sequence before calculating changes.
- If the immediately preceding calendar month is missing, show `Not available`
  for month-on-month change.
- Alternatively label the value `Change since <month>` and show the elapsed
  number of months.
- Apply the same rule to price-change inputs used by climate analysis.

**Acceptance criteria**

- “Month change” is only displayed when two consecutive calendar months exist.
- Missing periods are visible in both the chart and the summary values.

**MIT connection:** visibility of system state, error prevention, and honest
output (Lectures 3, 5, 11, 23).

### 3. Make control scope obvious

**Problem**

The global filter band is rendered above every top-level tab
(`R/app_ui.R:13-35, 49-52`). On the Climate tab, commodity controls affect only
the lower price analysis, while climate month/county controls affect the maps.
The existing explanatory sentence helps, but users must still reason about two
different filter systems in one view.

There is also duplicate geography state: the global County filter and the
Climate `Focus county` selector can disagree.

**Improve it**

- Separate **global price context** from **controls for this view**.
- Show active global filters as removable chips, including an explicit scope
  label such as `Applies to: price panels`.
- On Climate, visually group climate controls with the maps and price controls
  with the price/climate analysis, or synchronize the county selections.
- Hide or disable irrelevant controls on views where they have no effect.
- Preserve selections when navigating, but provide a clear `Reset this view`
  and `Reset all` distinction.

**Acceptance criteria**

- A first-time user can correctly predict which outputs each control changes.
- No two county selectors silently represent conflicting states.

**MIT connection:** learnability, visibility, user control, and UI architecture
(Lectures 2, 3, 5, 9).

### 4. Establish an accessibility baseline

**Problem**

The UI has visible focus styling, but important gaps remain:

- the page lacks a skip link and explicit `main`, `nav`, and complementary
  landmarks;
- charts depend heavily on hover tooltips and SVG/Plotly interaction;
- chart selections are primarily mouse-oriented;
- up/down status is reinforced mainly by red/green KPI border color;
- custom toggle targets are only 32 px high (`style.css:619-630`);
- loading and validation changes are not exposed as live status messages;
- most charts do not have an adjacent text summary or equivalent data table;
- the fixed 520-620 px map heights are burdensome on small screens.

**Improve it**

1. Add a “Skip to main content” link and semantic page landmarks.
2. Give each panel a programmatic heading relationship and each visualization
   a short text description of its current takeaway.
3. Verify every control and tab with keyboard-only navigation. If ggiraph map
   regions cannot be operated reliably by keyboard, keep the synchronized
   county selector and accessible table as equivalent controls.
4. Announce loading, errors, filter resets, and updated result counts through
   an `aria-live` status region without stealing focus.
5. Never use color alone. Add arrows/words for changes, direct labels or line
   styles for series, and explicit category labels for map conditions.
6. Increase interactive targets to at least 44 by 44 CSS pixels and test at
   200% zoom, narrow mobile width, high contrast, and reduced motion.
7. Run automated accessibility checks, followed by NVDA keyboard/screen-reader
   testing; automation alone is insufficient.

**Acceptance criteria**

- All primary tasks are possible without a mouse.
- The current filters, loading state, validation messages, and key chart result
  are understandable with a screen reader.
- Meaning survives grayscale and common color-vision deficiencies.

**MIT connection:** input, color/typography, accessibility, and input/output
technology (Lectures 12, 20, 21, 25).

## Priority 1: improve task flow and interpretation

### 5. Organize navigation around user questions

The current top-level navigation exposes six implementation-oriented sections:
Overview, Trends, Map, Climate, Compare, and Coverage. Before changing it,
interview likely users—such as market analysts, food-security staff,
researchers, and journalists—and identify their frequent questions.

A candidate task-centered structure is:

- **Prices:** overview, trends, and market map;
- **Compare:** counties and commodities;
- **Climate and prices:** current conditions, trends, and lag exploration;
- **Data coverage and methods:** coverage, definitions, downloads, and sources.

Provide one short first-run orientation with a meaningful default such as a
common staple and recent period. Avoid a long instruction block; use concise,
contextual help beside unfamiliar terms such as NDVI, z-score, volatility, and
seasonality index.

**MIT connection:** user-centered design, task analysis, generating designs,
and prototyping (Lectures 6-8, 17).

### 6. Put coverage beside every conclusion

Coverage currently has its own tab, while the strongest claims appear on other
tabs. Users should not have to remember to cross-check a separate page.

- Add a subtle coverage strip below time charts showing records/markets by
  month, or provide a `Show coverage` layer.
- Flag low-coverage periods and incomplete county comparisons in place.
- Show first/latest observation and covered-month count in rankings.
- Distinguish `No observation` from a zero value.
- Explain that price data covers 25 of Kenya's 47 counties for the current
  packaged dataset, while climate maps cover all 47.

This follows the information-visualization principle of overview first, then
zoom/filter, then details on demand—without hiding essential quality context.

### 7. Strengthen direct manipulation and reversible exploration

- Clicking a market on the map should highlight and scroll to its table row;
  clicking a table row should highlight the map point.
- Clicking a county or series should filter related panels only after the app
  visibly indicates the new state.
- Add `Clear selection` beside selected map/series states.
- Let users brush or zoom a time range, with a one-step reset.
- Preserve a shareable URL or bookmark for the active filters and tab.

These changes improve feedback and exploration while keeping actions easily
reversible (Lectures 3, 5, 19).

### 8. Clarify climate-map categories

`climate_condition()` defines five named condition bands, but the maps render a
continuous gradient (`R/girafe_helpers.R:148-157`). Meanwhile,
`CLIMATE_IMPLEMENTATION.md` says the design uses fixed condition bins. Choose
one approach and make implementation, legend, tooltips, and documentation
agree.

For operational interpretation, five labeled bins are likely easier:
`Much below normal`, `Below normal`, `Near normal`, `Above normal`, and
`Much above normal`. Show the numeric z-score on demand. Use a palette checked
for contrast and color-vision deficiencies, with selected-county emphasis that
does not depend only on a colored outline.

### 9. Improve small-screen layout

- Collapse the global filter band into a clear `Filters (n active)` disclosure
  on small screens.
- Replace fixed visualization heights with responsive aspect ratios and
  sensible minimum/maximum heights.
- Stack chart/table pairs in the order needed for the task, not merely their
  desktop column order.
- Keep the sticky filter band from consuming the viewport at tablet widths.
- Test long commodity/county labels, landscape phones, 200% zoom, and the
  navbar's collapsed state.

### 10. Make errors actionable

Current validation messages describe missing data but rarely tell users how to
recover. Prefer messages such as:

> No retail maize observations are available for Garissa in Jan-Jun 2026.
> Try all markets, broaden the date range, or reset the county filter.

Retain the user's selections, identify the constraint that caused the empty
result, and provide a nearby recovery action. Do not silently substitute a
different selection.

## Priority 2: product and engineering quality

### 11. Validate the redesign with users

Run lightweight studies before and after implementation:

1. Interview 5-8 people across the intended user groups.
2. Write observable tasks, for example: “Find whether maize prices in Nairobi
   rose in the latest consecutive month and judge whether coverage is enough to
   trust the change.”
3. Sketch at least three navigation/filter alternatives before coding.
4. Test a low-fidelity prototype, then a working prototype.
5. Measure task completion, time, errors, recovery, and confidence; collect
   post-task comments.
6. Conduct an independent heuristic evaluation with severity ratings.

Instrument only events tied to these questions—filter changes, empty results,
task completion, and reset use—rather than collecting analytics without a
decision plan.

### 12. Add UI, accessibility, and data-contract tests

The current tests cover helpers and map construction, but
`tests/testthat/test-app.R` is still the placeholder `2 * 2 = 4` test.

Add tests for:

- dependent filter choices and reset behavior;
- consecutive-month change rules;
- the documented aggregation contract;
- low/no-coverage messages and recovery actions;
- global versus local filter scope;
- selected county synchronization;
- keyboard navigation and accessible names;
- responsive screenshots at desktop, tablet, and phone widths;
- stable output given a small fixture dataset with intentionally unequal
  market coverage.

### 13. Fix environment and integration hygiene

- `renv::status()` reports that the lockfile was generated with R 4.5.0 while
  the current runtime is R 4.6.1, that `Rcpp` is out of sync, and that many used
  packages are not recorded. Audit and refresh the lockfile deliberately.
- In this environment, starting R through `.Rprofile`/`renv` consumed CPU for
  several minutes, while the full tests passed in about 14 seconds with
  `Rscript --vanilla`. Profile `renv` activation and remove unnecessary startup
  work.
- The Google Analytics loader uses `G-XXXXXXXXXX`, while `gtag('config', ...)`
  uses a different real ID (`R/app_ui.R:252-260`). Use one configured ID or
  remove analytics. Document privacy/consent expectations.
- Remove unused UI/CSS remnants such as `output$category_ui`, `.kfp-welcome`,
  and `#quarto-header` after confirming they have no consumers.
- Rename `main_price_histogram`; it renders an annual range chart, not a
  histogram.
- Move hard-coded labels and month/date formatting into a translation layer.
  This prepares the app for Kiswahili and avoids locale assumptions
  (internationalization, Lecture 22).

## Suggested implementation sequence

### Phase 1: trustworthy output

1. Define and test the aggregation contract.
2. Fix consecutive-month calculations.
3. Put coverage and calculation labels beside every major output.
4. Resolve the continuous-versus-binned climate-map discrepancy.

### Phase 2: understandable control model

1. Separate global and view-specific controls.
2. Synchronize or remove duplicate county state.
3. Add filter chips, scope labels, and actionable empty states.
4. Prototype the task-centered navigation with users.

### Phase 3: accessible interaction

1. Add landmarks, skip navigation, live status, text chart summaries, and
   larger targets.
2. Make map/chart selection keyboard operable and visibly reversible.
3. Complete screen-reader, zoom, contrast, reduced-motion, and mobile testing.

### Phase 4: durable delivery

1. Add Shiny interaction, accessibility, responsive, and data-contract tests.
2. Repair `renv` consistency and startup performance.
3. Clean analytics configuration, dead code, and translation readiness.

## Definition of done for the improvement program

- Users can explain which filters affect which outputs without assistance.
- “Month change” never spans more than one calendar month.
- Rankings and trends use a documented, coverage-aware estimator.
- Key tasks work with keyboard and screen reader and at 200% zoom.
- Every important chart has a concise takeaway and accessible data equivalent.
- Empty states identify the active constraint and offer a recovery action.
- Usability tests show improved completion, fewer errors, and greater
  confidence for the priority tasks.
- Automated tests enforce these behavior and accessibility contracts.
