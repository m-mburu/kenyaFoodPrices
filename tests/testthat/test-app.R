test_that("the app UI exposes calculation and accessibility contracts", {
  ui <- app_ui(NULL)
  markup <- paste(as.character(ui), collapse = "\n")

  expect_s3_class(ui, "shiny.tag.list")
  expect_match(markup, "balanced_median")
  expect_match(markup, "Skip to main content")
  expect_match(markup, "main-content")
  expect_match(markup, "aria-live")
})

test_that("visualizations use responsive frames instead of fixed pixel heights", {
  html <- paste(as.character(app_ui(NULL)), collapse = "\n")

  expect_match(html, "kfp-viz-frame")
  expect_false(grepl('height=\"(300|330|410|430|520|620)px\"', html))
})

test_that("compact tables let people choose how many rows to show", {
  widget <- datatable_compact(data.frame(value = seq_len(12)), page_length = 6)
  options <- widget$x$options

  expect_identical(options$pageLength, 6)
  expect_match(options$dom, "l")
  expect_equal(options$lengthMenu[[1]], c(6L, 10L, 25L, -1L))
  expect_equal(options$lengthMenu[[2]], c("6", "10", "25", "All"))
})

test_that("incomplete reset date ranges cannot enter price filters", {
  expect_false(valid_price_date_range(NULL))
  expect_false(valid_price_date_range(as.Date(NA)))
  expect_false(valid_price_date_range(as.Date(c(
    "2006-01-15", NA
  ))))
  expect_false(valid_price_date_range(as.Date(c(
    "2026-01-01", "2006-01-15"
  ))))
  expect_true(valid_price_date_range(as.Date(c(
    "2006-01-15", "2026-08-15"
  ))))
})

test_that("overview change labels handle direction and missing comparisons", {
  expect_equal(format_price_comparison(-0.147), "14.7% lower")
  expect_equal(format_price_comparison(0.05), "5.0% higher")
  expect_equal(format_price_comparison(0), "Unchanged")
  expect_equal(format_price_comparison(NA_real_), "Not available")
})

test_that("trends page leads with one chart and optional detail", {
  html <- paste(as.character(app_ui(NULL)), collapse = "\n")

  expect_match(html, "Price over time")
  expect_match(html, "Trailing 3-period average")
  expect_match(html, "Select a period")
  expect_match(html, "Reference period")
  expect_match(html, "Comparison period")
  expect_match(html, "Seasonal pattern")
  expect_match(html, "Compare locations")
})

test_that("trend period helpers keep explicit labels and safe percentages", {
  trend <- data.table::data.table(
    period = as.Date(c("2026-01-01", "2026-04-01")),
    mean_price = c(100, 125),
    covered_months = c(2L, 3L)
  )

  quarterly_choices <- trend_period_choices(trend, quarterly = TRUE)

  expect_identical(
    names(quarterly_choices),
    c("Q2 2026 (3 months)", "Q1 2026 (2 months)")
  )
  expect_identical(
    unname(quarterly_choices),
    c("2026-04-01", "2026-01-01")
  )
  expect_equal(trend_percent_change(100, 125), 0.25)
  expect_true(is.na(trend_percent_change(0, 125)))
})

test_that("quarterly points average observed months and keep empty gaps", {
  monthly <- data.table::data.table(
    year_month_date = as.Date(c(
      "2026-01-01", "2026-03-01", "2026-04-01", "2026-07-01"
    )),
    mean_price = c(100, 200, NA_real_, 400),
    observations = c(1L, 2L, NA_integer_, 3L),
    counties = c(1L, 2L, NA_integer_, 1L),
    markets = c(1L, 2L, NA_integer_, 1L)
  )

  result <- quarterly_trend_data(monthly)
  expect_equal(result$mean_price, c(150, NA_real_, 400))
  expect_equal(result$covered_months, c(2L, 0L, 1L))
  expect_true(is.na(result$counties[2L]))
  expect_true(is.na(result$markets[2L]))
})
