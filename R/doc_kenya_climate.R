#' Harmonised WFP rainfall and vegetation indicators for Kenya
#'
#' A list containing compact monthly climate data used by the application.
#' Rainfall and NDVI originate from WFP products and are geographically
#' harmonised to current Kenya COD administrative areas by the World Bank
#' Joint Food Security Monitor.
#'
#' @format A list with five elements:
#' \describe{
#'   \item{county_monthly}{A `data.table` with one row per county and month,
#'   containing physical and standardised rainfall and NDVI indicators.}
#'   \item{subcounty_monthly}{A `data.table` with one row per COD ADM2
#'   subcounty and month, containing source rainfall and NDVI values and
#'   their standardised conditions.}
#'   \item{county_lookup}{A `data.table` mapping current ADM1 P-codes to
#'   county names.}
#'   \item{model_details}{A `data.table` documenting JMR climate indicator
#'   transformations and alert thresholds.}
#'   \item{metadata}{A list containing source, version, coverage and
#'   processing information.}
#' }
#' @source \url{https://microdata.worldbank.org/catalog/8115}
"kenya_climate"
