tool_library <- Sys.getenv("WORKFLOW_R_LIBRARY")

if (!nzchar(tool_library)) {
  stop("WORKFLOW_R_LIBRARY must identify the CI package library.", call. = FALSE)
}

dir.create(tool_library, recursive = TRUE, showWarnings = FALSE)
tool_library <- normalizePath(tool_library)

# This script runs with --vanilla and the workflow sets R_LIBS_SITE and
# R_LIBS_USER to this directory. Dependencies therefore cannot be borrowed
# from the renv project library or skipped during installation.
.libPaths(tool_library)

repo_url <- Sys.getenv("RSPM")
if (!nzchar(repo_url)) {
  repo_url <- "https://cloud.r-project.org"
}
options(repos = c(CRAN = repo_url))

workflow_packages <- c(
  "checkhelper",
  "devtools",
  "ggthemes",
  "remotes",
  "rsconnect",
  "usethis"
)

install.packages(
  workflow_packages,
  lib = tool_library,
  dependencies = NA
)

remotes::install_github(
  "dickoa/rhdx",
  lib = tool_library,
  dependencies = NA,
  upgrade = "never"
)

required_packages <- c(workflow_packages, "rhdx")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages)) {
  stop(
    "Failed to install workflow packages: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}
