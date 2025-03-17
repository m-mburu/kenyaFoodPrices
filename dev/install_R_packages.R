

# Function to check and install packages more efficiently
check_and_install_packages <- function(packages) {
  # Finding which packages are not installed
  installed <- installed.packages()[,"Package"]
  to_install <- packages[!packages %in% installed]

  # Installing the missing packages
  if (length(to_install) > 0) {
    install.packages(to_install, dependencies = TRUE, repos = 'http://cran.rstudio.com')
  }
}

# List of packages to ensure are installed
packages <- c("config", "data.table", "dplyr", "DT", "golem", "leaflet",
              "plotly", "ggplot2", "shiny", "lubridate", "remotes", "rmarkdown",
              "usethis", "devtools", "checkhelper", "sf", "rsconnect", "stringr",
              "shinycssloaders","waiter")


# Check and install packages as necessary
check_and_install_packages(packages)

# Additional GitHub packages can be installed here
remotes::install_github('dickoa/rhdx', upgrade = "never")
