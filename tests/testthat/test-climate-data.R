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
  # NDVI is occasionally missing for a whole month in the source feed; check
  # the observed values are within the physical [-1, 1] range rather than
  # requiring every month to be present.
  expect_true(all(data.table::between(climate$county_monthly$ndvi, -1, 1), na.rm = TRUE))
})

test_that("all existing county polygons match a climate P-code", {
  climate <- app_climate()
  geometry <- prepare_climate_geometry(app_counties(), climate$county_lookup)

  expect_equal(nrow(geometry), 47)
  expect_false(anyNA(geometry$adm1_pcode))
  expect_equal(data.table::uniqueN(geometry$adm1_pcode), 47)
  expect_equal(sf::st_crs(geometry)$epsg, 4326)
})


test_that("county names resolve to their own climate P-codes", {
  lookup <- app_climate()$county_lookup

  expect_equal(county_pcode_for_name("All", lookup), "All")
  expect_equal(county_pcode_for_name("Mombasa", lookup), "KE001")
  expect_equal(county_pcode_for_name("Garissa", lookup), "KE007")
  expect_equal(county_pcode_for_name("Nairobi", lookup),
               county_pcode_for_name("Nairobi City", lookup))
})
