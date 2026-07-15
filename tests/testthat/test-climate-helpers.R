test_that("county names are normalised for reliable joins", {
  expect_equal(
    normalise_county_name(c("Nairobi City", "Taita/Taveta", "Tharaka-Nithi County")),
    c("nairobi", "taitataveta", "tharakanithi")
  )
})

test_that("JMR climate values reshape and aggregate predictably", {
  jmr <- data.table::data.table(
    adm2_pcode = rep(c("KE001001", "KE001002"), each = 4),
    date = as.Date("2025-01-01"),
    indicator = rep(c(
      "Drought - NDVI", "Drought - NDVI",
      "Drought - rainfall", "Drought - rainfall"
    ), 2),
    grouping = rep(c("Original value", "Indicator value"), 4),
    value = c(0.5, -0.5, 20, -1, 0.7, 0.5, 40, 1)
  )
  pcodes <- data.table::data.table(
    adm1_pcode = "KE001",
    adm1_name = "Mombasa",
    adm2_pcode = c("KE001001", "KE001002"),
    adm2_name = c("Changamwe", "Jomvu")
  )

  adm2 <- prepare_jmr_climate(jmr, pcodes)
  county <- aggregate_climate_to_county(adm2)

  expect_equal(nrow(adm2), 2)
  expect_equal(county$rainfall_mm, 30)
  expect_equal(county$rainfall_z, 0)
  expect_equal(county$ndvi, 0.6)
  expect_equal(county$ndvi_z, 0)
  expect_equal(county$subcounties, 2)
})

test_that("lag correlations report both climate drivers", {
  dates <- seq(as.Date("2020-01-01"), by = "month", length.out = 30)
  rainfall <- seq_len(30)
  data <- data.table::data.table(
    date = dates,
    rainfall_z = rainfall,
    ndvi_z = rev(rainfall),
    price_change = data.table::shift(rainfall, 2, type = "lag")
  )

  result <- lagged_climate_correlations(data, max_lag = 3)

  expect_equal(sort(unique(result$driver)), c("Rainfall", "Vegetation"))
  expect_equal(sort(unique(result$lag_months)), 0:3)
  expect_true(all(result$observations >= 25))
})
