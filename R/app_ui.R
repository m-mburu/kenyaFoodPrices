#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shinycssloaders
#' @importFrom DT DTOutput
#' @importFrom ggiraph girafeOutput
#' @importFrom plotly plotlyOutput
#' @importFrom shinycssloaders withSpinner
#' @importFrom shiny column div fluidPage fluidRow h3 h4 navbarPage
#'   p radioButtons selectInput tabPanel tagList uiOutput
#' @noRd
#'

filter_panel <- function() {
  food_prices <- app_food_prices()

  div(
    class = "kfp-filter-band",
    fluidRow(
      shiny::column(
        2,
        shiny::selectInput(
          "category",
          "Category",
          choices = sort(unique(food_prices$category))
        )
      ),
      shiny::column(2, uiOutput("commodity_ui")),
      shiny::column(2, uiOutput("unit_ui")),
      shiny::column(2, uiOutput("pricetype_ui")),
      shiny::column(
        2,
        shiny::selectInput(
          "Currency",
          "Currency",
          c("KES" = "price", "USD" = "usdprice")
        )
      ),
      shiny::column(2, uiOutput("page_year_ui"))
    ),
    fluidRow(
      shiny::column(3, uiOutput("page1_county_ui")),
      shiny::column(3, uiOutput("page1_market_ui"))
    ),
    div(
      class = "kfp-calculation-control",
      radioButtons(
        "calculation",
        "Calculation",
        choices = price_calculation_choices(),
        selected = "balanced_median",
        inline = TRUE
      )
    ),
    div(
      class = "kfp-filter-footer",
      tags$span(class = "kfp-filter-scope", "Applies to: price panels"),
      uiOutput("filter_context"),
      shiny::actionButton(
        "reset_filters",
        "Reset filters",
        class = "kfp-reset-button"
      )
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

visualization_frame <- function(output, size = "standard") {
  div(
    class = paste("kfp-viz-frame", paste0("kfp-viz-", size)),
    output
  )
}

app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),
    shiny::tags$a(
      class = "kfp-skip-link",
      href = "#main-content",
      "Skip to main content"
    ),
    tags$div(
      id = "kfp-live-status",
      class = "sr-only",
      `aria-live` = "polite",
      `aria-atomic` = "true"
    ),
    tags$main(
      id = "main-content", `aria-label` = "Kenya Food Prices Dashboard",
      navbarPage(
        title = "Kenya Food Prices Dashboard",
        id = "main_nav",
        header = filter_panel(),
        tabPanel(
          "Overview",
          fluidPage(
            uiOutput("summary_kpis"),
            fluidRow(
              shiny::column(
                8,
                plot_panel(
                  "Price Trend",
                  shinycssloaders::withSpinner(
                    visualization_frame(
                      ggiraph::girafeOutput("overview_trend", height = "100%")
                    ),
                    color = "#00a2ab"
                  )
                )
              ),
              shiny::column(
                4,
                plot_panel(
                  "Recent Monthly Change",
                  shinycssloaders::withSpinner(
                    DT::DTOutput("recent_change_table"),
                    color = "#00a2ab"
                  )
                )
              )
            ),
            fluidRow(
              shiny::column(
                6,
                plot_panel(
                  "Highest Average Prices by County",
                  shinycssloaders::withSpinner(
                    DT::DTOutput("top_county_table"),
                    color = "#00a2ab"
                  )
                )
              ),
              shiny::column(
                6,
                plot_panel(
                  "Highest Average Prices by Market",
                  shinycssloaders::withSpinner(
                    DT::DTOutput("top_market_table"),
                    color = "#00a2ab"
                  )
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
              p(
                "Understand the direction, seasonality, spread, and",
                "geographic differences in the selected data."
              ),
              uiOutput("trends_context")
            ),
            div(
              class = "kfp-trends-controls",
              fluidRow(
                shiny::column(
                  3,
                  div(
                    class = "kfp-toggle-control",
                    radioButtons(
                      "trend_frequency",
                      "Trend frequency",
                      choices = c("Monthly" = "month", "Quarterly" = "quarter"),
                      selected = "month",
                      inline = TRUE
                    )
                  )
                ),
                shiny::column(
                  3,
                  div(
                    class = "kfp-toggle-control",
                    radioButtons(
                      "trend_display",
                      "Trend display",
                      choices = c(
                        "Actual price" = "actual",
                        "Smoothed average" = "smooth"
                      ),
                      selected = "actual",
                      inline = TRUE
                    )
                  )
                )
              )
            ),
            uiOutput("trends_kpis"),
            fluidRow(
              shiny::column(
                8,
                plot_panel(
                  "Price trend",
                  shinycssloaders::withSpinner(
                    visualization_frame(
                      ggiraph::girafeOutput("linePlot", height = "100%")
                    ),
                    color = "#00a2ab"
                  )
                )
              ),
              shiny::column(
                4,
                plot_panel(
                  "Recent changes",
                  shinycssloaders::withSpinner(
                    DT::DTOutput("trend_change_table"),
                    color = "#00a2ab"
                  )
                )
              )
            ),
            fluidRow(
              shiny::column(
                6,
                plot_panel(
                  "Seasonality index",
                  shinycssloaders::withSpinner(
                    visualization_frame(
                      ggiraph::girafeOutput("price_month_means", height = "100%"),
                      "compact"
                    ),
                    color = "#00a2ab"
                  )
                )
              ),
              shiny::column(
                6,
                plot_panel(
                  "Annual price range",
                  shinycssloaders::withSpinner(
                    visualization_frame(
                      ggiraph::girafeOutput(
                        "main_price_histogram",
                        height = "100%"
                      ),
                      "compact"
                    ),
                    color = "#00a2ab"
                  )
                )
              )
            ),
            fluidRow(
              shiny::column(
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
              shiny::column(
                8,
                plot_panel(
                  "Market Price Map",
                  shinycssloaders::withSpinner(
                    visualization_frame(
                      ggiraph::girafeOutput("price_map", height = "100%"),
                      "map"
                    ),
                    color = "#00a2ab"
                  )
                )
              ),
              column(
                4,
                plot_panel(
                  "Mapped Markets",
                  shinycssloaders::withSpinner(
                    DT::DTOutput("map_market_table"),
                    color = "#00a2ab"
                  )
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
              shiny::column(6, uiOutput("compare_counties_ui")),
              shiny::column(6, uiOutput("compare_commodities_ui"))
            ),
            fluidRow(
              shiny::column(
                6,
                plot_panel(
                  "County Comparison",
                  shinycssloaders::withSpinner(
                    visualization_frame(
                      ggiraph::girafeOutput(
                        "county_compare_plot",
                        height = "100%"
                      )
                    ),
                    color = "#00a2ab"
                  )
                )
              ),
              shiny::column(
                6,
                plot_panel(
                  "Commodity Comparison",
                  shinycssloaders::withSpinner(
                    visualization_frame(
                      ggiraph::girafeOutput(
                        "commodity_compare_plot",
                        height = "100%"
                      )
                    ),
                    color = "#00a2ab"
                  )
                )
              )
            )
          )
        ),
        tabPanel(
          "Coverage",
          fluidPage(
            uiOutput("coverage_summary"),
            fluidRow(
              shiny::column(
                7,
                plot_panel(
                  "Observation Coverage by Year",
                  shinycssloaders::withSpinner(
                    visualization_frame(
                      ggiraph::girafeOutput(
                        "coverage_year_plot",
                        height = "100%"
                      )
                    ),
                    color = "#00a2ab"
                  )
                )
              ),
              shiny::column(
                5,
                plot_panel(
                  "Coverage Detail",
                  shinycssloaders::withSpinner(
                    DT::DTOutput("coverage_table"),
                    color = "#00a2ab"
                  )
                )
              )
            )
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
    tags$script(
      async = NA,
      src = paste0(
        "https://www.googletagmanager.com/gtag/js?id=",
        "G-BFNZ97VTLJ"
      )
    ),
    tags$script(
      HTML(
        paste(
          "window.dataLayer = window.dataLayer || [];",
          "function gtag(){dataLayer.push(arguments);}",
          "gtag('js', new Date());",
          "gtag('config', 'G-BFNZ97VTLJ');",
          sep = "\n"
        )
      )
    ),
    tags$meta(
      name = "description",
      content = "Kenya food prices and climate conditions dashboard"
    )
  )
}
