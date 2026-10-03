filter_module_fixture <- function() {
  data.table::data.table(
    date = as.Date(c(
      "2025-01-15", "2025-02-15", "2025-03-15", "2025-01-15",
      "2025-02-15", "2025-03-15", "2025-01-15", "2025-02-15"
    )),
    year_month_date = as.Date(c(
      "2025-01-01", "2025-02-01", "2025-03-01", "2025-01-01",
      "2025-02-01", "2025-03-01", "2025-01-01", "2025-02-01"
    )),
    category = c(
      "Food", "Food", "Food", "Food", "Food", "Food",
      "Livestock", "Livestock"
    ),
    commodity = c(
      "Bread", "Bread", "Bread", "Maize", "Maize", "Maize",
      "Milk", "Milk"
    ),
    unit = c("kg", "kg", "90 KG", "bag", "bag", "90 KG", "litre", "litre"),
    pricetype = c(
      "Retail", "Retail", "Wholesale", "Retail", "Retail", "Wholesale",
      "Retail", "Wholesale"
    ),
    county = c("Alpha", "Beta", "Alpha", "Beta", NA, "Alpha", "Gamma", NA),
    market = c("A market", "B market", "A market", "C market", NA,
                "A market", "D market", NA),
    price = c(10, 20, 30, 12, 14, 40, 50, 60),
    usdprice = c(1, 2, 3, 1.2, 1.4, 4, 5, 6)
  )
}

test_that("initial defaults form an observed combination and date scope", {
  defaults <- filter_initial_state(filter_module_fixture())
  expect_identical(defaults$category, "Food")
  expect_identical(defaults$commodity, "Bread")
  expect_identical(defaults$unit, "90 KG")
  expect_identical(defaults$pricetype, "Wholesale")
  expect_identical(defaults$dates, rep(as.Date("2025-03-15"), 2L))
})

test_that("date preservation falls back to coverage when periods do not meet", {
  available <- as.Date(c("2025-01-15", "2025-03-15"))
  expect_identical(filter_valid_dates(
    as.Date(c("2024-01-01", "2024-12-31")), available
  ), available)
  expect_identical(filter_valid_dates(
    as.Date(c("2026-01-01", "2026-12-31")), available
  ), available)
  expect_identical(filter_valid_dates(
    as.Date(c("2025-02-01", "2025-04-01")), available
  ), as.Date(c("2025-02-01", "2025-03-15")))
})

new_filter_test_session <- function() {
  captured <- new.env(parent = emptyenv())
  captured$messages <- list()
  mock <- shiny::MockShinySession$new()
  mock$sendInputMessage <- function(inputId, message) {
    captured$messages[[inputId]] <- message
  }
  list(session = mock, captured = captured)
}

test_that("filter UI namespaces controls and orders main categories", {
  fixture <- filter_module_fixture()
  first_ui <- htmltools::renderTags(filters_module_ui("first", fixture))$html
  second_ui <- htmltools::renderTags(filters_module_ui("second", fixture))$html

  main_ids <- c(
    "category", "commodity", "pricetype", "page1_county", "page1_date"
  )
  advanced_ids <- c(
    "page1_market", "unit", "Currency", "calculation"
  )
  first_ids <- c(
    "kfp-main-filters", "kfp-advanced-filters", main_ids, advanced_ids,
    "filter_context", "reset_filters"
  )

  for (control_id in first_ids) {
    expect_match(first_ui, paste0('id="first-', control_id, '"'), fixed = TRUE)
  }
  expect_false(anyDuplicated(first_ids) > 0L)
  expect_match(second_ui, 'id="second-kfp-main-filters"', fixed = TRUE)
  expect_false(grepl('id="first-', second_ui, fixed = TRUE))
  empty_ui <- htmltools::renderTags(
    filters_module_ui("empty", fixture[0])
  )$html
  expect_match(empty_ui, 'id="empty-category"', fixed = TRUE)

  positions <- vapply(
    main_ids,
    function(control_id) regexpr(
      paste0('id="first-', control_id, '"'), first_ui, fixed = TRUE
    )[[1L]],
    integer(1)
  )
  expect_true(all(diff(positions) > 0L))
  expect_lt(
    regexpr('id="first-kfp-main-filters"', first_ui, fixed = TRUE),
    regexpr('id="first-kfp-advanced-filters"', first_ui, fixed = TRUE)
  )
})

