# Shared number and price-change presentation.

# Missing and non-finite values share the same reader-facing label.
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
