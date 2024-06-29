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

ke_food_prices[, year_month := format(date, "%Y-%m")]
ke_food_prices[, year_month_date := as.Date(paste(year_month, "-01", sep = ""))]
ke_food_prices[, year := format(date, "%Y")]
ke_food_prices[, month := format(date, "%b")]

months_levels <- c("Jan", "Feb", "Mar",
                   "Apr", "May", "Jun",
                   "Jul", "Aug", "Sep",
                   "Oct", "Nov", "Dec")

ke_food_prices[, month := factor(month, levels = months_levels)]
ke_food_prices[, quarter := quarter(date)]
ke_food_prices[, year_quarter := paste(year, quarter, sep = "-")]

ke_food_prices[, year_quarter_date := median(date), by = .(year_quarter)]


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

          fluidRow(
            column(6, plotlyOutput("linePlot")),
            column(6, plotlyOutput("main_price_histogram"))
          ),
          ## UI output for year
          fluidRow(
            column(4, uiOutput("page_year_ui"))
          ),

          fluidRow(
            column(6, plotlyOutput("price_quarter_means")),
            column(6, plotlyOutput("price_month_means"))
          )
        )
      ),

      tabPanel(
        "Latest Prices",
        fluidPage(
          h4("Additional Analysis"),
          p("This section can include additional graphs, tables, or other analyses.")
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
