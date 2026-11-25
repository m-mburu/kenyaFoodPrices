# Shared price aggregation and coverage contracts.

#' List the price estimators available in the filter controls
#'
#' @return A named character vector of display labels and estimator keys.
#' @noRd
price_calculation_choices <- function() {
  c(
    "Balanced median" = "balanced_median",
    "Record-weighted mean" = "record_weighted_mean"
  )
}

#' Describe the selected estimator in method and filter text
#'
#' @param calculation Estimator key.
#' @return A full estimator label. Unrecognised keys use the balanced-median
#'   label.
#' @noRd
price_calculation_label <- function(calculation) {
  switch(
    calculation,
    balanced_median = "Balanced median (market-month, then county-month)",
    record_weighted_mean = "Record-weighted mean",
    "Balanced median (market-month, then county-month)"
  )
}

# Short estimator name for axis titles, legends and table headings where the
# full aggregation description would be too long.
#' Label price estimates in axes, legends and tables
#'
#' @param calculation Estimator key.
#' @return A short median or mean label, or a generic price estimate label for
#'   an unrecognised key.
#' @noRd
price_calculation_short_label <- function(calculation) {
  switch(
    calculation,
    balanced_median = "Median price estimate",
    record_weighted_mean = "Mean price estimate",
    "Price estimate"
  )
}

#' Estimate monthly prices at market, county and national levels
#'
#' @param data Observation records with month, county and market fields. Rows
#'   lacking geography or month and rows with non-finite prices are omitted.
#' @param price_column Name of the numeric price column.
#' @param calculation Estimator key selecting the balanced median or
#'   record-weighted mean.
#' @return A list of market-month, county-month and national-month tables with
#'   estimates in the source price units and counts at each level. The balanced
#'   median gives market estimates equal weight within a county and county
#'   estimates equal weight in the national summary. The mean carries
#'   observation counts through both levels.
#' @noRd
aggregate_price_data <- function(data, price_column, calculation = "balanced_median") {
  stopifnot(is.character(price_column), length(price_column) == 1L)
  if (!calculation %in% unname(price_calculation_choices())) {
    stop("Unknown calculation: ", calculation, call. = FALSE)
  }

  required <- c("year_month_date", "county", "market", price_column)
  missing <- setdiff(required, names(data))
  if (length(missing)) {
    stop("Price data is missing required fields: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  dt <- data.table::as.data.table(data.table::copy(data))
  dt <- dt[!is.na(year_month_date) & !is.na(county) & !is.na(market) & is.finite(get(price_column))]
  if (!nrow(dt)) {
    empty <- data.table::data.table()
    return(list(market_month = empty, county_month = empty, national_month = empty))
  }

  estimator <- if (identical(calculation, "balanced_median")) stats::median else mean
  market_month <- dt[
    ,
    .(
      estimate = estimator(get(price_column), na.rm = TRUE),
      records = .N
    ),
    by = .(year_month_date, county, market)
  ]

  county_month <- market_month[
    ,
    .(
      estimate = if (identical(calculation, "balanced_median")) {
        stats::median(estimate, na.rm = TRUE)
      } else {
        stats::weighted.mean(estimate, w = records, na.rm = TRUE)
      },
      records = sum(records),
      markets = .N
    ),
    by = .(year_month_date, county)
  ]

  national_month <- county_month[
    ,
    .(
      estimate = if (identical(calculation, "balanced_median")) {
        stats::median(estimate, na.rm = TRUE)
      } else {
        stats::weighted.mean(estimate, w = records, na.rm = TRUE)
      },
      records = sum(records),
      markets = sum(markets),
      counties = .N
    ),
    by = year_month_date
  ]

  data.table::setorder(market_month, year_month_date, county, market)
  data.table::setorder(county_month, year_month_date, county)
  data.table::setorder(national_month, year_month_date)
  list(market_month = market_month, county_month = county_month, national_month = national_month)
}

#' Fill missing calendar months and calculate consecutive-month changes
#'
#' @param data Monthly estimates with one row per observed month.
#' @param date_column Name of the column containing month-start Dates.
#' @param value_column Name of the estimate column, in the selected currency
#'   and physical unit.
#' @return A sorted monthly data.table with the previous estimate, an adjacency
#'   flag, an absolute change and a proportional change. Gaps and unavailable
#'   estimates propagate missing changes. A zero previous estimate makes the
#'   proportional change unavailable.
#' @noRd
complete_monthly_changes <- function(data, date_column = "year_month_date", value_column = "estimate") {
  dt <- data.table::as.data.table(data.table::copy(data))
  if (!nrow(dt)) return(dt)
  required <- c(date_column, value_column)
  missing <- setdiff(required, names(dt))
  if (length(missing)) stop("Monthly data is missing: ", paste(missing, collapse = ", "), call. = FALSE)

  data.table::setorderv(dt, date_column)
  dates <- dt[[date_column]]
  all_months <- data.table::data.table(month = seq(min(dates), max(dates), by = "month"))
  data.table::setnames(all_months, "month", date_column)
  dt <- merge(all_months, dt, by = date_column, all.x = TRUE, sort = TRUE)
  previous <- data.table::shift(dt[[value_column]])
  previous_date <- data.table::shift(dt[[date_column]])
  # The index increases by one per month even across the end of a year.
  month_index <- function(x) {
    as.integer(format(x, "%Y")) * 12L + as.integer(format(x, "%m"))
  }
  consecutive <- !is.na(previous) &
    month_index(previous_date) == month_index(dt[[date_column]]) - 1L
  dt[, previous_estimate := previous]
  dt[, consecutive_month := consecutive]
  dt[, change := data.table::fifelse(consecutive, get(value_column) - previous_estimate, NA_real_)]
  dt[, percent_change := data.table::fifelse(
    consecutive & is.finite(previous_estimate) & previous_estimate != 0,
    change / previous_estimate,
    NA_real_
  )]
  dt
}

# Add calendar gaps and consecutive-month changes to the national estimates.
#' Prepare the shared national price series for Overview and Trends
#'
#' @param national_month The national-month table from aggregate_price_data().
#' @return A monthly table with price_estimate, observations, geographic counts
#'   and consecutive-month changes.
#' @noRd
summarise_monthly_prices <- function(national_month) {
  monthly <- complete_monthly_changes(national_month)
  if (nrow(monthly) == 0L) {
    return(monthly)
  }

  data.table::setnames(
    monthly,
    c("estimate", "records"),
    c("price_estimate", "observations")
  )
  monthly
}

#' Summarise the observation coverage behind a displayed price estimate
#'
#' @param records Number of observation records.
#' @param markets Number of represented markets, if available.
#' @param counties Number of represented counties, if available.
#' @param covered_months Number of observed months, if available.
#' @return Character labels with record counts and any available geography or
#'   month counts.
#' @noRd
price_coverage_label <- function(records, markets = NA_integer_, counties = NA_integer_, covered_months = NA_integer_) {
  size <- max(length(records), length(markets), length(counties), length(covered_months))
  records <- rep_len(records, size)
  markets <- rep_len(markets, size)
  counties <- rep_len(counties, size)
  covered_months <- rep_len(covered_months, size)

  vapply(seq_len(size), function(index) {
    parts <- paste(format_number(records[index]), "records")
    if (is.finite(markets[index])) parts <- c(parts, paste(format_number(markets[index]), "markets"))
    if (is.finite(counties[index])) parts <- c(parts, paste(format_number(counties[index]), "counties"))
    if (is.finite(covered_months[index])) parts <- c(parts, paste(format_number(covered_months[index]), "months"))
    paste(parts, collapse = " | ")
  }, character(1))
}
