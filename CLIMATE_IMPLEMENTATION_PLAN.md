# Climate implementation plan for a small-context model

## Instruction to the implementing model

**Follow this plan strictly, in order. Complete one step per work session.**
Read this overview and only the current step, named files, and applicable
repository guidance. Do not load the whole repository or all guidance files.
At the end of a step, record a short hand-off: files changed, commands run,
results, remaining issue, and the next step. Stop that session. The next
session starts from the hand-off and this plan. Do not start an unrelated
redesign, data refresh, deployment, or dependency update.

`CLIMATE_IMPLEMENTATION.md` describes a feature that has **already been
implemented** in this checkout. Its data counts and end date are a snapshot,
not an instruction to roll the package back. Your job is to check the stated
contract against the current code, repair any actual gaps, and verify the
result. Mark a step **already satisfied** with evidence when no edit is needed.
Preserve later improvements already in the app, especially focused county
maps, source-level COD ADM2 values, and reference-only GADM ward outlines.
Do not copy the old description's claim that all price filters affect the
climate price series; verify the actual filter contract before changing it.

Do not infer completion from file names or this plan alone. Use the relevant
focused test and an app check where the step concerns interactive behaviour.
If a gate fails, fix that step before moving on. If a source or dependency is
unavailable, record the exact blocker and continue only with independent work.

## Project context: read this once

`kenyaFoodPrices` is an R package with a Shiny dashboard. Food prices are
packaged locally. The Climate tab compares rainfall and vegetation conditions
on two county maps, then offers trend, lag-association, data and method views.
The source is the World Bank Kenya Joint Food Security Monitor (JMR): its
rainfall and NDVI indicators originate with WFP and are harmonised to Kenya's
COD ADM2 geography. County monthly values are **unweighted means** of source
ADM2 values. The app also retains actual ADM2 monthly measurements for focused
sub-county maps. GADM boundaries provide geographic context; ward outlines
are **not ward-level measurements**. Lag correlations are associations, not
causal estimates.

Core files and their jobs:

| File | Job |
| --- | --- |
| `CLIMATE_IMPLEMENTATION.md` | Original outcome, source and processing contract. |
| `data-raw/climate_dataset.R` | Download three JMR bulk ZIPs, build packaged data. |
| `R/climate_helpers.R` | Normalise source schemas, aggregate, compute lag statistics. |
| `data/kenya_climate.rda` | Packaged climate list: `county_monthly`, `subcounty_monthly`, `county_lookup`, `model_details`, `metadata`. |
| `R/app_data.R` | Process-local data and boundary accessors. |
| `R/climate_module.R` | Climate UI, selections, maps, trends and methods. |
| `R/girafe_helpers.R` | County and focused-area map plotting. |
| `R/app_ui.R`, `R/app_server.R` | Insert module and pass filtered price data. |
| `inst/app/www/style.css` | Layout and responsive styling. |
| `tests/testthat/test-climate-helpers.R` | Transformation and lag checks. |
| `tests/testthat/test-climate-data.R` | Packaged data, identifiers and geometry checks. |
| `tests/testthat/test-girafe-maps.R` | Map rendering and value joins. |

Use `/usr/bin/Rscript --vanilla` for R commands. Before reviewing or editing R,
read `/home/mburu/.codex/guidance/r-style.md`. Before writing explanatory copy
in the user's voice, read `/home/mburu/.codex/guidance/writing-voice.md`.
Read `/home/mburu/.codex/guidance/mathematics.md` if changing notation or
its rendering. If investigating a repeated failure, read
`/home/mburu/.codex/guidance/root-cause-analysis.md`. Follow repository
`AGENTS.md`. The project uses `data.table`; keep R code within 80 characters
and preserve British English labels. Respect existing uncommitted changes.

Use `pkgload::load_all(".")` when testing the checkout. An installed package
may differ. Prefer fixture and packaged-data checks over downloading the feed
in routine tests. Any JMR refresh must check the **current** source manifest
and schema before replacing `data/kenya_climate.rda`; do not assume dates or
row counts in the original note remain current.

## Step 0 — Establish the baseline and gap list

**Read:** `CLIMATE_IMPLEMENTATION.md`; the headings and named functions in
`R/climate_helpers.R`, `R/climate_module.R`, `data-raw/climate_dataset.R`;
`git status --short`. Inspect tests by test title only. Do not dump whole files.

