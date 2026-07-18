#' Climate dashboard UI
#'
#' @param id Module identifier.
#' @importFrom DT DTOutput
#' @importFrom ggiraph girafeOutput
#' @importFrom plotly plotlyOutput
#' @importFrom shiny NS column div fluidRow radioButtons selectInput tabPanel tabsetPanel tagList uiOutput
#' @noRd
climate_module_ui <- function(id) {
  ns <- shiny::NS(id)

  shiny::tagList(
    shiny::div(
      class = "kfp-climate-intro",
      shiny::tags$h3("Rainfall and vegetation conditions"),
      shiny::tags$p(
        paste(
          "Start with the national picture, then select or click a county for",
          "local trends and its relationship with the active commodity filters."
        )
      )
    ),
    shiny::div(
      class = "kfp-climate-controls",
      shiny::fluidRow(
        shiny::column(4, shiny::uiOutput(ns("month_ui"))),
        shiny::column(4, shiny::uiOutput(ns("county_ui"))),
        shiny::column(
          4,
          shiny::div(
            class = "kfp-toggle-control",
            shiny::radioButtons(
              ns("map_measure"),
              "Map values",
              choices = c(
                "Compared with normal" = "condition",
                "Actual levels" = "actual"
              ),
              selected = "condition",
              inline = TRUE
            )
          )
        )
      ),
      shiny::div(
        class = "kfp-context-note",
        "The commodity, unit, price type and currency filters above apply to the price analysis below; they do not change the climate maps."
      )
    ),
    shiny::uiOutput(ns("climate_summary")),
    shiny::fluidRow(
      shiny::column(
        6,
        plot_panel(
          "Rainfall conditions",
          shinycssloaders::withSpinner(
            ggiraph::girafeOutput(ns("rainfall_map"), height = "520px"),
            color = "#00a2ab"
          )
        )
      ),
      shiny::column(
        6,
        plot_panel(
          "Vegetation greenness",
          shinycssloaders::withSpinner(
            ggiraph::girafeOutput(ns("vegetation_map"), height = "520px"),
            color = "#00a2ab"
          )
        )
      )
    ),
    shiny::tabsetPanel(
      id = ns("climate_details"),
      shiny::tabPanel(
        "Trends",
        shiny::fluidRow(
          shiny::column(
            12,
            plot_panel(
              "Climate conditions and commodity price movement",
              shinycssloaders::withSpinner(
                plotly::plotlyOutput(ns("climate_price_trend"), height = "430px"),
                color = "#00a2ab"
              )
            )
          )
        )
      ),
      shiny::tabPanel(
        "Lag relationships",
        shiny::fluidRow(
          shiny::column(
            8,
            plot_panel(
              "Climate conditions versus later price changes",
              shinycssloaders::withSpinner(
                plotly::plotlyOutput(ns("lag_correlation_plot"), height = "410px"),
                color = "#00a2ab"
              )
            )
          ),
          shiny::column(4, plot_panel("How to read this", shiny::uiOutput(ns("lag_note"))))
        )
      ),
      shiny::tabPanel(
        "Data and methods",
        shiny::fluidRow(
          shiny::column(7, plot_panel("Recent monthly values", DT::DTOutput(ns("climate_table")))),
          shiny::column(5, plot_panel("Sources and processing", shiny::uiOutput(ns("method_note"))))
        )
      )
    )
  )
}

prepare_climate_geometry <- function(counties, county_lookup) {
  counties_copy <- data.table::copy(counties)
  counties_sf <- sf::st_as_sf(counties_copy, sf_column_name = "geometry")
  counties_sf <- sf::st_transform(counties_sf, 4326)
  counties_sf$county_key <- normalise_county_name(counties_sf$county)
  counties_sf$adm1_pcode <- county_lookup$adm1_pcode[
    match(counties_sf$county_key, county_lookup$county_key)
  ]

  if (anyNA(counties_sf$adm1_pcode)) {
    missing <- counties_sf$county[is.na(counties_sf$adm1_pcode)]
    stop("County geometry has unmatched names: ", paste(missing, collapse = ", "))
  }

  counties_sf
}

