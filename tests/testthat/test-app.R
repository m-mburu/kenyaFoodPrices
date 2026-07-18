test_that("the app UI exposes calculation and accessibility contracts", {
  ui <- app_ui(NULL)
  markup <- paste(as.character(ui), collapse = "\n")

  expect_s3_class(ui, "shiny.tag.list")
  expect_match(markup, "balanced_median")
  expect_match(markup, "Skip to main content")
  expect_match(markup, "main-content")
  expect_match(markup, "aria-live")
})

test_that("visualizations use responsive frames instead of fixed pixel heights", {
  html <- paste(as.character(app_ui(NULL)), collapse = "\n")

  expect_match(html, "kfp-viz-frame")
  expect_false(grepl('height=\"(300|330|410|430|520|620)px\"', html))
})