**Do:** Make a short checklist for the original contract: three source ZIPs;
legacy long/current wide handling; COD P-codes; physical values and condition
scores; 47-county summaries; provenance; two maps/shared month; county focus;
trends/lag/method panels; responsive layout. For each item note the owner file,
existing evidence and any actual gap. Record currently packaged coverage from
the data, not the note's January 2010–May 2026 snapshot. Preserve the newer
`subcounty_monthly` list element, which the old note omits.

**Gate:** Each contract item is `satisfied`, `gap`, or `unverified`, with one
specific reason. If all are satisfied, proceed through the verification gates
without editing code. Do not invent tasks to fill later steps.

## Step 1 — Source acquisition contract

**Read:** only `data-raw/climate_dataset.R` and the source section of
`CLIMATE_IMPLEMENTATION.md`.

**Do if a gap exists:** Confirm the current JMR manifest lists the named
`KEN_JMR_data.zip`, `KEN_JMR_pcodes.zip` and
`KEN_JMR_model_details.zip` for the configured study. Select by filename,
check uniqueness, download to a temporary directory, reject empty downloads
and archives without exactly one CSV, and retain source URLs/version details.
Keep network I/O out of Shiny filter reactions. Do not run a full refresh merely
to check the code path.

**Gate:** Manifest/ZIP behaviour is checked with focused fixtures or an
explicit live source check. The result either names all three current files
or reports which source contract has changed. No packaged data is overwritten
on an unverified download.

## Step 2 — Pure climate transformations

**Read:** `R/climate_helpers.R` and
`tests/testthat/test-climate-helpers.R`. Limit inspection to the transformation
functions and their tests.

**Do if a gap exists:** Accept the documented legacy long fields and current
wide `year`, `month`, `drought_ndvi_original`,
`drought_rainfall_original` schema. Build one valid ADM2-month row with
`rainfall_mm`, `rainfall_z`, `ndvi`, `ndvi_z`. For wide data, standardise within
ADM2 and calendar month; handle zero variance and missing values explicitly.
Reject duplicate ADM2-month keys, invalid dates, unmatched P-codes and
implausible physical ranges. Keep conditions separate from physical levels.

**Gate:** Run `testthat::test_file("tests/testthat/test-climate-helpers.R")`
after loading the checkout, or the equivalent focused package test if needed.
Fixtures cover both schemas, duplicates, missing values, and county means.
Report the actual test result, not just that a test command was started.

## Step 3 — Packaged data and provenance

**Read:** `data-raw/climate_dataset.R`, `R/doc_kenya_climate.R` and
`tests/testthat/test-climate-data.R` only.

**Do if a gap exists:** Build `county_monthly`, `subcounty_monthly`,
`county_lookup`, `model_details` and `metadata`. Check 47 unique ADM1 codes,
all expected ADM2 identifiers against the **current** P-code file, one row per
geography-month, valid rainfall/NDVI ranges and equal reconstruction of county
means from ADM2 values. Keep coverage counts and source dates. Avoid treating
one old fixed count of months or rows as a permanent invariant. Save with
`usethis::use_data()` only after all checks pass. Update data documentation to
match the actual object. A live refresh is needed only for a demonstrated
data gap, not as routine plan execution.

**Gate:** Run the focused packaged-data test. Verify the saved object loads
through `pkgload::load_all(".")` and the metadata matches its contents.

## Step 4 — Geography and data access

**Read:** `R/app_data.R`, the geometry helpers in `R/climate_module.R`, and
the geometry tests in `tests/testthat/test-climate-data.R`.

**Do if a gap exists:** Match all county polygons to the COD ADM1 P-codes by
validated county names. Keep geometry in EPSG:4326 for display and reuse the
process-local accessors. Source COD ADM2 polygons must join to JMR ADM2 values
by exact P-code. Treat GADM level 2/3 as optional local reference outlines;
verify parent county matching, and never colour GADM wards with county or ADM2
values. Prepare lightweight display boundaries ahead of deployment. Avoid
fetching boundary files on a filter change.

**Gate:** Every county joins once, required polygons are valid/non-empty,
source ADM2 polygons and value codes match, and only the selected county's
local outlines are sent for focused detail. Run the affected geometry tests.

