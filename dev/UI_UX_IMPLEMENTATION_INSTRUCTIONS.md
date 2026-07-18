# Instructions for implementing the UI/UX improvement review

## Mission

Implement `dev/UI_UX_IMPROVEMENTS.md` in safe, testable phases. Treat it as
the product and usability specification. Do not merely summarize it or make
cosmetic changes. Improve the application's data contract, interaction model,
accessibility, tests, and delivery quality while preserving the existing
Shiny/golem architecture and working features.

The work is complete only when the relevant acceptance criteria in the review
are enforced by tests or documented manual verification. Prepare items that
require real user research for validation; never claim they were validated
without evidence.

## Read before editing

1. Read `dev/UI_UX_IMPROVEMENTS.md` completely.
2. Read any repository `AGENTS.md` instructions.
3. Inspect `R/app_ui.R`, `R/app_server.R`, `R/app_data.R`,
   `R/climate_module.R`, `R/girafe_helpers.R`, `R/climate_helpers.R`,
   `inst/app/www/style.css`, all tests, `README.Rmd`,
   `CLIMATE_IMPLEMENTATION.md`, `DESCRIPTION`, and `renv.lock`.
4. Inspect `git status` and preserve unrelated user changes.
5. Run the current tests and record the baseline before changing behavior.

## Supported R runtime and project environment

- Use R 4.5.3 as the supported development, test, build, and check runtime.
- On Windows, `R.exe` and `Rscript.exe` for R 4.5.3 are available on `PATH`.
  Confirm this with `R.exe --version` and `Rscript.exe --version` before the
  baseline run; do not silently run the work with an older R installation.
- Use `Rscript.exe --vanilla` for environment diagnostics and dependency
  recovery so a broken project profile cannot hide the underlying error.
- Restore the project library from the committed lockfile without depending on
  profile activation: `Rscript.exe --vanilla -e "project <-
  normalizePath('.'); renv::restore(project = project, library =
  renv::paths[['library']](project = project), prompt = FALSE)"`.
  If `renv` itself is unavailable, bootstrap it first with
  `Rscript.exe --vanilla -e "install.packages('renv', repos =
  'https://cloud.r-project.org')"`, then run the restore command.
- After restoration, verify normal project activation with
  `Rscript.exe -e "renv::status()"`. Investigate a slow or failed activation;
  do not work around it permanently by disabling `renv`.
- Install project dependencies through `renv::restore()`. Use the scripts in
  `dev/` only for their documented workflow/tooling purpose; they include
  packages that are not part of the application lockfile.
- The committed `renv.lock` currently records R 4.5.0. Reconcile its R metadata
  to 4.5.3 deliberately after `renv::status()` is clean. Review the lockfile
  diff and avoid upgrading unrelated package records.

## Working rules

- Maintain a written plan and complete one phase at a time.
- Prefer `data.table` over `dplyr` for shared helpers and tests. See https://rdatatable.gitlab.io/data.table/articles/datatable-programming.html  https://rdatatable.gitlab.io/data.table/articles/datatable-intro.html
- Prefer shared helpers with explicit contracts over duplicated reactives.
- Use fixture data in tests; never depend on live external APIs.
- Do not silently change source data, geography, currency, or climate methods.
- Do not present association as causation.
- Do not claim WCAG conformance from automated tests alone.
- Preserve filter context, resets, tooltips, visible missing periods, climate
  methodology notes, and clickable climate maps.
- Update `README.Rmd`, not generated README content alone.
- Add dependencies to `DESCRIPTION` only when necessary and explain why.
- Do not refresh `renv.lock` blindly.

## Required implementation sequence

### Phase 0: baseline and behavioral contracts

1. Run `Rscript.exe --vanilla -e
   "renv::load(); testthat::test_local(reporter = 'summary')"` with R 4.5.3.
2. Add a fixture with two counties, multiple markets, unequal record counts,
   consecutive and missing months, two price types, and two commodities.
3. Write failing tests for aggregation and consecutive-month contracts first.
4. Record input/output IDs that must stay compatible, or document migrations.

### Phase 1: trustworthy price output

Implement Priority 0 items 1-2 and Priority 1 item 6 first.

#### Central aggregation contract

Create pure shared helpers instead of calculating raw means in each output.
Unless the owner selects another estimator, the default is:

1. market-month median;
2. county-month median of market values;
3. national-month median of county values.

Retain an explicitly named record-weighted mean option. Add a `Calculation`
input with stable values such as `balanced_median` and
`record_weighted_mean`.

Each result must provide the estimate, record count, market count, county
count, covered-month count where relevant, and estimator label. Route Overview,
Trends, rankings, geographic comparison, map, Compare, and Climate price data
through this contract. Any intentional exception must be visible and
documented.

Put estimator and coverage labels beside outputs. Add minimum coverage rules
to rankings and state when a location is excluded. Tests must prove that two
locations with identical monthly values receive equal weight despite unequal
raw row counts.

#### Consecutive-month calculations

Create a helper that completes the monthly sequence before calculating change.
Label a value month-on-month only when the immediately preceding calendar month
exists. Otherwise render `Not available` or explicitly label the longer gap as
`Change since <month>`.

