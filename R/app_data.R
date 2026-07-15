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
    utils::data("kenya_counties", package = "kenyaFoodPrices", envir = .app_data_cache)
    data.table::setDT(.app_data_cache$kenya_counties)
  }

  .app_data_cache$kenya_counties
}
