# Climate data helpers ------------------------------------------------------

#' Average available values within a group
#'
#' @param x Numeric observations in a common unit.
#' @return A numeric mean, or NA when no values are available.
#' @noRd
mean_or_na <- function(x) {
  if (!length(x) || all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}

#' Create county-name keys for matching climate and geometry records
#'
#' @param x County names to normalise.
#' @return Lower-case keys with a trailing county or city label and punctuation
#'   removed.
#' @noRd
normalise_county_name <- function(x) {
  value <- tolower(trimws(as.character(x)))
  value <- sub("\\s+county$", "", value)
  value <- sub("\\s+city$", "", value)
  gsub("[^a-z0-9]", "", value)
}

#' Standardise values within a comparable reference group
#'
#' @param x Numeric measurements from one reference group.
#' @return A numeric vector aligned to x. Non-finite inputs and groups with
#'   fewer than two finite values yield NA. Finite values in a constant group
#'   receive zero.
#' @noRd
safe_zscore <- function(x) {
  result <- rep(NA_real_, length(x))
  valid <- is.finite(x)

  if (sum(valid) < 2L) {
    return(result)
  }

  spread <- stats::sd(x[valid])
  if (!is.finite(spread) || spread == 0) {
    result[valid] <- 0
    return(result)
  }

  result[valid] <- (x[valid] - mean(x[valid])) / spread
  result
}

#' Classify a standardised climate measurement
#'
#' @param z Standardised rainfall or NDVI scores, in standard deviations.
#' @return One condition label per score. Missing and non-finite scores are
#'   labelled Not available.
#' @noRd
climate_condition <- function(z) {
  result <- rep("Not available", length(z))
  valid <- is.finite(z)
  result[valid & z < -1] <- "Much below normal"
  result[valid & z >= -1 & z < -0.5] <- "Below normal"
  result[valid & z >= -0.5 & z <= 0.5] <- "Near normal"
  result[valid & z > 0.5 & z <= 1] <- "Above normal"
  result[valid & z > 1] <- "Much above normal"
  result
}

#' Harmonise raw JMR climate records with the COD area lookup
#'
#' @param jmr_data Raw Kenya JMR indicator records in a supported long or wide
#'   format.
#' @param pcodes ADM2-to-county code and name lookup from the same source
#'   release.
#' @return A data.table ordered by month and area, with physical rainfall and
#'   NDVI values and standardised scores. Wide-file scores use each ADM2 and
#'   calendar month as the reference group. Long-file scores retain the
#'   supplied indicator values.
#' @noRd
prepare_jmr_climate <- function(jmr_data, pcodes) {
  long_fields <- c("adm2_pcode", "date", "indicator", "grouping", "value")
  wide_fields <- c(
    "adm2_pcode", "year", "month",
    "drought_ndvi_original", "drought_rainfall_original"
  )
  required_pcodes <- c("adm1_pcode", "adm1_name", "adm2_pcode", "adm2_name")

  if (!all(required_pcodes %in% names(pcodes))) {
    stop("P-code data is missing required fields: ", paste(setdiff(required_pcodes, names(pcodes)), collapse = ", "))
  }

  data <- data.table::as.data.table(jmr_data)

  if (all(long_fields %in% names(data))) {
    climate <- data[
      indicator %chin% c("Drought - NDVI", "Drought - rainfall") &
        grouping %chin% c("Original value", "Indicator value"),
      .(adm2_pcode, date, indicator, grouping, value)
    ]
    climate[, date := as.Date(date)]
    climate[, measure := data.table::fcase(
      indicator == "Drought - NDVI" & grouping == "Original value", "ndvi",
      indicator == "Drought - NDVI" & grouping == "Indicator value", "ndvi_z",
      indicator == "Drought - rainfall" & grouping == "Original value", "rainfall_mm",
      indicator == "Drought - rainfall" & grouping == "Indicator value", "rainfall_z",
      default = NA_character_
    )]
    climate <- climate[!is.na(measure)]

    climate <- data.table::dcast(
      climate,
      adm2_pcode + date ~ measure,
      value.var = "value"
    )
  } else if (all(wide_fields %in% names(data))) {
    climate <- data[
      ,
      .(
        adm2_pcode,
        date = as.Date(sprintf("%04d-%02d-01", as.integer(year), as.integer(month))),
        rainfall_mm = as.numeric(drought_rainfall_original),
        ndvi = as.numeric(drought_ndvi_original)
      )
    ]
    climate <- climate[date >= as.Date("2010-01-01")]

    if (anyNA(climate$date)) {
      stop("JMR wide data contains invalid year or month values.")
    }
    if (anyDuplicated(climate[, .(adm2_pcode, date)])) {
      stop("JMR wide data contains duplicate ADM2-month rows.")
    }

    climate[, calendar_month := as.integer(format(date, "%m"))]
    climate[
      ,
      `:=`(
        rainfall_z = safe_zscore(rainfall_mm),
        ndvi_z = safe_zscore(ndvi)
      ),
      by = .(adm2_pcode, calendar_month)
    ]
    climate[, calendar_month := NULL]
  } else {
    stop(
      "JMR data does not match the supported long or wide schema. ",
      "Missing long fields: ", paste(setdiff(long_fields, names(data)), collapse = ", "),
      "; missing wide fields: ", paste(setdiff(wide_fields, names(data)), collapse = ", ")
    )
  }

  lookup <- unique(data.table::as.data.table(pcodes)[
    ,
    .(adm1_pcode, adm1_name, adm2_pcode, adm2_name)
  ])
  climate <- merge(climate, lookup, by = "adm2_pcode", all.x = TRUE)

  if (climate[is.na(adm1_pcode), .N] > 0L) {
    stop("Some climate records do not match the supplied P-code lookup.")
  }

  data.table::setcolorder(
    climate,
    c(
      "date", "adm1_pcode", "adm1_name", "adm2_pcode", "adm2_name",
      "rainfall_mm", "rainfall_z", "ndvi", "ndvi_z"
    )
  )
  data.table::setorder(climate, date, adm1_pcode, adm2_pcode)
  climate[]
}

#' Summarise monthly ADM2 climate measurements within counties
#'
#' @param climate_adm2 ADM2-month data with dates, COD identifiers and physical
#'   and standardised rainfall and NDVI values.
#' @return One row per county-month, with an unweighted mean of available ADM2
#'   values per measure and counts of all and complete sub-counties.
#' @noRd
aggregate_climate_to_county <- function(climate_adm2) {
  climate <- data.table::as.data.table(climate_adm2)
  required <- c(
    "date", "adm1_pcode", "adm1_name", "adm2_pcode",
    "rainfall_mm", "rainfall_z", "ndvi", "ndvi_z"
  )

  if (!all(required %in% names(climate))) {
    stop("ADM2 climate data is missing required fields: ", paste(setdiff(required, names(climate)), collapse = ", "))
  }

  result <- climate[
    ,
    .(
      rainfall_mm = mean_or_na(rainfall_mm),
      rainfall_z = mean_or_na(rainfall_z),
      ndvi = mean_or_na(ndvi),
      ndvi_z = mean_or_na(ndvi_z),
      subcounties = data.table::uniqueN(adm2_pcode),
      complete_subcounties = sum(
        stats::complete.cases(rainfall_mm, rainfall_z, ndvi, ndvi_z)
      )
    ),
    by = .(date, adm1_pcode, county = adm1_name)
  ]
  data.table::setorder(result, date, adm1_pcode)
  result[]
}

#' Measure how climate conditions relate to subsequent price changes
#'
#' @param data A monthly table containing date, price_change, rainfall_z and
#'   ndvi_z. Keep missing months in the calendar so row shifts represent
#'   months.
#' @param max_lag Largest number of months by which climate can lead prices.
#' @return One row per indicator and lag with the Spearman correlation and
#'   complete-pair count. Fewer than 12 pairs yield NA.
#' @noRd
lagged_climate_correlations <- function(data, max_lag = 6L) {
  dt <- data.table::as.data.table(data)
  required <- c("date", "price_change", "rainfall_z", "ndvi_z")

  if (!all(required %in% names(dt))) {
    stop("Correlation data is missing required fields: ", paste(setdiff(required, names(dt)), collapse = ", "))
  }

  data.table::setorder(dt, date)
  max_lag <- as.integer(max_lag)
  drivers <- data.table::data.table(
    driver = c("Rainfall", "Vegetation"),
    field = c("rainfall_z", "ndvi_z")
  )

  data.table::rbindlist(lapply(0:max_lag, function(lag_months) {
    future_price <- data.table::shift(dt$price_change, lag_months, type = "lead")

    data.table::rbindlist(lapply(seq_len(nrow(drivers)), function(index) {
        field <- drivers$field[[index]]
        valid <- stats::complete.cases(dt[[field]], future_price)
        data.table::data.table(
          lag_months = lag_months,
          driver = drivers$driver[[index]],
          correlation = if (sum(valid) >= 12L) {
            stats::cor(dt[[field]][valid], future_price[valid], method = "spearman")
          } else {
            NA_real_
          },
          observations = sum(valid)
        )
      }))
  }))[]
}
