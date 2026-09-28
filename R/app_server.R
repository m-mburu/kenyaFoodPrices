#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import data.table
#' @import ggplot2
#' @importFrom dplyr %>%
#' @importFrom DT datatable
#' @importFrom ggiraph renderGirafe
#' @importFrom plotly layout plot_ly renderPlotly
#' @importFrom shiny checkboxGroupInput dateRangeInput div h4 need
#'     reactive renderUI renderText req selectInput selectizeInput
#'     shinyServer validate
#' @importFrom stats reorder
#' @keywords internal
#' @noRd
utils::globalVariables(c(
  ":=", "change", "consecutive_month", "covered_months",
  "display_y", "estimate", "label", "Latest observation month",
  "percent_change",
  "period_id", "previous_estimate", "segment", "smooth_segment"
))

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

kpi_card <- function(label, value, note = NULL, status = "") {
  div(
    class = paste("kfp-kpi", status),
    div(class = "kfp-kpi-label", label),
    div(class = "kfp-kpi-value", value),
    if (!is.null(note)) div(class = "kfp-kpi-note", note)
  )
}

# Compact DataTable. When every row fits on one page, pagination and the
# page-length selector are hidden so the panel shows only useful controls.
datatable_compact <- function(data, page_length = 8, scroll_x = TRUE) {
  page_options <- sort(unique(c(as.integer(page_length), 10L, 25L)))
  single_page <- nrow(data) <= page_length

  DT::datatable(
    data,
    rownames = FALSE,
    options = list(
      pageLength = page_length,
      lengthMenu = list(
        c(page_options, -1L),
        c(as.character(page_options), "All")
      ),
      dom = if (single_page) "t" else "ltip",
      paging = !single_page,
      autoWidth = TRUE,
      scrollX = scroll_x
    )
  )
}

valid_price_date_range <- function(dates) {
  length(dates) == 2L &&
    inherits(dates, "Date") &&
    !anyNA(dates) &&
    dates[1L] <= dates[2L]
}

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

