# Column names referenced inside data.table and ggplot2 expressions.
utils::globalVariables(c(
  ":=", "change", "consecutive_month", "covered_months",
  "display_y", "estimate", "label", "Latest observation month",
  "percent_change",
  "period_id", "previous_estimate", "segment", "smooth_segment"
))

#' Register the dashboard filters, shared summaries and tab modules
#'
#' @param input App-level Shiny inputs, including the active tab.
#' @param output App-level output bindings supplied by Shiny.
#' @param session App-level session used to switch tabs from Overview.
#' @return Registers modules and their shared reactive inputs for the session.
#' @import data.table
#' @import ggplot2
#' @importFrom dplyr %>%
#' @importFrom DT datatable
#' @importFrom ggiraph renderGirafe
#' @importFrom plotly layout plot_ly renderPlotly
#' @importFrom shiny checkboxGroupInput dateRangeInput div h4 need
#'     reactive renderUI renderText req selectInput selectizeInput
#'     shinyServer validate
#' @importFrom stats reorder
#' @keywords internal
#' @noRd
app_server <- function(input, output, session) {
  food_prices <- app_food_prices()
  filters <- filters_module_server("filters", food_prices = food_prices)
  selection <- filters$fields

  price_aggregation <- reactive({
    records <- filters$data()
    req(nrow(records) > 0)

    aggregate_price_data(
      records,
      price_column = filters$price_column(),
      calculation = selection$calculation()
    )
  })
  market_month <- reactive(price_aggregation()$market_month)
  county_month <- reactive(price_aggregation()$county_month)
  monthly_summary <- reactive({
    prices <- price_aggregation()$national_month
    req(nrow(prices) > 0)

    summarise_monthly_prices(prices)
  })

  overview_module_server(
    "overview",
    price_records = filters$data,
    monthly_summary = monthly_summary,
    market_month = market_month,
    county_month = county_month,
    calculation = selection$calculation,
    calculation_label = filters$calculation_label,
    calculation_short = filters$calculation_short,
    selected_unit = selection$unit,
    unit_denominator = filters$unit_denominator,
    price_unit_label = filters$price_unit_label,
    currency_label = filters$currency_label,
    open_trends = function() {
      shiny::updateNavbarPage(session, "main_nav", selected = "Trends")
    }
  )

  trends_module_server(
    "trends",
    price_records = filters$data,
    base_price_records = filters$base_data,
    monthly_summary = monthly_summary,
    price_column = filters$price_column,
    price_unit_label = filters$price_unit_label,
    unit_denominator = filters$unit_denominator,
    calculation = selection$calculation,
    selected_commodity = selection$commodity,
    selected_price_type = selection$pricetype,
    selected_unit = selection$unit,
    selected_county = selection$county,
    selected_market = selection$market,
    reset_event = filters$reset_event
  )

  climate_module_server(
    "climate",
    price_data = filters$base_data,
    price_column = filters$price_column,
    price_unit_label = filters$price_unit_label,
    global_county = filters$county,
    set_global_county = filters$set_county,
    reset_focus = filters$reset_event,
    active = reactive(identical(input$main_nav, "Climate"))
  )

  # The commodity comparison spans the selected category, unit and price type.
  commodity_comparison_records <- reactive({
    req(selection$category(), selection$unit(), selection$pricetype())
    compare_commodity_records(
      food_prices,
      selected_category = selection$category(),
      selected_unit = selection$unit(),
      selected_price_type = selection$pricetype(),
      selected_dates = filters$selected_dates()
    )
  })
  compare_module_server(
    "compare",
    county_price_records = filters$base_data,
    commodity_price_records = commodity_comparison_records,
    price_column = filters$price_column,
    price_unit_label = filters$price_unit_label,
    unit_denominator = filters$unit_denominator
  )

  coverage_module_server(
    "coverage",
    price_records = filters$data,
    selected_commodity = selection$commodity
  )
}
