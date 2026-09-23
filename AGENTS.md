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