app_server <- function(input, output, session) {
  food_prices <- app_food_prices()

  selected_price_dates <- reactive({
    shiny::req(valid_price_date_range(input$page1_date))
    input$page1_date
  })

  price_column <- reactive({
    if (identical(input$Currency, "usdprice")) {
      "usdprice"
    } else {
      "price"
    }
  })

  currency_label <- reactive({
    if (identical(input$Currency, "usdprice")) {
      "USD"
    } else {
      "KES"
    }
  })

  price_unit_label <- reactive({
    unit <- tolower(gsub("\\s+", " ", input$unit %||% "unit"))
    paste(currency_label(), "per", unit)
  })

  calculation_label <- reactive({
    price_calculation_label(input$calculation %||% "balanced_median")
  })

  # Short estimator name for axis titles and table headings.
  calculation_short <- reactive({
    price_calculation_short_label(input$calculation %||% "balanced_median")
  })

  # Unit denominator for headings, for example "KES per kg".
  unit_denominator <- reactive({
    paste0("(", price_unit_label(), ")")
  })

  output$category_ui <- renderUI({
    selectInput("category", "Category",
     choices = sort(unique(food_prices$category)))
  })

  output$commodity_ui <- renderUI({
    req(input$category)
    commodity_filtered <- food_prices[category == input$category]

    selectInput(
      "commodity",
      "Commodity",
      choices = sort(unique(commodity_filtered$commodity))
    )
  })

  output$unit_ui <- renderUI({
    req(input$category, input$commodity)

    unit_filtered <- food_prices[
      category == input$category & commodity == input$commodity
    ]

    selectInput(
      "unit",
      "Unit",
      choices = sort(unique(unit_filtered$unit))
    )
  })

  output$pricetype_ui <- renderUI({
    req(input$category, input$commodity, input$unit)

    pricetype_filtered <- food_prices[
      category == input$category &
        commodity == input$commodity &
        unit == input$unit
    ]

    selectInput(
      "pricetype",
      "Price Type",
      choices = sort(unique(pricetype_filtered$pricetype))
    )
  })

  # Recreate the range input on reset after its dependent controls settle.
  reset_date_input <- shiny::reactiveVal(0L)

  output$page_year_ui <- renderUI({
    reset_date_input()
    req(input$category, input$commodity, input$unit, input$pricetype)

    year_filtered <- food_prices[
      category == input$category &
        commodity == input$commodity &
        unit == input$unit &
        pricetype == input$pricetype
    ]
    req(nrow(year_filtered) > 0)

    min_date <- year_filtered[, min(date, na.rm = TRUE)]
    max_date <- year_filtered[, max(date, na.rm = TRUE)]

    dateRangeInput(
      "page1_date",
      "Date Range",
      start = min_date,
      end = max_date,
      min = min_date,
      max = max_date
    )
  })

  output$page1_county_ui <- renderUI({
    req(input$category, input$commodity,
     input$unit, input$pricetype,
     input$page1_date)

    price_dates <- selected_price_dates()
    county_filtered <- food_prices[
      category == input$category &
        commodity == input$commodity &
        unit == input$unit &
        pricetype == input$pricetype &
        data.table::between(date, price_dates[1L], price_dates[2L]) &
        !is.na(county)
    ]

    choices <- c("All", sort(unique(county_filtered$county)))
    selectInput(
      "page1_county",
      "County",
      choices = choices,
      multiple = FALSE,
      selected = "All"
    )
  })

  output$page1_market_ui <- renderUI({
    req(input$category, input$commodity,
        input$unit, input$pricetype,
        input$page1_date,
        input$page1_county)

    price_dates <- selected_price_dates()
    market_filtered <- food_prices[
      category == input$category &
        commodity == input$commodity &
        unit == input$unit &
        pricetype == input$pricetype &
        data.table::between(date, price_dates[1L], price_dates[2L])
    ]

    if (!identical(input$page1_county, "All")) {
      market_filtered <- market_filtered[county %in% input$page1_county]
    }

    choices <- c("All", sort(unique(market_filtered$market)))
    selectInput(
      "page1_market",
      "Market",
      choices = choices,
      multiple = FALSE,
      selected = "All"
    )
  })

  base_filtered_data <- reactive({
    shiny::req(
      input$category,
      input$commodity,
      input$unit,
      input$pricetype,
      input$page1_date
    )

    price_dates <- selected_price_dates()
    food_prices[
      category %in% input$category &
        commodity %in% input$commodity &
        unit %in% input$unit &
        pricetype %in% input$pricetype &
        data.table::between(date, price_dates[1L], price_dates[2L])
    ]
  })

  filtered_data <- reactive({
    req(input$page1_county, input$page1_market)

    dt <- copy(base_filtered_data())

    if (!identical(input$page1_county, "All")) {
      dt <- dt[county %in% input$page1_county]
    }

    if (!identical(input$page1_market, "All")) {
      dt <- dt[market %in% input$page1_market]
    }

    dt
  })

  output$filter_context <- renderUI({
    req(input$category, input$commodity,
     input$unit, input$pricetype, input$page1_date,
     input$page1_county, input$page1_market)

    county_label <- if (identical(input$page1_county, "All")) {
      "All counties"
    } else {
      input$page1_county
    }
    market_label <- if (identical(input$page1_market, "All")) {
      "All markets"
    } else {
      input$page1_market
    }
    date_label <- paste(
      format(selected_price_dates()[1L], "%b %Y"),
      format(selected_price_dates()[2L], "%b %Y"),
      sep = " - "
    )

    shiny::tags$div(
      class = "kfp-filter-context",
      shiny::tags$span(class = "kfp-filter-chip", input$commodity),
      shiny::tags$span(class = "kfp-filter-chip", input$pricetype),
      shiny::tags$span(class = "kfp-filter-chip", price_unit_label()),
      shiny::tags$span(class = "kfp-filter-chip", county_label),
      shiny::tags$span(class = "kfp-filter-chip", market_label),
      shiny::tags$span(class = "kfp-filter-chip", date_label),
      shiny::tags$span(
        class = "kfp-filter-chip",
        if (identical(input$calculation, "record_weighted_mean")) {
          "Record-weighted mean"
        } else {
          "Balanced median"
        }
      )
    )
  })

  observeEvent(input$reset_filters,
    {
      first_category <- sort(unique(food_prices$category))[1]
      updateSelectInput(session, "category", selected = first_category)
      updateSelectInput(session, "Currency", selected = "price")

      reset_date_input(reset_date_input() + 1L)
      if (!is.null(input$page1_county)) {
        updateSelectInput(session, "page1_county", selected = "All")
      }
      if (!is.null(input$page1_market)) {
        updateSelectInput(session, "page1_market", selected = "All")
      }
      shiny::updateRadioButtons(
        session,
        "calculation",
        selected = "balanced_median"
      )
    },
    ignoreInit = TRUE
  )

  climate_module_server(
    "climate",
    price_data = base_filtered_data,
    price_column = price_column,
    price_unit_label = price_unit_label,
    global_county = reactive(input$page1_county %||% "All"),
    set_global_county = function(county) {
      updateSelectInput(session, "page1_county", selected = county)
    },
    reset_focus = reactive(input$reset_filters)
  )

  price_aggregation <- reactive({
    dt <- filtered_data()
    req(nrow(dt) > 0)
    aggregate_price_data(dt, 
    price_column(), 
    input$calculation %||% "balanced_median")
  })

  monthly_summary <- reactive({
    monthly <- data.table::copy(price_aggregation()$national_month)
    req(nrow(monthly) > 0)
    data.table::setnames(monthly, "estimate", "mean_price")
    data.table::setnames(monthly, "records", "observations")
    complete_monthly_changes(monthly, value_column = "mean_price")
  })

  output$summary_kpis <- renderUI({
    dt <- filtered_data()
    shiny::validate(shiny::need(
      nrow(dt) > 0,
      "No price records match these filters. Broaden the selection or reset."
    ))
    monthly <- monthly_summary()
    latest_row <- monthly[.N]
    latest_month <- latest_row$year_month_date
    previous_month <- seq(latest_month, by = "-1 month", length.out = 2L)[2L]
    year_ago <- as.Date(sprintf(
      "%s-%s-01",
      as.integer(format(latest_month, "%Y")) - 1L,
      format(latest_month, "%m")
    ))
    year_row <- monthly[year_month_date == year_ago]
    year_price <- if (nrow(year_row)) year_row$mean_price else NA_real_
    year_pct <- if (is.finite(year_price) && year_price != 0) {
      (latest_row$mean_price - year_price) / year_price
    } else {
      NA_real_
    }
    method <- if (identical(input$calculation, "record_weighted_mean")) {
      "Record-weighted mean"
    } else {
      "Balanced median"
    }
    method_note <- if (identical(input$calculation, "record_weighted_mean")) {
      paste(
        "Each market-month mean contributes in proportion to its records;",
        "the record weights carry through county and selected-area means."
      )
    } else {
      paste(
        "Take the median of records in each market-month, then the median",
        "across markets in each county-month, then across available counties."
      )
    }
    record_word <- if (latest_row$observations == 1L) "record" else "records"
    market_word <- if (latest_row$markets == 1L) "market" else "markets"
    county_word <- if (latest_row$counties == 1L) "county" else "counties"

    div(
      class = "kfp-overview-summary",
      div(
        class = "kfp-overview-summary-heading",
        tags$span("Latest available price"),
        tags$span(
          class = "kfp-overview-date",
          paste(format(latest_month, "%b %Y"), "within selected period")
        )
      ),
      div(
        class = "kfp-overview-price",
        tags$strong(paste(
          currency_label(),
          format_number(latest_row$mean_price, 2)
        )),
        tags$span(paste("per", tolower(input$unit)))
      ),
      div(class = "kfp-overview-method", method),
      div(
        class = "kfp-overview-comparisons",
        div(
          class = "kfp-overview-comparison",
          tags$span(class = "kfp-overview-comparison-label",
                    paste("From", format(previous_month, "%b %Y"))),
          tags$strong(format_price_comparison(
            latest_row$percent_change
          )),
          if (!isTRUE(latest_row$consecutive_month)) {
            tags$span("No estimate for the prior calendar month.")
          }
        ),
        div(
          class = "kfp-overview-comparison",
          tags$span(class = "kfp-overview-comparison-label",
                    paste("From", format(year_ago, "%b %Y"))),
          tags$strong(format_price_comparison(year_pct)),
          if (!is.finite(year_pct)) {
            tags$span("No valid estimate for the same month last year.")
          }
        )
      ),
      p(
        class = "kfp-overview-coverage",
        paste0(
          "Based on ", format_number(latest_row$observations),
          " ", record_word, " from ", format_number(latest_row$markets),
          " ", market_word, " in ", format_number(latest_row$counties),
          " ", county_word, " this month."
        )
      ),
      tags$details(
        class = "kfp-overview-method-note",
        tags$summary("How is this estimate calculated?"),
        p(method_note),
        p("Available markets can change between months.")
      )
    )
  })

  observeEvent(input$overview_to_trends, {
    shiny::updateNavbarPage(session, "main_nav", selected = "Trends")
  })

  output$overview_trend <- ggiraph::renderGirafe({
    shiny::validate(shiny::need(
      nrow(filtered_data()) > 0,
      "No price records match these filters. Broaden the selection or reset."
    ))
    monthly <- data.table::copy(monthly_summary())
    shiny::validate(shiny::need(
      sum(is.finite(monthly$mean_price)) > 1L,
      "There is not enough monthly data for a trend."
    ))

    monthly[, tooltip := paste0(
      "Month: ", format(year_month_date, "%b %Y"),
      "<br>", calculation_short(), ": ",
      format_number(mean_price, 2), " ", price_unit_label(),
      "<br>", calculation_label(),
      "<br>Coverage: ",
      price_coverage_label(observations, markets, counties)
    )]
    monthly[, segment := cumsum(!is.finite(mean_price))]
    observed <- is.finite(monthly$mean_price)
    isolated <- observed &
      !data.table::shift(observed, fill = FALSE) &
      !data.table::shift(observed, type = "lead", fill = FALSE)
    points <- monthly[observed]
    if (nrow(points) > 36L) {
      points <- monthly[which(isolated |
        seq_along(observed) == length(observed))]
    }
    points[, month_id := as.character(year_month_date)]
    span_months <- nrow(monthly)
    date_breaks <- if (span_months <= 24L) {
      "3 months"
    } else if (span_months <= 72L) {
      "1 year"
    } else {
      "2 years"
    }

    gg <- ggplot2::ggplot(
      monthly,
      ggplot2::aes(x = year_month_date, y = mean_price)
    ) +
      ggiraph::geom_line_interactive(
        ggplot2::aes(group = segment, tooltip = tooltip),
        colour = "#008d98",
        linewidth = 1.1,
        na.rm = TRUE
      ) +
      ggiraph::geom_point_interactive(
        data = points,
        ggplot2::aes(tooltip = tooltip, data_id = month_id),
        colour = "#008d98",
        size = 2.7
      ) +
      ggplot2::labs(
        x = NULL,
        y = price_unit_label()
      ) +
      ggplot2::scale_x_date(
        date_labels = "%b %Y",
        date_breaks = date_breaks
      ) +
      ggplot2::theme_minimal(base_size = 14) +
      ggplot2::theme(
        panel.grid.minor = ggplot2::element_blank(),
        panel.grid.major.x = ggplot2::element_blank(),
        axis.title.y = ggplot2::element_text(margin =
          ggplot2::margin(r = 10))
      )

    standard_girafe(gg, width_svg = 12, height_svg = 4.2)
  })

  output$recent_change_table <- DT::renderDT({
    monthly <- copy(monthly_summary())
    shiny::validate(shiny::need(nrow(monthly) > 0,
    "No monthly data available."))

    monthly[, pct_change := percent_change]

    estimate_heading <- paste0(calculation_short(), "\n", unit_denominator())
    display <- monthly[order(-year_month_date)][1:min(.N, 12)][
      ,
      .(
        Month = format(year_month_date, "%b %Y"),
        Estimate = format_number(mean_price, 2),
        Change = vapply(change, format_change, character(1),
         unit_label = price_unit_label()),
        `% Change` = vapply(pct_change, format_percent, character(1)),
        Coverage = vapply(seq_len(.N),
         function(i) price_coverage_label(observations[i],
          markets[i], counties[i]),
           character(1))
      )
    ]
    data.table::setnames(display, "Estimate", estimate_heading)

    datatable_compact(display, page_length = 12, scroll_x = FALSE)
  })

  output$top_county_table <- DT::renderDT({
    monthly <- data.table::copy(price_aggregation()$county_month)
    shiny::validate(shiny::need(
      nrow(monthly) > 0,
      paste(
        "No county data available. Try all counties, broaden the",
        "date range, or reset the county filter."
      )
    ))
    estimate_heading <- paste0(calculation_short(), "\n", unit_denominator())
    display <- monthly[
      ,
      .(
        Estimate = if (
          identical(input$calculation, "record_weighted_mean")
        ) {
          stats::weighted.mean(estimate, records)
        } else {
          stats::median(estimate)
        },
        `Latest observation month` = max(year_month_date),
        Records = sum(records),
        Markets = max(markets),
        `Covered Months` = .N
      ),
      by = .(County = county)
    ][order(-Estimate)][1:min(.N, 10)]

    display[, Estimate := vapply(Estimate,
     format_number, character(1), digits = 2)]
    display[
      ,
      `Latest observation month` := format(
        `Latest observation month`, "%b %Y"
      )
    ]
    data.table::setnames(display, "Estimate", estimate_heading)
    datatable_compact(display, page_length = 10, scroll_x = FALSE)
  })

  output$top_market_table <- DT::renderDT({
    monthly <- data.table::copy(price_aggregation()$market_month)
    shiny::validate(shiny::need(
      nrow(monthly) > 0,
      "No market data available. Try all markets, broaden the date range, or reset the market filter."
    ))
    estimate_heading <- paste0(calculation_short(), "\n", unit_denominator())
    display <- monthly[
      ,
      .(
        County = county[which.max(year_month_date)],
        Estimate = if (
          identical(input$calculation, "record_weighted_mean")
        ) {
          stats::weighted.mean(estimate, records)
        } else {
          stats::median(estimate)
        },
        `Latest observation month` = max(year_month_date),
        Records = sum(records),
        `Covered Months` = .N
      ),
      by = .(Market = market)
    ][order(-Estimate)][1:min(.N, 10)]

    display[, Estimate := vapply(Estimate, format_number, character(1), digits = 2)]
    display[
      ,
      `Latest observation month` := format(
        `Latest observation month`, "%b %Y"
      )
    ]
    data.table::setnames(display, "Estimate", estimate_heading)
    datatable_compact(display, page_length = 10, scroll_x = FALSE)
  })

  trend_summary <- reactive({
    monthly <- data.table::copy(monthly_summary())
    req(nrow(monthly) > 0, input$trend_frequency)

    if (identical(input$trend_frequency, "quarter")) {
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

    all_periods <- data.table::data.table(
      period = seq(min(summary$period), max(summary$period), by = step)
    )
    summary <- merge(
      all_periods, summary, by = "period", all.x = TRUE, sort = TRUE
    )
    summary[, display_price := mean_price]
    if (identical(input$trend_display, "smooth")) {
      summary[, display_price := data.table::frollmean(
        mean_price, n = 3L, align = "right", fill = NA_real_
      )]
    }
    summary[]
  })

  trend_panel_open <- shiny::reactiveVal(FALSE)
  trend_compare_open <- shiny::reactiveVal(FALSE)
  trend_reference_id <- shiny::reactiveVal("")
  trend_compare_id <- shiny::reactiveVal("")

  trend_observed_periods <- reactive({
    trend <- data.table::copy(trend_summary())
    trend <- trend[is.finite(mean_price)]
    if (!nrow(trend)) {
      return(trend)
    }

    trend[, period_id := as.character(period)]
    trend[]
  })

  valid_trend_period <- function(period_id, trend) {
    nzchar(period_id) && nrow(trend) && period_id %in% trend$period_id
  }

  clear_trend_comparison <- function() {
    trend_compare_id("")
    trend_compare_open(FALSE)
    shiny::updateSelectInput(
      session,
      "trend_compare_period",
      selected = ""
    )
  }

  clear_trend_selection <- function(return_focus = FALSE) {
    trend_reference_id("")
    trend_panel_open(FALSE)
    clear_trend_comparison()
    shiny::updateSelectInput(
      session,
      "trend_reference_period",
      selected = ""
    )
    if (isTRUE(return_focus)) {
      session$sendCustomMessage("kfp-focus", list(id = "trend_selection_open"))
    }
  }

  observe({
    if (isTRUE(trend_panel_open())) {
      shinyjs::show("trend_selection_panel")
    } else {
      shinyjs::hide("trend_selection_panel")
    }

    if (isTRUE(trend_panel_open()) && isTRUE(trend_compare_open())) {
      shinyjs::show("trend_compare_panel")
      shinyjs::hide("trend_compare_toggle")
    } else {
      shinyjs::hide("trend_compare_panel")
      shinyjs::show("trend_compare_toggle")
    }

    shinyjs::toggleState(
      "trend_compare_toggle",
      condition = nzchar(trend_reference_id())
    )
  })

  observeEvent(trend_observed_periods(), {
    trend <- trend_observed_periods()
    quarterly <- identical(input$trend_frequency, "quarter")
    choices <- c(
      "Choose a period" = "",
      trend_period_choices(trend, quarterly)
    )

    reference_id <- trend_reference_id()
    if (!valid_trend_period(reference_id, trend)) {
      reference_id <- ""
      trend_reference_id("")
      clear_trend_comparison()
    }

    compare_id <- trend_compare_id()
    if (!valid_trend_period(compare_id, trend) ||
        identical(compare_id, reference_id)) {
      compare_id <- ""
      trend_compare_id("")
    }

    shiny::updateSelectInput(
      session,
      "trend_reference_period",
      choices = choices,
      selected = reference_id
    )
    shiny::updateSelectInput(
      session,
      "trend_compare_period",
      choices = choices,
      selected = compare_id
    )

    if (!nrow(trend)) {
      clear_trend_selection()
    }
  }, ignoreNULL = FALSE)

  trend_reference_row <- reactive({
    trend <- trend_observed_periods()
    reference_id <- trend_reference_id()
    if (!valid_trend_period(reference_id, trend)) {
      return(trend[0])
    }
    trend[period_id == reference_id]
  })

  trend_compare_row <- reactive({
    trend <- trend_observed_periods()
    compare_id <- trend_compare_id()
    if (!valid_trend_period(compare_id, trend)) {
      return(trend[0])
    }
    trend[period_id == compare_id]
  })

  output$trend_period_summary <- renderUI({
    reference_row <- trend_reference_row()
    quarterly <- identical(input$trend_frequency, "quarter")

    if (!nrow(reference_row)) {
      return(tags$p(
        class = "kfp-trends-note kfp-trend-selection-empty",
        "Choose a month or quarter from the chart, or use the",
        "Reference period selector below."
      ))
    }

    period_label <- trend_period_label(
      reference_row$period,
      quarterly,
      reference_row$covered_months
    )
    smooth_value <- if (
      identical(input$trend_display, "smooth") &&
        is.finite(reference_row$display_price)
    ) {
      paste(format_number(reference_row$display_price, 2), price_unit_label())
    } else if (identical(input$trend_display, "smooth")) {
      "Not available"
    } else {
      "Not shown"
    }

    div(
      class = "kfp-trend-selection-summary",
      div(
        class = "kfp-trend-selection-card",
        tags$span("Period"),
        tags$strong(period_label)
      ),
      div(
        class = "kfp-trend-selection-card",
        tags$span("Selected estimate"),
        tags$strong(paste(
          format_number(reference_row$mean_price, 2),
          price_unit_label()
        )),
        tags$small(price_calculation_label(
          input$calculation %||% "balanced_median"
        ))
      ),
      div(
        class = "kfp-trend-selection-card",
        tags$span("Trailing average"),
        tags$strong(smooth_value),
        tags$small("Shown only in trailing-average mode")
      ),
      div(
        class = "kfp-trend-selection-card",
        tags$span("Coverage"),
        tags$strong(paste(
          format_number(reference_row$observations), "records"
        )),
        tags$small(paste(
          format_number(reference_row$markets), "markets |",
          format_number(reference_row$counties), "counties"
        ))
      )
    )
  })

  output$trend_compare_summary <- renderUI({
    reference_row <- trend_reference_row()
    compare_row <- trend_compare_row()
    quarterly <- identical(input$trend_frequency, "quarter")

    if (!isTRUE(trend_compare_open()) || !nrow(reference_row) ||
        !nrow(compare_row)) {
      return(NULL)
    }

    difference <- compare_row$mean_price - reference_row$mean_price
    percent_change <- trend_percent_change(
      reference_row$mean_price,
      compare_row$mean_price
    )

    div(
      class = "kfp-trend-compare-result",
      if (identical(input$trend_display, "smooth")) {
        tags$p(
          class = "kfp-trends-note",
          "Comparison uses the selected period estimate, not the",
          "trailing average line."
        )
      },
      div(
        class = "kfp-trend-selection-card",
        tags$span("Reference period"),
        tags$strong(trend_period_label(
          reference_row$period,
          quarterly,
          reference_row$covered_months
        ))
      ),
      div(
        class = "kfp-trend-selection-card",
        tags$span("Comparison period"),
        tags$strong(trend_period_label(
          compare_row$period,
          quarterly,
          compare_row$covered_months
        ))
      ),
      div(
        class = "kfp-trend-selection-card",
        tags$span("Difference"),
        tags$strong(format_change(difference, price_unit_label()))
      ),
      div(
        class = "kfp-trend-selection-card",
        tags$span("Percentage difference"),
        tags$strong(if (is.finite(percent_change)) {
          format_percent(percent_change)
        } else {
          "Not available"
        }),
        tags$small("Comparison minus reference")
      )
    )
  })

  observeEvent(input$trend_selection_open, {
    trend_panel_open(TRUE)
    session$sendCustomMessage("kfp-focus", list(id = "trend_reference_period"))
  }, ignoreInit = TRUE)

  observeEvent(input$trend_reference_period, {
    trend <- trend_observed_periods()
    reference_id <- input$trend_reference_period %||% ""

    trend_reference_id(reference_id)
    trend_panel_open(TRUE)

    if (!valid_trend_period(reference_id, trend)) {
      clear_trend_comparison()
      return()
    }

    if (identical(trend_compare_id(), reference_id)) {
      clear_trend_comparison()
    }
  }, ignoreInit = TRUE)

  observeEvent(input$trend_compare_toggle, {
    if (!nzchar(trend_reference_id())) {
      return()
    }

    trend_compare_open(TRUE)
    session$sendCustomMessage("kfp-focus", list(id = "trend_compare_period"))
  }, ignoreInit = TRUE)

  observeEvent(input$trend_compare_period, {
    trend <- trend_observed_periods()
    compare_id <- input$trend_compare_period %||% ""
    if (!valid_trend_period(compare_id, trend) ||
        identical(compare_id, trend_reference_id())) {
      trend_compare_id("")
      return()
    }

    trend_compare_id(compare_id)
  }, ignoreInit = TRUE)

  observeEvent(input$trend_compare_close, {
    clear_trend_comparison()
  }, ignoreInit = TRUE)

  observeEvent(input$trend_selection_clear, {
    clear_trend_selection(return_focus = TRUE)
  }, ignoreInit = TRUE)

  observeEvent(input$trend_selection_escape, {
    clear_trend_selection(return_focus = TRUE)
  }, ignoreInit = TRUE)

  observeEvent(input$linePlot_selected, {
    trend <- trend_observed_periods()
    selected_id <- input$linePlot_selected[1]

    if (length(selected_id) == 0L ||
        !valid_trend_period(selected_id, trend) ||
        identical(selected_id, trend_reference_id())) {
      return()
    }

    trend_reference_id(selected_id)
    trend_panel_open(TRUE)
    shiny::updateSelectInput(
      session,
      "trend_reference_period",
      selected = selected_id
    )

    if (identical(trend_compare_id(), selected_id)) {
      clear_trend_comparison()
    }
  }, ignoreInit = TRUE)

  observeEvent(input$reset_filters, {
    clear_trend_selection()
  }, ignoreInit = TRUE)

  output$trends_context <- renderUI({
    dt <- filtered_data()
    req(nrow(dt) > 0, input$page1_county, input$page1_market)

    last_date <- max(dt$date, na.rm = TRUE)
    location <- if (!identical(input$page1_county, "All")) {
      paste0(input$page1_county, " county")
    } else {
      "Available markets in Kenya"
    }

    if (!identical(input$page1_market, "All")) {
      location <- paste(location, "-", input$page1_market)
    }

    estimator <- price_calculation_label(
      input$calculation %||% "balanced_median"
    )

    shiny::tags$div(
      class = "kfp-trends-context",
      shiny::tags$strong(
        paste(input$commodity, input$pricetype, input$unit, sep = " | ")
      ),
      shiny::tags$span(paste(" | Selected estimator:", estimator)),
      shiny::tags$span(paste(" | ", location, " | As of", format(last_date, "%b %Y"))),
      shiny::tags$span(paste(" | ", format_number(nrow(dt)), "records"))
    )
  })

  output$trends_kpis <- renderUI({
    monthly <- data.table::copy(monthly_summary())
    monthly <- monthly[is.finite(mean_price)]
    req(nrow(monthly) > 0)

    latest <- monthly[.N]
    previous_date <- as.Date(sprintf(
      "%s-%s-01",
      as.integer(format(latest$year_month_date, "%Y")) - 1L,
      format(latest$year_month_date, "%m")
    ))
    previous <- monthly[year_month_date == previous_date]
    yoy_pct <- if (nrow(previous) && previous$mean_price != 0) {
      (latest$mean_price - previous$mean_price) / previous$mean_price
    } else {
      NA_real_
    }

    div(
      class = "kfp-trends-summary",
      div(
        class = "kfp-trends-summary-item",
        tags$span("Latest monthly estimate"),
        tags$strong(paste(
          format_number(latest$mean_price, 2), price_unit_label()
        )),
        tags$small(paste(
          format(latest$year_month_date, "%b %Y"), " | ",
          format_number(latest$observations), " records | ",
          format_number(latest$markets), " markets | ",
          format_number(latest$counties), " counties"
        ))
      ),
      div(
        class = "kfp-trends-summary-item",
        tags$span("Same month last year"),
        tags$strong(format_price_comparison(yoy_pct)),
        tags$small(if (nrow(previous)) {
          paste("vs", format(previous_date, "%b %Y"))
        } else {
          "No matching month available"
        })
      )
    )
  })

  output$trend_scope_note <- renderUI({
    method <- price_calculation_label(
      input$calculation %||% "balanced_median"
    )
    period <- if (identical(input$trend_frequency, "quarter")) {
      "Quarterly points average the available monthly estimates;"
    } else {
      "Each point is a monthly estimate;"
    }
    smooth <- if (identical(input$trend_display, "smooth")) {
      " The bold line is a trailing average of three consecutive points."
    } else {
      ""
    }
    tags$p(
      class = "kfp-trends-note",
      paste0(period, " method: ", method, ".", smooth),
      "Missing months remain gaps. Prices are nominal."
    )
  })

  output$trend_table_note <- renderUI({
    tags$p(
      class = "kfp-trends-note",
      if (identical(input$trend_frequency, "quarter")) {
        "Quarterly values average available monthly estimates using "
      } else {
        "Monthly values use "
      },
      price_calculation_label(
        input$calculation %||% "balanced_median"
      ),
      " (", price_unit_label(), "). Change requires consecutive",
      " periods; gaps and missing comparisons are shown as blank."
    )
  })

  output$annual_note <- renderUI({
    price_val <- price_column()
    dt <- filtered_data()[is.finite(get(price_val))]
    req(nrow(dt) > 0)
    monthly <- dt[
      , .(mean_price = mean(get(price_val))),
      by = .(month = as.Date(format(date, "%Y-%m-01")))
    ]
    spread <- if (nrow(monthly) > 1L) {
      format_number(stats::sd(monthly$mean_price), 2)
    } else {
      "Unavailable"
    }
    tags$p(
      class = "kfp-trends-note",
      "Dots show each year's mean recorded price; bars span the lowest",
      " to highest record. This view uses raw records, not the selected",
      " monthly estimator. Incomplete years and changing market coverage",
      " limit comparisons. Spread of monthly raw-record means: ",
      spread, " ", price_unit_label(), "."
    )
  })

  output$seasonality_note <- renderUI({
    dt <- filtered_data()
    req(nrow(dt) > 0)
    years <- as.integer(format(dt$date, "%Y"))
    tags$p(
      class = "kfp-trends-note",
      "Index 100 is each year's mean of its available monthly raw-record",
      " means; 110 means 10% above that yearly mean. The shaded band",
      " spans the middle half of observed yearly values. Partial years",
      " are included. This view does not use the monthly estimator.",
      " Contributing years: ", min(years), " to ", max(years), "."
    )
  })

  output$linePlot <- ggiraph::renderGirafe({
    trend <- trend_summary()
    shiny::validate(shiny::need(
      sum(is.finite(trend$mean_price)) > 1,
      "There is not enough data for a trend."
    ))

    method <- price_calculation_short_label(
      input$calculation %||% "balanced_median"
    )
    quarterly <- identical(input$trend_frequency, "quarter")
    smoothed <- identical(input$trend_display, "smooth")
    trend[, segment := cumsum(!is.finite(mean_price))]
    trend[, smooth_segment := cumsum(!is.finite(display_price))]
    trend[, period_id := as.character(period)]
    trend[, display_y := data.table::fifelse(
      is.finite(display_price), display_price, mean_price
    )]
    trend[, hover_text := paste0(
      format(period, if (quarterly) "%Y-%m" else "%b %Y"),
      if (quarterly) paste0(
        " (quarter; ", covered_months, " observed months)"
      ) else "",
      "<br>", method, ": ", format_number(mean_price, 2),
      " ", price_unit_label(),
      if (smoothed) paste0(
        "<br>Trailing 3-period average: ",
        format_number(display_price, 2), " ", price_unit_label()
      ) else "",
      "<br>Records: ", format_number(observations),
      "<br>Markets: ", format_number(markets),
      "<br>Counties: ", format_number(counties)
    )]

    gg <- ggplot2::ggplot(trend, ggplot2::aes(x = period))
    if (smoothed) {
      gg <- gg +
        ggplot2::geom_line(
          ggplot2::aes(y = mean_price, group = segment),
          colour = "#9bb5b5", linewidth = 0.7, na.rm = TRUE
        ) +
        ggiraph::geom_line_interactive(
          ggplot2::aes(
            y = display_price, group = smooth_segment,
            tooltip = hover_text
          ),
          colour = "#008e96", linewidth = 1.4, na.rm = TRUE
        )
    } else {
      gg <- gg + ggiraph::geom_line_interactive(
        ggplot2::aes(
          y = mean_price, group = segment, tooltip = hover_text
        ),
        colour = "#008e96", linewidth = 1.4, na.rm = TRUE
      )
    }
    selection_points <- trend[is.finite(mean_price)]
    gg <- gg + ggiraph::geom_point_interactive(
      data = selection_points,
      ggplot2::aes(
        y = display_y, tooltip = hover_text, data_id = period_id
      ),
      shape = 21,
      fill = "#008e96",
      colour = "#008e96",
      alpha = 0.01,
      size = 5,
      stroke = 0.2
    )
    points <- trend[is.finite(display_price)][
      , .SD[c(1L, .N)], by = segment
    ]
    points <- unique(points, by = "period")
    gg <- gg + ggiraph::geom_point_interactive(
      data = points,
      ggplot2::aes(
        y = display_price, tooltip = hover_text, data_id = period_id
      ),
      colour = "#008e96", size = 2.5
    ) +
      ggplot2::labs(
        x = if (quarterly) "Quarter" else "Month",
        y = paste(method, unit_denominator())
      ) +
      ggplot2::scale_x_date(
        date_labels = "%Y",
        date_breaks = if (nrow(trend) > 120) "2 years" else "1 year"
      ) +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

    selected_id <- trend_reference_id()
    if (!selected_id %in% selection_points$period_id) {
      selected_id <- character()
    }

    standard_girafe(
      gg,
      width_svg = 14,
      height_svg = 4.4,
      selectable = TRUE,
      selected = selected_id
    )
  })

  output$trend_change_table <- DT::renderDT({
    trend <- data.table::copy(trend_summary())
    shiny::validate(shiny::need(
      nrow(trend) > 0, "No period values are available."
    ))
    trend[, previous := data.table::shift(mean_price)]
    trend[, change := mean_price - previous]
    trend[, percent_change := data.table::fifelse(
      is.finite(previous) & previous != 0,
      100 * change / previous, NA_real_
    )]
    quarterly <- identical(input$trend_frequency, "quarter")
    trend[, label := if (quarterly) {
      paste0(
        "Q", (as.integer(format(period, "%m")) - 1L) %/% 3L + 1L,
        " ", format(period, "%Y")
      )
    } else {
      format(period, "%b %Y")
    }]
    display <- trend[order(-period)][
      ,
      .(
        Period = label,
        Estimate = mean_price,
        Change = change,
        `% change` = percent_change,
        `Trailing average` = if (
          identical(input$trend_display, "smooth")
        ) display_price else NULL,
        Records = observations,
        Markets = markets,
        Counties = counties,
        `Covered months` = covered_months
      )
    ]
    widget <- datatable_compact(
      display, page_length = 12, scroll_x = TRUE
    )
    number_columns <- intersect(
      c("Estimate", "Change", "% change", "Trailing average"),
      names(display)
    )
    DT::formatRound(widget, columns = number_columns, digits = 1)
  })

  output$main_price_histogram <- ggiraph::renderGirafe({
    price_val <- price_column()
    dt <- filtered_data()[is.finite(get(price_val))]
    shiny::validate(shiny::need(
      nrow(dt) > 2,
      "There is not enough data for an annual price trend."
    ))

    annual <- dt[
      ,
      .(
        mean_price = mean(get(price_val), na.rm = TRUE),
        min_price = min(get(price_val), na.rm = TRUE),
        max_price = max(get(price_val), na.rm = TRUE),
        observations = .N,
        covered_months = data.table::uniqueN(format(date, "%Y-%m")),
        markets = data.table::uniqueN(market),
        counties = data.table::uniqueN(county)
      ),
      by = .(calendar_year = as.integer(format(date, "%Y")))
    ][order(calendar_year)]
    annual[, year_date := as.Date(sprintf("%s-01-01", calendar_year))]
    annual[, year_id := as.character(calendar_year)]
    annual[, hover_text := paste0(
      "Year: ", calendar_year,
      "<br>Mean recorded price: ", format_number(mean_price, 2),
      " ", price_unit_label(),
      "<br>Range: ", format_number(min_price, 2), " - ",
      format_number(max_price, 2),
      "<br>Records: ", format_number(observations),
      "<br>Covered months: ", covered_months, " of 12",
      ifelse(covered_months < 12, " (partial)", ""),
      "<br>Markets: ", markets,
      "<br>Counties: ", counties
    )]

    gg <- ggplot2::ggplot(annual, ggplot2::aes(x = year_date, y = mean_price)) +
      ggplot2::geom_linerange(
        ggplot2::aes(ymin = min_price, ymax = max_price),
        colour = "#b9dfe1",
        linewidth = 1.1
      ) +
      ggiraph::geom_point_interactive(
        ggplot2::aes(tooltip = hover_text, data_id = year_id),
        colour = "#00a2ab",
        size = 2
      ) +
      ggplot2::labs(
        title = NULL,
        x = "Year",
        y = paste("Mean recorded price", unit_denominator())
      ) +
      ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(
        plot.title = ggplot2::element_text(face = "bold"),
        panel.grid.minor = ggplot2::element_blank()
      )

    standard_girafe(gg, width_svg = 11.5, height_svg = 4.1)
  })

  output$price_month_means <- ggiraph::renderGirafe({
    price_val <- price_column()
    dt <- filtered_data()[is.finite(get(price_val))]
    shiny::validate(shiny::need(nrow(dt) > 2, "There is not enough data for seasonality."))

    monthly <- dt[
      ,
      .(
        mean_price = mean(get(price_val), na.rm = TRUE),
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

    season <- monthly[
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
    season[, month_label := month.abb[month_num]]
    season[, month_id := as.character(month_num)]
    season[, hover_text := paste0(
      month_label,
      "<br>Index: ", format_number(season_index, 1),
      "<br>Middle 50%: ", format_number(lower, 1), " - ", format_number(upper, 1),
      "<br>Years: ", years,
      "<br>Records: ", format_number(observations)
    )]

    gg <- ggplot2::ggplot(
      season,
      ggplot2::aes(x = month_num, y = season_index, group = 1)
    ) +
      ggplot2::geom_ribbon(
        ggplot2::aes(ymin = lower, ymax = upper),
        fill = "#00a2ab",
        alpha = 0.16
      ) +
      ggiraph::geom_line_interactive(
        ggplot2::aes(tooltip = hover_text, data_id = month_id, group = 1),
        colour = "#00a2ab",
        linewidth = 1.3
      ) +
      ggiraph::geom_point_interactive(
        ggplot2::aes(tooltip = hover_text, data_id = month_id),
        colour = "#00a2ab",
        size = 2.2
      ) +
      ggplot2::geom_hline(yintercept = 100, linetype = "dashed", colour = "#7b8c8c") +
      ggplot2::scale_x_continuous(breaks = 1:12, labels = month.abb) +
      ggplot2::labs(
        title = NULL,
        x = "Month",
        y = "Index"
      ) +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(
        plot.title = ggplot2::element_text(face = "bold"),
        panel.grid.minor = ggplot2::element_blank()
      )

    standard_girafe(gg, width_svg = 11.5, height_svg = 4.1)
  })

  geography_summary <- reactive({
    price_val <- price_column()
    dt <- filtered_data()[
      is.finite(get(price_val)) & !is.na(county) & !is.na(market)
    ]
    req(nrow(dt) > 0)

    if (!identical(input$page1_market, "All")) {
      benchmark <- base_filtered_data()[
        is.finite(get(price_val)) & !is.na(county) & !is.na(market)
      ]
      if (!identical(input$page1_county, "All")) {
        benchmark <- benchmark[county == input$page1_county]
      }
      scope <- if (identical(input$page1_county, "All")) {
        "All available markets"
      } else {
        paste("All available markets in", input$page1_county)
      }
      comparison <- data.table::rbindlist(list(
        data.table::data.table(
          location = input$page1_market,
          mean_price = mean(dt[[price_val]]),
          records = nrow(dt),
          covered_months = data.table::uniqueN(
            format(dt$date, "%Y-%m")
          ),
          latest_month = max(as.Date(format(dt$date, "%Y-%m-01")))
        ),
        data.table::data.table(
          location = scope,
          mean_price = mean(benchmark[[price_val]]),
          records = nrow(benchmark),
          covered_months = data.table::uniqueN(
            format(benchmark$date, "%Y-%m")
          ),
          latest_month = max(as.Date(
            format(benchmark$date, "%Y-%m-01")
          ))
        )
      ))
    } else {
      grouping <- if (!identical(input$page1_county, "All") ||
        data.table::uniqueN(dt$county) == 1L) {
        "market"
      } else {
        "county"
      }
      comparison <- dt[
        ,
        .(
          mean_price = mean(get(price_val)),
          records = .N,
          covered_months = data.table::uniqueN(
            format(date, "%Y-%m")
          ),
          latest_month = max(as.Date(format(date, "%Y-%m-01")))
        ),
        by = .(location = get(grouping))
      ]
    }
    comparison[order(-mean_price)]
  })

  output$geography_panel_ui <- renderUI({
    comparison <- geography_summary()
    if (nrow(comparison) < 2L) {
      return(tags$p(
        class = "kfp-trends-note",
        "Only one location has prices for this selection."
      ))
    }
    tags$div(
      tags$p(
        class = "kfp-trends-note",
        "Mean of raw price records in the selected period (",
        price_unit_label(), "). Locations can have different months and",
        " numbers of records. The chart shows up to 12 locations;",
        " search the table for all locations."
      ),
      shinycssloaders::withSpinner(
        visualization_frame(
          ggiraph::girafeOutput("geography_bar_plot", height = "100%"),
          "trend-detail"
        ),
        color = "#00a2ab"
      ),
      DT::DTOutput("geography_table")
    )
  })

  output$geography_table <- DT::renderDT({
    comparison <- geography_summary()
    display <- comparison[
      ,
      .(
        Location = location,
        `Mean recorded price` = mean_price,
        Records = records,
        `Covered months` = covered_months,
        `Latest month` = format(latest_month, "%b %Y")
      )
    ]
    DT::formatRound(
      datatable_compact(display, page_length = 12),
      columns = "Mean recorded price", digits = 2
    )
  })

  output$geography_bar_plot <- ggiraph::renderGirafe({
    comparison <- data.table::copy(geography_summary())
    shiny::validate(shiny::need(
      nrow(comparison) > 1, "No location comparison is available."
    ))
    comparison <- comparison[seq_len(min(nrow(comparison), 12L))]
    comparison[, location_id := make.unique(as.character(location))]
    comparison[, hover_text := paste0(
      location,
      "<br>Mean recorded price: ",
      format_number(mean_price, 2), " ", price_unit_label(),
      "<br>Records: ", format_number(records),
      "<br>Covered months: ", covered_months,
      "<br>Latest month: ", format(latest_month, "%b %Y")
    )]

    gg <- ggplot2::ggplot(
      comparison,
      ggplot2::aes(x = mean_price, y = reorder(location, mean_price))
    ) +
      ggiraph::geom_col_interactive(
        ggplot2::aes(tooltip = hover_text, data_id = location_id),
        fill = "#008e96", width = 0.68
      ) +
      ggplot2::labs(
        x = paste("Mean recorded price", unit_denominator()),
        y = NULL
      ) +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

    standard_girafe(gg, width_svg = 12, height_svg = 4.4)
  })

  map_data <- reactive({
    dt <- filtered_data()[!is.na(latitude) & !is.na(longitude)]
    monthly <- price_aggregation()$market_month
    shiny::validate(shiny::need(nrow(monthly) > 0,
    "No mapped market data available. Try all markets, broaden the date range, or reset the county filter."))
    location <- dt[, .(county = county[which.max(date)],
     latitude = mean(latitude),
      longitude = mean(longitude)), by = market]
    summary <- monthly[
      ,
      .(
        avg_price = if (identical(input$calculation,
         "record_weighted_mean")) stats::weighted.mean(estimate,
          records) else stats::median(estimate),
        latest_date = max(year_month_date),
        records = sum(records),
        covered_months = .N
      ),
      by = market
    ]
    merge(location, summary, by = "market")[order(-avg_price)]
  })

  output$price_map <- ggiraph::renderGirafe({
    market_price_map(
      map_df = map_data(),
      counties = app_counties(),
      price_unit = price_unit_label(),
      currency = currency_label(),
      calculation = input$calculation %||% "balanced_median",
      period_label = paste(
        format(selected_price_dates()[1L], "%b %Y"),
        format(selected_price_dates()[2L], "%b %Y"),
        sep = " - "
      )
    )
  })

  output$map_market_title <- shiny::renderText({
    total <- nrow(map_data())
    shown <- min(total, 15L)
    paste0(
      shown, " highest market price estimates (of ", total,
      " mapped markets, selected period)"
    )
  })

  output$map_market_note <- shiny::renderText({
    paste0(
      "Colour and estimates summarise the selected period. ",
      "Markets may have been observed in different months, so this is not ",
      "a same-month comparison."
    )
  })

  output$map_market_table <- DT::renderDT({
    estimate_heading <- paste0(calculation_short(), "\n", unit_denominator())
    display <- copy(map_data())[1:min(.N, 15)]
    display <- display[
      ,
      .(
        Market = market,
        County = county,
        Estimate = avg_price,
        `Latest Month` = latest_date,
        `Covered Months` = covered_months,
        Records = records
      )
    ]
    display[, Estimate := vapply(Estimate, format_number, character(1), digits = 2)]
    display[, `Latest Month` := format(`Latest Month`, "%b %Y")]
    data.table::setnames(display, "Estimate", estimate_heading)
    datatable_compact(display, page_length = 6)
  })

  output$compare_counties_ui <- renderUI({
    dt <- base_filtered_data()[!is.na(county)]
    shiny::validate(shiny::need(nrow(dt) > 0, "No counties are available for this selection."))

    ranked <- dt[, .N, by = county][order(-N, county)]
    choices <- ranked$county
    selected <- ranked[1:min(.N, 4)]$county

    div(
      class = "kfp-toggle-control kfp-compare-control",
      checkboxGroupInput(
        "compare_counties",
        "Counties to compare",
        choices = choices,
        selected = selected,
        inline = TRUE
      )
    )
  })

  output$compare_commodities_ui <- renderUI({
    req(input$category, input$unit, input$pricetype, input$page1_date)
    price_dates <- selected_price_dates()
    dt <- food_prices[
      category == input$category &
        unit == input$unit &
        pricetype == input$pricetype &
        data.table::between(date, price_dates[1L], price_dates[2L])
    ]
    shiny::validate(shiny::need(nrow(dt) > 0, "No commodities are available for this selection."))

    ranked <- dt[, .N, by = commodity][order(-N, commodity)]
    choices <- ranked$commodity
    selected <- ranked[1:min(.N, 5)]$commodity

    div(
      class = "kfp-toggle-control kfp-compare-control",
      checkboxGroupInput(
        "compare_commodities",
        "Commodities to compare",
        choices = choices,
        selected = selected,
        inline = TRUE
      )
    )
  })

  output$county_compare_plot <- ggiraph::renderGirafe({
    req(input$compare_counties)
    dt <- base_filtered_data()[county %in% input$compare_counties]
    price_val <- price_column()
    shiny::validate(shiny::need(nrow(dt) > 1, "Select at least one county with available data."))

    compare <- dt[
      ,
      .(mean_price = mean(get(price_val), na.rm = TRUE)),
      by = .(year_month_date, county)
    ][order(year_month_date)]
    compare[, tooltip := paste0(
      county, "<br>", format(year_month_date, "%b %Y"),
      "<br>Mean recorded price: ", format_number(mean_price, 2),
      " ", price_unit_label()
    )]
    compare[, county_id := as.character(county)]
    compare[, county_point_id := paste(county, year_month_date, sep = "|")]
    county_levels <- sort(unique(compare$county))
    county_palette <- stats::setNames(
      rep(c("#00a2ab", "#f2a541", "#647acb", "#23845f", "#c94a32", "#7a5fa3"), length.out = length(county_levels)),
      county_levels
    )

    gg <- ggplot2::ggplot(
      compare,
      ggplot2::aes(x = year_month_date, y = mean_price, colour = county, group = county)
    ) +
      ggiraph::geom_line_interactive(
        ggplot2::aes(tooltip = tooltip, data_id = county_id, group = county),
        linewidth = 1
      ) +
      ggiraph::geom_point_interactive(
        ggplot2::aes(tooltip = tooltip, data_id = county_point_id),
        size = 1.8
      ) +
      ggplot2::labs(
        title = "County price comparison",
        x = "Month",
        y = paste("Mean recorded price", unit_denominator()),
        colour = "County"
      ) +
      ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
      ggplot2::scale_colour_manual(values = county_palette) +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(
        plot.title = ggplot2::element_text(face = "bold"),
        legend.position = "bottom",
        panel.grid.minor = ggplot2::element_blank()
      )

    standard_girafe(gg, width_svg = 12, height_svg = 4.2)
  })

  output$commodity_compare_plot <- ggiraph::renderGirafe({
    req(input$compare_commodities, input$category, input$unit,
        input$pricetype, input$page1_date)
    price_val <- price_column()
    price_dates <- selected_price_dates()
    dt <- food_prices[
      category == input$category &
        commodity %in% input$compare_commodities &
        unit == input$unit &
        pricetype == input$pricetype &
        data.table::between(date, price_dates[1L], price_dates[2L])
    ]
    shiny::validate(shiny::need(nrow(dt) > 1, "Select commodities with available data for the current unit and price type."))

    compare <- dt[
      ,
      .(mean_price = mean(get(price_val), na.rm = TRUE)),
      by = .(year_month_date, commodity)
    ][order(year_month_date)]
    compare[, tooltip := paste0(
      commodity, "<br>", format(year_month_date, "%b %Y"),
      "<br>Mean recorded price: ", format_number(mean_price, 2),
      " ", price_unit_label()
    )]
    compare[, commodity_id := as.character(commodity)]
    compare[, commodity_point_id := paste(commodity, year_month_date, sep = "|")]
    commodity_levels <- sort(unique(compare$commodity))
    commodity_palette <- stats::setNames(
      rep(c("#00a2ab", "#f2a541", "#647acb", "#23845f", "#c94a32", "#7a5fa3"), length.out = length(commodity_levels)),
      commodity_levels
    )

    gg <- ggplot2::ggplot(
      compare,
      ggplot2::aes(x = year_month_date, y = mean_price, colour = commodity, group = commodity)
    ) +
      ggiraph::geom_line_interactive(
        ggplot2::aes(tooltip = tooltip, data_id = commodity_id, group = commodity),
        linewidth = 1
      ) +
      ggiraph::geom_point_interactive(
        ggplot2::aes(tooltip = tooltip, data_id = commodity_point_id),
        size = 1.8
      ) +
      ggplot2::labs(
        title = "Commodity price comparison",
        x = "Month",
        y = paste("Mean recorded price", unit_denominator()),
        colour = "Commodity"
      ) +
      ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
      ggplot2::scale_colour_manual(values = commodity_palette) +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(
        plot.title = ggplot2::element_text(face = "bold"),
        legend.position = "bottom",
        panel.grid.minor = ggplot2::element_blank()
      )

    standard_girafe(gg, width_svg = 12, height_svg = 4.2)
  })

  output$coverage_summary <- renderUI({
    dt <- filtered_data()
    req(nrow(dt) > 0)

    div(
      class = "kfp-kpi-grid kfp-coverage-grid",
      kpi_card("Records", format_number(nrow(dt)), "selected filters"),
      kpi_card("Date span", paste(format(min(dt$date), "%Y"), format(max(dt$date), "%Y"), sep = "-"), paste(min(dt$date), "to", max(dt$date))),
      kpi_card("Counties", format_number(uniqueN(dt$county, na.rm = TRUE)), "covered"),
      kpi_card("Markets", format_number(uniqueN(dt$market, na.rm = TRUE)), "covered"),
      kpi_card("Missing county", format_number(sum(is.na(dt$county))), "records"),
      kpi_card("Latest record", as.character(max(dt$date, na.rm = TRUE)), input$commodity)
    )
  })

  output$coverage_year_plot <- ggiraph::renderGirafe({
    dt <- filtered_data()
    shiny::validate(shiny::need(nrow(dt) > 0, "No coverage data available."))

    coverage <- dt[
      ,
      .(
        Records = .N,
        Counties = uniqueN(county, na.rm = TRUE),
        Markets = uniqueN(market)
      ),
      by = .(Year = year)
    ][order(Year)]
    coverage[, tooltip := paste0(
      "Year: ", Year,
      "<br>Records: ", format_number(Records),
      "<br>Counties: ", format_number(Counties),
      "<br>Markets: ", format_number(Markets)
    )]
    coverage[, year_id := as.character(Year)]

    gg <- ggplot2::ggplot(
      coverage,
      ggplot2::aes(x = Year, y = Records)
    ) +
      ggiraph::geom_col_interactive(
        ggplot2::aes(tooltip = tooltip, data_id = year_id),
        fill = "#00a2ab",
        width = 0.7
      ) +
      ggplot2::labs(
        title = "Observation coverage by year",
        x = "Year",
        y = "Records"
      ) +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(
        plot.title = ggplot2::element_text(face = "bold"),
        panel.grid.minor = ggplot2::element_blank()
      )

    standard_girafe(gg, width_svg = 12, height_svg = 4.2)
  })

  output$coverage_table <- DT::renderDT({
    dt <- filtered_data()
    shiny::validate(shiny::need(nrow(dt) > 0, "No coverage data available."))

    display <- dt[
      ,
      .(
        Records = .N,
        Counties = uniqueN(county, na.rm = TRUE),
        Markets = uniqueN(market),
        `First Date` = min(date),
        `Latest Date` = max(date)
      ),
      by = .(Year = year)
    ][order(-Year)]

    display[, `First Date` := as.character(`First Date`)]
    display[, `Latest Date` := as.character(`Latest Date`)]
    datatable_compact(display, page_length = 6)
  })
}
