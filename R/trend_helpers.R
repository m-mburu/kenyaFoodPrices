# Price-period preparation and comparison contracts.

# Dependent inputs can briefly send incomplete dates during a reset.
#' Check that an observation date range is usable
#'
#' @param dates Candidate vector of observation dates.
#' @return TRUE for two ordered, non-missing Dates.
#' @noRd
valid_price_date_range <- function(dates) {
  length(dates) == 2L &&
    inherits(dates, "Date") &&
    !anyNA(dates) &&
    dates[1L] <= dates[2L]
}

# Quarter labels report observed months, rather than implying full coverage.
#' Label an observed month or quarter for display
#'
#' @param period Date or values coercible to Date for the period start.
#' @param quarterly Whether periods represent quarters.
#' @param covered_months Counts of observed months to include in quarter
#'   labels, when known.
#' @return One label per period. A quarter label can include the count of
#'   observed months.
#' @noRd
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
#' Build the available choices for the Trend period selectors
#'
#' @param trend Table of period starts, price estimates and coverage from
#'   prepare_trend_series().
#' @param quarterly Whether choice labels should display quarters.
#' @return A named character vector of period IDs newest first, restricted to
#'   periods with a finite estimate.
#' @noRd
trend_period_choices <- function(trend, quarterly = FALSE) {
  trend <- data.table::copy(trend)
  trend <- trend[is.finite(price_estimate)][order(-period)]
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
#' Calculate the proportional change from a pinned reference period
#'
#' @param reference_value Price estimate for the reference period.
#' @param comparison_value Price estimate for the comparison period in the same
#'   units.
#' @return One proportional change, or NA if either estimate is unavailable or
#'   the reference is zero.
#' @noRd
trend_percent_change <- function(reference_value, comparison_value) {
  if (!is.finite(reference_value) || !is.finite(comparison_value) ||
      reference_value == 0) {
    return(NA_real_)
  }

  (comparison_value - reference_value) / reference_value
}

# A quarterly point is the mean of available monthly selected estimates.
# Empty quarters remain missing; do not replace them with zero.
#' Average observed monthly estimates within each quarter
#'
#' @param monthly Monthly price table from summarise_monthly_prices(),
#'   including any calendar gaps.
#' @return One row per quarter with an equal-month mean and coverage counts.
#'   Quarters containing only missing estimates have an NA estimate.
#' @noRd
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
      price_estimate = if (all(is.na(price_estimate))) NA_real_ else
        mean(price_estimate, na.rm = TRUE),
      observations = sum(observations, na.rm = TRUE),
      counties = if (all(is.na(counties))) NA_integer_ else
        max(counties, na.rm = TRUE),
      markets = if (all(is.na(markets))) NA_integer_ else
        max(markets, na.rm = TRUE),
      covered_months = sum(is.finite(price_estimate))
    ),
    by = period
  ]
}

#' Prepare monthly or quarterly price estimates for the Trends panel
#'
#' @param monthly Non-empty completed monthly series with year_month_date,
#'   price_estimate, observations, counties and markets columns.
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
        price_estimate, observations, counties, markets,
        covered_months = as.integer(is.finite(price_estimate))
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
  summary[, display_price := price_estimate]
  if (identical(display, "smooth")) {
    # Missing periods keep the trailing window unavailable, rather than zero.
    summary[, display_price := data.table::frollmean(
      price_estimate, n = 3L, align = "right", fill = NA_real_
    )]
  }
  summary[]
}

# Both recorded-price summaries receive rows with finite prices.
#' Summarise the distribution of recorded prices within each year
#'
#' @param finite_prices Observation records with finite prices in the selected
#'   column.
#' @param price_column Name of the numeric price column.
#' @return One row per year with the mean, minimum, maximum, number of records
#'   and geographic and monthly coverage.
#' @noRd
summarise_annual_recorded_prices <- function(finite_prices, price_column) {
  finite_prices[
    ,
    .(
      mean_price = mean(get(price_column), na.rm = TRUE),
      min_price = min(get(price_column), na.rm = TRUE),
      max_price = max(get(price_column), na.rm = TRUE),
      observations = .N,
      covered_months = data.table::uniqueN(format(date, "%Y-%m")),
      markets = data.table::uniqueN(market),
      counties = data.table::uniqueN(county)
    ),
    by = .(calendar_year = as.integer(format(date, "%Y")))
  ][order(calendar_year)]
}

# Index each month against the mean of observed months in the same year.
# Then pool the same calendar month across years.
#' Index recorded monthly prices relative to their own year
#'
#' @param finite_prices Observation records with finite prices in the selected
#'   column.
#' @param price_column Name of the numeric price column.
#' @return One row per calendar month with the mean and middle half of yearly
#'   indices and supporting counts. Index 100 represents the mean of each
#'   year's observed monthly means.
#' @noRd
summarise_price_seasonality <- function(finite_prices, price_column) {
  monthly <- finite_prices[
    ,
    .(
      mean_price = mean(get(price_column), na.rm = TRUE),
      observations = .N
    ),
    by = .(
      calendar_year = as.integer(format(date, "%Y")),
      month_num = as.integer(format(date, "%m"))
    )
  ]
  annual <- monthly[
    ,
    .(annual_mean = mean(mean_price, na.rm = TRUE)),
    by = calendar_year
  ]
  monthly <- merge(monthly, annual, by = "calendar_year", all.x = TRUE)
  monthly[, season_index := 100 * mean_price / annual_mean]

  monthly[
    ,
    .(
      season_index = mean(season_index, na.rm = TRUE),
      lower = stats::quantile(season_index, 0.25, na.rm = TRUE, names = FALSE),
      upper = stats::quantile(season_index, 0.75, na.rm = TRUE, names = FALSE),
      observations = sum(observations),
      years = .N
    ),
    by = month_num
  ][order(month_num)]
}
