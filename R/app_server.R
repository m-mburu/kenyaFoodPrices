#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @import dplyr
#' @import data.table
#' @import DT
#' @import ggplot2
#' @noRd



app_server <-  function(input, output, session) {


  output$category_ui <- renderUI({

    selectInput("category", "Category:", choices = unique(ke_food_prices$category))
  })

  output$commodity_ui <- renderUI({
    req(input$category)
    commodity_filtered <- ke_food_prices[ke_food_prices$category == input$category, ]

    selectInput("commodity", "Commodity:", choices = unique(commodity_filtered$commodity))
  })

  output$unit_ui <- renderUI({

    req(input$category, input$commodity)

    unit_filtered <- ke_food_prices[commodity == input$commodity, ]

    selectInput("unit", "Unit:", choices = unique(unit_filtered$unit))

  })

  # output$priceflag_ui <- renderUI({
  #
  #   req(input$category, input$commodity, input$unit)
  #   priceflag_filtered <- ke_food_prices[category == input$category &
  #                                          commodity == input$commodity &
  #                                          unit == input$unit, ]
  #
  #   selectInput("priceflag", "Price Flag:",
  #               choices = unique(priceflag_filtered$priceflag))
  # })

  output$pricetype_ui <- renderUI({
   req(input$category, input$commodity, input$unit)#, input$priceflag

    pricetype_filtered <- ke_food_prices[category == input$category &
                                           commodity == input$commodity &
                                           unit == input$unit ]
                                           #priceflag == input$priceflag, ]

    selectInput("pricetype", "Price Type:",
                choices = unique(pricetype_filtered$pricetype))
  })

  output$page_year_ui <- renderUI({

    req(input$category, input$commodity, input$unit,  input$pricetype)#input$priceflag,

    year_filtered <- ke_food_prices[category == input$category &
                                      commodity == input$commodity &
                                      unit == input$unit &
                                      #priceflag == input$priceflag &
                                      pricetype == input$pricetype, ]
    req(nrow(year_filtered ) > 2)

    min_date <- year_filtered[, min(date, na.rm = TRUE)]
    max_date <- year_filtered[, max(date, na.rm = TRUE)]

    dateRangeInput("page1_date", "Date Range:",
                   start = min_date, end = max_date,
                   min = min_date, max = max_date)

  })

  output$page1_county_ui <- renderUI({

    req(input$category, input$commodity, input$unit, input$pricetype)# input$priceflag, , input$page1_date

    county_filtered <- ke_food_prices[category == input$category &
                                        commodity == input$commodity&
                                        unit == input$unit &
                                       # priceflag == input$priceflag &
                                        pricetype == input$pricetype &
                                        data.table::between(date, input$page1_date[1], input$page1_date[2]) ]


    choices <-  c("All", unique(county_filtered$county))
    selectInput("page1_county", "County:",
                choices = choices, multiple = FALSE,
                selected = "All")
  })

  output$page1_market_ui <- renderUI({

    req(input$category, input$commodity, input$unit, input$pricetype, input$page1_county)# input$priceflag, , input$page1_date,

    market_filtered <- ke_food_prices[category == input$category &
                                        commodity == input$commodity&
                                        unit == input$unit &
                                        #priceflag == input$priceflag &
                                        pricetype == input$pricetype &
                                        data.table::between(date, input$page1_date[1], input$page1_date[2]) ]

    if(input$page1_county != "All"){

      market_filtered <- market_filtered[county %in% input$page1_county]
    }

    choices <-  c("All", unique(market_filtered$market))
    selectInput("page1_market", "Market:",
                choices = choices, multiple = FALSE,
                selected = "All")
  })


  filtered_data <- reactive({

    req(input$category, input$commodity, input$unit,  input$pricetype, input$page1_date, input$page1_county)#input$priceflag,, input$page1_market_ui

    by_vec <- c("year_month_date","year_month",
                input$category, input$commodity,
                input$unit, input$pricetype)



    filteredd_data <- ke_food_prices[
      category %in% input$category &
        commodity %in% input$commodity &
        unit %in% input$unit &
        #priceflag %in% input$priceflag &
        pricetype %in% input$pricetype &
        data.table::between(date, input$page1_date[1], input$page1_date[2])
    ]

    if(input$page1_county != "All"){

      filteredd_data <- filteredd_data[county %in% input$page1_county]
    }

    req(length(input$page1_market) != 0)

    if(input$page1_market != "All"){

      filteredd_data <- filteredd_data[market %in% input$page1_market]

    }

    filteredd_data

  })



  #Plot the filtered data
  currency <- reactive({

    if(input$Currency == "price"){
      "price"
    }else{
      "usdprice"
    }
  })

  output$linePlot <- renderPlotly({


    filtered_data <- filtered_data()
    req(nrow(filtered_data) > 2)
    #fwrite(filtered_data, "filtered_data.csv")
    commodity <- input$commodity
    pricetype <- input$pricetype

    validate(
      need(nrow(filtered_data) > 2, "The  data has insufficient rows for meaningful analysis. Please adjust your filters.")
    )
    price_val <-currency()
    mean_data <- filtered_data[, .(mean_price = mean(get(price_val))), by = year_quarter_date]

    line_plot_prices(mean_data, commodity, pricetype)

  })

  output$main_price_histogram <- renderPlotly({

    price_val <-currency()

    gg <- filtered_data() %>%
      ggplot(aes(x = get(price_val))) +
      geom_histogram(bins = 30,  color = "black", fill = "#51C56AFF") +
      labs(title = paste("Histogram of Prices for", input$commodity, input$pricetype),
           x = "Price",
           y = "Frequency") +
      theme_minimal()+
      theme(legend.position = "none")
    ggplotly(gg)

    #girafe(gg)


  })

  output$price_quarter_means <- renderPlotly({
    price_val =  currency()

     df_q <- filtered_data()[,.(mean_price = mean(get(price_val))),
                             by = .(quarter)]

    df_q[, quarter := factor(quarter, levels = 1:4,
                             labels = c("Q1", "Q2", "Q3", "Q4"))]


    bar_plot_time(df_q,
                  time_var = quarter,
                  price_var = mean_price,
                  input$commodity,
                  input$pricetype,
                  mytitle = "Average Prices by Quarter",
                  x_lab = "Quarter",
                  y_lab = "Price",
                  convert_axis = F)


  })

  # prices average months
  output$price_month_means <- renderPlotly({
    price_val =  currency()

    df_m <- filtered_data()[, .(mean_price = mean(get(price_val))),
                            by = .(month)]
    bar_plot_time(df_m,
                  time_var = month,
                  price_var = mean_price,
                  input$commodity,
                  input$pricetype,
                  mytitle = "Average Prices by Month",
                  x_lab = "Month",
                  y_lab = "Price",
                  convert_axis = F)

  })
  output$county_bar_plot <- renderPlotly({

    ## validate  of input$page1_county to be "all" and not a single county

    price_val =  currency()

    df_county <- filtered_data()[, .(mean_price = mean(get(price_val))),
                                by = .(county)]
    validate(
      need(nrow(df_county) > 0, "The  data has insufficient rows for meaningful analysis. Please adjust your filters.")
    )

    bar_plot_time(df_county,
                  time_var = county,
                  price_var = mean_price,
                  input$commodity,
                  input$pricetype,
                  mytitle = "Average Prices by County",
                  x_lab = "County",
                  y_lab = "Price")

  })

  output$market_bar_plot <- renderPlotly({

    ## validate  of input$page1_county to be "all" and not a single county

    price_val =  currency()

    df_market <- filtered_data()[, .(mean_price = mean(get(price_val))),
                                by = .(market)]
    validate(
      need(nrow(df_market) > 1 & input$page1_county != "All", "The  data has insufficient rows for meaningful analysis. Please adjust your filters. Or check the counties filter to select one county")
    )

    bar_plot_time(df_market,
                  time_var = market,
                  price_var = mean_price,
                  input$commodity,
                  input$pricetype,
                  mytitle = "Average Prices by Market",
                  x_lab = "Market",
                  y_lab = "Price")

  })

  waiter_show( # show the waiter
    html = spin_fading_circles())

  # observeEvent(input$show, {
  #
  #     waiter_show( # show the waiter
  #         html = spin_fading_circles() # use a spinner
  #     )

  Sys.sleep(4) # do something that takes time

  waiter_hide() # hide the waiter



  }
