# Filter and map performance implementation

Implemented on `refactor/modularise-dashboard`, 3 October 2026. Changes are
local; the public application has not been deployed.

## Changes

1. **Independent dependencies.** `filters$fields` exposes separate reactives
   for each input. Price-page consumers read those directly; the complete
   selection remains for the summary. Currency and calculation changes no
   longer recreate commodity-comparison controls.
2. **Separate display geometry.** Maps use `kenya_counties_display.rda`, derived
   from GADM 4.1. Original analytical boundaries remain unchanged. Coverage
   simplification uses EPSG:6933 and a 1,000 m tolerance parameter. This
   parameter controls removed triangle area; it is not a maximum displacement
   guarantee. All 47 identifiers, polygon components, valid/non-empty shapes,
   shared coverage and representative click locations were checked. See
   [Shapely's coverage simplifier](https://shapely.readthedocs.io/en/stable/reference/shapely.coverage_simplify.html).
3. **Persistent controls.** Inputs are created once and updated from shared
   scoped subsets. Valid choices survive upstream changes. Dates retain their
   overlap with available observations, or use full coverage when there is no
   overlap. Reset explicitly restores defaults. First valid updates are
   processed. Default-selection names avoid `data.table` column shadowing.
4. **Incremental Climate maps.** Leaflet's
   [proxy API](https://rstudio.github.io/leaflet/reference/leafletProxy.html)
   updates focused layers and bounds without rebuilding widgets or resending
   the national layer on county changes. Month/measure changes replace value
   layers and legends while retaining the extent; individual styles are not
   patched separately. Hidden Climate panels defer updates. Global County,
   dropdowns and map clicks synchronise through canonical identifiers.
   ADM2 colours retain source sub-county measurements; ward outlines remain
   reference geometry. Price and climate estimators are preserved.
5. **Profile before partitioning or removing copies.** Loading all simplified
   wards took 0.047 seconds and occupied 1.89 MB; Mombasa's subset was about
   41 KB and took less than the timer resolution. County partitions would add
   files and loading logic without a measured benefit, so process caching
   remains. A protective copy of the 1,148-row price subset averaged 0.00005
   seconds over 100 repetitions and allocated 234,400 bytes in `Rprofmem()`.
   Copies protecting shared tables therefore remain. The existing price
   aggregation was much cheaper than original map generation.

## Measurements

Run from the project root:

```sh
/usr/bin/Rscript --vanilla dev/profile_performance_flags.R
```

The comparison uses identical August 2026 county observations, national extent
and actual-value colours on R 4.5.3, with three consecutive local runs. August
NDVI values are missing; missing fills and source condition values are kept
separate.

| Operation | Elapsed seconds | Uncompressed representation per map |
| --- | --- | --- |
| Original rainfall SVG, initial audit | 0.35–0.43 | 7,793,259 bytes |
| Display rainfall SVG | 0.145–0.205 | 203,571 bytes |
| Leaflet rainfall layer | 0.045–0.051 | 322,691 JSON bytes |
| Display vegetation SVG | 0.146–0.151 | 204,434 bytes |
| Leaflet vegetation layer | 0.042–0.044 | 322,817 JSON bytes |

Coordinates fell from 322,136 to 5,818, about 98.2%. Rainfall SVG bytes fell
about 97.4% on the same representation. Leaflet JSON describes widget data and
polygon calls, excluding library assets, protocol overhead and compression.
SVG and JSON are different representations; these are not measured wire bytes
or production latency.

The calculation-only consumer now evaluates once across initialisation,
currency change and market change combined, versus three times previously.
Maize / Wholesale / 90 KG aggregation on 1,148 records took about 0.03 seconds.

## Verification

- All 11 R test files pass. Tests cover valid defaults, empty choices, date
  overlap/non-overlap, source measurements, missing fills, distinct map legends,
  retained geometry parts and identifiers.
- Captured proxy calls show no national polygons on county focus or return to
  Kenya. Repeated selection sends no updates. Month/measure changes retain
  bounds; hidden panels defer work and receive pending values when shown.
  Missing price observations retain climate focus; unavailable reference
  outlines display an explanation while the measured climate layer remains.
- Chrome checks passed: custom comparison selections survive currency and
  calculation changes; controls retain their DOM objects; Reset restores
  defaults; dropdowns and map clicks synchronise; Mombasa zoom and return to
  Kenya work; month/measure changes retain focus; ward outlines appear.
- Map widget output counts stay unchanged during focus. One local focus check
  reached synchronised controls/summary in about 0.25 seconds. This is one
  observation, not a benchmark or final-paint timing.
- Inspected 1440 px desktop and 390/320 px phones. Initial phone filters collapse;
  legends fit; no page-level horizontal overflow or settled Shiny errors appeared.
- R syntax, new R line widths, JavaScript syntax and `git diff --check` pass.
  The package source build and new dataset documentation also pass.

Screenshots: [county comparison](performance_checks/county_geometry_comparison.png),
[desktop maps](performance_checks/climate_maps_desktop.png),
[phone maps](performance_checks/climate_maps_phone.png).

Production latency, concurrent-session capacity and a complete accessibility
review remain unmeasured. After deployment, compare warm interactions,
compressed payloads and server metrics against the hosted baseline.

## Rebuild and dependencies

Leaflet 2.2.3 and its missing dependencies are recorded in `renv.lock`.
`htmlwidgets` and `htmltools` are direct imports. Maps request no external tiles.
Other dashboard plots retain their existing widgets.

Python is needed only to rebuild the packaged display artifact after a GADM
refresh, not to run the app:

```sh
KFP_PYTHON_BIN=/home/mburu/miniconda3/bin/python \
  /usr/bin/Rscript --vanilla data-raw/build_county_display_geometry.R
```

The build requires Shapely 2.1+ and GEOS 3.12+. It rejects invalid coverage,
changed identifiers, lost components and displaced representative click points.
Repeat geometry tests and visual checks after a boundary refresh.
