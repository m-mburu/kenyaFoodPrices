# Climate implementation notes

## Outcome

The application now includes a Climate tab that puts two county choropleths
first: rainfall conditions and vegetation greenness. A shared month selector
keeps the maps comparable. County selection, historical trends, lagged
climate-price associations, recent values, and methodology are available on
demand below the maps.

## Download and source contract

The refresh pipeline is implemented in `data-raw/climate_dataset.R`. It calls
the World Bank bulk-file manifest for study
`KEN_2010-2025_JMR_v01_M`, identifies resources by filename rather than a
hard-coded resource ID, and downloads:

- `KEN_JMR_data.zip`: original and transformed JMR indicator values.
- `KEN_JMR_pcodes.zip`: current OCHA COD ADM1/ADM2 names and P-codes.
- `KEN_JMR_model_details.zip`: transformations and alert thresholds.

The Kenya bulk files are preferable to the global table API because the global
table contains about 19 million rows. The country file is smaller, versioned,
and documented on the [Kenya JMR catalog page](https://microdata.worldbank.org/catalog/8115).

Rainfall originates from WFP's CHIRPS-based rainfall indicators. NDVI
originates from WFP's MODIS Collection 6.1 vegetation indicators. The World
Bank JMR provides the transformation to current Kenya COD ADM2 geography.

## Processing

The pipeline performs the following repeatable steps:

1. Validate the manifest response and expected resource filenames.
2. Download each ZIP to a temporary working directory.
3. Verify that each archive contains exactly one CSV and read it with
   `data.table::fread()`.
4. Keep only rainfall and NDVI `Original value` and `Indicator value` rows.
5. Reshape the long JMR values to one ADM2-month row containing:
   `rainfall_mm`, `rainfall_z`, `ndvi`, and `ndvi_z`.
6. Join and validate all 290 ADM2 P-codes.
7. Summarise ADM2 indicators to all 47 counties using an unweighted mean and
   retain coverage counts.
8. Store source URLs, source version, coverage dates, processing description,
   and model details alongside the values.
9. Validate ranges and county coverage before saving the package dataset.

The county mean is an overview statistic, not an area-weighted physical
estimate. This is stated in the application metadata. ADM2 values remain the
right future extension if more spatial detail is required.

To refresh the packaged data from the project root:

```r
source("data-raw/climate_dataset.R")
```

## Shiny data structure

The resulting `data/kenya_climate.rda` is approximately 116 KB and contains a
single list named `kenya_climate`:

| Element | Structure | Purpose |
|---|---|---|
| `county_monthly` | `data.table`, 9,259 rows | Map and trend values for 47 counties, January 2010–May 2026 |
| `county_lookup` | `data.table`, 47 rows | ADM1 P-code and normalized county-name joins |
| `model_details` | `data.table` | JMR rainfall/NDVI transformations and thresholds |
| `metadata` | named list | Source, version, coverage and processing provenance |

Package-local accessors cache this list and the existing county geometry once
per R process. The Shiny module receives the existing filtered price reactive
rather than reading or copying the full price dataset again.

## UI and interaction decisions

- Overview first: source explanation, controls, summary cards and maps appear
  before analytical detail.
- Details on demand: trend, lag relationship, and data/method views use a
  secondary tabset.
- Map comparisons default to JMR standardized conditions so unlike months and
  counties are comparable. Physical rainfall and NDVI values remain available
  in tooltips and through the Actual levels option.
- Fixed condition bins and distinct, accessible palettes communicate dry/wet
  and stressed/green conditions. Missing values are grey.
- Clicking either map focuses the county used by the detailed plots.
- `ggiraph` renders the county polygons as interactive SVG, with tooltips and single-county click selection shared across rainfall and vegetation maps.
- Price analysis uses the active commodity filters and county-month medians to
  avoid markets with more records dominating the result.

## Implementation observations

- The original WFP downloads contain 8 ADM1 and 73 ADM2 WFP aggregation units;
  their P-code references must not be forced onto the modern 47-county shapes.
  The harmonized JMR geography resolves that mismatch.
- JMR rainfall `Original value` is average rainfall per dekad in millimetres;
  JMR NDVI `Original value` is average normalized vegetation greenness.
- The standardized indicators are more appropriate for an overview map than
  raw levels because Kenyan rainfall and vegetation are strongly seasonal.
- The browser review showed a clear 3-by-2 KPI layout at tablet width, two
  balanced maps, readable legends, and the trend view below the fold. On small
  screens Bootstrap stacks the map columns and the custom KPI grid collapses.
- NDVI covers crops, grassland, shrubland and forest. It is a vegetation and
  crop-condition proxy, not a direct crop-yield measure.
- Lag correlations are exploratory. Imports, exchange rates, storage,
  transport, policy and general inflation can dominate household commodity
  prices, especially for non-local or processed products.

## Verification

Automated tests cover transformations, P-code completeness, indicator ranges,
county geometry matching, and lag-correlation output. A Shiny module smoke test
also exercises summary, trend, and lag outputs using filtered maize prices.
