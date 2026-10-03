# Update persistent controls from the same scoped observation subsets.
register_filter_controls <- function(
  input, session, food_prices, selected_price_dates
) {
  commodity_records <- shiny::reactive({
    shiny::req(input$category)
    food_prices[category == input$category]
  })
  unit_records <- shiny::reactive({
    shiny::req(input$category, input$commodity)
    commodity_records()[commodity == input$commodity]
  })
  pricetype_records <- shiny::reactive({
    shiny::req(input$category, input$commodity, input$unit)
    unit_records()[unit == input$unit]
  })
  price_records <- shiny::reactive({
    shiny::req(input$category, input$commodity, input$unit, input$pricetype)
    pricetype_records()[pricetype == input$pricetype]
  })
  geography_records <- shiny::reactive({
    dates <- selected_price_dates()
    data <- price_records()[
      data.table::between(date, dates[1L], dates[2L])
    ]
    data
  })

  shiny::observeEvent(input$category, {
    choices <- sort(unique(commodity_records()$commodity))
    shiny::updateSelectInput(
      session, "commodity", choices = choices,
      selected = filter_valid_choice(input$commodity, choices)
    )
  }, ignoreInit = FALSE)

  shiny::observeEvent(unit_records(), {
    choices <- sort(unique(unit_records()$unit))
    shiny::updateSelectInput(
      session, "unit", choices = choices,
      selected = filter_valid_choice(input$unit, choices)
    )
  }, ignoreInit = FALSE)

  shiny::observeEvent(pricetype_records(), {
    choices <- sort(unique(pricetype_records()$pricetype))
    shiny::updateSelectInput(
      session, "pricetype", choices = choices,
      selected = filter_valid_choice(input$pricetype, choices)
    )
  }, ignoreInit = FALSE)

  shiny::observeEvent(
    list(input$category, input$commodity, input$unit, input$pricetype),
    {
      records <- price_records()
      if (!nrow(records)) return()
      observation_dates <- records$date[!is.na(records$date)]
      if (!length(observation_dates)) return()
      min_date <- min(observation_dates)
      max_date <- max(observation_dates)
      dates <- filter_valid_dates(input$page1_date, c(min_date, max_date))
      shiny::updateDateRangeInput(
        session, "page1_date", start = dates[1L], end = dates[2L],
        min = min_date, max = max_date
      )
    },
    ignoreInit = FALSE
  )

  shiny::observeEvent(
    list(input$page1_date, input$category, input$commodity,
         input$unit, input$pricetype),
    {
      records <- geography_records()
      county_choices <- c("All", sort(unique(
        records[!is.na(county), county]
      )))
      shiny::updateSelectInput(
        session, "page1_county", choices = county_choices,
        selected = filter_valid_choice(input$page1_county,
                                       county_choices, "All")
      )
    },
    ignoreInit = FALSE
  )

  shiny::observeEvent(
    list(input$page1_date, input$category, input$commodity,
         input$unit, input$pricetype, input$page1_county),
    {
      records <- geography_records()
      if (!identical(input$page1_county, "All")) {
        records <- records[county %in% input$page1_county]
      }
      choices <- c("All", sort(unique(records[!is.na(market), market])))
      shiny::updateSelectInput(
        session, "page1_market", choices = choices,
        selected = filter_valid_choice(input$page1_market, choices, "All")
      )
    },
    ignoreInit = FALSE
  )
}
