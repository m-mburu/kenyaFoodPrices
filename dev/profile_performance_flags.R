# Local generation costs and filter dependency checks.
# Run from the project root; timings exclude network and browser work.
pkgload::load_all(".", quiet = TRUE)
ns <- asNamespace("kenyaFoodPrices")
get_helper <- function(name) get(name, envir = ns)
prices <- get_helper("app_food_prices")()
climate <- get_helper("app_climate")()
geometry <- get_helper("prepare_climate_geometry")(
  get_helper("app_counties")(), climate$county_lookup
)
month <- max(climate$county_monthly$date)
values <- climate$county_monthly[date == month]
ix <- match(geometry$adm1_pcode, values$adm1_pcode)
for (field in c("rainfall_mm", "rainfall_z", "ndvi", "ndvi_z")) {
  geometry[[field]] <- values[[field]][ix]
}
geometry$rainfall_condition <- get_helper("climate_condition")(
  geometry$rainfall_z
)
geometry$ndvi_condition <- get_helper("climate_condition")(geometry$ndvi_z)
cat("R:", R.version.string, "\n")
cat("Price rows:", nrow(prices), "month:", as.character(month), "\n")
cat("County coordinates:", nrow(sf::st_coordinates(geometry)), "\n")
cat("Missing latest-month NDVI:", sum(is.na(values$ndvi)), "\n")
subset <- prices[commodity == "Maize" & unit == "90 KG" &
                   pricetype == "Wholesale"]
cat("Price subset:", nrow(subset), "\n")
for (i in 1:3) {
  elapsed <- system.time(get_helper("aggregate_price_data")(
    subset, "price", "balanced_median"
  ))[["elapsed"]]
  cat("Aggregate", i, elapsed, "\n")
}
# Measure the protective copy separately before changing its ownership rule.
elapsed <- system.time({
  for (i in seq_len(100L)) invisible(data.table::copy(subset))
})[["elapsed"]]
cat("Price subset copy, mean seconds:", elapsed / 100, "\n")
if (capabilities("profmem")) {
  allocation_log <- tempfile()
  utils::Rprofmem(allocation_log)
  invisible(data.table::copy(subset))
  utils::Rprofmem(NULL)
  allocations <- suppressWarnings(as.numeric(sub(
    " .*", "", readLines(allocation_log)
  )))
  cat("Price subset copy, allocated bytes:",
      sum(allocations, na.rm = TRUE), "\n")
  unlink(allocation_log)
}
for (type in c("rainfall", "vegetation")) {
  for (i in 1:3) {
    elapsed <- system.time({
      plot <- get_helper("climate_map_plot")(
        geometry, type, FALSE, month, climate$county_monthly
      )
      widget <- get_helper("standard_girafe")(plot, 6.8, 6.4)
    })[["elapsed"]]
    cat(type, i, elapsed, nchar(widget$x$html, type = "bytes"), "\n")
  }
}
# Compare a lighter SVG and the current Leaflet layer on identical values.
display_geometry <- get_helper("prepare_climate_geometry")(
  get_helper("app_display_counties")(), climate$county_lookup
)
for (field in c("rainfall_mm", "rainfall_z", "ndvi", "ndvi_z")) {
  display_geometry[[field]] <- geometry[[field]]
}
display_geometry$rainfall_condition <- geometry$rainfall_condition
display_geometry$ndvi_condition <- geometry$ndvi_condition
cat("Display coordinates:", nrow(sf::st_coordinates(display_geometry)),
    "\n")
for (type in c("rainfall", "vegetation")) {
  for (i in 1:3) {
    elapsed <- system.time({
      plot <- get_helper("climate_map_plot")(
        display_geometry, type, FALSE, month, climate$county_monthly
      )
      widget <- get_helper("standard_girafe")(plot, 6.8, 6.4)
    })[["elapsed"]]
    cat("Display SVG", type, i, elapsed,
        nchar(widget$x$html, type = "bytes"), "\n")
    elapsed <- system.time({
      style <- get_helper("climate_leaflet_style")(
        display_geometry, type, FALSE, month, climate$county_monthly
      )
      widget <- get_helper("climate_leaflet_widget")(
        as.numeric(sf::st_bbox(display_geometry))
      )
      widget <- get_helper("add_climate_leaflet_values")(
        widget, display_geometry, style, "national"
      )
    })[["elapsed"]]
    layer_bytes <- nchar(jsonlite::toJSON(
      widget$x, auto_unbox = TRUE, digits = 16, force = TRUE
    ), type = "bytes")
    cat("Leaflet layer", type, i, elapsed, layer_bytes, "\n")
  }
}
# Profile complete detail loading before introducing county partitions.
elapsed <- system.time(wards <- get_helper("app_wards")())[["elapsed"]]
cat("Cold wards:", elapsed, "seconds; object bytes:",
    as.numeric(object.size(wards)), "\n")
elapsed <- system.time({
  county_wards <- wards[wards$county_key == "mombasa", ]
})[["elapsed"]]
cat("Mombasa wards:", elapsed, "seconds; object bytes:",
    as.numeric(object.size(county_wards)), "\n")
# Isolate the module's dependency contract from browser output scheduling.
shiny::testServer(get_helper("filters_module_server"), args = list(
  food_prices = prices
), {
  session$setInputs(category = "cereals and tubers", commodity = "Maize",
    unit = "90 KG", pricetype = "Wholesale", Currency = "price",
    calculation = "balanced_median", page1_county = "All",
    page1_market = "All", page1_date = range(subset$date))
  calls <- 0L
  consumer <- shiny::reactive({
    calls <<- calls + 1L
    fields$calculation()
  })
  invisible(consumer())
  session$setInputs(Currency = "usdprice")
  invisible(consumer())
  session$setInputs(page1_market = "Nairobi")
  invisible(consumer())
  cat("Calculation-only consumer evaluations:", calls, "\n")
})
