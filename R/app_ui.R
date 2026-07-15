#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shinycssloaders
#' @importFrom DT DTOutput
#' @importFrom ggiraph girafeOutput
#' @importFrom plotly plotlyOutput
#' @importFrom shiny column div fluidPage fluidRow h4 navbarPage selectInput tabPanel tagList uiOutput
#' @noRd
#'

filter_panel <- function() {
  food_prices <- app_food_prices()

  div(
    class = "kfp-filter-band",
    fluidRow(
      column(2, selectInput("category", "Category", choices = sort(unique(food_prices$category)))),
      column(2, uiOutput("commodity_ui")),
      column(2, uiOutput("unit_ui")),
      column(2, uiOutput("pricetype_ui")),
      column(2, selectInput("Currency", "Currency", c("KES" = "price", "USD" = "usdprice"))),
      column(2, uiOutput("page_year_ui"))
    ),
    fluidRow(
      column(3, uiOutput("page1_county_ui")),
      column(3, uiOutput("page1_market_ui"))
    )
  )
}

plot_panel <- function(title, output) {
  div(
    class = "kfp-panel",
    h4(title),
    output
  )
}

app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),
    navbarPage(
      title = "Kenya Food Prices Dashboard",
      id = "main_nav",
      header = filter_panel(),

      tabPanel(
        "Overview",
        fluidPage(
          uiOutput("summary_kpis"),
          fluidRow(
            column(
              8,
              plot_panel(
                "Price Trend",
                withSpinner(plotlyOutput("overview_trend", height = "390px"), color = "#00a2ab")
              )
            ),
            column(
              4,
              plot_panel(
                "Recent Monthly Change",
                withSpinner(DTOutput("recent_change_table"), color = "#00a2ab")
              )
            )
          ),
          fluidRow(
            column(
              6,
              plot_panel(
                "Highest Average Prices by County",
                withSpinner(DTOutput("top_county_table"), color = "#00a2ab")
              )
            ),
            column(
              6,
              plot_panel(
                "Highest Average Prices by Market",
                withSpinner(DTOutput("top_market_table"), color = "#00a2ab")
              )
            )
          )
        )
      ),

      tabPanel(
        "Trends",
        fluidPage(
          fluidRow(
            column(6, plot_panel("Quarterly Price Trend", withSpinner(plotlyOutput("linePlot"), color = "#00a2ab"))),
            column(6, plot_panel("Price Distribution", withSpinner(plotlyOutput("main_price_histogram"), color = "#00a2ab")))
          ),
          fluidRow(
            column(6, plot_panel("Average Price by Quarter", withSpinner(plotlyOutput("price_quarter_means"), color = "#00a2ab"))),
            column(6, plot_panel("Average Price by Month", withSpinner(plotlyOutput("price_month_means"), color = "#00a2ab")))
          ),
          fluidRow(
            column(6, plot_panel("Average Price by County", withSpinner(plotlyOutput("county_bar_plot"), color = "#00a2ab"))),
            column(6, plot_panel("Average Price by Market", withSpinner(plotlyOutput("market_bar_plot"), color = "#00a2ab")))
          )
        )
      ),

      tabPanel(
        "Map",
        fluidPage(
          fluidRow(
            column(
              8,
              plot_panel(
                "Market Price Map",
                withSpinner(ggiraph::girafeOutput("price_map", height = "620px"), color = "#00a2ab")
              )
            ),
            column(
              4,
              plot_panel(
                "Mapped Markets",
                withSpinner(DTOutput("map_market_table"), color = "#00a2ab")
              )
            )
          )
        )
      ),

      tabPanel(
        "Climate",
        fluidPage(
          climate_module_ui("climate")
        )
      ),

      tabPanel(
        "Compare",
        fluidPage(
          fluidRow(
            column(4, uiOutput("compare_counties_ui")),
            column(4, uiOutput("compare_commodities_ui"))
          ),
          fluidRow(
            column(6, plot_panel("County Comparison", withSpinner(plotlyOutput("county_compare_plot"), color = "#00a2ab"))),
            column(6, plot_panel("Commodity Comparison", withSpinner(plotlyOutput("commodity_compare_plot"), color = "#00a2ab")))
          )
        )
      ),

      tabPanel(
        "Coverage",
        fluidPage(
          uiOutput("coverage_summary"),
          fluidRow(
            column(7, plot_panel("Observation Coverage by Year", withSpinner(plotlyOutput("coverage_year_plot"), color = "#00a2ab"))),
            column(5, plot_panel("Coverage Detail", withSpinner(DTOutput("coverage_table"), color = "#00a2ab")))
          )
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
#' @importFrom shiny HTML tags
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
    ),
    HTML("
      <!-- Google tag (gtag.js) -->
      <script async src='https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX'></script>
      <script>
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());

        gtag('config',  'G-BFNZ97VTLJ');
      </script>
    ")
  )
}
