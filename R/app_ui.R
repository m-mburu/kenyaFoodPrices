#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shinycssloaders
#' @importFrom DT DTOutput
#' @importFrom ggiraph girafeOutput
#' @importFrom plotly plotlyOutput
#' @importFrom shiny column div fluidPage fluidRow h3 h4 navbarPage p selectInput tabPanel tagList uiOutput
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
    ),
    div(
      class = "kfp-filter-footer",
      uiOutput("filter_context"),
      shiny::actionButton("reset_filters", "Reset filters", class = "kfp-reset-button")
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
                withSpinner(ggiraph::girafeOutput("overview_trend", height = "330px"), color = "#00a2ab")
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
          div(
            class = "kfp-trends-intro",
            h3("Price trends"),
            p("Understand the direction, seasonality, spread, and geographic differences in the selected data."),
            uiOutput("trends_context")
          ),
          div(
            class = "kfp-trends-controls",
            fluidRow(
              column(
                3,
                selectInput(
                  "trend_frequency",
                  "Trend frequency",
                  choices = c("Monthly" = "month", "Quarterly" = "quarter"),
                  selected = "month"
                )
              ),
              column(
                3,
                selectInput(
                  "trend_display",
                  "Trend display",
                  choices = c("Actual price" = "actual", "Smoothed average" = "smooth"),
                  selected = "actual"
                )
              )
            )
          ),
          uiOutput("trends_kpis"),
          fluidRow(
            column(
              8,
              plot_panel(
                "Price trend",
                withSpinner(ggiraph::girafeOutput("linePlot", height = "330px"), color = "#00a2ab")
              )
            ),
            column(
              4,
              plot_panel(
                "Recent changes",
                withSpinner(DTOutput("trend_change_table"), color = "#00a2ab")
              )
            )
          ),
          fluidRow(
            column(
              6,
              plot_panel(
                "Seasonality index",
                withSpinner(ggiraph::girafeOutput("price_month_means", height = "300px"), color = "#00a2ab")
              )
            ),
            column(
              6,
              plot_panel(
                "Annual price range",
                withSpinner(ggiraph::girafeOutput("main_price_histogram", height = "300px"), color = "#00a2ab")
              )
            )
          ),
          fluidRow(
            column(
              12,
              uiOutput("geography_panel_ui")
            )
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
            column(6, uiOutput("compare_counties_ui")),
            column(6, uiOutput("compare_commodities_ui"))
          ),
          fluidRow(
            column(6, plot_panel("County Comparison", withSpinner(ggiraph::girafeOutput("county_compare_plot", height = "330px"), color = "#00a2ab"))),
            column(6, plot_panel("Commodity Comparison", withSpinner(ggiraph::girafeOutput("commodity_compare_plot", height = "330px"), color = "#00a2ab")))
          )
        )
      ),

      tabPanel(
        "Coverage",
        fluidPage(
          uiOutput("coverage_summary"),
          fluidRow(
            column(7, plot_panel("Observation Coverage by Year", withSpinner(ggiraph::girafeOutput("coverage_year_plot", height = "330px"), color = "#00a2ab"))),
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