test_that("filter module returns scoped price and geography data", {
  fixture <- filter_module_fixture()
  fixture_before <- data.table::copy(fixture)
  test_session <- new_filter_test_session()

  shiny::testServer(
    filters_module_server,
    args = list(food_prices = fixture),
    session = test_session$session,
    {
      session$setInputs(
        category = "Food",
        commodity = "Bread",
        unit = "kg",
        pricetype = "Retail",
        Currency = "price",
        calculation = "balanced_median",
        page1_date = as.Date(c("2025-01-01", "2025-02-28")),
        page1_county = "All",
        page1_market = "All"
      )

      expect_named(
        session$returned$selection(),
        c(
          "category", "commodity", "unit", "pricetype", "currency",
          "calculation", "dates", "county", "market"
        )
      )
      expect_equal(session$returned$selection()$commodity, "Bread")
      expect_equal(session$returned$selection()$currency, "price")
      expect_identical(
        session$returned$selected_dates(),
        as.Date(c("2025-01-01", "2025-02-28"))
      )
      expect_identical(session$returned$county(), "All")
      expect_equal(session$returned$base_data()$county, c("Alpha", "Beta"))
      expect_equal(nrow(session$returned$data()), 2L)
      expect_true(all(session$returned$data()$county %in% c("Alpha", "Beta")))

      expect_named(session$returned$fields, c(
        "category", "commodity", "unit", "pricetype", "currency",
        "calculation", "dates", "county", "market"
      ))
      expect_equal(session$returned$fields$commodity(), "Bread")
      session$setInputs(page1_county = "Alpha")
      expect_equal(session$returned$data()$county, "Alpha")
      session$setInputs(page1_market = "A market")
      expect_equal(session$returned$data()$market, "A market")
      expect_equal(session$returned$base_data()$county, c("Alpha", "Beta"))

      session$setInputs(page1_county = "Beta")

      expect_equal(session$returned$price_column(), "price")
      expect_equal(session$returned$currency_label(), "KES")
      expect_equal(session$returned$price_unit_label(), "KES per kg")
      expect_equal(
        session$returned$calculation_short(), "Median price estimate"
      )
      expect_equal(session$returned$unit_denominator(), "(KES per kg)")

      session$setInputs(
        commodity = "Maize",
        unit = "bag",
        pricetype = "Retail",
        page1_date = as.Date(c("2025-01-01", "2025-02-28")),
        page1_county = "All",
        page1_market = "All"
      )
      expect_true(anyNA(session$returned$base_data()$county))
      expect_equal(nrow(session$returned$base_data()), 2L)
      session$setInputs(page1_county = "Beta")
      expect_false(anyNA(session$returned$data()$county))
      expect_equal(nrow(session$returned$data()), 1L)

      test_session$captured$messages <- list()
      session$returned$set_county("Alpha")
      session$returned$set_county("Without observations")
      expect_match(
        test_session$captured$messages$page1_county$options,
        "Without observations", fixed = TRUE
      )
      session$returned$set_county("Alpha")
      expect_identical(
        test_session$captured$messages$page1_county$value, "Alpha"
      )
      expect_named(test_session$captured$messages, "page1_county")
      session$setInputs(page1_county = "Alpha")
      test_session$captured$messages <- list()
      session$returned$set_county("Alpha")
      expect_length(test_session$captured$messages, 0L)

      test_session$captured$messages <- list()
      session$setInputs(
        Currency = "usdprice",
        calculation = "record_weighted_mean"
      )
      expect_length(test_session$captured$messages, 0L)
      expect_equal(session$returned$price_column(), "usdprice")
      expect_equal(session$returned$currency_label(), "USD")
      expect_equal(session$returned$price_unit_label(), "USD per bag")
      expect_equal(session$returned$calculation_short(), "Mean price estimate")
      expect_equal(session$returned$calculation_label(), "Record-weighted mean")
      expect_identical(session$returned$fields$commodity(), "Maize")
      expect_identical(session$returned$fields$unit(), "bag")

      test_session$captured$messages <- list()
      session$setInputs(reset_filters = 1)
      expect_equal(session$returned$reset_event(), 1)
      reset_messages <- test_session$captured$messages
      expect_setequal(
        names(reset_messages),
        c("category", "commodity", "unit", "pricetype", "page1_date",
          "Currency", "calculation", "page1_county", "page1_market")
      )
      expect_identical(reset_messages$category$value, "Food")
      expect_identical(reset_messages$commodity$value, "Bread")
      expect_identical(reset_messages$unit$value, "90 KG")
      expect_identical(reset_messages$Currency$value, "price")
      expect_identical(
        reset_messages$calculation$value, "balanced_median"
      )
      expect_identical(reset_messages$page1_county$value, "All")
      expect_identical(reset_messages$page1_market$value, "All")

      date_range_html <- htmltools::renderTags(
        filters_module_ui("filters", fixture)
      )$html
      expect_match(
        date_range_html,
        "id=\"filters-page1_date\"",
        fixed = TRUE
      )
      expect_match(
        date_range_html, "data-min-date=\"2025-03-15\"", fixed = TRUE
      )
      expect_match(
        date_range_html, "data-max-date=\"2025-03-15\"", fixed = TRUE
      )
      expect_identical(fixture, fixture_before)
    }
  )
})