## Step 5 — Climate UI shell and filter contract

**Read:** the UI half of `R/climate_module.R`, the Climate insertion in
`R/app_ui.R`, and the call to `climate_module_server()` plus
`base_filtered_data` in `R/app_server.R`.

**Do if a gap exists:** Keep one shared month selector and one canonical county
identifier for both maps. Put source/controls/maps before secondary trend,
lag and method views. Make the price filter scope explicit: commodity, price
type, unit and currency affect the price analysis; they do not recolour the
climate data. The climate price series currently uses `balanced_median`
regardless of the global calculation control, and the module receives price
data before the global county/market filters. Preserve this contract or make
a separate, explicit product decision with matching labels and tests. Never
silently imply those selectors affect climate prices if they do not.

**Gate:** Render the module UI from the checkout; check all IDs are namespaced,
all input labels are readable, and the Climate tab does not duplicate data
loading. Verify a price-only filter does not alter either climate map.

## Step 6 — Maps, focus and measurement labels

**Read:** the map-related functions in `R/climate_module.R`,
`climate_map_plot()` in `R/girafe_helpers.R`, and
`tests/testthat/test-girafe-maps.R`.

**Do if a gap exists:** For a shared month, render rainfall and NDVI with
matched geography and a common county focus. Condition mode uses standardised
scores and fixed, distinct legends; actual mode uses physical values and
units. Show missing observations separately. County selection or a map click
must update both maps, related titles and detail views. All Kenya restores the
national extent. Focused sub-county colour may use JMR ADM2 values only when
matched to COD ADM2 polygons; ward outlines remain reference geometry. Guard
against selector feedback loops and unnecessary full SVG redraws. Retain
keyboard/touch access to map information through another view.

**Gate:** Map tests pass; manual checks cover selector and click agreement,
All Kenya, repeated selection, month/measure changes, sparse values and both
map modes. Measure map payloads if changing the render path. Do not claim a
performance improvement without a comparable before/after measure.

## Step 7 — Summary, trends and lag analysis

**Read:** only the lower server half of `R/climate_module.R`,
`lagged_climate_correlations()` in `R/climate_helpers.R`, and their focused tests.

**Do if a gap exists:** Keep monthly climate and price dates aligned.
Price analysis uses valid filtered records and its stated balanced median
estimator; the global county focus is applied separately. Compute monthly
price changes only for consecutive months with valid positive prices before
log change. Standardise the displayed price-change series as labelled.
Calculate lagged Spearman associations using paired, non-missing months and
report sample counts; make no causal claim. Preserve no-data messages and
source/aggregation method text. Explain dekad and NDVI in ordinary language.

**Gate:** Check a known county and All Kenya against independently inspected
rows; test a missing month, no price records, and too few paired months.
Focused transformation tests pass. The panel's units, dates and estimator
match the underlying values.

## Step 8 — Integration and final verification

**Read:** only files changed in steps 1–7, their focused tests, and relevant
style rules. Use `git diff --stat` to find changes. Do not reread all source.

**Do:** Run focused tests first, then the package's applicable checks. Start
the app from the checkout and inspect desktop, tablet and phone sizes. Check
both maps, county selection, back to Kenya, month and measure switches,
price filter scope, tabs, loading and missing-data messages, and keyboard
focus. Check that a settled change does not trigger repeated map rebuilds.
Review the relevant `AGENTS.md` verification guidance. Run `git diff --check`
and inspect the exact changed payload. Update `CLIMATE_IMPLEMENTATION.md` only
for corrected current behaviour, provenance or verified observations; do not
replace its history with unmeasured claims.

**Gate:** Report satisfied contract items, changes made, exact tests and browser
checks, remaining limitations, and any source refresh or deployment that was
not performed. If Step 0 found no gaps and all gates pass, say clearly that
no implementation edits were needed. Do not mark this plan complete solely
because code exists.

## Hand-off format after each step

Keep this to six short lines in the working model's response or a temporary
handoff note, so a new small-context session can resume without a full recap:

```text
Step: N — satisfied / changed / blocked
Evidence: one file/function or observed value
Files changed: exact paths, or none
Validation: exact command and pass/fail, or not run with reason
Open issue: one concrete issue, or none
Next: step N+1 and its first file
```
