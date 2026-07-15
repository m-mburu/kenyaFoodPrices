test_that("standard_girafe supports single county selection", {
  plot <- ggplot2::ggplot(
    data.frame(x = 1, y = 1, id = "KE001"),
    ggplot2::aes(x, y)
  ) +
    ggiraph::geom_point_interactive(ggplot2::aes(data_id = id))

  widget <- standard_girafe(
    plot,
    width_svg = 4,
    height_svg = 3,
    selectable = TRUE,
    selected = "KE001"
  )

  expect_s3_class(widget, "girafe")
  expect_equal(widget$x$settings$select$type, "single")
  expect_equal(widget$x$settings$select$selected, "KE001")
})

test_that("climate choropleths render without raster dependencies", {
  climate <- app_climate()
  map_sf <- prepare_climate_geometry(
    app_counties(),
    climate$county_lookup
  )
  values <- climate$county_monthly[date == max(date)]
  row_index <- match(map_sf$adm1_pcode, values$adm1_pcode)

  for (field in c("rainfall_mm", "rainfall_z", "ndvi", "ndvi_z")) {
    map_sf[[field]] <- values[[field]][row_index]
  }
  map_sf$rainfall_condition <- climate_condition(map_sf$rainfall_z)
  map_sf$ndvi_condition <- climate_condition(map_sf$ndvi_z)

  rainfall <- climate_map_plot(
    map_sf,
    type = "rainfall",
    condition_view = TRUE,
    selected_date = max(values$date),
    climate_monthly = climate$county_monthly
  )
  vegetation <- climate_map_plot(
    map_sf,
    type = "vegetation",
    condition_view = FALSE,
    selected_date = max(values$date),
    climate_monthly = climate$county_monthly
  )

  expect_s3_class(rainfall, "ggplot")
  expect_s3_class(vegetation, "ggplot")
  expect_equal(nrow(rainfall$data), 47L)
  expect_equal(nrow(vegetation$data), 47L)
})

test_that("market map renders as a girafe widget", {
  markets <- data.table::data.table(
    market = "Nairobi",
    county = "Nairobi",
    latitude = -1.2864,
    longitude = 36.8172,
    avg_price = 100,
    latest_date = as.Date("2026-01-01"),
    records = 12L
  )

  widget <- market_price_map(
    markets,
    counties = app_counties(),
    price_unit = "KES/KG",
    currency = "KES"
  )

  expect_s3_class(widget, "girafe")
})
