# Geography is a separate stage: Climate consumes base records and applies
# its own county focus, while the price pages also restrict the market.
# Missing geography remains in All; a named location excludes unmatched rows.
filter_price_geography <- function(records, selected_county, selected_market) {
  records <- data.table::copy(records)
  if (!identical(selected_county, "All")) {
    records <- records[county %in% selected_county]
  }
  if (!identical(selected_market, "All")) {
    records <- records[market %in% selected_market]
  }
  records
}

# Keep a valid selection; otherwise use the scoped default or first choice.
filter_valid_choice <- function(current, choices, default = NULL) {
  if (length(current) == 1L && current %in% choices) {
    return(current)
  }
  if (length(default) == 1L && default %in% choices) {
    return(default)
  }
  if (length(choices)) choices[[1L]] else character()
}

# Preserve the overlapping period; an unrelated period uses full coverage.
filter_valid_dates <- function(current, available) {
  if (!valid_price_date_range(current) ||
      current[2L] < available[1L] || current[1L] > available[2L]) {
    return(available)
  }
  as.Date(c(max(current[1L], available[1L]),
            min(current[2L], available[2L])))
}

# Establish the original filter defaults once for persistent input controls.
filter_initial_state <- function(food_prices) {
  categories <- sort(unique(food_prices$category))
  selected_category <- filter_valid_choice(NULL, categories)
  records <- food_prices[category %in% selected_category]
  commodities <- sort(unique(records$commodity))
  selected_commodity <- filter_valid_choice(NULL, commodities)
  records <- records[commodity %in% selected_commodity]
  units <- sort(unique(records$unit))
  selected_unit <- filter_valid_choice(NULL, units)
  records <- records[unit %in% selected_unit]
  pricetypes <- sort(unique(records$pricetype))
  selected_pricetype <- filter_valid_choice(NULL, pricetypes)
  records <- records[pricetype %in% selected_pricetype]
  observation_dates <- records$date[!is.na(records$date)]

  list(
    category = selected_category,
    commodity = selected_commodity,
    unit = selected_unit,
    pricetype = selected_pricetype,
    dates = if (length(observation_dates)) {
      as.Date(c(min(observation_dates), max(observation_dates)))
    } else as.Date(character())
  )
}

# Labels remain reactive so currency/units change without rebuilding controls.
filter_label_reactives <- function(input) {
  price_column <- shiny::reactive({
    if (identical(input$Currency, "usdprice")) "usdprice" else "price"
  })
  currency_label <- shiny::reactive({
    if (identical(input$Currency, "usdprice")) "USD" else "KES"
  })
  price_unit_label <- shiny::reactive({
    unit <- tolower(gsub("\\s+", " ", input$unit %||% "unit"))
    paste(currency_label(), "per", unit)
  })
  list(
    price_column = price_column,
    currency_label = currency_label,
    price_unit_label = price_unit_label,
    calculation_label = shiny::reactive({
      price_calculation_label(input$calculation %||% "balanced_median")
    }),
    calculation_short = shiny::reactive({
      price_calculation_short_label(input$calculation %||% "balanced_median")
    }),
    unit_denominator = shiny::reactive(paste0("(", price_unit_label(), ")"))
  )
}

# This display consumes plain values, so it can be reused without a session.
filter_context_ui <- function(selection, price_unit, dates) {
  county <- if (identical(selection$county, "All")) {
    "All counties"
  } else selection$county
  market <- if (identical(selection$market, "All")) {
    "All markets"
  } else selection$market
  period <- paste(format(dates, "%b %Y"), collapse = " - ")
  method <- if (identical(selection$calculation, "record_weighted_mean")) {
    "Record-weighted mean"
  } else "Balanced median"
  chips <- c(selection$commodity, selection$pricetype, price_unit,
             county, market, period, method)
  shiny::div(
    class = "kfp-filter-context",
    lapply(chips, function(label) {
      shiny::tags$span(class = "kfp-filter-chip", label)
    })
  )
}
