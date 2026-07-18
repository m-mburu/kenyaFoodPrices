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

test_that("compact tables let people choose how many rows to show", {
  widget <- datatable_compact(data.frame(value = seq_len(12)), page_length = 6)
  options <- widget$x$options

  expect_identical(options$pageLength, 6)
  expect_match(options$dom, "l")
  expect_equal(options$lengthMenu[[1]], c(6L, 10L, 25L, -1L))
  expect_equal(options$lengthMenu[[2]], c("6", "10", "25", "All"))
})
