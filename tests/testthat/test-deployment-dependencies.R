dependency_checker <- new.env(parent = globalenv())
sys.source(
  testthat::test_path("../../dev/check_deployment_dependencies.R"),
  envir = dependency_checker
)

test_that("deployment validation retains recommended dependencies", {
  database <- matrix(
    NA_character_,
    nrow = 3L,
    ncol = 7L,
    dimnames = list(
      c("sp", "lattice", "methods"),
      c("Package", "Version", "Priority", "Depends", "Imports",
        "LinkingTo", "Suggests")
    )
  )
  database[, "Package"] <- rownames(database)
  database[, "Version"] <- "1.0"
  database["sp", "Imports"] <- "lattice, methods"
  database["lattice", "Priority"] <- "recommended"
  database["methods", "Priority"] <- "base"
  lock <- list(Packages = list(sp = list(Version = "1.0")))
  check <- dependency_checker$check_deployment_dependencies

  # Empty recorded Requirements must not hide sp's real dependency on lattice.
  expect_error(check(lock, database), "missing from renv.lock: lattice")
  lock$Packages$lattice <- list(Version = "1.0")
  expect_true(check(lock, database))

  database["sp", "Version"] <- "2.0"
  expect_error(check(lock, database), "versions differ from lockfile: sp")
})
