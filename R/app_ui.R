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
    navbarPage(
      "Kenya Food Prices Dashboard",

      tabPanel(
        "Trends Over Time",
        fluidPage(
          generate_welcome_message(),

          fluidRow(
            column(2, selectInput("category", "Category:", choices = unique(ke_food_prices$category))),
            column(2, uiOutput("commodity_ui")),
            column(2, uiOutput("unit_ui")),
            column(2, uiOutput("priceflag_ui")),
            column(2, uiOutput("pricetype_ui")),
            column(2,selectInput("Currency", "Currency", c("KES" = "price", "USD" ="usdprice" )))
          ),
          br(),

          fluidRow(
            column(2, uiOutput("page_year_ui")),
            column(2, uiOutput("page1_county_ui"))
          ),


          fluidRow(
            column(6, plotlyOutput("linePlot")),
            column(6, plotlyOutput("main_price_histogram"))
          ),
          ## UI output for year

          fluidRow(
            column(6, plotlyOutput("price_quarter_means")),
            column(6, plotlyOutput("price_month_means"))
          )
        )
      ),

      tabPanel(
        "Maps",
        fluidPage(
          h4("Additional Analysis"),
          p("This section will include additional graphs, tables, or other analyses.")
          # Add additional UI elements for the second tab here
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
