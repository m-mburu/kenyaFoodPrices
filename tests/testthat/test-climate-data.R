test_that("packaged climate data has current county coverage", {
  climate <- app_climate()

  expect_s3_class(climate$county_monthly, "data.table")
  expect_s3_class(climate$county_lookup, "data.table")
  expect_equal(data.table::uniqueN(climate$county_lookup$adm1_pcode), 47)
  expect_equal(
    climate$county_monthly[, data.table::uniqueN(adm1_pcode), by = date]$V1,
    rep(47L, data.table::uniqueN(climate$county_monthly$date))
  )
  expect_true(all(climate$county_monthly$rainfall_mm >= 0))
  expect_true(all(data.table::between(climate$county_monthly$ndvi, -1, 1)))
})

test_that("all existing county polygons match a climate P-code", {
  climate <- app_climate()
  geometry <- prepare_climate_geometry(app_counties(), climate$county_lookup)

  expect_equal(nrow(geometry), 47)
  expect_false(anyNA(geometry$adm1_pcode))
  expect_equal(data.table::uniqueN(geometry$adm1_pcode), 47)
  expect_equal(sf::st_crs(geometry)$epsg, 4326)
})
