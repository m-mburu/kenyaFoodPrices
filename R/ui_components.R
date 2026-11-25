# Shared dashboard markup; keep classes stable for CSS and browser handlers.

# Values are already formatted by the caller; cards do not change units.
#' Display a formatted summary value with its label and context
#'
#' @param label Short name of the measure.
#' @param value Formatted value or tag, including units where needed.
#' @param note Optional explanatory text below the value.
#' @param status Optional CSS status class.
#' @return A Shiny div for a dashboard summary card.
#' @noRd
kpi_card <- function(label, value, note = NULL, status = "") {
  shiny::div(
    class = paste("kfp-kpi", status),
    shiny::div(class = "kfp-kpi-label", label),
    shiny::div(class = "kfp-kpi-value", value),
    if (!is.null(note)) shiny::div(class = "kfp-kpi-note", note)
  )
}

#' Wrap an output in a dashboard panel
#'
#' @param title Panel heading text or a Shiny tag.
#' @param output Output or group of tags to place in the panel.
#' @param footer Optional content below the output.
#' @return A Shiny div with a heading, body and optional footer.
#' @noRd
plot_panel <- function(title, output, footer = NULL) {
  shiny::div(
    class = "kfp-panel",
    shiny::h4(title),
    output,
    footer
  )
}

# Size selects a CSS layout class rather than fixing widget pixel dimensions.
#' Wrap a chart in a responsive layout frame
#'
#' @param output Widget tag to wrap.
#' @param size Suffix identifying the layout size in the app stylesheet.
#' @return A Shiny div whose CSS class sets the visualisation size.
#' @noRd
visualization_frame <- function(output, size = "standard") {
  shiny::div(
    class = paste("kfp-viz-frame", paste0("kfp-viz-", size)),
    output
  )
}