Use this in Overview, Trends, recent-change tables, and climate lag inputs.
Test consecutive months, missing months, zero previous price, non-finite values,
and the first observation.

#### Coverage and climate categories

Add reusable coverage metadata beside every price conclusion. Distinguish no
observation from zero and disclose the different price/climate geographic
coverage.

Resolve the mismatch between `climate_condition()`, the continuous map, and
`CLIMATE_IMPLEMENTATION.md`. Prefer five labeled bins for the default condition
map, retain z-scores in details, use a color-vision-safe palette, and add a
non-color selection cue. Update tests and documentation together.

### Phase 2: understandable controls and recovery

Implement Priority 0 item 3 and Priority 1 items 7 and 10.

1. Distinguish global price context from controls local to a view.
2. Render selections as removable filter chips with a scope label.
3. Synchronize the global County and Climate `Focus county`, or remove the
   duplicate state. Never allow silent disagreement.
4. Hide, disable, or relabel controls that do not affect the active view.
5. Provide distinct `Reset this view` and `Reset all` behavior.
6. Preserve selections across tabs.
7. Link map/table selection in both directions where practical, show selection
   visibly, and provide `Clear selection`.
8. Make empty states name the constraint and offer a recovery action.

Add server tests for dependent filters, scope, county synchronization, resets,
empty states, and recovery. Do not rename the entire navigation solely from the
review's candidate structure. Prototype it and document the user-testing
questions first; safe grouping and contextual-help changes can proceed.

### Phase 3: accessibility and responsive interaction

Implement Priority 0 item 4 and Priority 1 item 9.

- Add a visible-on-focus skip link, `nav`/`main`/complementary landmarks, one
  page-level heading, logical heading order, and programmatic panel names.
- Add an unobtrusive `aria-live` region for loading completion, result counts,
  validation errors, resets, and selection changes. Do not move focus during
  ordinary reactive updates.
- Give every important chart a concise text summary and accessible data
  equivalent.
- Verify keyboard operation of tabs, controls, tables, maps, and plots. Where
  SVG regions are unreliable, the synchronized selector/table is the equivalent
  path.
- Never encode meaning with color alone; add words, arrows, shapes, line styles,
  or direct labels.
- Increase targets to at least 44 by 44 CSS pixels.
- Replace fixed visualization heights with bounded responsive rules.
- Collapse mobile filters behind `Filters (n active)` and prevent sticky
  controls from consuming the viewport.
- Support `prefers-reduced-motion` for nonessential effects.
- Verify 320 CSS-pixel width, landscape phone, tablet, desktop, and 200% zoom.

Run automated accessibility checks where available, but keep a manual checklist
for NVDA, keyboard-only use, high contrast, color vision, zoom, and reduced
motion. Report automated and manual results separately.

### Phase 4: durable delivery

1. Replace the placeholder multiplication test in `test-app.R` with real app
   tests and add interaction tests for Phases 1-3.
2. Add responsive visual regression tests only if reproducible in CI.
3. Run `Rscript.exe -e "renv::status()"` and deliberately reconcile the
   lockfile's R metadata to R 4.5.3, any `Rcpp` mismatch, and used but
   unrecorded packages. Do not accept package-version changes unrelated to the
   reconciliation.
4. Profile `.Rprofile`/`renv` activation. Tests must not consume CPU for
   several minutes before starting.
5. Replace conflicting Google Analytics IDs with one configured value, or
   remove analytics. Never expose secrets; document privacy/consent behavior.
6. Remove dead UI/CSS only after proving it is unused.
7. Rename misleading internals such as `main_price_histogram`, preserving
   public output IDs where compatibility matters.
8. Introduce a label/translation layer and locale-aware dates. Prepare the
   structure for Kiswahili, but obtain reviewed translations separately.

## Verification gates

At the end of every phase:

1. Run focused tests for the changed contract.
2. Run `Rscript.exe --vanilla -e
   "renv::load(); testthat::test_local(reporter = 'summary')"`.
3. Run an app smoke test with representative filters.
4. Inspect desktop and mobile layouts.
5. Run `git diff --check` and review unrelated/generated changes.

Before handoff, build and check the package with R 4.5.3 using `R.exe CMD build
.` and `R.exe CMD check <tarball>`. The target is `R CMD check` without errors,
warnings, or notes unless a pre-existing exception is documented.

## Required handoff

For each phase report the user-visible outcome, files changed, contracts
introduced, tests and exact commands, manual checks, known limitations, and
items deferred for user research or manual accessibility testing.

Do not say “all improvements implemented” while a Priority 0 acceptance
criterion is unmet. Do not say “accessible” without listing the automated and
manual checks actually completed.

## Final definition of done

- Price outputs use one documented, coverage-aware estimator contract.
- Month-on-month never spans a missing calendar month.
- Users can predict which controls affect which outputs.
- Empty states explain how to recover.
- Key tasks are keyboard-operable with non-visual equivalents.
- Responsive behavior works at narrow widths and 200% zoom.
- Tests enforce the new data and interaction contracts.
- Package checks pass.
- Research-dependent decisions are explicitly documented, not guessed.
