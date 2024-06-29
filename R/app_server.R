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

  filtered_data <- reactive({
    #req(input$category, input$commodity, input$unit, input$priceflag, input$pricetype)

    by_vec <- c("year_month_date","year_month", input$category, input$commodity, input$unit, input$pricetype)



    filteredd_data <- ke_food_prices[
      category %in% input$category &
        commodity %in% input$commodity &
        unit %in% input$unit &
        priceflag %in% input$priceflag &
        pricetype %in% input$pricetype
    ]





    # mysummary <- filteredd_data[, .(mean_price = mean(price)), by =  by_vec]
    # mysummary
    filteredd_data
    #fwrite(mysummary, "filteredd_data.csv")

  })

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
    unit_filtered <- ke_food_prices[ke_food_prices$category == input$category & ke_food_prices$commodity == input$commodity, ]
    selectInput("unit", "Unit:", choices = unique(unit_filtered$unit))

  })

  output$priceflag_ui <- renderUI({
    req(input$category, input$commodity, input$unit)
    priceflag_filtered <- ke_food_prices[ke_food_prices$category == input$category & ke_food_prices$commodity == input$commodity & ke_food_prices$unit == input$unit, ]
    selectInput("priceflag", "Price Flag:", choices = unique(priceflag_filtered$priceflag))
  })

  output$pricetype_ui <- renderUI({
    req(input$category, input$commodity, input$unit, input$priceflag)
    pricetype_filtered <- ke_food_prices[ke_food_prices$category == input$category & ke_food_prices$commodity == input$commodity & ke_food_prices$unit == input$unit & ke_food_prices$priceflag == input$priceflag, ]
    selectInput("pricetype", "Price Type:", choices = unique(pricetype_filtered$pricetype))
  })

  output$page_year_ui <- renderUI({
    year_filtered <- ke_food_prices[ke_food_prices$category == input$category & ke_food_prices$commodity == input$commodity & ke_food_prices$unit == input$unit & ke_food_prices$priceflag == input$priceflag & ke_food_prices$pricetype == input$pricetype, ]
    choices <-  unique(year_filtered$year)
    selectInput("page1_year", "Year:", choices =choices, multiple = TRUE, selected = choices)
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
    commodity <- input$commodity
    pricetype <- input$pricetype

    validate(
      need(nrow(filtered_data) > 2, "The  data has insufficient rows for meaningful analysis. Please adjust your filters.")
    )
    price_val <-currency()
    mean_data <- filtered_data[, .(mean_price = mean(get(price_val))), by = year_quarter_date]

    line_plot_prices(mean_data, commodity, pricetype, palette = "Set1")

  })

  output$main_price_histogram <- renderPlotly({

    price_val <-currency()

    gg <- filtered_data() %>%
      ggplot(aes(x = get(price_val))) +
      geom_histogram(bins = 30,  color = "black", fill = "steelblue") +
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

    df_q <- filtered_data()[year%in% input$page1_year, .(mean_price = mean(get(price_val))),
                            by = .(quarter)]

    df_q[, quarter := factor(quarter, levels = 1:4,
                             labels = c("Q1", "Q2", "Q3", "Q4"))]


    bar_plot <- ggplot(df_q, aes(x = quarter, y = mean_price, fill = quarter)) +
      geom_bar(stat = "identity") +
      labs(title = paste("Mean Price per Quarter for", input$commodity, input$pricetype),
           x = "Quarter",
           y = "Mean Price") +
      scale_fill_viridis_d()+
      theme_minimal()+
      theme(legend.position = "none")
    ggplotly(bar_plot)

  })

  # prices average months
  output$price_month_means <- renderPlotly({
    price_val =  currency()

    df_m <- filtered_data()[year%in% input$page1_year, .(mean_price = mean(get(price_val))),
                            by = .(month)]

    month_plot <- ggplot(df_m, aes(x = month, y = mean_price, fill = month)) +
      geom_bar(stat = "identity") +
      labs(title = paste("Mean Price per Month for", input$commodity, input$pricetype),
           x = "Month",
           y = "Mean Price") +
      scale_fill_viridis_d()+
      theme_minimal()

  })


  }
