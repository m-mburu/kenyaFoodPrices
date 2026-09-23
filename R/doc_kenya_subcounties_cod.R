#' Kenya COD subcounty polygons for JMR climate display
#'
#' Simplified OCHA COD ADM2 boundaries with P-codes matching the JMR climate
#' observations. These polygons are for display; source values are retained
#' at ADM2 level in `kenya_climate$subcounty_monthly`.
#'
#' @format An `sf` object with 290 rows and ADM1/ADM2 P-codes, ADM2 names,
#'   and WGS84 geometry.
#' @source \url{https://data.humdata.org/dataset/cod-ab-ken}
"kenya_subcounties_cod"