#' Climate dashboard server
#'
#' @param id Module identifier.
#' @param price_data Reactive returning filtered food-price records.
#' @param price_column Reactive returning the active price column name.
#' @param price_unit_label Reactive returning a display unit for prices.
#' @importFrom ggiraph renderGirafe
#' @importFrom plotly layout plot_ly renderPlotly
#' @importFrom shiny HTML moduleServer need observe observeEvent reactive renderUI req updateSelectInput validate
#' @noRd
climate_module_server <- function(
  id,
  price_data,
  price_column,
  price_unit_label,
  global_county = NULL,
  set_global_county = NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    climate <- app_climate()
    climate_monthly <- climate$county_monthly
    county_lookup <- climate$county_lookup
    county_geometry <- prepare_climate_geometry(app_counties(), county_lookup)

    available_dates <- sort(unique(climate_monthly$date))
    month_choices <- stats::setNames(
      as.character(available_dates),
      format(available_dates, "%b %Y")
    )
    county_choices <- c(
      "All Kenya" = "All",
      stats::setNames(county_lookup$adm1_pcode, county_lookup$county)
    )

    output$month_ui <- shiny::renderUI({
      shiny::selectInput(
        session$ns("month"),
        "Climate month",
        choices = month_choices,
        selected = as.character(max(available_dates))
      )
    })

    output$county_ui <- shiny::renderUI({
      shiny::selectInput(
        session$ns("county"),
        "Focus county",
        choices = county_choices,
        selected = "All"
      )
    })

    selected_date <- shiny::reactive({
      shiny::req(input$month)
      as.Date(input$month)
    })

    selected_county_name <- shiny::reactive({
      shiny::req(input$county)
      if (identical(input$county, "All")) {
        return("All Kenya")
      }
      county_lookup[adm1_pcode == input$county, county][1L]
    })

    map_values <- shiny::reactive({
      values <- climate_monthly[date == selected_date()]
      shiny::validate(shiny::need(nrow(values) == 47L, "Climate coverage is incomplete for this month."))

      map_sf <- county_geometry
      row_index <- match(map_sf$adm1_pcode, values$adm1_pcode)
      for (field in c("rainfall_mm", "rainfall_z", "ndvi", "ndvi_z")) {
        map_sf[[field]] <- values[[field]][row_index]
      }
      map_sf$rainfall_condition <- climate_condition(map_sf$rainfall_z)
      map_sf$ndvi_condition <- climate_condition(map_sf$ndvi_z)
      map_sf
    })

    render_climate_map <- function(type) {
      map_sf <- map_values()
      condition_view <- identical(input$map_measure, "condition")
      plot <- climate_map_plot(
        map_sf = map_sf,
        type = type,
        condition_view = condition_view,
        selected_date = selected_date(),
        climate_monthly = climate_monthly
      )
      selected <- if (identical(input$county, "All")) character() else input$county

      standard_girafe(
        plot,
        width_svg = 6.8,
        height_svg = 6.4,
        selectable = TRUE,
        selected = selected
      )
    }

    output$rainfall_map <- ggiraph::renderGirafe({
      shiny::req(input$map_measure)
      render_climate_map("rainfall")
    })

    output$vegetation_map <- ggiraph::renderGirafe({
      shiny::req(input$map_measure)
      render_climate_map("vegetation")
    })

    select_clicked_county <- function(selected) {
      if (length(selected) == 1L && selected %in% county_lookup$adm1_pcode) {
        shiny::updateSelectInput(session, "county", selected = selected)
        if (is.function(set_global_county)) {
          set_global_county(county_lookup[adm1_pcode == selected, county][1L])
        }
      }
    }

    if (is.function(global_county)) {
      shiny::observeEvent(global_county(), {
        county <- global_county()
        if (identical(county, "All")) {
          shiny::updateSelectInput(session, "county", selected = "All")
        } else {
          target <- county_lookup[county_key == normalise_county_name(county), adm1_pcode][1L]
          if (!is.na(target)) shiny::updateSelectInput(session, "county", selected = target)
        }
      }, ignoreInit = TRUE)
    }

    shiny::observeEvent(
      input$rainfall_map_selected,
      select_clicked_county(input$rainfall_map_selected),
      ignoreInit = TRUE
    )
    shiny::observeEvent(
      input$vegetation_map_selected,
      select_clicked_county(input$vegetation_map_selected),
      ignoreInit = TRUE
    )

    output$climate_summary <- shiny::renderUI({
      values <- climate_monthly[date == selected_date()]
      if (!identical(input$county, "All")) {
        values <- values[adm1_pcode == input$county]
      }
      shiny::req(nrow(values) > 0)

      rainfall_z <- mean_or_na(values$rainfall_z)
      ndvi_z <- mean_or_na(values$ndvi_z)

      shiny::div(
        class = "kfp-kpi-grid kfp-climate-kpis",
        kpi_card("Climate month", format(selected_date(), "%b %Y"), selected_county_name()),
        kpi_card("Rainfall", paste0(format_number(mean_or_na(values$rainfall_mm), 1), " mm"), "average per dekad"),
        kpi_card("Rainfall condition", format_number(rainfall_z, 2), climate_condition(rainfall_z)),
        kpi_card("Average NDVI", format_number(mean_or_na(values$ndvi), 3), "vegetation greenness"),
        kpi_card("Greenness condition", format_number(ndvi_z, 2), climate_condition(ndvi_z)),
        kpi_card(
          "Counties stressed",
          format_number(climate_monthly[date == selected_date() & (rainfall_z < -1 | ndvi_z < -1), uniqueN(adm1_pcode)]),
          "rainfall or NDVI below -1"
        )
      )
    })

    climate_series <- shiny::reactive({
      shiny::req(input$county)
      if (identical(input$county, "All")) {
        climate_monthly[
          ,
          .(
            rainfall_mm = mean_or_na(rainfall_mm),
            rainfall_z = mean_or_na(rainfall_z),
            ndvi = mean_or_na(ndvi),
            ndvi_z = mean_or_na(ndvi_z)
          ),
          by = date
        ][order(date)]
      } else {
        climate_monthly[adm1_pcode == input$county, .(date, rainfall_mm, rainfall_z, ndvi, ndvi_z)]
      }
    })

    price_series <- shiny::reactive({
      prices <- data.table::copy(price_data())
      shiny::validate(shiny::need(nrow(prices) > 0, "No price observations match the active filters."))
      price_field <- price_column()
      prices <- prices[is.finite(get(price_field)) & !is.na(county)]

      if (!identical(input$county, "All")) {
        target_key <- county_lookup[adm1_pcode == input$county, county_key]
        prices[, county_key := normalise_county_name(county)]
        prices <- prices[county_key == target_key]
      }
      shiny::validate(shiny::need(nrow(prices) > 1, "No county price observations match the active filters."))

      aggregation <- aggregate_price_data(prices, price_field, "balanced_median")
      monthly <- data.table::copy(aggregation$national_month)
      data.table::setnames(monthly, c("year_month_date", "estimate"), c("date", "median_price"))
      monthly <- complete_monthly_changes(monthly, date_column = "date", value_column = "median_price")
      monthly[, price_change := data.table::fifelse(
        consecutive_month & median_price > 0 & previous_estimate > 0,
        100 * (log(median_price) - log(previous_estimate)),
        NA_real_
      )]
      monthly
    })

    combined_series <- shiny::reactive({
      combined <- merge(climate_series(), price_series(), by = "date", all.x = TRUE)
      combined[, price_change_z := safe_zscore(price_change)]
      data.table::setorder(combined, date)
      combined
    })

    output$climate_price_trend <- plotly::renderPlotly({
      combined <- combined_series()
      long <- data.table::melt(
        combined,
        id.vars = "date",
        measure.vars = c("rainfall_z", "ndvi_z", "price_change_z"),
        variable.name = "series",
        value.name = "value",
        na.rm = TRUE
      )
      long[, series := factor(
        series,
        levels = c("rainfall_z", "ndvi_z", "price_change_z"),
        labels = c("Rainfall condition", "Vegetation condition", "Price change (standardised)")
      )]
      shiny::validate(shiny::need(nrow(long) > 12, "Not enough overlapping climate and price data."))

      plotly::plot_ly(
        long,
        x = ~date,
        y = ~value,
        color = ~series,
        colors = c("#2c7fb8", "#238443", "#c94a32"),
        type = "scatter",
        mode = "lines",
        text = ~paste0(
          series, "<br>", format(date, "%b %Y"),
          "<br>Standardised value: ", format_number(value, 2)
        ),
        hoverinfo = "text"
      ) %>%
        plotly::layout(
          xaxis = list(title = "Month"),
          yaxis = list(title = "Standardised value", zeroline = TRUE),
          legend = list(orientation = "h", x = 0, y = -0.2),
          margin = list(l = 65, r = 20, t = 20, b = 80)
        )
    })

    lag_results <- shiny::reactive({
      lagged_climate_correlations(combined_series(), max_lag = 6L)
    })

    output$lag_correlation_plot <- plotly::renderPlotly({
      correlations <- lag_results()[is.finite(correlation)]
      shiny::validate(shiny::need(nrow(correlations) > 0, "At least 12 overlapping months are required."))

      plotly::plot_ly(
        correlations,
        x = ~lag_months,
        y = ~correlation,
        color = ~driver,
        colors = c("#2c7fb8", "#238443"),
        type = "scatter",
        mode = "lines+markers",
        text = ~paste0(
          driver, " leads price by ", lag_months, " month(s)",
          "<br>Spearman correlation: ", format_number(correlation, 2),
          "<br>Overlapping months: ", observations
        ),
        hoverinfo = "text"
      ) %>%
        plotly::layout(
          xaxis = list(title = "Months climate leads price", dtick = 1),
          yaxis = list(title = "Spearman correlation", range = c(-1, 1), zeroline = TRUE),
          legend = list(orientation = "h", x = 0, y = -0.2),
          margin = list(l = 65, r = 20, t = 20, b = 80)
        )
    })

    output$lag_note <- shiny::renderUI({
      shiny::tagList(
        shiny::tags$p(
          "Each point compares climate conditions in one month with the commodity price change a number of months later."
        ),
        shiny::tags$p(
          "A positive value means higher rainfall or greenness tends to accompany a later price increase; a negative value means it tends to accompany a later decrease."
        ),
        shiny::tags$p(
          class = "kfp-context-note",
          "This is exploratory association, not a causal estimate. Trade, inflation, transport, storage and policy can also move food prices."
        )
      )
    })

    output$climate_table <- DT::renderDT({
      display <- combined_series()[order(-date)][1:min(.N, 18)]
      display <- display[
        ,
        .(
          Month = format(date, "%b %Y"),
          `Rainfall mm/dekad` = format_number(rainfall_mm, 1),
          `Rainfall condition` = format_number(rainfall_z, 2),
          NDVI = format_number(ndvi, 3),
          `Greenness condition` = format_number(ndvi_z, 2),
          `Median price` = format_number(median_price, 2),
          `Price change` = ifelse(is.finite(price_change), paste0(format_number(price_change, 1), "%"), "Not available")
        )
      ]
      datatable_compact(display, page_length = 9)
    })

    output$method_note <- shiny::renderUI({
      metadata <- climate$metadata
      shiny::tagList(
        shiny::tags$p(shiny::tags$strong("Source: "), metadata$source_label),
        shiny::tags$p(shiny::tags$strong("Rainfall: "), metadata$rainfall_source),
        shiny::tags$p(shiny::tags$strong("Vegetation: "), metadata$vegetation_source),
        shiny::tags$p(shiny::tags$strong("Geography: "), metadata$boundary_standard),
        shiny::tags$p(shiny::tags$strong("County processing: "), metadata$aggregation),
        shiny::tags$p(
          shiny::tags$strong("Coverage: "),
          format(metadata$data_start, "%b %Y"), " to ", format(metadata$data_end, "%b %Y")
        ),
        shiny::tags$p(
          shiny::tags$a(
            "View the World Bank JMR source and methodology",
            href = metadata$study_url,
            target = "_blank",
            rel = "noopener noreferrer"
          )
        ),
        shiny::tags$p(
          class = "kfp-context-note",
          "NDVI measures all vegetation in an administrative area, including crops, grassland and forest. It is a proxy for crop conditions, not a direct yield measure."
        )
      )
    })
  })
}
