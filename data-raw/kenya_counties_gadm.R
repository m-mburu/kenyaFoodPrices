## Download and prepare GADM (4.1) Kenya admin boundaries.
##
## Purpose
##   Provide clean, valid administrative boundary layers for the dashboard
##   maps. The current packaged `kenya_counties` layer contains ring
##   self-intersections in five counties; GADM supplies valid WGS84
##   (EPSG:4326) polygons that the climate and price maps can simplify without
##   first repairing the source. Level 1 (counties) drives the national maps;
##   levels 2 (sub-counties) and 3 (wards) provide local context when a county
##   is focused, as described in AGENTS.md.
##
## Behaviour
##   The download is large (about 45 MB) and network dependent, so this script
##   only runs when the prepared outputs are NOT already present in `data/`.
##   Delete the corresponding `data/*.rda` file (or set the environment
##   variable `KFP_FORCE_GADM_DOWNLOAD=true`) to force a rebuild.

library(sf)

# Configuration -------------------------------------------------------------

gadm_version <- "4.1"
gadm_url <- paste0(
  "https://geodata.ucdavis.edu/gadm/gadm", gadm_version,
  "/gpkg/gadm41_KEN.gpkg"
)

raw_dir <- file.path("data-raw", "gadm")
raw_file <- file.path(raw_dir, "gadm41_KEN.gpkg")

force_download <- identical(tolower(Sys.getenv("KFP_FORCE_GADM_DOWNLOAD")), "true")

# Levels to prepare: GADM layer name -> output object / file stem. The order
# matters only for readable log output. The geopackage stores the levels under
# the layer names ADM_ADM_1, ADM_ADM_2 and ADM_ADM_3.
gadm_levels <- c(
  ADM_ADM_1 = "kenya_counties_gadm",      # counties
  ADM_ADM_2 = "kenya_subcounties_gadm",   # sub-counties
  ADM_ADM_3 = "kenya_wards_gadm"          # wards
)

output_files <- file.path("data", paste0(unname(gadm_levels), ".rda"))

# Helper: read, repair and save one admin level ------------------------------

prepare_level <- function(raw_file, layer, object_name, gadm_version, gadm_url) {
  # Layer names look like "ADM_ADM_1"; the admin level is the trailing digit.
  level_number <- sub(".*_([0-9]+)$", "\\1", layer)

  # Parent identifiers (GID_1/NAME_1, GID_2/NAME_2) build the
  # county -> sub-county -> ward crosswalk used when focusing a county.
  keep_cols <- unique(c(
    paste0("GID_", level_number),
    paste0("NAME_", level_number),
    paste0("TYPE_", level_number),
    "GID_0", "GID_1", "NAME_1",
    if (level_number %in% c("2", "3")) c("GID_2"),
    if (level_number == "3") c("NAME_2")
  ))

  boundaries <- st_read(raw_file, layer = layer, quiet = TRUE)
  boundaries <- st_as_sf(boundaries)
  boundaries <- boundaries[, intersect(keep_cols, names(boundaries))]

  # GADM 4.1 geometry is generally valid; repair is cheap insurance before
  # any later simplification step.
  if (!all(st_is_valid(boundaries))) {
    message("Repairing invalid GADM geometries for layer ", layer, ".")
    suppressMessages(sf_use_s2(FALSE))
    boundaries <- st_make_valid(boundaries)
    suppressMessages(sf_use_s2(TRUE))
  }

  # Give the county layer the columns the app expects elsewhere: a `county`
  # name column and a geometry column named `geometry`. This lets
  # app_counties(), prepare_climate_geometry() and the price map keep working
  # with the same field names as the legacy layer.
  if (layer == "ADM_ADM_1") {
    names(boundaries)[names(boundaries) == "NAME_1"] <- "county"
    boundaries <- sf::st_set_geometry(boundaries, "geometry")
  }

  attr(boundaries, "gadm_version") <- gadm_version
  attr(boundaries, "source_url") <- gadm_url

  assign(object_name, boundaries)
  out <- file.path("data", paste0(object_name, ".rda"))
  save(list = object_name, file = out, compress = "bzip2")
  message("Saved ", nrow(boundaries), " features to ", out)
}

# Only run when the prepared outputs are missing ----------------------------

all_outputs_present <- all(file.exists(output_files))

if (all_outputs_present && !force_download) {
  message(
    "Prepared GADM boundaries already exist in data/. ",
    "Set KFP_FORCE_GADM_DOWNLOAD=true or delete the files to rebuild."
  )
} else {
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

  # Download once, with a generous timeout for the ~45 MB file.
  if (!file.exists(raw_file) || force_download) {
    message("Downloading GADM ", gadm_version, " Kenya from:\n  ", gadm_url)
    old_timeout <- options(timeout = max(600, getOption("timeout")))
    on.exit(options(old_timeout), add = TRUE)
    download.file(gadm_url, destfile = raw_file, mode = "wb", quiet = FALSE)
  }

  message("Layers in geopackage: ", paste(st_layers(raw_file)$name, collapse = ", "))

  for (i in seq_along(gadm_levels)) {
    prepare_level(
      raw_file,
      layer = names(gadm_levels)[i],
      object_name = unname(gadm_levels)[i],
      gadm_version = gadm_version,
      gadm_url = gadm_url
    )
  }
}
