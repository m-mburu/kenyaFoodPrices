# Shared table controls and sizing.

# Compact DataTable. When every row fits on one page, pagination and the
# page-length selector are hidden so the panel shows only useful controls.
datatable_compact <- function(data, page_length = 8, scroll_x = TRUE) {
  page_options <- sort(unique(c(as.integer(page_length), 10L, 25L)))
  single_page <- nrow(data) <= page_length

  DT::datatable(
    data,
    rownames = FALSE,
    options = list(
      pageLength = page_length,
      lengthMenu = list(
        c(page_options, -1L),
        c(as.character(page_options), "All")
      ),
      dom = if (single_page) "t" else "ltip",
      paging = !single_page,
      autoWidth = TRUE,
      scrollX = scroll_x
    )
  )
}
