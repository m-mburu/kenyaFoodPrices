cran_repo <- Sys.getenv("RSPM", unset = "https://cloud.r-project.org")

# Function to check and install packages more efficiently
check_and_install_packages <- function(packages) {
  # Finding which packages are not installed
  to_install <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]

  # Installing the missing packages
  if (length(to_install) > 0) {
    install.packages(to_install, dependencies = TRUE, repos = cran_repo)
  }

  still_missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(still_missing) > 0) {
    stop(
      "Failed to install required packages: ",
      paste(still_missing, collapse = ", "),
      call. = FALSE
    )
  }
}

# List of packages to ensure are installed
packages <- c("config", "data.table", "dplyr", "DT", "ggiraph", "golem",
              "plotly", "ggplot2", "shiny", "lubridate", "remotes", "rmarkdown",
              "usethis", "devtools", "sf", "rsconnect", "stringr",
              "shinycssloaders","waiter")


# Check and install packages as necessary
check_and_install_packages(packages)

# Additional GitHub packages can be installed here
remotes::install_github('dickoa/rhdx', upgrade = "never")
