# Price-period preparation and comparison contracts.

# Dependent inputs can briefly send incomplete dates during a reset.
valid_price_date_range <- function(dates) {
  length(dates) == 2L &&
    inherits(dates, "Date") &&
    !anyNA(dates) &&
    dates[1L] <= dates[2L]
}

# Quarter labels report observed months, rather than implying full coverage.
trend_period_label <- function(
  period,
  quarterly = FALSE,
  covered_months = NA_integer_
) {
  period <- as.Date(period)
  covered_months <- rep_len(covered_months, length(period))

  vapply(
    seq_along(period),
    function(index) {
      if (!isTRUE(quarterly)) {
        return(format(period[index], "%b %Y"))
      }

      quarter <- (as.integer(format(period[index], "%m")) - 1L) %/% 3L + 1L
      label <- paste0("Q", quarter, " ", format(period[index], "%Y"))
      if (is.na(covered_months[index])) {
        return(label)
      }
      paste0(label, " (", covered_months[index], " months)")
    },
    character(1)
  )
}

# Work on a copy because monthly tables can be shared by several outputs.
trend_period_choices <- function(trend, quarterly = FALSE) {
  trend <- data.table::copy(trend)
  trend <- trend[is.finite(mean_price)][order(-period)]
  if (!nrow(trend)) {
    return(stats::setNames(character(), character()))
  }

  trend[, period_id := as.character(period)]
  stats::setNames(
    trend$period_id,
    trend_period_label(trend$period, quarterly, trend$covered_months)
  )
}

# Return a proportion; a zero reference has no defined relative change.
trend_percent_change <- function(reference_value, comparison_value) {
  if (!is.finite(reference_value) || !is.finite(comparison_value) ||
      reference_value == 0) {
    return(NA_real_)
  }

  (comparison_value - reference_value) / reference_value
}

# A quarterly point is the mean of available monthly selected estimates.
# Empty quarters remain missing; do not replace them with zero.
quarterly_trend_data <- function(monthly) {
  monthly <- data.table::copy(monthly)
  monthly[, period := as.Date(sprintf(
    "%s-%02d-01",
    format(year_month_date, "%Y"),
    ((as.integer(format(year_month_date, "%m")) - 1L) %/% 3L) *
      3L + 1L
  ))]
  monthly[
    ,
    .(
      mean_price = if (all(is.na(mean_price))) NA_real_ else
        mean(mean_price, na.rm = TRUE),
      observations = sum(observations, na.rm = TRUE),
      counties = if (all(is.na(counties))) NA_integer_ else
        max(counties, na.rm = TRUE),
      markets = if (all(is.na(markets))) NA_integer_ else
        max(markets, na.rm = TRUE),
      covered_months = sum(is.finite(mean_price))
    ),
    by = period
  ]
}

#' Prepare monthly or quarterly price estimates for the Trends panel
#'
#' @param monthly Non-empty completed monthly series with year_month_date,
#'   mean_price, observations, counties and markets columns.
#' @param frequency "quarter" for quarterly means; otherwise monthly values.
#' @param display "smooth" for a trailing three-period mean; otherwise the
#'   selected estimate. This follows the existing input-control contract.
#' @return A data.table ordered by period, with estimates, coverage and
#'   display_price in the original currency per selected physical unit.
#' @noRd
prepare_trend_series <- function(monthly, frequency, display) {
  monthly <- data.table::copy(monthly)

  if (identical(frequency, "quarter")) {
    summary <- quarterly_trend_data(monthly)
    step <- "3 months"
  } else {
    summary <- monthly[
      ,
      .(
        period = year_month_date,
        mean_price, observations, counties, markets,
        covered_months = as.integer(is.finite(mean_price))
      )
    ]
    step <- "month"
  }

  # Complete the calendar before smoothing so gaps are not skipped.
  all_periods <- data.table::data.table(
    period = seq(min(summary$period), max(summary$period), by = step)
  )
  summary <- merge(
    all_periods, summary, by = "period", all.x = TRUE, sort = TRUE
  )
  summary[, display_price := mean_price]
  if (identical(display, "smooth")) {
    # Missing periods keep the trailing window unavailable, rather than zero.
    summary[, display_price := data.table::frollmean(
      mean_price, n = 3L, align = "right", fill = NA_real_
    )]
  }
  summary[]
}
