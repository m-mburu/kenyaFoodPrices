fixture_prices <- function() {
  data.table::data.table(
    year_month_date = as.Date(c(
      rep("2025-01-01", 6), "2025-02-01", "2025-02-01", "2025-04-01", "2025-04-01"
    )),
    county = c(rep("Alpha", 5), "Beta", "Alpha", "Beta", "Alpha", "Beta"),
    market = c(rep("A market", 5), "C market", "B market", "C market", "A market", "C market"),
    price = c(rep(10, 5), 30, 30, 30, 20, 40),
    usdprice = c(rep(1, 5), 3, 3, 3, 2, 4)
  )
}

test_that("balanced aggregation gives locations equal monthly weight", {
  aggregated <- aggregate_price_data(fixture_prices(), "price", "balanced_median")

  january <- aggregated$national_month[year_month_date == as.Date("2025-01-01")]
  expect_equal(january$estimate, 20)
  expect_equal(january$records, 6)
  expect_equal(january$markets, 2)

  february <- aggregated$national_month[year_month_date == as.Date("2025-02-01")]
  expect_equal(february$estimate, 30)
  expect_equal(february$counties, 2)
})

test_that("record-weighted mean remains explicitly available", {
  aggregated <- aggregate_price_data(fixture_prices(), "price", "record_weighted_mean")
  january <- aggregated$national_month[year_month_date == as.Date("2025-01-01")]
  expect_equal(january$estimate, 80 / 6)
})

test_that("month changes only exist for consecutive observations", {
  monthly <- data.table::data.table(
    year_month_date = as.Date(c("2025-01-01", "2025-02-01", "2025-04-01")),
    estimate = c(10, 15, 20), records = 1L
  )
  result <- complete_monthly_changes(monthly)

  expect_true(result[year_month_date == as.Date("2025-02-01"), consecutive_month])
  expect_equal(result[year_month_date == as.Date("2025-02-01"), change], 5)
  expect_false(result[year_month_date == as.Date("2025-04-01"), consecutive_month])
  expect_true(is.na(result[year_month_date == as.Date("2025-04-01"), change]))
  expect_true(is.na(result[year_month_date == as.Date("2025-03-01"), estimate]))
})

test_that("zero and non-finite prior values never produce a percentage change", {
  monthly <- data.table::data.table(
    year_month_date = as.Date(c("2025-01-01", "2025-02-01")),
    estimate = c(0, 5)
  )
  result <- complete_monthly_changes(monthly)
  expect_true(is.na(result[2, percent_change]))
})
