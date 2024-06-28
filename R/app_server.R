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

    # Dynamic UI for filters based on previous selections
    output$commodity_ui <- renderUI({
      req(input$category)
      selectInput("commodity", "Commodity:", choices = unique(ke_food_prices[category == input$category]$commodity))
    })

    output$unit_ui <- renderUI({
      req(input$commodity)
      selectInput("unit", "Unit:", choices = unique(ke_food_prices[commodity == input$commodity]$unit))
    })

    output$priceflag_ui <- renderUI({
      req(input$unit)
      selectInput("priceflag", "Price Flag:", choices = unique(ke_food_prices[unit == input$unit]$priceflag))
    })

    output$pricetype_ui <- renderUI({
      req(input$priceflag)
      selectInput("pricetype", "Price Type:", choices = unique(ke_food_prices[priceflag == input$priceflag]$pricetype))
    })


    filtered_data <- reactive({
      req(input$category, input$commodity, input$unit, input$priceflag, input$pricetype)

      ke_food_prices[
        category %in% input$category &
          commodity %in% input$commodity &
          unit %in% input$unit &
          priceflag %in% input$priceflag &
          pricetype %in% input$pricetype
      ]
    })

    # Plot the filtered data
    output$linePlot <- renderPlotly({


      filtered_data <- filtered_data()
      commodity <- input$commodity
      pricetype <- input$pricetype

      validate(
        need(nrow(filtered_data) > 2, "The  data has insufficient rows for meaningful analysis. Please adjust your filters.")
      )
      mean_data <- filtered_data[, .(mean_price = mean(price)), by = date]

      line_plot_prices(mean_data, commodity, pricetype, palette = "Set1")

    })

  }
