# Shared number and price-change presentation.

# Missing and non-finite values share the same reader-facing label.
#' Format numeric values for display in dashboard outputs
#'
#' @param x Numeric values to format.
#' @param digits Number of decimal places to display.
#' @return Character values with grouping marks and the requested precision.
#'   Empty or non-finite values display as Not available.
#' @noRd
format_number <- function(x, digits = 0) {
  if (length(x) == 0) {
    return("Not available")
  }

  vapply(
    x,
    function(value) {
      if (is.na(value) || !is.finite(value)) {
        return("Not available")
      }
      format(round(value, digits), big.mark = ",", nsmall = digits, trim = TRUE)
    },
    character(1)
  )
}

# Changes retain the selected currency and physical price denominator.
#' Format absolute price changes with signs and units
#'
#' @param x Absolute changes in the selected price units.
#' @param unit_label Currency and price denominator to append.
#' @return Character labels with two decimal places and a plus sign for
#'   increases. Missing changes display as Not available.
#' @noRd
format_change <- function(x, unit_label) {
  if (length(x) == 0) {
    return("Not available")
  }

  vapply(
    x,
    function(value) {
      if (is.na(value) || !is.finite(value)) {
        return("Not available")
      }
      paste0(
        ifelse(value > 0, "+", ""),
        format_number(value, 2),
        " ",
        unit_label
      )
    },
    character(1)
  )
}

# Input is a proportion: 0.05 is displayed as +5.0%.
#' Display relative changes as percentages
#'
#' @param x Numeric proportions, such as 0.05 for a five percent increase.
#' @return Character percentages with one decimal place and a plus sign for
#'   increases. Non-finite changes display as Not available.
#' @noRd
format_percent <- function(x) {
  if (length(x) == 0) {
    return("Not available")
  }

  vapply(
    x,
    function(value) {
      if (is.na(value) || !is.finite(value)) {
        return("Not available")
      }
      paste0(ifelse(value > 0, "+", ""), format_number(100 * value, 1), "%")
    },
    character(1)
  )
}

# A scalar proportional change is expressed as higher/lower for Overview.
#' Describe the direction of a relative price change
#'
#' @param percent_change One proportional change relative to the reference
#'   price.
#' @return A higher, lower or unchanged label. An unavailable comparison yields
#'   Not available.
#' @noRd
format_price_comparison <- function(percent_change) {
  if (length(percent_change) == 0L ||
      !is.finite(percent_change)) {
    return("Not available")
  }
  if (percent_change == 0) {
    return("Unchanged")
  }
  direction <- if (percent_change > 0) "higher" else "lower"
  paste0(format_number(abs(100 * percent_change), 1), "% ", direction)
}
