#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import data.table
#' @import ggplot2
#' @importFrom dplyr %>%
#' @importFrom DT datatable
#' @importFrom leaflet addCircleMarkers addLegend addProviderTiles colorNumeric leaflet providers renderLeaflet
#' @importFrom plotly layout plot_ly renderPlotly
#' @importFrom shiny dateRangeInput div h4 need reactive renderUI req selectInput selectizeInput validate
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
  DT::datatable(
    data,
    rownames = FALSE,
    options = list(
      pageLength = page_length,
      dom = "tip",
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
    paste(currency_label(), input$unit %||% "unit", sep = "/")
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

  monthly_summary <- reactive({
    dt <- filtered_data()
    req(nrow(dt) > 0)
    price_val <- price_column()

    dt[
      ,
      .(
        mean_price = mean(get(price_val), na.rm = TRUE),
        observations = .N,
        counties = uniqueN(county, na.rm = TRUE),
        markets = uniqueN(market, na.rm = TRUE)
      ),
      by = .(year_month_date)
    ][order(year_month_date)]
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
      kpi_card("Latest month", format(latest_month, "%b %Y"), paste(format_number(latest_row$observations), "records")),
      kpi_card("Average price", format_number(current_price, 2), unit_label),
      kpi_card("Month change", format_change(mom_change, unit_label), format_percent(mom_pct), ifelse(mom_change > 0, "kfp-up", "kfp-down")),
      kpi_card("Year change", format_percent(yoy_pct), paste("vs", format(yoy_month, "%b %Y")), ifelse(yoy_pct > 0, "kfp-up", "kfp-down")),
      kpi_card("Counties", format_number(uniqueN(dt$county, na.rm = TRUE)), "in selected data"),
      kpi_card("Markets", format_number(uniqueN(dt$market, na.rm = TRUE)), "in selected data")
    )
  })

  output$overview_trend <- renderPlotly({
    monthly <- monthly_summary()
    validate(need(nrow(monthly) > 1, "There is not enough monthly data for a trend."))

    plot_ly(
      monthly,
      x = ~year_month_date,
      y = ~mean_price,
      type = "scatter",
      mode = "lines+markers",
      line = list(color = "#00a2ab", width = 3),
      marker = list(color = "#00a2ab", size = 6),
      text = ~paste0(
        "Month: ", format(year_month_date, "%b %Y"),
        "<br>Average price: ", format_number(mean_price, 2), " ", price_unit_label(),
        "<br>Records: ", observations,
        "<br>Markets: ", markets
      ),
      hoverinfo = "text"
    ) %>%
      layout(
        xaxis = list(title = "Month"),
        yaxis = list(title = paste("Average price", price_unit_label())),
        margin = list(l = 60, r = 20, t = 20, b = 50)
      )
  })

  output$recent_change_table <- DT::renderDT({
    monthly <- copy(monthly_summary())
    validate(need(nrow(monthly) > 0, "No monthly data available."))

    monthly[, previous_price := shift(mean_price)]
    monthly[, change := mean_price - previous_price]
    monthly[, pct_change := fifelse(previous_price != 0, change / previous_price, NA_real_)]

    display <- monthly[order(-year_month_date)][1:min(.N, 12)][
      ,
      .(
        Month = format(year_month_date, "%b %Y"),
        `Average Price` = format_number(mean_price, 2),
        Change = vapply(change, format_change, character(1), unit_label = price_unit_label()),
        `% Change` = vapply(pct_change, format_percent, character(1)),
        Records = observations
      )
    ]

    datatable_compact(display, page_length = 12)
  })

  output$top_county_table <- DT::renderDT({
    dt <- filtered_data()[!is.na(county)]
    price_val <- price_column()
    validate(need(nrow(dt) > 0, "No county data available."))

    display <- dt[
      ,
      .(
        `Average Price` = mean(get(price_val), na.rm = TRUE),
        `Latest Date` = max(date, na.rm = TRUE),
        Records = .N,
        Markets = uniqueN(market)
      ),
      by = .(County = county)
    ][order(-`Average Price`)][1:min(.N, 10)]

    display[, `Average Price` := vapply(`Average Price`, format_number, character(1), digits = 2)]
    display[, `Latest Date` := as.character(`Latest Date`)]
    datatable_compact(display)
  })

  output$top_market_table <- DT::renderDT({
    dt <- filtered_data()[!is.na(market)]
    price_val <- price_column()
    validate(need(nrow(dt) > 0, "No market data available."))

    display <- dt[
      ,
      .(
        County = county[which.max(date)],
        `Average Price` = mean(get(price_val), na.rm = TRUE),
        `Latest Date` = max(date, na.rm = TRUE),
        Records = .N
      ),
      by = .(Market = market)
    ][order(-`Average Price`)][1:min(.N, 10)]

    display[, `Average Price` := vapply(`Average Price`, format_number, character(1), digits = 2)]
    display[, `Latest Date` := as.character(`Latest Date`)]
    datatable_compact(display)
  })

  output$linePlot <- renderPlotly({
    dt <- filtered_data()
    req(nrow(dt) > 2)
    price_val <- price_column()
    mean_data <- dt[, .(mean_price = mean(get(price_val), na.rm = TRUE)), by = year_quarter_date]
    line_plot_prices(mean_data, input$commodity, input$pricetype)
  })

  output$main_price_histogram <- renderPlotly({
    price_val <- price_column()
    dt <- filtered_data()
    validate(need(nrow(dt) > 2, "There is not enough data for a distribution."))

    gg <- dt %>%
      ggplot(aes(x = get(price_val))) +
      geom_histogram(bins = 30, color = "white", fill = "#00a2ab") +
      labs(
        title = paste("Price distribution for", input$commodity, input$pricetype),
        x = paste("Price", price_unit_label()),
        y = "Records"
      ) +
      theme_minimal() +
      theme(legend.position = "none")

    ggplotly(gg)
  })

  output$price_quarter_means <- renderPlotly({
    price_val <- price_column()
    dt <- filtered_data()
    validate(need(nrow(dt) > 0, "No data available."))

    df_q <- dt[, .(mean_price = mean(get(price_val), na.rm = TRUE)), by = .(quarter)]
    df_q[, quarter := factor(quarter, levels = 1:4, labels = c("Q1", "Q2", "Q3", "Q4"))]

    bar_plot_time(
      df_q,
      time_var = quarter,
      price_var = mean_price,
      input$commodity,
      input$pricetype,
      mytitle = "Average Prices by Quarter",
      x_lab = "Quarter",
      y_lab = paste("Price", price_unit_label()),
      convert_axis = FALSE
    )
  })

  output$price_month_means <- renderPlotly({
    price_val <- price_column()
    dt <- filtered_data()
    validate(need(nrow(dt) > 0, "No data available."))

    df_m <- dt[, .(mean_price = mean(get(price_val), na.rm = TRUE)), by = .(month)]
    bar_plot_time(
      df_m,
      time_var = month,
      price_var = mean_price,
      input$commodity,
      input$pricetype,
      mytitle = "Average Prices by Month",
      x_lab = "Month",
      y_lab = paste("Price", price_unit_label()),
      convert_axis = FALSE
    )
  })

  output$county_bar_plot <- renderPlotly({
    price_val <- price_column()
    dt <- filtered_data()[!is.na(county)]
    validate(need(nrow(dt) > 0, "No county data available."))

    df_county <- dt[, .(mean_price = mean(get(price_val), na.rm = TRUE)), by = .(county)][order(-mean_price)][1:min(.N, 15)]
    bar_plot_time(
      df_county,
      time_var = county,
      price_var = mean_price,
      input$commodity,
      input$pricetype,
      mytitle = "Average Prices by County",
      x_lab = "County",
      y_lab = paste("Price", price_unit_label())
    )
  })

  output$market_bar_plot <- renderPlotly({
    price_val <- price_column()
    dt <- filtered_data()[!is.na(market)]
    validate(need(nrow(dt) > 1, "No market data available. Select a county or broaden the filters."))

    df_market <- dt[, .(mean_price = mean(get(price_val), na.rm = TRUE)), by = .(market)][order(-mean_price)][1:min(.N, 15)]
    bar_plot_time(
      df_market,
      time_var = market,
      price_var = mean_price,
      input$commodity,
      input$pricetype,
      mytitle = "Average Prices by Market",
      x_lab = "Market",
      y_lab = paste("Price", price_unit_label())
    )
  })

  map_data <- reactive({
    dt <- filtered_data()[!is.na(latitude) & !is.na(longitude)]
    price_val <- price_column()
    validate(need(nrow(dt) > 0, "No mapped market data available."))

    dt[
      ,
      .(
        county = county[which.max(date)],
        latitude = mean(latitude, na.rm = TRUE),
        longitude = mean(longitude, na.rm = TRUE),
        avg_price = mean(get(price_val), na.rm = TRUE),
        latest_date = max(date, na.rm = TRUE),
        records = .N
      ),
      by = .(market)
    ][order(-avg_price)]
  })

  output$price_map <- renderLeaflet({
    map_df <- map_data()
    pal <- colorNumeric("YlOrRd", domain = map_df$avg_price)

    popup <- paste0(
      "<strong>", map_df$market, "</strong>",
      "<br>County: ", map_df$county,
      "<br>Average price: ", vapply(map_df$avg_price, format_number, character(1), digits = 2), " ", price_unit_label(),
      "<br>Latest date: ", map_df$latest_date,
      "<br>Records: ", map_df$records
    )

    leaflet(map_df) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addCircleMarkers(
        lng = ~longitude,
        lat = ~latitude,
        radius = ~pmax(5, pmin(14, sqrt(records) + 3)),
        color = ~pal(avg_price),
        fillColor = ~pal(avg_price),
        fillOpacity = 0.75,
        weight = 1,
        popup = popup
      ) %>%
      addLegend(
        "bottomright",
        pal = pal,
        values = ~avg_price,
        title = paste("Avg", currency_label()),
        opacity = 0.8
      )
  })

  output$map_market_table <- DT::renderDT({
    display <- copy(map_data())[1:min(.N, 15)]
    setnames(display, c("market", "county", "avg_price", "latest_date", "records"), c("Market", "County", "Average Price", "Latest Date", "Records"), skip_absent = TRUE)
    display[, `Average Price` := vapply(`Average Price`, format_number, character(1), digits = 2)]
    display[, `Latest Date` := as.character(`Latest Date`)]
    display <- display[, .(Market, County, `Average Price`, `Latest Date`, Records)]
    datatable_compact(display, page_length = 10)
  })

  output$compare_counties_ui <- renderUI({
    dt <- base_filtered_data()[!is.na(county)]
    choices <- sort(unique(dt$county))
    selected <- dt[, .N, by = county][order(-N)][1:min(.N, 4)]$county

    selectizeInput(
      "compare_counties",
      "Counties to compare",
      choices = choices,
      selected = selected,
      multiple = TRUE,
      options = list(maxItems = 6)
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
    choices <- sort(unique(dt$commodity))
    selected <- dt[, .N, by = commodity][order(-N)][1:min(.N, 5)]$commodity

    selectizeInput(
      "compare_commodities",
      "Commodities to compare",
      choices = choices,
      selected = selected,
      multiple = TRUE,
      options = list(maxItems = 6)
    )
  })

  output$county_compare_plot <- renderPlotly({
    req(input$compare_counties)
    dt <- base_filtered_data()[county %in% input$compare_counties]
    price_val <- price_column()
    validate(need(nrow(dt) > 1, "Select at least one county with available data."))

    compare <- dt[, .(mean_price = mean(get(price_val), na.rm = TRUE)), by = .(year_month_date, county)][order(year_month_date)]

    plot_ly(
      compare,
      x = ~year_month_date,
      y = ~mean_price,
      color = ~county,
      type = "scatter",
      mode = "lines",
      hoverinfo = "text",
      text = ~paste0(county, "<br>", format(year_month_date, "%b %Y"), "<br>", format_number(mean_price, 2), " ", price_unit_label())
    ) %>%
      layout(
        xaxis = list(title = "Month"),
        yaxis = list(title = paste("Average price", price_unit_label())),
        legend = list(orientation = "h", x = 0, y = -0.2)
      )
  })

  output$commodity_compare_plot <- renderPlotly({
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

    compare <- dt[, .(mean_price = mean(get(price_val), na.rm = TRUE)), by = .(year_month_date, commodity)][order(year_month_date)]

    plot_ly(
      compare,
      x = ~year_month_date,
      y = ~mean_price,
      color = ~commodity,
      type = "scatter",
      mode = "lines",
      hoverinfo = "text",
      text = ~paste0(commodity, "<br>", format(year_month_date, "%b %Y"), "<br>", format_number(mean_price, 2), " ", price_unit_label())
    ) %>%
      layout(
        xaxis = list(title = "Month"),
        yaxis = list(title = paste("Average price", price_unit_label())),
        legend = list(orientation = "h", x = 0, y = -0.2)
      )
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

  output$coverage_year_plot <- renderPlotly({
    dt <- filtered_data()
    validate(need(nrow(dt) > 0, "No coverage data available."))

    coverage <- dt[, .(Records = .N, Counties = uniqueN(county, na.rm = TRUE), Markets = uniqueN(market)), by = .(Year = year)][order(Year)]

    plot_ly(coverage, x = ~Year, y = ~Records, type = "bar", marker = list(color = "#00a2ab"), name = "Records") %>%
      layout(
        xaxis = list(title = "Year"),
        yaxis = list(title = "Records"),
        margin = list(l = 60, r = 20, t = 20, b = 50)
      )
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
    datatable_compact(display, page_length = 10)
  })
}
