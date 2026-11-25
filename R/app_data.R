# Package-local cache for app datasets.
.app_data_cache <- new.env(parent = emptyenv())

#' Load packaged food-price observations on first use
#'
#' @return The cached data.table of observation-level prices. Copy it before
#'   modifying it by reference.
#' @noRd
app_food_prices <- function() {
  if (!exists("ke_food_prices", envir = .app_data_cache, inherits = FALSE)) {
    utils::data("ke_food_prices", package = "kenyaFoodPrices", envir = .app_data_cache)
    data.table::setDT(.app_data_cache$ke_food_prices)
  }

  .app_data_cache$ke_food_prices
}

#' Load the packaged rainfall and vegetation data on first use
#'
#' @return A cached list containing county-month and ADM2-month tables, the
#'   county lookup, model details and provenance.
#' @noRd
app_climate <- function() {
  if (!exists("kenya_climate", envir = .app_data_cache, inherits = FALSE)) {
    utils::data(
      "kenya_climate",
      package = "kenyaFoodPrices",
      envir = .app_data_cache
    )
    data.table::setDT(.app_data_cache$kenya_climate$county_monthly)
    data.table::setDT(.app_data_cache$kenya_climate$subcounty_monthly)
    data.table::setDT(.app_data_cache$kenya_climate$county_lookup)
    data.table::setDT(.app_data_cache$kenya_climate$model_details)
  }

  .app_data_cache$kenya_climate
}

#' Load county boundaries for spatial use
#'
#' @return A cached data.table with county names and WGS84 geometry. Uses GADM
#'   when available and transforms the legacy layer as a fallback.
#' @noRd
app_counties <- function() {
  if (!exists("kenya_counties", envir = .app_data_cache, inherits = FALSE)) {
    # Prefer the GADM county layer (valid WGS84 EPSG:4326, `county` +
    # `geometry` columns). Fall back to the legacy `kenya_counties` layer,
    # which is stored in UTM zone 37S and needs its CRS declared before use.
    has_gadm <- tryCatch({
      utils::data(
        "kenya_counties_gadm",
        package = "kenyaFoodPrices",
        envir = .app_data_cache
      )
      "kenya_counties_gadm" %in% ls(envir = .app_data_cache, all.names = TRUE)
    }, error = function(e) FALSE)

    if (isTRUE(has_gadm)) {
      counties <- data.table::as.data.table(.app_data_cache$kenya_counties_gadm)
      .app_data_cache$kenya_counties_gadm <- NULL
    } else {
      utils::data(
        "kenya_counties",
        package = "kenyaFoodPrices",
        envir = .app_data_cache
      )
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

# Lightweight national map geometry, separate from analytical boundaries.
#' Load the simplified county layer used by the national maps
#'
#' @return The cached sf polygons prepared for display.
#' @noRd
app_display_counties <- function() {
  if (!exists("kenya_counties_display", envir = .app_data_cache,
              inherits = FALSE)) {
    utils::data(
      "kenya_counties_display",
      package = "kenyaFoodPrices",
      envir = .app_data_cache
    )
  }

  .app_data_cache$kenya_counties_display
}

# Normalise a county name for matching (lowercase, strip punctuation/spaces).
#' Prepare county names for matching across boundary sources
#'
#' @param x County names.
#' @return A character vector of lower-case keys with spaces and punctuation
#'   removed.
#' @noRd
county_name_key <- function(x) {
  gsub("[^a-z0-9]", "", tolower(trimws(x)))
}

# Simplified sub-county boundaries (GADM level 2), with a `county_key` derived
# from the parent county name for joining to the app's county lookup.
#' Load simplified GADM level-2 outlines for map context
#'
#' @return An sf layer with parent county keys, or NULL when the optional
#'   dataset cannot be loaded.
#' @noRd
app_subcounties <- function() {
  if (!exists("kenya_subcounties", envir = .app_data_cache, inherits = FALSE)) {
    .app_data_cache$kenya_subcounties <- tryCatch({
      utils::data(
        "kenya_subcounties_gadm_simplified",
        package = "kenyaFoodPrices",
        envir = .app_data_cache
      )
      sc <- .app_data_cache$kenya_subcounties_gadm_simplified
      .app_data_cache$kenya_subcounties_gadm_simplified <- NULL
      sc$county_key <- county_name_key(sc$NAME_1)
      sf::st_set_geometry(sc, "geometry")
    }, error = function(e) NULL)
  }

  .app_data_cache$kenya_subcounties
}

# Simplified ward boundaries (GADM level 3). Loaded on demand for a single
# county rather than shipped to the map on every interaction.
#' Load simplified GADM level-3 outlines for map context
#'
#' @return An sf layer with parent county keys, or NULL when the optional
#'   dataset cannot be loaded.
#' @noRd
app_wards <- function() {
  if (!exists("kenya_wards", envir = .app_data_cache, inherits = FALSE)) {
    .app_data_cache$kenya_wards <- tryCatch({
      utils::data(
        "kenya_wards_gadm_simplified",
        package = "kenyaFoodPrices",
        envir = .app_data_cache
      )
      wd <- .app_data_cache$kenya_wards_gadm_simplified
      .app_data_cache$kenya_wards_gadm_simplified <- NULL
      wd$county_key <- county_name_key(wd$NAME_1)
      sf::st_set_geometry(wd, "geometry")
    }, error = function(e) NULL)
  }

  .app_data_cache$kenya_wards
}

# COD ADM2 polygons use the same P-codes as the JMR subcounty records.
#' Load the COD sub-county polygons used by the climate maps
#'
#' @return The cached sf polygons with the ADM2 codes used by the JMR
#'   observations.
#' @noRd
app_cod_subcounties <- function() {
  if (!exists("kenya_subcounties_cod", envir = .app_data_cache,
              inherits = FALSE)) {
    utils::data(
      "kenya_subcounties_cod",
      package = "kenyaFoodPrices",
      envir = .app_data_cache
    )
  }

  .app_data_cache$kenya_subcounties_cod
}
