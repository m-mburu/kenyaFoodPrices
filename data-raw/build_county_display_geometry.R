# Build the simplified county layer used by national display maps.
#
# Run after data/kenya_counties_gadm.rda exists. Requires sf and Python
# Shapely >= 2.1 at build time; the app uses only the generated R data file.

source_file <- file.path("data", "kenya_counties_gadm.rda")
output_file <- file.path("data", "kenya_counties_display.rda")
python_script <- file.path(
  "data-raw",
  "simplify_county_coverage.py"
)
tolerance_m <- 1000
python_bin <- Sys.getenv(
  "KFP_PYTHON_BIN",
  Sys.which("python3")
)
if (!nzchar(python_bin)) {
  stop("Set KFP_PYTHON_BIN to a Python interpreter with Shapely >= 2.1")
}

if (!file.exists(source_file)) {
  stop("Missing GADM county data: ", source_file)
}
if (!file.exists(python_script)) {
  stop("Missing coverage simplifier: ", python_script)
}

source_env <- new.env(parent = emptyenv())
load(source_file, envir = source_env)
counties <- source_env$kenya_counties_gadm
if (is.null(counties) || nrow(counties) != 47L) {
  stop("Expected 47 GADM county geometries in ", source_file)
}

projected <- sf::st_transform(counties, 6933)
wkb <- sf::st_as_binary(sf::st_geometry(projected), EWKB = FALSE)
input_table <- data.frame(
  GID_1 = counties$GID_1,
  county = counties$county,
  wkb = vapply(
    wkb,
    function(bytes) paste(sprintf("%02x", as.integer(bytes)),
                          collapse = ""),
    character(1)
  ),
  stringsAsFactors = FALSE
)

temporary_input <- tempfile(fileext = ".tsv")
temporary_output <- tempfile(fileext = ".tsv")
utils::write.table(
  input_table,
  file = temporary_input,
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

result <- system2(
  python_bin,
  args = c(
    shQuote(python_script),
    shQuote(temporary_input),
    shQuote(temporary_output),
    as.character(tolerance_m)
  ),
  stdout = TRUE,
  stderr = TRUE
)
if (!is.null(attr(result, "status")) && attr(result, "status") != 0L) {
  stop(paste(result, collapse = "\n"))
}
cat(paste(result, collapse = "\n"), "\n")

display_table <- utils::read.delim(
  temporary_output,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
if (!identical(display_table$GID_1, counties$GID_1) ||
    !identical(display_table$county, counties$county)) {
  stop("Simplification output changed county identifiers or ordering")
}

display_geometry <- sf::st_as_sfc(
  structure(as.list(display_table$wkb), class = "WKB"),
  crs = 6933
)
kenya_counties_display <- sf::st_sf(
  sf::st_drop_geometry(counties),
  geometry = sf::st_transform(display_geometry, 4326)
)
attr(kenya_counties_display, "source") <-
  "GADM 4.1, Kenya ADM1; gadm41_KEN.gpkg"
attr(kenya_counties_display, "source_url") <-
  "https://geodata.ucdavis.edu/gadm/gadm4.1/gpkg/gadm41_KEN.gpkg"
attr(kenya_counties_display, "simplification_method") <-
  "GEOS CoverageSimplifier via Shapely coverage_simplify"
attr(kenya_counties_display, "simplify_tolerance_m") <- tolerance_m
attr(kenya_counties_display, "projected_crs") <- "EPSG:6933"
shapely_versions <- unique(display_table$shapely_version)
if (length(shapely_versions) != 1L) {
  stop("Simplifier output has inconsistent Shapely versions")
}
attr(kenya_counties_display, "shapely_version") <- shapely_versions

if (any(sf::st_is_empty(kenya_counties_display)) ||
    !all(sf::st_is_valid(kenya_counties_display))) {
  stop("Generated county display geometries must be valid and non-empty")
}

save(
  kenya_counties_display,
  file = output_file,
  compress = "bzip2"
)
unlink(c(temporary_input, temporary_output))
message("Saved display geometries to ", output_file)