test_that("date selection requires two ordered, non-missing Dates", {
  fixture <- filter_module_fixture()

  shiny::testServer(
    filters_module_server,
    args = list(food_prices = fixture),
    {
      valid_inputs <- list(
        category = "Food",
        commodity = "Bread",
        unit = "kg",
        pricetype = "Retail",
        page1_county = "All",
        page1_market = "All"
      )
      do.call(session$setInputs, c(valid_inputs, list(
        page1_date = as.Date(c("2025-01-01", "2025-02-28"))
      )))
      expect_length(session$returned$selected_dates(), 2L)

      session$setInputs(page1_date = as.Date("2025-01-01"))
      expect_error(
        session$returned$selected_dates(), class = "shiny.silent.error"
      )
      session$setInputs(page1_date = NULL)
      expect_error(
        session$returned$selected_dates(), class = "shiny.silent.error"
      )
      session$setInputs(page1_date = as.Date(c(NA, "2025-02-01")))
      expect_error(
        session$returned$selected_dates(), class = "shiny.silent.error"
      )
      session$setInputs(page1_date = as.Date(c("2025-02-01", "2025-01-01")))
      expect_error(
        session$returned$selected_dates(), class = "shiny.silent.error"
      )
    }
  )
})

test_that("dependent choices update across category changes", {
  fixture <- filter_module_fixture()
  fixture[category == "Livestock", commodity := "Bread"]
  fixture[category == "Livestock", pricetype := "Retail"]
  test_session <- new_filter_test_session()

  shiny::testServer(
    filters_module_server,
    args = list(food_prices = fixture),
    session = test_session$session,
    {
      session$setInputs(
        category = "Food",
        commodity = "Bread",
        unit = "kg",
        pricetype = "Retail",
        Currency = "price",
        calculation = "balanced_median",
        page1_date = as.Date(c("2025-02-01", "2025-02-28")),
        page1_county = "All",
        page1_market = "All"
      )
      test_session$captured$messages <- list()

      session$setInputs(category = "Livestock")
      session$setInputs(unit = "litre")

      expect_identical(
        test_session$captured$messages$unit$value, "litre"
      )
      expect_identical(
        test_session$captured$messages$page1_date$value$start,
        "2025-02-01"
      )
      expect_identical(
        test_session$captured$messages$page1_date$value$end,
        "2025-02-15"
      )
    }
  )
})

test_that("two filter module instances keep selections isolated", {
  fixture <- filter_module_fixture()
  server <- function(input, output, session) {
    session$userData$filters <- list(
      left = filters_module_server("left", food_prices = fixture),
      right = filters_module_server("right", food_prices = fixture)
    )
  }

  shiny::testServer(
    server,
    {
      module_inputs <- list(
        "left-category" = "Food",
        "left-commodity" = "Bread",
        "left-unit" = "kg",
        "left-pricetype" = "Retail",
        "left-page1_date" = as.Date(c("2025-01-01", "2025-02-28")),
        "left-page1_county" = "Alpha",
        "left-page1_market" = "A market",
        "right-category" = "Food",
        "right-commodity" = "Bread",
        "right-unit" = "kg",
        "right-pricetype" = "Retail",
        "right-page1_date" = as.Date(c("2025-01-01", "2025-02-28")),
        "right-page1_county" = "Beta",
        "right-page1_market" = "B market"
      )
      do.call(session$setInputs, module_inputs)

      filters <- session$userData$filters
      expect_identical(filters$left$data()$county, "Alpha")
      expect_identical(filters$left$data()$market, "A market")
      expect_identical(filters$right$data()$county, "Beta")
      expect_identical(filters$right$data()$market, "B market")

      session$setInputs(
        `left-commodity` = "Maize",
        `left-unit` = "bag",
        `left-page1_county` = "Beta",
        `left-page1_market` = "All"
      )
      expect_identical(filters$left$selection()$commodity, "Maize")
      expect_identical(filters$left$data()$county, "Beta")
      expect_identical(filters$right$selection()$commodity, "Bread")
      expect_identical(filters$right$data()$county, "Beta")
      expect_identical(filters$right$data()$market, "B market")
    }
  )
})
