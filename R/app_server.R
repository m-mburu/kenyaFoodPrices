#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @import dplyr
#' @import data.table
#' @import DT
#' @noRd

mtcars <- mtcars
setDT(mtcars, keep.rownames = "CarType")
app_server <- function(input, output, session) {
  # Your application server logic

  ## Example: a reactive value
  mtcars_rv <- reactive({
    req(input$selectCar)

    mtcars[CarType %in% input$selectCar,]
  })

  output$my_table <- renderDT({
    mtcars_rv()
  })

}
