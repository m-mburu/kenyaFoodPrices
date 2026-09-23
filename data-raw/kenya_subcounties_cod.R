# Prepare OCHA COD ADM2 boundaries that match JMR climate P-codes.
# Run after data-raw/climate_dataset.R from the package root.

library(sf)

source_url <- paste0(
  "https://data.humdata.org/dataset/",
  "2c0b7571-4bef-4347-9b81-b2174c13f9ef/resource/",
  "674ea496-5451-4312-bcab-8aa95fa3f36c/",
  "download/ken_admin_boundaries.geojson.zip"
)

work_dir <- tempfile("kenya-cod-")
dir.create(work_dir)
zip_path <- file.path(work_dir, "ken_admin_boundaries.geojson.zip")
archive_override <- Sys.getenv("KFP_COD_ARCHIVE", unset = "")
if (nzchar(archive_override)) {
  if (!file.copy(archive_override, zip_path)) {
    stop("Could not copy the supplied COD archive.")
  }
} else {
  utils::download.file(source_url, zip_path, mode = "wb")
}
utils::unzip(
  zip_path,
  files = "ken_admin2.geojson",
  exdir = work_dir
)

cod <- sf::st_read(
  file.path(work_dir, "ken_admin2.geojson"),
  quiet = TRUE
)
required <- c(
  "adm1_pcode", "adm2_pcode", "adm2_name", "geometry"
)
if (!all(required %in% names(cod))) {
  stop("COD ADM2 polygons are missing required fields.")
}
if (anyDuplicated(cod$adm2_pcode) || anyNA(cod$adm2_pcode)) {
  stop("COD ADM2 P-codes must be present and unique.")
}

climate_env <- new.env(parent = emptyenv())
load(file.path("data", "kenya_climate.rda"), envir = climate_env)
climate <- climate_env$kenya_climate$subcounty_monthly
climate_codes <- unique(climate$adm2_pcode)
if (!setequal(cod$adm2_pcode, climate_codes)) {
  stop("COD ADM2 P-codes do not match JMR climate areas.")
}

cod <- sf::st_make_valid(cod)
cod <- sf::st_collection_extract(cod, "POLYGON", warn = FALSE)
cod <- sf::st_cast(cod, "MULTIPOLYGON", warn = FALSE)
projected <- sf::st_transform(cod, 6933)
simplified <- sf::st_simplify(
  projected,
  preserveTopology = TRUE,
  dTolerance = 100
)
simplified <- sf::st_make_valid(simplified)
simplified <- sf::st_collection_extract(
  simplified,
  "POLYGON",
  warn = FALSE
)
simplified <- sf::st_cast(
  simplified,
  "MULTIPOLYGON",
  warn = FALSE
)
area_ratio <- as.numeric(sf::st_area(simplified)) /
  as.numeric(sf::st_area(projected))

if (nrow(simplified) != nrow(cod) ||
    any(sf::st_is_empty(simplified)) ||
    !all(sf::st_is_valid(simplified)) ||
    any(area_ratio < 0.97)) {
  stop("Simplified COD geometry failed coverage or area checks.")
}

kenya_subcounties_cod <- sf::st_transform(simplified, 4326)
kenya_subcounties_cod <- kenya_subcounties_cod[
  ,
  c("adm1_pcode", "adm2_pcode", "adm2_name", "geometry")
]
attr(kenya_subcounties_cod, "source_url") <- source_url
attr(kenya_subcounties_cod, "simplify_tolerance_m") <- 100
save(
  kenya_subcounties_cod,
  file = file.path("data", "kenya_subcounties_cod.rda"),
  compress = "xz"
)
