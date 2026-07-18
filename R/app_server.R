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
#' @importFrom shiny checkboxGroupInput dateRangeInput div h4 need reactive renderUI req selectInput selectizeInput validate
#' @importFrom stats reorder
#' @keywords internal
#' @noRd
utils::globalVariables(c(
  "Average Price", ":=", "consecutive_month", "estimate",
  "percent_change", "previous_estimate"
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
      paste0(ifelse(value > 0, "+", ""), format_number(value, 2), " ", unit_label)
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

kpi_card <- function(label, value, note = NULL, status = "") {
  div(
    class = paste("kfp-kpi", status),
    div(class = "kfp-kpi-label", label),
    div(class = "kfp-kpi-value", value),
    if (!is.null(note)) div(class = "kfp-kpi-note", note)
  )
}

datatable_compact <- function(data, page_length = 8) {
  page_options <- sort(unique(c(as.integer(page_length), 10L, 25L)))

  DT::datatable(
    data,
    rownames = FALSE,
    options = list(
      pageLength = page_length,
      lengthMenu = list(
        c(page_options, -1L),
        c(as.character(page_options), "All")
      ),
      dom = "ltip",
      autoWidth = TRUE,
      scrollX = TRUE
    )
  )
}

app_server <- function(input, output, session) {
  food_prices <- app_food_prices()


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

  output$category_ui <- renderUI({
    selectInput("category", "Category", choices = sort(unique(food_prices$category)))
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

  output$page_year_ui <- renderUI({
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
    req(input$category, input$commodity, input$unit, input$pricetype, input$page1_date)

    county_filtered <- food_prices[
      category == input$category &
        commodity == input$commodity &
        unit == input$unit &
        pricetype == input$pricetype &
        data.table::between(date, input$page1_date[1], input$page1_date[2]) &
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
    req(input$category, input$commodity, input$unit, input$pricetype, input$page1_date, input$page1_county)

    market_filtered <- food_prices[
      category == input$category &
        commodity == input$commodity &
        unit == input$unit &
        pricetype == input$pricetype &
        data.table::between(date, input$page1_date[1], input$page1_date[2])
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
    req(input$category, input$commodity, input$unit, input$pricetype, input$page1_date)

    food_prices[
      category %in% input$category &
        commodity %in% input$commodity &
        unit %in% input$unit &
        pricetype %in% input$pricetype &
        data.table::between(date, input$page1_date[1], input$page1_date[2])
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
    req(input$category, input$commodity, input$unit, input$pricetype, input$page1_date, input$page1_county, input$page1_market)

    county_label <- if (identical(input$page1_county, "All")) "All counties" else input$page1_county
    market_label <- if (identical(input$page1_market, "All")) "All markets" else input$page1_market
    date_label <- paste(
      format(input$page1_date[1], "%b %Y"),
      format(input$page1_date[2], "%b %Y"),
      sep = " - "
    )

    shiny::tags$div(
      class = "kfp-filter-context",
      shiny::tags$span(class = "kfp-filter-chip", input$commodity),
      shiny::tags$span(class = "kfp-filter-chip", input$pricetype),
      shiny::tags$span(class = "kfp-filter-chip", input$unit),
      shiny::tags$span(class = "kfp-filter-chip", county_label),
      shiny::tags$span(class = "kfp-filter-chip", market_label),
      shiny::tags$span(class = "kfp-filter-chip", date_label),
      shiny::tags$span(class = "kfp-filter-chip", calculation_label())
    )
  })

  observeEvent(input$reset_filters,
    {
      first_category <- sort(unique(food_prices$category))[1]
      updateSelectInput(session, "category", selected = first_category)
      updateSelectInput(session, "Currency", selected = "price")

      if (!is.null(input$page1_date)) {
        shiny::updateDateRangeInput(
          session,
          "page1_date",
          start = min(food_prices$date, na.rm = TRUE),
          end = max(food_prices$date, na.rm = TRUE)
        )
      }
      if (!is.null(input$page1_county)) {
        updateSelectInput(session, "page1_county", selected = "All")
      }
      if (!is.null(input$page1_market)) {
        updateSelectInput(session, "page1_market", selected = "All")
      }
      shiny::updateRadioButtons(session, "calculation", selected = "balanced_median")
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
    }
  )

  price_aggregation <- reactive({
    dt <- filtered_data()
    req(nrow(dt) > 0)
    aggregate_price_data(dt, price_column(), input$calculation %||% "balanced_median")
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
    req(nrow(dt) > 0)
    price_val <- price_column()
    unit_label <- price_unit_label()
    monthly <- monthly_summary()

    latest_row <- monthly[.N]
    previous_row <- if (nrow(monthly) > 1) monthly[.N - 1] else NULL
    current_price <- latest_row$mean_price
    previous_price <- if (!is.null(previous_row)) previous_row$mean_price else NA_real_
    mom_change <- current_price - previous_price
    mom_pct <- if (!is.na(previous_price) && previous_price != 0) mom_change / previous_price else NA_real_

    latest_month <- latest_row$year_month_date
    yoy_month <- as.Date(sprintf(
      "%s-%s-01",
      as.integer(format(latest_month, "%Y")) - 1,
      format(latest_month, "%m")
    ))
    yoy_row <- monthly[year_month_date == yoy_month]
    yoy_price <- if (nrow(yoy_row) > 0) yoy_row$mean_price else NA_real_
    yoy_pct <- if (!is.na(yoy_price) && yoy_price != 0) (current_price - yoy_price) / yoy_price else NA_real_

    div(
      class = "kfp-kpi-grid",
      kpi_card("Latest month", format(latest_month, "%b %Y"), price_coverage_label(latest_row$observations, latest_row$markets, latest_row$counties, sum(is.finite(monthly$mean_price)))),
      kpi_card("Price estimate", format_number(current_price, 2), paste(unit_label, "-", calculation_label())),
      kpi_card("Month change", format_change(mom_change, unit_label), if (isTRUE(latest_row$consecutive_month)) format_percent(mom_pct) else "Not available: prior calendar month has no observation", ifelse(mom_change > 0, "kfp-up", "kfp-down")),
      kpi_card("Year change", format_percent(yoy_pct), paste("vs", format(yoy_month, "%b %Y")), ifelse(yoy_pct > 0, "kfp-up", "kfp-down")),
      kpi_card("Counties", format_number(latest_row$counties), "in latest month"),
      kpi_card("Markets", format_number(latest_row$markets), "in latest month")
    )
  })

  output$overview_trend <- ggiraph::renderGirafe({
    monthly <- monthly_summary()
    validate(need(nrow(monthly) > 1, "There is not enough monthly data for a trend."))

    monthly[, tooltip := paste0(
      "Month: ", format(year_month_date, "%b %Y"),
      "<br>Average price: ", format_number(mean_price, 2), " ", price_unit_label(),
      "<br>", calculation_label(),
      "<br>Coverage: ", price_coverage_label(observations, markets, counties)
    )]
    monthly[, month_id := as.character(year_month_date)]

    gg <- ggplot2::ggplot(
      monthly,
      ggplot2::aes(x = year_month_date, y = mean_price)
    ) +
      ggiraph::geom_line_interactive(
        ggplot2::aes(tooltip = tooltip, data_id = month_id, group = 1),
        colour = "#00a2ab",
        linewidth = 1.2
      ) +
      ggiraph::geom_point_interactive(
        ggplot2::aes(tooltip = tooltip, data_id = month_id),
        colour = "#00a2ab",
        size = 2
      ) +
      ggplot2::labs(
        title = "Monthly price trend",
        x = "Month",
        y = paste("Average price", price_unit_label())
      ) +
      ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(
        plot.title = ggplot2::element_text(face = "bold"),
        panel.grid.minor = ggplot2::element_blank()
      )

    standard_girafe(gg, width_svg = 14, height_svg = 4.4)
  })

  output$recent_change_table <- DT::renderDT({
    monthly <- copy(monthly_summary())
    validate(need(nrow(monthly) > 0, "No monthly data available."))

    monthly[, pct_change := percent_change]

    display <- monthly[order(-year_month_date)][1:min(.N, 12)][
      ,
      .(
        Month = format(year_month_date, "%b %Y"),
        `Average Price` = format_number(mean_price, 2),
        Change = vapply(change, format_change, character(1), unit_label = price_unit_label()),
        `% Change` = vapply(pct_change, format_percent, character(1)),
        Coverage = vapply(seq_len(.N), function(i) price_coverage_label(observations[i], markets[i], counties[i]), character(1))
      )
    ]

    datatable_compact(display, page_length = 6)
  })

  output$top_county_table <- DT::renderDT({
    monthly <- data.table::copy(price_aggregation()$county_month)
    validate(need(nrow(monthly) > 0, "No county data available. Try all counties, broaden the date range, or reset the county filter."))
    display <- monthly[
      ,
      .(
        `Average Price` = if (identical(input$calculation, "record_weighted_mean")) stats::weighted.mean(estimate, records) else stats::median(estimate),
        `Latest Date` = max(year_month_date),
        Records = sum(records),
        Markets = max(markets),
        `Covered Months` = .N
      ),
      by = .(County = county)
    ][order(-`Average Price`)][1:min(.N, 10)]

    display[, `Average Price` := vapply(`Average Price`, format_number, character(1), digits = 2)]
    display[, `Latest Date` := as.character(`Latest Date`)]
    datatable_compact(display)
  })

  output$top_market_table <- DT::renderDT({
    monthly <- data.table::copy(price_aggregation()$market_month)
    validate(need(nrow(monthly) > 0, "No market data available. Try all markets, broaden the date range, or reset the market filter."))
    display <- monthly[
      ,
      .(
        County = county[which.max(year_month_date)],
        `Average Price` = if (identical(input$calculation, "record_weighted_mean")) stats::weighted.mean(estimate, records) else stats::median(estimate),
        `Latest Date` = max(year_month_date),
        Records = sum(records),
        `Covered Months` = .N
      ),
      by = .(Market = market)
    ][order(-`Average Price`)][1:min(.N, 10)]

    display[, `Average Price` := vapply(`Average Price`, format_number, character(1), digits = 2)]
    display[, `Latest Date` := as.character(`Latest Date`)]
    datatable_compact(display)
  })

  trend_summary <- reactive({
    dt <- filtered_data()
    req(nrow(dt) > 1, input$trend_frequency)
    price_val <- price_column()

    dt <- dt[is.finite(get(price_val))]
    req(nrow(dt) > 1)

    if (identical(input$trend_frequency, "quarter")) {
      summary <- dt[
        ,
        .(
          mean_price = mean(get(price_val), na.rm = TRUE),
          observations = .N,
          counties = uniqueN(county, na.rm = TRUE),
          markets = uniqueN(market, na.rm = TRUE)
        ),
        by = .(period = year_quarter_date)
      ]
      step <- "3 months"
      frequency_label <- "quarterly"
    } else {
      summary <- dt[
        ,
        .(
          mean_price = mean(get(price_val), na.rm = TRUE),
          observations = .N,
          counties = uniqueN(county, na.rm = TRUE),
          markets = uniqueN(market, na.rm = TRUE)
        ),
        by = .(period = year_month_date)
      ]
      step <- "month"
      frequency_label <- "monthly"
    }

    summary <- summary[order(period)]
    if (nrow(summary) > 1) {
      all_periods <- data.table::data.table(
        period = seq(min(summary$period), max(summary$period), by = step)
      )
      summary <- merge(all_periods, summary, by = "period", all.x = TRUE, sort = TRUE)
    }

    summary[, display_price := mean_price]
    if (identical(input$trend_display, "smooth")) {
      summary[, display_price := data.table::frollmean(
        mean_price,
        n = 3L,
        align = "right",
        fill = NA_real_
      )]
    }

    summary[, frequency_label := frequency_label]
    summary
  })

  output$trends_context <- renderUI({
    dt <- filtered_data()
    req(nrow(dt) > 0, input$page1_county, input$page1_market)

    last_date <- max(dt$date, na.rm = TRUE)
    location <- if (!identical(input$page1_county, "All")) {
      paste0(input$page1_county, " county")
    } else {
      "Kenya"
    }

    if (!identical(input$page1_market, "All")) {
      location <- paste(location, "-", input$page1_market)
    }

    shiny::tags$div(
      class = "kfp-trends-context",
      shiny::tags$strong(
        paste(input$commodity, input$pricetype, input$unit, sep = " | ")
      ),
      shiny::tags$span(paste(" | ", location, " | As of", format(last_date, "%b %Y"))),
      shiny::tags$span(paste(" | ", format_number(nrow(dt)), "records"))
    )
  })

  output$trends_kpis <- renderUI({
    dt <- filtered_data()
    req(nrow(dt) > 1)
    price_val <- price_column()
    valid <- dt[is.finite(get(price_val))]
    req(nrow(valid) > 1)

    monthly <- valid[
      ,
      .(mean_price = mean(get(price_val), na.rm = TRUE)),
      by = .(year_month_date)
    ][order(year_month_date)]

    latest <- monthly[.N]
    latest_year <- as.integer(format(latest$year_month_date, "%Y")) - 1L
    latest_month <- format(latest$year_month_date, "%m")
    previous_date <- as.Date(sprintf("%s-%s-01", latest_year, latest_month))
    previous <- monthly[year_month_date == previous_date]
    yoy_pct <- if (nrow(previous) > 0 && previous$mean_price != 0) {
      (latest$mean_price - previous$mean_price) / previous$mean_price
    } else {
      NA_real_
    }

    volatility <- if (nrow(monthly) > 1) {
      stats::sd(monthly$mean_price, na.rm = TRUE)
    } else {
      NA_real_
    }

    div(
      class = "kfp-kpi-grid kfp-trends-kpis",
      kpi_card(
        "Latest price",
        format_number(latest$mean_price, 2),
        price_unit_label()
      ),
      kpi_card(
        "12-month change",
        format_percent(yoy_pct),
        if (nrow(previous) > 0) {
          paste("vs", format(previous_date, "%b %Y"))
        } else {
          "Not available"
        },
        ifelse(is.na(yoy_pct), "", ifelse(yoy_pct > 0, "kfp-up", "kfp-down"))
      ),
      kpi_card("Period high", format_number(max(monthly$mean_price, na.rm = TRUE), 2), price_unit_label()),
      kpi_card("Monthly volatility", format_number(volatility, 2), "SD of monthly averages"),
      kpi_card("Observations", format_number(nrow(valid)), "price records")
    )
  })

  output$linePlot <- ggiraph::renderGirafe({
    trend <- trend_summary()
    validate(need(sum(is.finite(trend$mean_price)) > 1, "There is not enough data for a trend."))

    trend[, hover_text := ifelse(
      is.na(mean_price),
      paste0(format(period, "%b %Y"), " - No observations"),
      paste0(
        format(period, "%b %Y"),
        "<br>Average price: ", format_number(mean_price, 2), " ", price_unit_label(),
        "<br>Records: ", format_number(observations),
        "<br>Counties: ", format_number(counties),
        "<br>Markets: ", format_number(markets)
      )
    )]
    trend[, period_id := as.character(period)]

    gg <- ggplot2::ggplot(trend, ggplot2::aes(x = period))
    if (identical(input$trend_display, "smooth")) {
      gg <- gg +
        ggiraph::geom_line_interactive(
          ggplot2::aes(
            y = mean_price,
            tooltip = hover_text,
            data_id = period_id,
            group = 1
          ),
          colour = "#9bb5b5",
          linewidth = 0.8,
          na.rm = TRUE
        ) +
        ggiraph::geom_line_interactive(
          ggplot2::aes(
            y = display_price,
            tooltip = hover_text,
            data_id = period_id,
            group = 1
          ),
          colour = "#00a2ab",
          linewidth = 1.3,
          na.rm = TRUE
        ) +
        ggiraph::geom_point_interactive(
          ggplot2::aes(
            y = display_price,
            tooltip = hover_text,
            data_id = period_id
          ),
          colour = "#00a2ab",
          size = 2.2,
          na.rm = TRUE
        )
    } else {
      gg <- gg +
        ggiraph::geom_line_interactive(
          ggplot2::aes(
            y = mean_price,
            tooltip = hover_text,
            data_id = period_id,
            group = 1
          ),
          colour = "#00a2ab",
          linewidth = 1.3,
          na.rm = TRUE
        ) +
        ggiraph::geom_point_interactive(
          ggplot2::aes(
            y = mean_price,
            tooltip = hover_text,
            data_id = period_id,
            group = 1
          ),
          colour = "#00a2ab",
          size = 2.2,
          na.rm = TRUE
        )
    }

    gg <- gg +
      ggplot2::labs(
        title = paste(input$commodity, input$pricetype, "price trend"),
        x = if (identical(input$trend_frequency, "quarter")) {
          "Quarter"
        } else {
          "Month"
        },
        y = paste("Average price", price_unit_label())
      ) +
      ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(
        legend.position = "bottom",
        plot.title = ggplot2::element_text(face = "bold"),
        panel.grid.minor = ggplot2::element_blank()
      )

    standard_girafe(gg, width_svg = 14, height_svg = 4.4)
  })

  output$trend_change_table <- DT::renderDT({
    monthly <- copy(monthly_summary())
    validate(need(nrow(monthly) > 1, "No monthly changes available."))

    monthly[, previous_price := data.table::shift(mean_price)]
    monthly[, change := mean_price - previous_price]
    monthly[, pct_change := data.table::fifelse(
      previous_price != 0,
      change / previous_price,
      NA_real_
    )]

    display <- monthly[order(-year_month_date)][1:min(.N, 12)][
      ,
      .(
        Month = format(year_month_date, "%b %Y"),
        avg_price = format_number(mean_price, 2),
        Change = vapply(change, format_change, character(1),
          unit_label = price_unit_label()
        ),
        pct_change = vapply(pct_change, format_percent, character(1)),
        Records = observations
      )
    ]
    data.table::setnames(
      display, c("avg_price", "pct_change"),
      c("Average price", "% change")
    )

    datatable_compact(display, page_length = 6)
  })

  output$main_price_histogram <- ggiraph::renderGirafe({
    price_val <- price_column()
    dt <- filtered_data()[is.finite(get(price_val))]
    validate(need(
      nrow(dt) > 2,
      "There is not enough data for an annual price trend."
    ))

    annual <- dt[
      ,
      .(
        mean_price = mean(get(price_val), na.rm = TRUE),
        min_price = min(get(price_val), na.rm = TRUE),
        max_price = max(get(price_val), na.rm = TRUE),
        observations = .N
      ),
      by = .(calendar_year = as.integer(format(date, "%Y")))
    ][order(calendar_year)]
    annual[, year_date := as.Date(sprintf("%s-01-01", calendar_year))]
    annual[, year_id := as.character(calendar_year)]
    annual[, hover_text := paste0(
      "Year: ", calendar_year,
      "<br>Average price: ", format_number(mean_price, 2),
      " ", price_unit_label(),
      "<br>Range: ", format_number(min_price, 2), " - ",
      format_number(max_price, 2),
      "<br>Records: ", format_number(observations)
    )]

    gg <- ggplot2::ggplot(annual, ggplot2::aes(x = year_date, y = mean_price)) +
      ggplot2::geom_linerange(
        ggplot2::aes(ymin = min_price, ymax = max_price),
        colour = "#b9dfe1",
        linewidth = 1.1
      ) +
      ggiraph::geom_line_interactive(
        ggplot2::aes(tooltip = hover_text, data_id = year_id, group = 1),
        colour = "#00a2ab",
        linewidth = 1.1
      ) +
      ggiraph::geom_point_interactive(
        ggplot2::aes(tooltip = hover_text, data_id = year_id),
        colour = "#00a2ab",
        size = 2
      ) +
      ggplot2::labs(
        title = paste(input$commodity, input$pricetype, "annual price range"),
        x = "Year",
        y = paste("Average price", price_unit_label())
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
    validate(need(nrow(dt) > 2, "There is not enough data for seasonality."))

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
        observations = sum(observations)
      ),
      by = month_num
    ][order(month_num)]
    season[, month_label := month.abb[month_num]]
    season[, month_id := as.character(month_num)]
    season[, hover_text := paste0(
      month_label,
      "<br>Index: ", format_number(season_index, 1),
      "<br>Middle 50%: ", format_number(lower, 1), " - ", format_number(upper, 1),
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
        title = "Monthly price index (year average = 100)",
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

  output$geography_panel_ui <- renderUI({
    price_val <- price_column()
    dt <- filtered_data()[is.finite(get(price_val)) & !is.na(county) & !is.na(market)]

    show_chart <- nrow(dt) > 0 && (
      !identical(input$page1_market, "All") ||
        (!identical(input$page1_county, "All") && data.table::uniqueN(dt$market) > 1) ||
        (identical(input$page1_county, "All") && data.table::uniqueN(dt$county) > 1) ||
        (identical(input$page1_county, "All") && data.table::uniqueN(dt$market) > 1)
    )

    if (isTRUE(show_chart)) {
      plot_panel(
        "Geographic comparison",
        withSpinner(
          visualization_frame(
            ggiraph::girafeOutput("geography_bar_plot", height = "100%"),
            "compact"
          ),
          color = "#00a2ab"
        )
      )
    } else {
      location <- if (nrow(dt) > 0) unique(dt$county)[1] else "No location"
      div(
        class = "kfp-panel kfp-compact-message",
        h4("Geographic comparison"),
        shiny::tags$p(paste("Only", location, "is available for this selection."))
      )
    }
  })
  output$geography_bar_plot <- ggiraph::renderGirafe({
    price_val <- price_column()
    dt <- filtered_data()[is.finite(get(price_val)) & !is.na(county) & !is.na(market)]
    validate(need(nrow(dt) > 0, "No geographic data available."))

    if (!identical(input$page1_market, "All")) {
      benchmark_dt <- base_filtered_data()[is.finite(get(price_val))]
      selected_mean <- mean(dt[[price_val]], na.rm = TRUE)
      benchmark_mean <- mean(benchmark_dt[[price_val]], na.rm = TRUE)
      scope_label <- if (identical(input$page1_county, "All")) "Kenya benchmark" else paste(input$page1_county, "benchmark")
      comparison <- data.table::data.table(
        location = c(input$page1_market, scope_label),
        mean_price = c(selected_mean, benchmark_mean),
        records = c(nrow(dt), nrow(benchmark_dt))
      )
      chart_title <- paste(input$page1_market, "against", scope_label)
    } else {
      if (!identical(input$page1_county, "All")) {
        grouping <- "market"
        chart_title <- paste("Markets in", input$page1_county)
      } else if (data.table::uniqueN(dt$county) > 1) {
        grouping <- "county"
        chart_title <- "Average price by county"
      } else if (data.table::uniqueN(dt$market) > 1) {
        grouping <- "market"
        chart_title <- "Average price by market"
      } else {
        validate(need(FALSE, paste("Only", unique(dt$county)[1], "is available for this selection.")))
      }

      comparison <- dt[
        ,
        .(
          mean_price = mean(get(price_val), na.rm = TRUE),
          records = .N
        ),
        by = .(location = get(grouping))
      ][order(mean_price)]
    }

    comparison[, hover_text := paste0(
      location,
      "<br>Average price: ", format_number(mean_price, 2), " ", price_unit_label(),
      "<br>Records: ", format_number(records)
    )]
    comparison[, location_id := make.unique(as.character(location))]

    gg <- ggplot2::ggplot(
      comparison,
      ggplot2::aes(
        x = mean_price,
        y = reorder(location, mean_price)
      )
    ) +
      ggiraph::geom_col_interactive(
        ggplot2::aes(tooltip = hover_text, data_id = location_id),
        fill = "#00a2ab",
        width = 0.68
      ) +
      ggplot2::labs(
        title = chart_title,
        x = paste("Average price", price_unit_label()),
        y = NULL
      ) +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(
        plot.title = ggplot2::element_text(face = "bold"),
        panel.grid.minor = ggplot2::element_blank()
      )

    standard_girafe(gg, width_svg = 12, height_svg = 4)
  })

  map_data <- reactive({
    dt <- filtered_data()[!is.na(latitude) & !is.na(longitude)]
    monthly <- price_aggregation()$market_month
    validate(need(nrow(monthly) > 0, "No mapped market data available. Try all markets, broaden the date range, or reset the county filter."))
    location <- dt[, .(county = county[which.max(date)], latitude = mean(latitude), longitude = mean(longitude)), by = market]
    summary <- monthly[
      ,
      .(
        avg_price = if (identical(input$calculation, "record_weighted_mean")) stats::weighted.mean(estimate, records) else stats::median(estimate),
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
      currency = currency_label()
    )
  })

  output$map_market_table <- DT::renderDT({
    display <- copy(map_data())[1:min(.N, 15)]
    setnames(display, c("market", "county", "avg_price", "latest_date", "records"), c("Market", "County", "Average Price", "Latest Date", "Records"), skip_absent = TRUE)
    display[, `Average Price` := vapply(`Average Price`, format_number, character(1), digits = 2)]
    display[, `Latest Date` := as.character(`Latest Date`)]
    display <- display[, .(Market, County, `Average Price`, `Latest Date`, Records)]
    datatable_compact(display, page_length = 6)
  })

  output$compare_counties_ui <- renderUI({
    dt <- base_filtered_data()[!is.na(county)]
    validate(need(nrow(dt) > 0, "No counties are available for this selection."))

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
    dt <- food_prices[
      category == input$category &
        unit == input$unit &
        pricetype == input$pricetype &
        data.table::between(date, input$page1_date[1], input$page1_date[2])
    ]
    validate(need(nrow(dt) > 0, "No commodities are available for this selection."))

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
    validate(need(nrow(dt) > 1, "Select at least one county with available data."))

    compare <- dt[
      ,
      .(mean_price = mean(get(price_val), na.rm = TRUE)),
      by = .(year_month_date, county)
    ][order(year_month_date)]
    compare[, tooltip := paste0(
      county, "<br>", format(year_month_date, "%b %Y"),
      "<br>Average price: ", format_number(mean_price, 2), " ", price_unit_label()
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
        y = paste("Average price", price_unit_label()),
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
    req(input$compare_commodities, input$category, input$unit, input$pricetype, input$page1_date)
    price_val <- price_column()
    dt <- food_prices[
      category == input$category &
        commodity %in% input$compare_commodities &
        unit == input$unit &
        pricetype == input$pricetype &
        data.table::between(date, input$page1_date[1], input$page1_date[2])
    ]
    validate(need(nrow(dt) > 1, "Select commodities with available data for the current unit and price type."))

    compare <- dt[
      ,
      .(mean_price = mean(get(price_val), na.rm = TRUE)),
      by = .(year_month_date, commodity)
    ][order(year_month_date)]
    compare[, tooltip := paste0(
      commodity, "<br>", format(year_month_date, "%b %Y"),
      "<br>Average price: ", format_number(mean_price, 2), " ", price_unit_label()
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
        y = paste("Average price", price_unit_label()),
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
    validate(need(nrow(dt) > 0, "No coverage data available."))

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
    validate(need(nrow(dt) > 0, "No coverage data available."))

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
