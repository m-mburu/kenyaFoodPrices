#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @import data.table
#' @import leaflet
#' @import plotly
#' @noRd
#'

data("ke_food_prices")
app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),  # Function for adding external resources

    navbarPage(title = "Kenya Food Prices Dashboard",
               tabPanel("Home",
                        fluidPage(
                          titlePanel("Home"),
                          fluidRow(
                            column(12,
                                   wellPanel("Welcome to the Kenya Food Prices Dashboard. This interactive tool allows users to explore food price data across different regions and markets in Kenya. Navigate to other tabs to visualize price trends and geographical distributions.")
                            )
                          )
                        )
               ),
               tabPanel("Trend Charts & Bar Graphs",
                        sidebarLayout(
                          sidebarPanel(
                            dateRangeInput("dateRange", "Select Date Range:", start = min(ke_food_prices$date), end = max(ke_food_prices$date)),
                            selectInput("commodity", "Select Commodity:", choices = unique(ke_food_prices$commodity), selected = unique(ke_food_prices$commodity)[1]),
                            selectInput("market", "Select Market:", choices = unique(ke_food_prices$market)),
                            actionButton("update", "Update Graph")
                          ),
                          mainPanel(
                            tabsetPanel(type = "tabs",
                                        tabPanel("Trend Chart", plotlyOutput("trendPlot")),
                                        tabPanel("Bar Graph", plotlyOutput("barPlot"))
                            )
                          )
                        )
               ),
               tabPanel("Map",
                        fluidPage(
                          leafletOutput("map", height = 600)
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
