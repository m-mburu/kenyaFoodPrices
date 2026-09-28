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
    tags$details(
      id = "kfp-main-filters",
      class = "kfp-main-filters",
      `data-kfp-remember` = "true",
      open = "open",
      tags$summary("Filters"),
      fluidRow(
        shiny::column(3, uiOutput("commodity_ui")),
        shiny::column(3, uiOutput("pricetype_ui")),
        shiny::column(3, uiOutput("page1_county_ui")),
        shiny::column(3, uiOutput("page_year_ui"))
      )
    ),
    tags$details(
      id = "kfp-advanced-filters",
      class = "kfp-advanced-filters",
      `data-kfp-remember` = "true",
      tags$summary("More filters"),
      fluidRow(
        shiny::column(
          3,
          shiny::selectInput(
            "category",
            "Category",
            choices = sort(unique(food_prices$category))
          )
        ),
        shiny::column(3, uiOutput("page1_market_ui")),
        shiny::column(3, uiOutput("unit_ui")),
        shiny::column(
          3,
          shiny::selectInput(
            "Currency",
            "Currency",
            c("KES" = "price", "USD" = "usdprice")
          )
        )
      ),
      fluidRow(
        shiny::column(
          12,
          div(
            class = "kfp-calculation-control",
            radioButtons(
              "calculation",
              "Calculation",
              choices = price_calculation_choices(),
              selected = "balanced_median",
              inline = TRUE
            )
          )
        )
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

plot_panel <- function(title, output, footer = NULL) {
  div(
    class = "kfp-panel",
    h4(title),
    output,
    footer
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
    shinyjs::useShinyjs(),
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
            class = "kfp-overview",
            uiOutput("summary_kpis"),
            div(
              class = "kfp-overview-trend",
              div(
                class = "kfp-overview-section-heading",
                h3("Monthly price trend"),
                shiny::actionLink("overview_to_trends", "Explore trends")
              ),
              shinycssloaders::withSpinner(
                visualization_frame(
                  ggiraph::girafeOutput(
                    "overview_trend",
                    height = "100%"
                  ),
                  "overview"
                ),
                color = "#00a2ab"
              ),
              p(
                class = "kfp-overview-note",
                "Available markets can change over time. Gaps mean no",
                "monthly estimate was observed."
              )
            ),
            tags$details(
              id = "kfp-overview-monthly-values",
              class = "kfp-overview-details",
              `data-kfp-remember` = "true",
              `data-kfp-adjust` = "datatable",
              tags$summary("Monthly values and coverage"),
              div(
                class = "kfp-overview-table",
                shinycssloaders::withSpinner(
                  DT::DTOutput("recent_change_table"),
                  color = "#00a2ab"
                )
              )
            ),
            tags$details(
              id = "kfp-overview-location-summaries",
              class = "kfp-overview-details",
              `data-kfp-remember` = "true",
              `data-kfp-adjust` = "datatable",
              tags$summary("Historical county and market summaries"),
              p(
                class = "kfp-overview-note",
                "Highest period estimates among available locations.",
                "Locations cover different months; these are not",
                "same-month price comparisons."
              ),
              h4("County estimates"),
              div(
                class = "kfp-overview-table",
                shinycssloaders::withSpinner(
                  DT::DTOutput("top_county_table"),
                  color = "#00a2ab"
                )
              ),
              h4("Market estimates"),
              div(
                class = "kfp-overview-table",
                shinycssloaders::withSpinner(
                  DT::DTOutput("top_market_table"),
                  color = "#00a2ab"
                )
              )
            )
          )
        ),
        tabPanel(
          "Trends",
          fluidPage(
            class = "kfp-trends",
            div(
              class = "kfp-trends-intro",
              h3("Price trends"),
              uiOutput("trends_context")
            ),
            uiOutput("trends_kpis"),
            div(
              class = "kfp-trends-primary",
              h4("Price over time"),
              div(
                class = "kfp-trends-controls",
                div(
                  class = "kfp-toggle-control",
                  radioButtons(
                    "trend_frequency",
                    "Trend frequency",
                    choices = c("Monthly" = "month",
                                "Quarterly" = "quarter"),
                    selected = "month",
                    inline = TRUE
                  )
                ),
                div(
                  class = "kfp-toggle-control",
                  radioButtons(
                    "trend_display",
                    "Display",
                    choices = c(
                      "Period estimate" = "actual",
                      "Trailing 3-period average" = "smooth"
                    ),
                    selected = "actual",
                    inline = TRUE
                  )
                )
              ),
              shinycssloaders::withSpinner(
                visualization_frame(
                  ggiraph::girafeOutput("linePlot", height = "100%"),
                  "trend"
                ),
                color = "#00a2ab"
              ),
              uiOutput("trend_scope_note"),
              div(
                class = "kfp-trend-explore",
                div(
                  class = "kfp-trend-explore-actions",
                  shiny::actionButton(
                    "trend_selection_open",
                    "Select a period",
                    class = "kfp-reset-button"
                  ),
                  tags$p(
                    class = "kfp-trend-explore-note",
                    "Pin an exact month or quarter, then compare it with",
                    "another period without changing the global filters."
                  )
                ),
                shinyjs::hidden(
                  div(
                    id = "trend_selection_panel",
                    class = "kfp-trend-selection",
                    tabindex = "-1",
                    div(
                      class = "kfp-trend-selection-header",
                      h4("Selected period"),
                      shiny::actionButton(
                        "trend_selection_clear",
                        "Clear selection",
                        class = "kfp-reset-button"
                      )
                    ),
                    uiOutput("trend_period_summary"),
                    div(
                      class = "kfp-trend-selection-grid",
                      div(
                        class = "kfp-trend-selection-field",
                        shiny::selectInput(
                          "trend_reference_period",
                          "Reference period",
                          choices = character(0)
                        )
                      ),
                      div(
                        class = paste(
                          "kfp-trend-selection-field",
                          "kfp-trend-selection-actions"
                        ),
                        shiny::actionButton(
                          "trend_compare_toggle",
                          "Compare with another period",
                          class = "kfp-reset-button"
                        )
                      )
                    ),
                    shinyjs::hidden(
                      div(
                        id = "trend_compare_panel",
                        class = "kfp-trend-compare-panel",
                        div(
                          class = "kfp-trend-selection-grid",
                          div(
                            class = "kfp-trend-selection-field",
                            shiny::selectInput(
                              "trend_compare_period",
                              "Comparison period",
                              choices = character(0)
                            )
                          ),
                          div(
                            class = paste(
                              "kfp-trend-selection-field",
                              "kfp-trend-selection-actions"
                            ),
                            shiny::actionButton(
                              "trend_compare_close",
                              "Hide comparison",
                              class = "kfp-reset-button"
                            )
                          )
                        ),
                        uiOutput("trend_compare_summary")
                      )
                    )
                  )
                )
              )
            ),
            tags$details(
              id = "kfp-trend-values",
              class = "kfp-trends-details",
              `data-kfp-remember` = "true",
              `data-kfp-adjust` = "datatable",
              tags$summary("Values and coverage"),
              uiOutput("trend_table_note"),
              div(
                class = "kfp-trends-table",
                shinycssloaders::withSpinner(
                  DT::DTOutput("trend_change_table"),
                  color = "#00a2ab"
                )
              )
            ),
            tags$details(
              id = "kfp-trend-seasonality",
              class = "kfp-trends-details",
              `data-kfp-remember` = "true",
              tags$summary("Seasonal pattern"),
              uiOutput("seasonality_note"),
              shinycssloaders::withSpinner(
                visualization_frame(
                  ggiraph::girafeOutput(
                    "price_month_means", height = "100%"
                  ),
                  "trend-detail"
                ),
                color = "#00a2ab"
              )
            ),
            tags$details(
              id = "kfp-trend-annual-range",
              class = "kfp-trends-details",
              `data-kfp-remember` = "true",
              tags$summary("Annual spread of recorded prices"),
              uiOutput("annual_note"),
              shinycssloaders::withSpinner(
                visualization_frame(
                  ggiraph::girafeOutput(
                    "main_price_histogram", height = "100%"
                  ),
                  "trend-detail"
                ),
                color = "#00a2ab"
              )
            ),
            tags$details(
              id = "kfp-trend-geography",
              class = "kfp-trends-details",
              `data-kfp-remember` = "true",
              tags$summary("Compare locations"),
              uiOutput("geography_panel_ui")
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
                  shiny::textOutput("map_market_title", inline = TRUE),
                  shinycssloaders::withSpinner(
                    DT::DTOutput("map_market_table"),
                    color = "#00a2ab"
                  ),
                  footer = shiny::tags$p(
                    class = "kfp-panel-note",
                    shiny::textOutput("map_market_note", inline = TRUE)
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
