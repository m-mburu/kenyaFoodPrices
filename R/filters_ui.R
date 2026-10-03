#' Reusable primary and advanced food-price filters
#'
#' @param id Unique module namespace.
#' @param food_prices Price records used to initialise category choices.
#' @return A namespaced filter-panel UI fragment.
#' @noRd
filters_module_ui <- function(id, food_prices = app_food_prices()) {
  ns <- shiny::NS(id)
  defaults <- filter_initial_state(food_prices)
  dates_available <- length(defaults$dates) == 2L &&
    !anyNA(defaults$dates)
  scoped_prices <- if (dates_available) {
    food_prices[
      category == defaults$category &
        commodity == defaults$commodity &
        unit == defaults$unit &
        pricetype == defaults$pricetype &
        data.table::between(date, defaults$dates[1L], defaults$dates[2L])
    ]
  } else food_prices[0]
  county_choices <- c("All", sort(unique(
    scoped_prices[!is.na(county), county]
  )))
  market_choices <- c(
    "All", sort(unique(scoped_prices[!is.na(market), market]))
  )

  shiny::div(
    class = "kfp-filter-band",
    shiny::tags$details(
      id = ns("kfp-main-filters"),
      class = "kfp-main-filters",
      `data-kfp-filter-role` = "main",
      `data-kfp-remember` = "true",
      open = "open",
      shiny::tags$summary("Filters"),
      shiny::fluidRow(
        # Category comes first because it determines the commodity choices.
        shiny::column(
          2,
          shiny::selectInput(
            ns("category"),
            "Category",
            choices = sort(unique(food_prices$category)),
            selected = defaults$category
          )
        ),
        shiny::column(
          2,
          shiny::selectInput(
            ns("commodity"), "Commodity",
            choices = sort(unique(food_prices[
              category == defaults$category, commodity
            ])),
            selected = defaults$commodity
          )
        ),
        shiny::column(
          2,
          shiny::selectInput(
            ns("pricetype"), "Price Type",
            choices = sort(unique(food_prices[
              category == defaults$category &
                commodity == defaults$commodity &
                unit == defaults$unit, pricetype
            ])),
            selected = defaults$pricetype
          )
        ),
        shiny::column(
          2,
          shiny::selectInput(
            ns("page1_county"), "County", choices = county_choices,
            selected = "All"
          )
        ),
        shiny::column(
          4,
          shiny::dateRangeInput(
            ns("page1_date"), "Date Range",
            start = if (dates_available) defaults$dates[1L] else NULL,
            end = if (dates_available) defaults$dates[2L] else NULL,
            min = if (dates_available) defaults$dates[1L] else NULL,
            max = if (dates_available) defaults$dates[2L] else NULL
          )
        )
      )
    ),
    shiny::tags$details(
      id = ns("kfp-advanced-filters"),
      class = "kfp-advanced-filters",
      `data-kfp-filter-role` = "advanced",
      `data-kfp-remember` = "true",
      shiny::tags$summary("More filters"),
      shiny::fluidRow(
        shiny::column(
          4,
          shiny::selectInput(
            ns("page1_market"), "Market", choices = market_choices,
            selected = "All"
          )
        ),
        shiny::column(
          4,
          shiny::selectInput(
            ns("unit"), "Unit",
            choices = sort(unique(food_prices[
              category == defaults$category &
                commodity == defaults$commodity, unit
            ])),
            selected = defaults$unit
          )
        ),
        shiny::column(
          4,
          shiny::selectInput(
            ns("Currency"),
            "Currency",
            c("KES" = "price", "USD" = "usdprice")
          )
        )
      ),
      shiny::fluidRow(
        shiny::column(
          12,
          shiny::div(
            class = "kfp-calculation-control",
            shiny::radioButtons(
              ns("calculation"),
              "Calculation",
              choices = price_calculation_choices(),
              selected = "balanced_median",
              inline = TRUE
            )
          )
        )
      )
    ),
    shiny::div(
      class = "kfp-filter-footer",
      shiny::tags$span(class = "kfp-filter-scope", "Applies to: price panels"),
      shiny::uiOutput(ns("filter_context")),
      shiny::actionButton(
        ns("reset_filters"),
        "Reset filters",
        class = "kfp-reset-button"
      )
    )
  )
}
