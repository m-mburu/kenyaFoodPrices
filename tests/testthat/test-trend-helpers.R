fixture_trend_monthly <- function() {
  data.table::data.table(
    year_month_date = as.Date(c(
      "2026-01-01", "2026-02-01", "2026-03-01", "2026-05-01"
    )),
    mean_price = c(10, 20, 30, 50),
    observations = c(2L, 3L, 4L, 5L),
    counties = 1L,
    markets = 2L
  )
}

test_that("monthly smoothing completes gaps and preserves source estimates", {
  monthly <- fixture_trend_monthly()
  original <- data.table::copy(monthly)

  result <- prepare_trend_series(monthly, "month", "smooth")

  expect_equal(result$period, seq(
    as.Date("2026-01-01"), as.Date("2026-05-01"), by = "month"
  ))
  expect_equal(result$mean_price, c(10, 20, 30, NA_real_, 50))
  expect_equal(result$display_price, c(NA_real_, NA_real_, 20,
                                     NA_real_, NA_real_))
  expect_equal(result$covered_months, c(1L, 1L, 1L, NA_integer_, 1L))
  expect_equal(monthly, original)
})

test_that("quarterly series keep absent quarters and partial coverage", {
  monthly <- fixture_trend_monthly()
  monthly <- monthly[year_month_date != as.Date("2026-05-01")]
  later <- data.table::copy(monthly[1L])
  later[, year_month_date := as.Date("2026-07-01")]
  later[, mean_price := 90]
  monthly <- data.table::rbindlist(list(monthly, later))

  result <- prepare_trend_series(monthly, "quarter", "raw")

  expect_equal(result$period, as.Date(c(
    "2026-01-01", "2026-04-01", "2026-07-01"
  )))
  expect_equal(result$mean_price, c(20, NA_real_, 90))
  expect_equal(result$display_price, result$mean_price)
  expect_equal(result$covered_months, c(3L, NA_integer_, 1L))
  expect_equal(result$observations, c(9L, NA_integer_, 2L))
})

test_that("quarterly smoothing operates on quarters rather than records", {
  monthly <- data.table::data.table(
    year_month_date = seq(
      as.Date("2026-01-01"), as.Date("2026-09-01"), by = "month"
    ),
    mean_price = seq(10, 90, by = 10),
    observations = seq_len(9L),
    counties = 1L,
    markets = 2L
  )

  result <- prepare_trend_series(monthly, "quarter", "smooth")

  expect_equal(result$mean_price, c(20, 50, 80))
  expect_equal(result$display_price, c(NA_real_, NA_real_, 50))
  expect_equal(result$covered_months, rep(3L, 3L))
})
