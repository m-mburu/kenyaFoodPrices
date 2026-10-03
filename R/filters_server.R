#' Own the dependent food-price filters and expose their reactive contract
#'
#' @param id Namespace matching filters_module_ui().
#' @param food_prices Observation-level price records, read without mutation.
#' @return A list of selection/label/data reactives, a reset-event reactive
#'   and a guarded county setter for Climate. Base data excludes geography;
#'   data additionally applies county and market. Dates use observation dates.
#' @noRd
filters_module_server <- function(id, food_prices = app_food_prices()) {
  shiny::moduleServer(id, function(input, output, session) {
    # Selection can contain NULL during dependent-input reconstruction.
    # Data consumers are gated separately by the required valid inputs.
    selection <- shiny::reactive({
      list(
        category = input$category,
        commodity = input$commodity,
        unit = input$unit,
        pricetype = input$pricetype,
        currency = input$Currency,
        calculation = input$calculation %||% "balanced_median",
        dates = input$page1_date,
        county = input$page1_county,
        market = input$page1_market
      )
    })
    fields <- list(
      category = shiny::reactive(input$category),
      commodity = shiny::reactive(input$commodity),
      unit = shiny::reactive(input$unit),
      pricetype = shiny::reactive(input$pricetype),
      currency = shiny::reactive(input$Currency),
      calculation = shiny::reactive(
        input$calculation %||% "balanced_median"
      ),
      dates = shiny::reactive(input$page1_date),
      county = shiny::reactive(input$page1_county),
      market = shiny::reactive(input$page1_market)
    )
    selected_dates <- shiny::reactive({
      shiny::req(valid_price_date_range(input$page1_date))
      input$page1_date
    })
    labels <- filter_label_reactives(input)
    register_filter_controls(
      input, session, food_prices, selected_dates
    )

    base_data <- shiny::reactive({
      shiny::req(input$category, input$commodity, input$unit,
                 input$pricetype)
      dates <- selected_dates()
      food_prices[
        category %in% input$category &
          commodity %in% input$commodity &
          unit %in% input$unit &
          pricetype %in% input$pricetype &
          data.table::between(date, dates[1L], dates[2L])
      ]
    })
    data <- shiny::reactive({
      shiny::req(input$page1_county, input$page1_market)
      filter_price_geography(
        base_data(), input$page1_county, input$page1_market
      )
    })
    output$filter_context <- shiny::renderUI({
      shiny::req(input$category, input$commodity, input$unit,
                 input$pricetype, input$page1_county, input$page1_market)
      filter_context_ui(selection(), labels$price_unit_label(),
                        selected_dates())
    })

    # Updates use local IDs: the module session adds its namespace.
    set_county <- function(county) {
      if (!identical(shiny::isolate(input$page1_county), county)) {
        # Climate can focus a county without matching price observations.
        # Offer that selection explicitly so selectize does not clear it.
        choices <- c("All", sort(unique(c(food_prices$county, county))))
        choices <- unique(choices[!is.na(choices)])
        shiny::updateSelectInput(
          session, "page1_county", choices = choices, selected = county
        )
      }
      invisible(NULL)
    }
    shiny::observeEvent(input$reset_filters, {
      reset_filter_inputs(session, food_prices)
    }, ignoreInit = TRUE)

    c(
      list(
        selection = selection,
        fields = fields,
        selected_dates = selected_dates,
        base_data = base_data,
        data = data,
        county = shiny::reactive(input$page1_county %||% "All"),
        set_county = set_county,
        reset_event = shiny::reactive(input$reset_filters)
      ),
      labels
    )
  })
}

# Reset dependent widgets through the module session, preserving defaults.
reset_filter_inputs <- function(session, food_prices) {
  defaults <- filter_initial_state(food_prices)
  records <- food_prices[
    category == defaults$category & commodity == defaults$commodity
  ]
  unit_choices <- sort(unique(records$unit))
  records <- records[unit == defaults$unit]
  pricetype_choices <- sort(unique(records$pricetype))
  records <- records[pricetype == defaults$pricetype]
  dates_available <- length(defaults$dates) == 2L &&
    !anyNA(defaults$dates)
  if (dates_available) {
    records <- records[data.table::between(
      date, defaults$dates[1L], defaults$dates[2L]
    )]
  } else {
    records <- records[0]
  }
  county_choices <- c("All", sort(unique(
    records[!is.na(county), county]
  )))
  market_choices <- c("All", sort(unique(records[!is.na(market), market])))

  shiny::updateSelectInput(
    session, "category", choices = sort(unique(food_prices$category)),
    selected = defaults$category
  )
  shiny::updateSelectInput(
    session, "commodity",
    choices = sort(unique(food_prices[
      category == defaults$category, commodity
    ])),
    selected = defaults$commodity
  )
  shiny::updateSelectInput(
    session, "unit", choices = unit_choices, selected = defaults$unit
  )
  shiny::updateSelectInput(
    session, "pricetype", choices = pricetype_choices,
    selected = defaults$pricetype
  )
  if (dates_available) {
    shiny::updateDateRangeInput(
      session, "page1_date", start = defaults$dates[1L],
      end = defaults$dates[2L], min = defaults$dates[1L],
      max = defaults$dates[2L]
    )
  }
  shiny::updateSelectInput(session, "Currency", selected = "price")
  shiny::updateSelectInput(
    session, "page1_county", choices = county_choices, selected = "All"
  )
  shiny::updateSelectInput(
    session, "page1_market", choices = market_choices, selected = "All"
  )
  shiny::updateRadioButtons(
    session, "calculation", selected = "balanced_median"
  )
}
