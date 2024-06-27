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



app_server <- function(input, output, session) {
  data_subset <- reactive({
    req(input$dateRange)
    ke_food_prices %>%
      filter(date >= input$dateRange[1] & date <= input$dateRange[2],
             commodity == input$commodity,
             market %in% input$market)
  })

  output$trendPlot <- renderPlotly({
    req(data_subset())
    gg <- ggplot(data_subset(), aes(x = date, y = price, color = market)) +
      geom_line() +
      labs(title = paste("Price Trends for", input$commodity), y = "Price (KES)", x = "Date") +
      theme_minimal()
    ggplotly(gg)
  })

  output$barPlot <- renderPlotly({
    req(data_subset())
    gg <- ggplot(data_subset(), aes(x = commodity, y = price, fill = market)) +
      geom_bar(stat = "identity", position = position_dodge()) +
      labs(title = "Comparative Price Bar Chart", y = "Price (KES)", x = "Commodity") +
      theme_minimal()
    ggplotly(gg)
  })

  output$map <- renderLeaflet({
    req(data_subset())
    m <- leaflet(data_subset()) %>%
      addTiles() %>%
      addCircleMarkers(~longitude, ~latitude, radius = 8, fillColor = ~price, color = "#000000", fillOpacity = 0.8, popup = ~paste(market, price, "KES"))
    m
  })
}
