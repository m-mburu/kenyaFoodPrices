# Check restored DESCRIPTION metadata as well as the recorded dependency graph.
# Recommended packages, such as lattice, must be included in deployment bundles.
check_deployment_dependencies <- function(
  lock,
  database = utils::installed.packages(),
  packages = names(lock$Packages)
) {
  missing_installed <- setdiff(packages, rownames(database))
  if (length(missing_installed) > 0L) {
    stop("Locked packages not installed: ",
         paste(missing_installed, collapse = ", "))
  }

  wrong_versions <- packages[vapply(packages, function(package) {
    lock$Packages[[package]]$Version != database[package, "Version"]
  }, logical(1))]
  if (length(wrong_versions) > 0L) {
    stop("Installed versions differ from lockfile: ",
         paste(wrong_versions, collapse = ", "))
  }

  dependencies <- tools::package_dependencies(
    packages,
    db = database,
    which = c("Depends", "Imports", "LinkingTo")
  )
  recorded <- lapply(lock$Packages, function(record) record$Requirements)
  priority <- database[, "Priority"]
  base_packages <- rownames(database)[
    !is.na(priority) & priority == "base"
  ]
  required <- unique(c(unlist(dependencies), unlist(recorded)))
  missing_locked <- setdiff(required, c(names(lock$Packages), base_packages))
  if (length(missing_locked) > 0L) {
    stop("Deployment dependencies missing from renv.lock: ",
         paste(sort(missing_locked), collapse = ", "))
  }

  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  lock <- jsonlite::read_json("renv.lock")
  check_deployment_dependencies(lock)
  message("Locked deployment dependencies are complete.")
}
