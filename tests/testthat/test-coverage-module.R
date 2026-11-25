test_that("annual coverage retains dates and the distinct missing-market count", {
  price_records <- data.table::data.table(
    year = c(2026L, 2025L, 2026L, 2026L),
    date = as.Date(c("2026-02-01", "2025-12-01", "2026-01-01", "2026-03-01")),
    county = c("Nairobi", "Kiambu", NA_character_, "Nairobi"),
    market = c("A", "B", NA_character_, NA_character_)
  )
  initial_records <- data.table::copy(price_records)

  annual <- summarise_annual_coverage(price_records)

  expect_identical(annual$year, c(2025L, 2026L))
  expect_identical(annual$records, c(1L, 3L))
  expect_identical(annual$counties, c(1L, 1L))
  expect_identical(annual$markets, c(1L, 2L))
  expect_identical(
    annual$first_date,
    as.Date(c("2025-12-01", "2026-01-01"))
  )
  expect_identical(
    annual$latest_date,
    as.Date(c("2025-12-01", "2026-03-01"))
  )
  expect_identical(summarise_annual_coverage(price_records[0L]), annual[0L])
  expect_identical(price_records, initial_records)
})
