test_that("the app UI exposes calculation and accessibility contracts", {
  ui <- app_ui(NULL)
  markup <- paste(as.character(ui), collapse = "\n")

  expect_s3_class(ui, "shiny.tag.list")
  expect_match(markup, "balanced_median")
  expect_match(markup, "Skip to main content")
  expect_match(markup, "main-content")
  expect_match(markup, "aria-live")
})
