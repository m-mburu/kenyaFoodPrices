# Build the application-ready Kenya climate datasets.
#
# Source data contract
# --------------------
# The World Bank Kenya Joint Food Security Monitor (JMR) bulk download is
# refreshed monthly. Its climate indicators originate from WFP rainfall and
# NDVI products and are harmonised to Kenya's current COD ADM2 geography.
#
# This script deliberately downloads the published Kenya bulk files instead
# of the 19-million-row global API table. It retains only physical and
# standardised rainfall/NDVI values, then prepares compact data.table objects
# for Shiny. Run this file from the package root to refresh data/kenya_climate.rda.

library(data.table)

source("R/climate_helpers.R")

jmr_study_id <- "KEN_2010-2025_JMR_v01_M"
jmr_files_api <- sprintf(
  "https://microdata.worldbank.org/api/downloads/%s/files?type=data",
  jmr_study_id
)

require_prep_package <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop("Package '", package, "' is required to refresh climate data.")
  }
}

list_jmr_files <- function(files_api = jmr_files_api) {
  require_prep_package("jsonlite")
  response <- jsonlite::fromJSON(files_api, simplifyDataFrame = TRUE)

  if (!identical(response$status, "success") || !nrow(response$files)) {
    stop("The JMR files endpoint did not return downloadable files.")
  }

  data.table::as.data.table(response$files)
}

download_jmr_file <- function(files, target_filename, destination) {
  row <- files[filename == target_filename]
  if (nrow(row) != 1L) {
    stop("Expected exactly one JMR resource named '", target_filename, "'.")
  }

  download_url <- row$links.download[[1L]]
  utils::download.file(download_url, destination, mode = "wb", quiet = FALSE)

  if (!file.exists(destination) || file.info(destination)$size == 0L) {
    stop("Download failed for '", target_filename, "'.")
  }

  invisible(row)
}

read_zipped_csv <- function(zip_path, extraction_dir) {
  files <- utils::unzip(zip_path, exdir = extraction_dir)
  csv_files <- files[grepl("\\.csv$", files, ignore.case = TRUE)]

  if (length(csv_files) != 1L) {
    stop("Expected one CSV in ", basename(zip_path), "; found ", length(csv_files), ".")
  }

  data.table::fread(csv_files)
}

build_kenya_climate <- function(work_dir = tempfile("kenya-climate-")) {
  dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
  files <- list_jmr_files()

  resources <- c(
    data = "KEN_JMR_data.zip",
    pcodes = "KEN_JMR_pcodes.zip",
    details = "KEN_JMR_model_details.zip"
  )

  downloaded <- lapply(resources, function(filename) {
    destination <- file.path(work_dir, filename)
    metadata <- download_jmr_file(files, filename, destination)
    list(path = destination, metadata = metadata)
  })

  jmr_data <- read_zipped_csv(downloaded$data$path, file.path(work_dir, "data"))
  pcodes <- read_zipped_csv(downloaded$pcodes$path, file.path(work_dir, "pcodes"))
  model_details <- read_zipped_csv(
    downloaded$details$path,
    file.path(work_dir, "details")
  )

  climate_adm2 <- prepare_jmr_climate(jmr_data, pcodes)
  county_monthly <- aggregate_climate_to_county(climate_adm2)
  county_lookup <- unique(
    data.table::as.data.table(pcodes)[, .(adm1_pcode, county = adm1_name)]
  )
  county_lookup[, county_key := normalise_county_name(county)]
  data.table::setorder(county_lookup, adm1_pcode)

  resource_rows <- files[filename %in% resources]
  source_version <- max(as.Date(resource_rows$dcdate), na.rm = TRUE)

  list(
    county_monthly = county_monthly,
    county_lookup = county_lookup,
    model_details = model_details[
      indicator %chin% c("Drought - NDVI", "Drought - rainfall")
    ],
    metadata = list(
      study_id = jmr_study_id,
      study_url = "https://microdata.worldbank.org/catalog/8115",
      source_label = "WFP climate indicators; World Bank JMR geographic harmonisation",
      rainfall_source = "WFP rainfall indicators derived from CHIRPS v2",
      vegetation_source = "WFP NDVI indicators derived from MODIS Collection 6.1",
      boundary_standard = "OCHA Common Operational Dataset (COD)",
      aggregation = paste(
        "Unweighted mean of harmonised ADM2 values within each county;",
        "physical values and JMR standardised indicators are retained."
      ),
      source_version = source_version,
      data_start = min(county_monthly$date),
      data_end = max(county_monthly$date),
      created_at = Sys.time(),
      resources = resource_rows[
        ,
        .(filename, title, dcdate, changed, file_size, download_url = links.download)
      ]
    )
  )
}

kenya_climate <- build_kenya_climate()

stopifnot(
  data.table::uniqueN(kenya_climate$county_lookup$adm1_pcode) == 47L,
  all(c("rainfall_mm", "rainfall_z", "ndvi", "ndvi_z") %in%
        names(kenya_climate$county_monthly)),
  min(kenya_climate$county_monthly$ndvi, na.rm = TRUE) >= -1,
  max(kenya_climate$county_monthly$ndvi, na.rm = TRUE) <= 1,
  min(kenya_climate$county_monthly$rainfall_mm, na.rm = TRUE) >= 0
)

usethis::use_data(kenya_climate, overwrite = TRUE, compress = "xz")
