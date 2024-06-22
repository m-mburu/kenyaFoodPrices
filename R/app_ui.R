#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @import data.table
#' @noRd
#'
choices <- c("Mazda RX4", "Mazda RX4 Wag", "Datsun 710", "Hornet 4 Drive",
             "Hornet Sportabout", "Valiant", "Duster 360", "Merc 240D", "Merc 230",
             "Merc 280", "Merc 280C", "Merc 450SE", "Merc 450SL", "Merc 450SLC",
             "Cadillac Fleetwood", "Lincoln Continental", "Chrysler Imperial",
             "Fiat 128", "Honda Civic", "Toyota Corolla", "Toyota Corona",
             "Dodge Challenger", "AMC Javelin", "Camaro Z28", "Pontiac Firebird",
             "Fiat X1-9", "Porsche 914-2", "Lotus Europa", "Ford Pantera L",
             "Ferrari Dino", "Maserati Bora", "Volvo 142E")

app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),  # Function for adding external resources
    fluidPage(
      sidebarLayout(
        sidebarPanel(
          selectInput("selectCar", "Choose a Car:", choices = choices)
        ),
        mainPanel(
          h1("Kenya Food Prices"),
          dataTableOutput("my_table")
        )
      )
    )
  )
}
#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path(
    "www",
    app_sys("app/www")
  )

  tags$head(
    favicon(),
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "kenyaFoodPrices"
    )
    # Add here other external resources
    # for example, you can add shinyalert::useShinyalert()
  )
}
