#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @import data.table
#' @import leaflet
#' @import plotly
#' @import shinycssloaders
#' @noRd
#'

data("ke_food_prices")


app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),  # Function for adding external resources
    navbarPage(
      title= "Kenya Food Prices Dashboard",

      tabPanel(
        "Trends Over Time",
        fluidPage(
          generate_welcome_message(),

          fluidRow(
            column(2, selectInput("category", "Category:", choices = unique(ke_food_prices$category))),
            column(2, uiOutput("commodity_ui")),
            column(2, uiOutput("unit_ui")),
            #column(2, uiOutput("priceflag_ui")),
            column(2, uiOutput("pricetype_ui")),
            column(2,selectInput("Currency", "Currency", c("KES" = "price", "USD" ="usdprice" ))),
            column(2, uiOutput("page_year_ui"))
          ),
          br(),

          fluidRow(
            column(2, uiOutput("page1_county_ui")),
            column(2, uiOutput("page1_market_ui"))
          ),


          fluidRow(
            column(6, plotlyOutput("linePlot")%>%
                     withSpinner(color="#482173FF")),
            column(6, plotlyOutput("main_price_histogram")%>%
                     withSpinner(color="#482173FF"))
          ),
          ## UI output for year

          fluidRow(
            column(6, plotlyOutput("price_quarter_means")%>%
                     withSpinner(color="#482173FF")),
            column(6, plotlyOutput("price_month_means")%>%
                     withSpinner(color="#482173FF"))
          ),
          ## county bar plot & market bar plot
          fluidRow(
            column(6, plotlyOutput("county_bar_plot")%>%
                     withSpinner(color="#482173FF")),
            column(6, plotlyOutput("market_bar_plot")%>%
                     withSpinner(color="#482173FF"))
          )
        )
      ),
      #
      tabPanel(
        "Maps & Additional Analysis",
        fluidPage(
          h4("Additional Analysis"),
          p("In future versions, I will add more analysis here. depending on the richness of the data.")
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
