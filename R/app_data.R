# Package-local cache for app datasets.
.app_data_cache <- new.env(parent = emptyenv())

app_food_prices <- function() {
  if (!exists("ke_food_prices", envir = .app_data_cache, inherits = FALSE)) {
    utils::data("ke_food_prices", package = "kenyaFoodPrices", envir = .app_data_cache)
    data.table::setDT(.app_data_cache$ke_food_prices)
  }

  .app_data_cache$ke_food_prices
}
