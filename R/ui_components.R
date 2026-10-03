# Shared dashboard markup; keep classes stable for CSS and browser handlers.

# Values are already formatted by the caller; cards do not change units.
kpi_card <- function(label, value, note = NULL, status = "") {
  shiny::div(
    class = paste("kfp-kpi", status),
    shiny::div(class = "kfp-kpi-label", label),
    shiny::div(class = "kfp-kpi-value", value),
    if (!is.null(note)) shiny::div(class = "kfp-kpi-note", note)
  )
}

plot_panel <- function(title, output, footer = NULL) {
  shiny::div(
    class = "kfp-panel",
    shiny::h4(title),
    output,
    footer
  )
}

# Size selects a CSS layout class rather than fixing widget pixel dimensions.
visualization_frame <- function(output, size = "standard") {
  shiny::div(
    class = paste("kfp-viz-frame", paste0("kfp-viz-", size)),
    output
  )
}
