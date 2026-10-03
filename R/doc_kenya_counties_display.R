#' Simplified county boundaries for dashboard display
#'
#' A separate GADM 4.1 county layer simplified as a polygon coverage in
#' EPSG:6933. Original analytical boundaries are retained separately.
#' Climate values are joined by county; these polygons contain no estimates.
#'
#' @format An sf data frame with 47 county rows, GADM identifiers and names,
#'   a normalised county label, and WGS84 MULTIPOLYGON geometry. Attributes
#'   record source, method, projected CRS, tolerance and Shapely version.
#' @source GADM 4.1 Kenya, https://gadm.org/
#' @seealso data-raw/build_county_display_geometry.R for the build procedure.
"kenya_counties_display"
