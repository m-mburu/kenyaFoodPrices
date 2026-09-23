# Package-local cache for app datasets.
.app_data_cache <- new.env(parent = emptyenv())

app_food_prices <- function() {
  if (!exists("ke_food_prices", envir = .app_data_cache, inherits = FALSE)) {
    utils::data("ke_food_prices", package = "kenyaFoodPrices", envir = .app_data_cache)
    data.table::setDT(.app_data_cache$ke_food_prices)
  }

  .app_data_cache$ke_food_prices
}

app_climate <- function() {
  if (!exists("kenya_climate", envir = .app_data_cache, inherits = FALSE)) {
    utils::data("kenya_climate", package = "kenyaFoodPrices", envir = .app_data_cache)
    data.table::setDT(.app_data_cache$kenya_climate$county_monthly)
    data.table::setDT(.app_data_cache$kenya_climate$county_lookup)
    data.table::setDT(.app_data_cache$kenya_climate$model_details)
  }

  .app_data_cache$kenya_climate
}

app_counties <- function() {
  if (!exists("kenya_counties", envir = .app_data_cache, inherits = FALSE)) {
    # Prefer the GADM county layer (valid WGS84 EPSG:4326, `county` +
    # `geometry` columns). Fall back to the legacy `kenya_counties` layer,
    # which is stored in UTM zone 37S and needs its CRS declared before use.
    has_gadm <- tryCatch({
      utils::data("kenya_counties_gadm", package = "kenyaFoodPrices", envir = .app_data_cache)
      "kenya_counties_gadm" %in% ls(envir = .app_data_cache, all.names = TRUE)
    }, error = function(e) FALSE)

    if (isTRUE(has_gadm)) {
      counties <- data.table::as.data.table(.app_data_cache$kenya_counties_gadm)
      .app_data_cache$kenya_counties_gadm <- NULL
    } else {
      utils::data("kenya_counties", package = "kenyaFoodPrices", envir = .app_data_cache)
      counties <- data.table::copy(.app_data_cache$kenya_counties)
      geom <- counties$geometry
      if (is.na(sf::st_crs(geom))) {
        sf::st_crs(geom) <- 17037
      }
      counties$geometry <- sf::st_transform(geom, 4326)
    }

    # Cache as a data.table with an sfc list-column so downstream helpers can
    # coerce to sf with a known column name and CRS.
    .app_data_cache$kenya_counties <- counties
  }

  .app_data_cache$kenya_counties
}
