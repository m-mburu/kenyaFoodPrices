# Climate data helpers ------------------------------------------------------

mean_or_na <- function(x) {
  if (!length(x) || all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}

normalise_county_name <- function(x) {
  value <- tolower(trimws(as.character(x)))
  value <- sub("\\s+county$", "", value)
  value <- sub("\\s+city$", "", value)
  gsub("[^a-z0-9]", "", value)
}

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

prepare_jmr_climate <- function(jmr_data, pcodes) {
  required_data <- c("adm2_pcode", "date", "indicator", "grouping", "value")
  required_pcodes <- c("adm1_pcode", "adm1_name", "adm2_pcode", "adm2_name")

  if (!all(required_data %in% names(jmr_data))) {
    stop("JMR data is missing required fields: ", paste(setdiff(required_data, names(jmr_data)), collapse = ", "))
  }
  if (!all(required_pcodes %in% names(pcodes))) {
    stop("P-code data is missing required fields: ", paste(setdiff(required_pcodes, names(pcodes)), collapse = ", "))
  }

  climate <- data.table::as.data.table(jmr_data)[
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
