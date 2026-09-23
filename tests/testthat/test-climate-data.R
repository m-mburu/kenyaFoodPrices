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

test_that("ADM2 climate rows reconstruct the packaged county estimates", {
  climate <- app_climate()
  areas <- climate$subcounty_monthly
  counties <- climate$county_monthly

  expect_equal(data.table::uniqueN(areas$adm2_pcode), 290L)
  expect_equal(data.table::uniqueN(areas$date), 200L)
  expect_true(all(
    areas[, .N, by = date]$N == 290L
  ))
  expect_equal(
    data.table::uniqueN(areas$adm1_pcode),
    47L
  )
  expect_true(all(areas$rainfall_mm >= 0, na.rm = TRUE))
  expect_true(all(
    data.table::between(areas$ndvi, -1, 1),
    na.rm = TRUE
  ))

  source_mean <- function(values) {
    if (all(is.na(values))) {
      return(NA_real_)
    }
    mean(values, na.rm = TRUE)
  }
  reconstructed <- areas[
    ,
    lapply(.SD, source_mean),
    by = .(date, adm1_pcode),
    .SDcols = c("rainfall_mm", "rainfall_z", "ndvi", "ndvi_z")
  ]
  matched <- counties[
    reconstructed,
    on = .(date, adm1_pcode)
  ]
  expect_equal(nrow(matched), nrow(counties))
  for (field in c("rainfall_mm", "rainfall_z", "ndvi", "ndvi_z")) {
    expect_equal(matched[[field]], matched[[paste0("i.", field)]])
  }
})

test_that("COD polygons join to distinct ADM2 values without filling gaps", {
  climate <- app_climate()
  boundaries <- app_cod_subcounties()
  areas <- climate$subcounty_monthly

  expect_s3_class(boundaries, "sf")
  expect_equal(nrow(boundaries), 290L)
  expect_setequal(boundaries$adm2_pcode, unique(areas$adm2_pcode))
  expect_true(all(sf::st_is_valid(boundaries)))

  july <- areas[date == as.Date("2026-07-01")]
  mombasa <- prepare_subcounty_map_values(
    boundaries,
    july,
    "KE001"
  )
  expect_true(nrow(mombasa) > 1L)
  expect_equal(
    mombasa$rainfall_mm,
    july$rainfall_mm[
      match(mombasa$adm2_pcode, july$adm2_pcode)
    ]
  )
  expect_true(data.table::uniqueN(mombasa$rainfall_mm) > 1L)

  august <- areas[date == as.Date("2026-08-01")]
  local <- prepare_subcounty_map_values(
    boundaries,
    august,
    "KE001"
  )
  expect_true(all(is.na(local$ndvi)))
  expect_false(all(is.na(local$ndvi_z)))
})
