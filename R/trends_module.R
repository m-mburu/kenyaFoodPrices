# Trends, period selection and comparisons of recorded prices.

#' Build the Trends tab and its period selection controls
#'
#' @param id Namespace shared with the Trends server.
#' @return A Shiny UI fragment containing the main series and supporting plots
#'   and tables.
#' @noRd
trends_module_ui <- function(id) {
  ns <- shiny::NS(id)

  fluidPage(
    class = "kfp-trends",
    div(
      class = "kfp-trends-intro",
      h3("Price trends"),
      uiOutput(ns("trends_context"))
    ),
    uiOutput(ns("trends_kpis")),
    div(
      class = "kfp-trends-primary",
      h4("Price over time"),
      div(
        class = "kfp-trends-controls",
        div(
          class = "kfp-toggle-control",
          radioButtons(
            ns("trend_frequency"),
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
            ns("trend_display"),
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
          ggiraph::girafeOutput(ns("linePlot"), height = "100%"),
          "trend"
        ),
        color = "#00a2ab"
      ),
      uiOutput(ns("trend_scope_note")),
      div(
        class = "kfp-trend-explore",
        div(
          class = "kfp-trend-explore-actions",
          shiny::actionButton(
            ns("trend_selection_open"),
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
            id = ns("trend_selection_panel"),
            `data-kfp-escape-input` = ns("trend_selection_escape"),
            class = "kfp-trend-selection",
            tabindex = "-1",
            div(
              class = "kfp-trend-selection-header",
              h4("Selected period"),
              shiny::actionButton(
                ns("trend_selection_clear"),
                "Clear selection",
                class = "kfp-reset-button"
              )
            ),
            uiOutput(ns("trend_period_summary")),
            div(
              class = "kfp-trend-selection-grid",
              div(
                class = "kfp-trend-selection-field",
                shiny::selectInput(
                  ns("trend_reference_period"),
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
                  ns("trend_compare_toggle"),
                  "Compare with another period",
                  class = "kfp-reset-button"
                )
              )
            ),
            shinyjs::hidden(
              div(
                id = ns("trend_compare_panel"),
                class = "kfp-trend-compare-panel",
                div(
                  class = "kfp-trend-selection-grid",
                  div(
                    class = "kfp-trend-selection-field",
                    shiny::selectInput(
                      ns("trend_compare_period"),
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
                      ns("trend_compare_close"),
                      "Hide comparison",
                      class = "kfp-reset-button"
                    )
                  )
                ),
                uiOutput(ns("trend_compare_summary"))
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
      uiOutput(ns("trend_table_note")),
      div(
        class = "kfp-trends-table",
        shinycssloaders::withSpinner(
          DT::DTOutput(ns("trend_change_table")),
          color = "#00a2ab"
        )
      )
    ),
    tags$details(
      id = "kfp-trend-seasonality",
      class = "kfp-trends-details",
      `data-kfp-remember` = "true",
      tags$summary("Seasonal pattern"),
      uiOutput(ns("seasonality_note")),
      shinycssloaders::withSpinner(
        visualization_frame(
          ggiraph::girafeOutput(
            ns("price_month_means"), height = "100%"
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
      uiOutput(ns("annual_note")),
      shinycssloaders::withSpinner(
        visualization_frame(
          ggiraph::girafeOutput(
            ns("main_price_histogram"), height = "100%"
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
      uiOutput(ns("geography_panel_ui"))
    )
  )
}

#' Render price trends and keep period selections local to the session
#'
#' @param id Namespace shared with the Trends UI.
#' @param price_records Reactive returning geographically filtered price
#'   records.
#' @param base_price_records Reactive returning records before geography
#'   filters, for location benchmarks.
#' @param monthly_summary Reactive returning national monthly estimates and
#'   coverage.
#' @param price_column Reactive returning the price column name.
#' @param price_unit_label Reactive returning currency and physical
#'   denominator.
#' @param unit_denominator Reactive returning a parenthesised price-unit label.
#' @param calculation Reactive returning the estimator key.
#' @param selected_commodity Reactive returning the commodity name.
#' @param selected_price_type Reactive returning the retail or wholesale price
#'   type.
#' @param selected_unit Reactive returning the physical unit.
#' @param selected_county Reactive returning the county restriction.
#' @param selected_market Reactive returning the market restriction.
#' @param reset_event Reactive that changes when the main filters are reset.
#' @return Registers Trends outputs and event handlers for chart selection,
#'   comparison, focus and reset.
#' @noRd
trends_module_server <- function(
  id,
  price_records,
  base_price_records,
  monthly_summary,
  price_column,
  price_unit_label,
  unit_denominator,
  calculation,
  selected_commodity,
  selected_price_type,
  selected_unit,
  selected_county,
  selected_market,
  reset_event
) {
  shiny::moduleServer(id, function(input, output, session) {
    trend_summary <- reactive({
      monthly <- monthly_summary()
      req(nrow(monthly) > 0, input$trend_frequency)

      prepare_trend_series(
        monthly = monthly,
        frequency = input$trend_frequency,
        display = input$trend_display
      )
    })

    trend_panel_open <- shiny::reactiveVal(FALSE)
    trend_compare_open <- shiny::reactiveVal(FALSE)
    trend_reference_id <- shiny::reactiveVal("")
    trend_compare_id <- shiny::reactiveVal("")

    # The browser focus handler needs the namespaced control ID.
    focus_trend_control <- function(control_id) {
      session$sendCustomMessage(
        "kfp-focus", list(id = session$ns(control_id))
      )
    }

    trend_observed_periods <- reactive({
      trend <- data.table::copy(trend_summary())
      trend <- trend[is.finite(price_estimate)]
      if (!nrow(trend)) {
        return(trend)
      }

      trend[, period_id := as.character(period)]
      trend[]
    })

    # The available periods can change with the frequency or filters.
    valid_trend_period <- function(period_id, trend) {
      nzchar(period_id) && nrow(trend) && period_id %in% trend$period_id
    }

    # Clear both the reactive comparison and the browser's selector.
    clear_trend_comparison <- function() {
      trend_compare_id("")
      trend_compare_open(FALSE)
      shiny::updateSelectInput(
        session,
        "trend_compare_period",
        selected = ""
      )
    }

    # Escape and Clear return focus to the button that opens period selection.
    clear_trend_selection <- function(return_focus = FALSE) {
      trend_reference_id("")
      trend_panel_open(FALSE)
      clear_trend_comparison()
      shiny::updateSelectInput(
        session,
        "trend_reference_period",
        selected = ""
      )
      if (isTRUE(return_focus)) {
        focus_trend_control("trend_selection_open")
      }
    }

    observe({
      if (isTRUE(trend_panel_open())) {
        shinyjs::show("trend_selection_panel")
      } else {
        shinyjs::hide("trend_selection_panel")
      }

      if (isTRUE(trend_panel_open()) && isTRUE(trend_compare_open())) {
        shinyjs::show("trend_compare_panel")
        shinyjs::hide("trend_compare_toggle")
      } else {
        shinyjs::hide("trend_compare_panel")
        shinyjs::show("trend_compare_toggle")
      }

      shinyjs::toggleState(
        "trend_compare_toggle",
        condition = nzchar(trend_reference_id())
      )
    })

    observeEvent(trend_observed_periods(), {
      trend <- trend_observed_periods()
      quarterly <- identical(input$trend_frequency, "quarter")
      choices <- c(
        "Choose a period" = "",
        trend_period_choices(trend, quarterly)
      )

      reference_id <- trend_reference_id()
      if (!valid_trend_period(reference_id, trend)) {
        reference_id <- ""
        trend_reference_id("")
        clear_trend_comparison()
      }

      compare_id <- trend_compare_id()
      if (!valid_trend_period(compare_id, trend) ||
          identical(compare_id, reference_id)) {
        compare_id <- ""
        trend_compare_id("")
      }

      shiny::updateSelectInput(
        session,
        "trend_reference_period",
        choices = choices,
        selected = reference_id
      )
      shiny::updateSelectInput(
        session,
        "trend_compare_period",
        choices = choices,
        selected = compare_id
      )

      if (!nrow(trend)) {
        clear_trend_selection()
      }
    }, ignoreNULL = FALSE)

    trend_reference_row <- reactive({
      trend <- trend_observed_periods()
      reference_id <- trend_reference_id()
      if (!valid_trend_period(reference_id, trend)) {
        return(trend[0])
      }
      trend[period_id == reference_id]
    })

    trend_compare_row <- reactive({
      trend <- trend_observed_periods()
      compare_id <- trend_compare_id()
      if (!valid_trend_period(compare_id, trend)) {
        return(trend[0])
      }
      trend[period_id == compare_id]
    })

    output$trend_period_summary <- renderUI({
      reference_row <- trend_reference_row()
      quarterly <- identical(input$trend_frequency, "quarter")

      if (!nrow(reference_row)) {
        return(tags$p(
          class = "kfp-trends-note kfp-trend-selection-empty",
          "Choose a month or quarter from the chart, or use the",
          "Reference period selector below."
        ))
      }

      period_label <- trend_period_label(
        reference_row$period,
        quarterly,
        reference_row$covered_months
      )
      smooth_value <- if (
        identical(input$trend_display, "smooth") &&
          is.finite(reference_row$display_price)
      ) {
        paste(format_number(reference_row$display_price, 2), price_unit_label())
      } else if (identical(input$trend_display, "smooth")) {
        "Not available"
      } else {
        "Not shown"
      }

      div(
        class = "kfp-trend-selection-summary",
        div(
          class = "kfp-trend-selection-card",
          tags$span("Period"),
          tags$strong(period_label)
        ),
        div(
          class = "kfp-trend-selection-card",
          tags$span("Selected estimate"),
          tags$strong(paste(
            format_number(reference_row$price_estimate, 2),
            price_unit_label()
          )),
          tags$small(price_calculation_label(
            calculation() %||% "balanced_median"
          ))
        ),
        div(
          class = "kfp-trend-selection-card",
          tags$span("Trailing average"),
          tags$strong(smooth_value),
          tags$small("Shown only in trailing-average mode")
        ),
        div(
          class = "kfp-trend-selection-card",
          tags$span("Coverage"),
          tags$strong(paste(
            format_number(reference_row$observations), "records"
          )),
          tags$small(paste(
            format_number(reference_row$markets), "markets |",
            format_number(reference_row$counties), "counties"
          ))
        )
      )
    })

    output$trend_compare_summary <- renderUI({
      reference_row <- trend_reference_row()
      compare_row <- trend_compare_row()
      quarterly <- identical(input$trend_frequency, "quarter")

      if (!isTRUE(trend_compare_open()) || !nrow(reference_row) ||
          !nrow(compare_row)) {
        return(NULL)
      }

      difference <- compare_row$price_estimate - reference_row$price_estimate
      percent_change <- trend_percent_change(
        reference_row$price_estimate,
        compare_row$price_estimate
      )

      div(
        class = "kfp-trend-compare-result",
        if (identical(input$trend_display, "smooth")) {
          tags$p(
            class = "kfp-trends-note",
            "Comparison uses the selected period estimate, not the",
            "trailing average line."
          )
        },
        div(
          class = "kfp-trend-selection-card",
          tags$span("Reference period"),
          tags$strong(trend_period_label(
            reference_row$period,
            quarterly,
            reference_row$covered_months
          ))
        ),
        div(
          class = "kfp-trend-selection-card",
          tags$span("Comparison period"),
          tags$strong(trend_period_label(
            compare_row$period,
            quarterly,
            compare_row$covered_months
          ))
        ),
        div(
          class = "kfp-trend-selection-card",
          tags$span("Difference"),
          tags$strong(format_change(difference, price_unit_label()))
        ),
        div(
          class = "kfp-trend-selection-card",
          tags$span("Percentage difference"),
          tags$strong(if (is.finite(percent_change)) {
            format_percent(percent_change)
          } else {
            "Not available"
          }),
          tags$small("Comparison minus reference")
        )
      )
    })

    observeEvent(input$trend_selection_open, {
      trend_panel_open(TRUE)
      focus_trend_control("trend_reference_period")
    }, ignoreInit = TRUE)

    observeEvent(input$trend_reference_period, {
      trend <- trend_observed_periods()
      reference_id <- input$trend_reference_period %||% ""

      trend_reference_id(reference_id)
      trend_panel_open(TRUE)

      if (!valid_trend_period(reference_id, trend)) {
        clear_trend_comparison()
        return()
      }

      if (identical(trend_compare_id(), reference_id)) {
        clear_trend_comparison()
      }
    }, ignoreInit = TRUE)

    observeEvent(input$trend_compare_toggle, {
      if (!nzchar(trend_reference_id())) {
        return()
      }

      trend_compare_open(TRUE)
      focus_trend_control("trend_compare_period")
    }, ignoreInit = TRUE)

    observeEvent(input$trend_compare_period, {
      trend <- trend_observed_periods()
      compare_id <- input$trend_compare_period %||% ""
      if (!valid_trend_period(compare_id, trend) ||
          identical(compare_id, trend_reference_id())) {
        trend_compare_id("")
        return()
      }

      trend_compare_id(compare_id)
    }, ignoreInit = TRUE)

    observeEvent(input$trend_compare_close, {
      clear_trend_comparison()
    }, ignoreInit = TRUE)

    observeEvent(input$trend_selection_clear, {
      clear_trend_selection(return_focus = TRUE)
    }, ignoreInit = TRUE)

    observeEvent(input$trend_selection_escape, {
      clear_trend_selection(return_focus = TRUE)
    }, ignoreInit = TRUE)

    observeEvent(input$linePlot_selected, {
      trend <- trend_observed_periods()
      selected_id <- input$linePlot_selected[1]

      if (length(selected_id) == 0L ||
          !valid_trend_period(selected_id, trend) ||
          identical(selected_id, trend_reference_id())) {
        return()
      }

      trend_reference_id(selected_id)
      trend_panel_open(TRUE)
      shiny::updateSelectInput(
        session,
        "trend_reference_period",
        selected = selected_id
      )

      if (identical(trend_compare_id(), selected_id)) {
        clear_trend_comparison()
      }
    }, ignoreInit = TRUE)

    observeEvent(reset_event(), {
      clear_trend_selection()
    }, ignoreInit = TRUE)

    output$trends_context <- renderUI({
      dt <- price_records()
      req(nrow(dt) > 0, selected_county(), selected_market())

      last_date <- max(dt$date, na.rm = TRUE)
      location <- if (!identical(selected_county(), "All")) {
        paste0(selected_county(), " county")
      } else {
        "Available markets in Kenya"
      }

      if (!identical(selected_market(), "All")) {
        location <- paste(location, "-", selected_market())
      }

      estimator <- price_calculation_label(
        calculation() %||% "balanced_median"
      )

      shiny::tags$div(
        class = "kfp-trends-context",
        shiny::tags$strong(
          paste(
            selected_commodity(),
            selected_price_type(),
            selected_unit(),
            sep = " | "
          )
        ),
        shiny::tags$span(paste(" | Selected estimator:", estimator)),
        shiny::tags$span(paste(" | ", location, " | As of", format(last_date, "%b %Y"))),
        shiny::tags$span(paste(" | ", format_number(nrow(dt)), "records"))
      )
    })

    output$trends_kpis <- renderUI({
      monthly <- data.table::copy(monthly_summary())
      monthly <- monthly[is.finite(price_estimate)]
      req(nrow(monthly) > 0)

      latest <- monthly[.N]
      previous_date <- as.Date(sprintf(
        "%s-%s-01",
        as.integer(format(latest$year_month_date, "%Y")) - 1L,
        format(latest$year_month_date, "%m")
      ))
      previous <- monthly[year_month_date == previous_date]
      yoy_pct <- if (nrow(previous) && previous$price_estimate != 0) {
        (latest$price_estimate - previous$price_estimate) / previous$price_estimate
      } else {
        NA_real_
      }

      div(
        class = "kfp-trends-summary",
        div(
          class = "kfp-trends-summary-item",
          tags$span("Latest monthly estimate"),
          tags$strong(paste(
            format_number(latest$price_estimate, 2), price_unit_label()
          )),
          tags$small(paste(
            format(latest$year_month_date, "%b %Y"), " | ",
            format_number(latest$observations), " records | ",
            format_number(latest$markets), " markets | ",
            format_number(latest$counties), " counties"
          ))
        ),
        div(
          class = "kfp-trends-summary-item",
          tags$span("Same month last year"),
          tags$strong(format_price_comparison(yoy_pct)),
          tags$small(if (nrow(previous)) {
            paste("vs", format(previous_date, "%b %Y"))
          } else {
            "No matching month available"
          })
        )
      )
    })

    output$trend_scope_note <- renderUI({
      method <- price_calculation_label(
        calculation() %||% "balanced_median"
      )
      period <- if (identical(input$trend_frequency, "quarter")) {
        "Quarterly points average the available monthly estimates;"
      } else {
        "Each point is a monthly estimate;"
      }
      smooth <- if (identical(input$trend_display, "smooth")) {
        " The bold line is a trailing average of three consecutive points."
      } else {
        ""
      }
      tags$p(
        class = "kfp-trends-note",
        paste0(period, " method: ", method, ".", smooth),
        "Missing months remain gaps. Prices are nominal."
      )
    })

    output$trend_table_note <- renderUI({
      tags$p(
        class = "kfp-trends-note",
        if (identical(input$trend_frequency, "quarter")) {
          "Quarterly values average available monthly estimates using "
        } else {
          "Monthly values use "
        },
        price_calculation_label(
          calculation() %||% "balanced_median"
        ),
        " (", price_unit_label(), "). Change requires consecutive",
        " periods; gaps and missing comparisons are shown as blank."
      )
    })

    output$annual_note <- renderUI({
      price_val <- price_column()
      dt <- price_records()[is.finite(get(price_val))]
      req(nrow(dt) > 0)
      monthly <- dt[
        , .(mean_price = mean(get(price_val))),
        by = .(month = as.Date(format(date, "%Y-%m-01")))
      ]
      spread <- if (nrow(monthly) > 1L) {
        format_number(stats::sd(monthly$mean_price), 2)
      } else {
        "Unavailable"
      }
      tags$p(
        class = "kfp-trends-note",
        "Dots show each year's mean recorded price; bars span the lowest",
        " to highest record. This view uses raw records, not the selected",
        " monthly estimator. Incomplete years and changing market coverage",
        " limit comparisons. Spread of monthly raw-record means: ",
        spread, " ", price_unit_label(), "."
      )
    })

    output$seasonality_note <- renderUI({
      dt <- price_records()
      req(nrow(dt) > 0)
      years <- as.integer(format(dt$date, "%Y"))
      tags$p(
        class = "kfp-trends-note",
        "Index 100 is each year's mean of its available monthly raw-record",
        " means; 110 means 10% above that yearly mean. The shaded band",
        " spans the middle half of observed yearly values. Partial years",
        " are included. This view does not use the monthly estimator.",
        " Contributing years: ", min(years), " to ", max(years), "."
      )
    })

    output$linePlot <- ggiraph::renderGirafe({
      trend <- data.table::copy(trend_summary())
      shiny::validate(shiny::need(
        sum(is.finite(trend$price_estimate)) > 1,
        "There is not enough data for a trend."
      ))

      method <- price_calculation_short_label(
        calculation() %||% "balanced_median"
      )
      quarterly <- identical(input$trend_frequency, "quarter")
      smoothed <- identical(input$trend_display, "smooth")
      trend[, segment := cumsum(!is.finite(price_estimate))]
      trend[, smooth_segment := cumsum(!is.finite(display_price))]
      trend[, period_id := as.character(period)]
      trend[, display_y := data.table::fifelse(
        is.finite(display_price), display_price, price_estimate
      )]
      trend[, hover_text := paste0(
        format(period, if (quarterly) "%Y-%m" else "%b %Y"),
        if (quarterly) paste0(
          " (quarter; ", covered_months, " observed months)"
        ) else "",
        "<br>", method, ": ", format_number(price_estimate, 2),
        " ", price_unit_label(),
        if (smoothed) paste0(
          "<br>Trailing 3-period average: ",
          format_number(display_price, 2), " ", price_unit_label()
        ) else "",
        "<br>Records: ", format_number(observations),
        "<br>Markets: ", format_number(markets),
        "<br>Counties: ", format_number(counties)
      )]

      gg <- ggplot2::ggplot(trend, ggplot2::aes(x = period))
      if (smoothed) {
        gg <- gg +
          ggplot2::geom_line(
            ggplot2::aes(y = price_estimate, group = segment),
            colour = "#9bb5b5", linewidth = 0.7, na.rm = TRUE
          ) +
          ggiraph::geom_line_interactive(
            ggplot2::aes(
              y = display_price, group = smooth_segment,
              tooltip = hover_text
            ),
            colour = "#008e96", linewidth = 1.4, na.rm = TRUE
          )
      } else {
        gg <- gg + ggiraph::geom_line_interactive(
          ggplot2::aes(
            y = price_estimate, group = segment, tooltip = hover_text
          ),
          colour = "#008e96", linewidth = 1.4, na.rm = TRUE
        )
      }
      selection_points <- trend[is.finite(price_estimate)]
      gg <- gg + ggiraph::geom_point_interactive(
        data = selection_points,
        ggplot2::aes(
          y = display_y, tooltip = hover_text, data_id = period_id
        ),
        shape = 21,
        fill = "#008e96",
        colour = "#008e96",
        alpha = 0.01,
        size = 5,
        stroke = 0.2
      )
      points <- trend[is.finite(display_price)][
        , .SD[c(1L, .N)], by = segment
      ]
      points <- unique(points, by = "period")
      gg <- gg + ggiraph::geom_point_interactive(
        data = points,
        ggplot2::aes(
          y = display_price, tooltip = hover_text, data_id = period_id
        ),
        colour = "#008e96", size = 2.5
      ) +
        ggplot2::labs(
          x = if (quarterly) "Quarter" else "Month",
          y = paste(method, unit_denominator())
        ) +
        ggplot2::scale_x_date(
          date_labels = "%Y",
          date_breaks = if (nrow(trend) > 120) "2 years" else "1 year"
        ) +
        ggplot2::theme_minimal(base_size = 12) +
        ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

      selected_id <- trend_reference_id()
      if (!selected_id %in% selection_points$period_id) {
        selected_id <- character()
      }

      standard_girafe(
        gg,
        width_svg = 14,
        height_svg = 4.4,
        selectable = TRUE,
        selected = selected_id
      )
    })

    output$trend_change_table <- DT::renderDT({
      trend <- data.table::copy(trend_summary())
      shiny::validate(shiny::need(
        nrow(trend) > 0, "No period values are available."
      ))
      trend[, previous := data.table::shift(price_estimate)]
      trend[, change := price_estimate - previous]
      trend[, percent_change := data.table::fifelse(
        is.finite(previous) & previous != 0,
        100 * change / previous, NA_real_
      )]
      quarterly <- identical(input$trend_frequency, "quarter")
      trend[, label := if (quarterly) {
        paste0(
          "Q", (as.integer(format(period, "%m")) - 1L) %/% 3L + 1L,
          " ", format(period, "%Y")
        )
      } else {
        format(period, "%b %Y")
      }]
      display <- trend[order(-period)][
        ,
        .(
          Period = label,
          Estimate = price_estimate,
          Change = change,
          `% change` = percent_change,
          `Trailing average` = if (
            identical(input$trend_display, "smooth")
          ) display_price else NULL,
          Records = observations,
          Markets = markets,
          Counties = counties,
          `Covered months` = covered_months
        )
      ]
      widget <- datatable_compact(
        display, page_length = 12, scroll_x = TRUE
      )
      number_columns <- intersect(
        c("Estimate", "Change", "% change", "Trailing average"),
        names(display)
      )
      DT::formatRound(widget, columns = number_columns, digits = 1)
    })

    recorded_prices <- reactive({
      price_val <- price_column()
      price_records()[is.finite(get(price_val))]
    })

    output$main_price_histogram <- ggiraph::renderGirafe({
      records <- recorded_prices()
      shiny::validate(shiny::need(
        nrow(records) > 2,
        "There is not enough data for an annual price trend."
      ))

      annual <- summarise_annual_recorded_prices(records, price_column())
      annual[, year_date := as.Date(sprintf("%s-01-01", calendar_year))]
      annual[, year_id := as.character(calendar_year)]
      annual[, hover_text := paste0(
        "Year: ", calendar_year,
        "<br>Mean recorded price: ", format_number(mean_price, 2),
        " ", price_unit_label(),
        "<br>Range: ", format_number(min_price, 2), " - ",
        format_number(max_price, 2),
        "<br>Records: ", format_number(observations),
        "<br>Covered months: ", covered_months, " of 12",
        ifelse(covered_months < 12, " (partial)", ""),
        "<br>Markets: ", markets,
        "<br>Counties: ", counties
      )]

      gg <- ggplot2::ggplot(annual, ggplot2::aes(x = year_date, y = mean_price)) +
        ggplot2::geom_linerange(
          ggplot2::aes(ymin = min_price, ymax = max_price),
          colour = "#b9dfe1",
          linewidth = 1.1
        ) +
        ggiraph::geom_point_interactive(
          ggplot2::aes(tooltip = hover_text, data_id = year_id),
          colour = "#00a2ab",
          size = 2
        ) +
        ggplot2::labs(
          title = NULL,
          x = "Year",
          y = paste("Mean recorded price", unit_denominator())
        ) +
        ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
        ggplot2::theme_minimal(base_size = 12) +
        ggplot2::theme(
          plot.title = ggplot2::element_text(face = "bold"),
          panel.grid.minor = ggplot2::element_blank()
        )

      standard_girafe(gg, width_svg = 11.5, height_svg = 4.1)
    })

    output$price_month_means <- ggiraph::renderGirafe({
      records <- recorded_prices()
      shiny::validate(shiny::need(
        nrow(records) > 2, "There is not enough data for seasonality."
      ))

      season <- summarise_price_seasonality(records, price_column())
      season[, month_label := month.abb[month_num]]
      season[, month_id := as.character(month_num)]
      season[, hover_text := paste0(
        month_label,
        "<br>Index: ", format_number(season_index, 1),
        "<br>Middle 50%: ", format_number(lower, 1), " - ", format_number(upper, 1),
        "<br>Years: ", years,
        "<br>Records: ", format_number(observations)
      )]

      gg <- ggplot2::ggplot(
        season,
        ggplot2::aes(x = month_num, y = season_index, group = 1)
      ) +
        ggplot2::geom_ribbon(
          ggplot2::aes(ymin = lower, ymax = upper),
          fill = "#00a2ab",
          alpha = 0.16
        ) +
        ggiraph::geom_line_interactive(
          ggplot2::aes(tooltip = hover_text, data_id = month_id, group = 1),
          colour = "#00a2ab",
          linewidth = 1.3
        ) +
        ggiraph::geom_point_interactive(
          ggplot2::aes(tooltip = hover_text, data_id = month_id),
          colour = "#00a2ab",
          size = 2.2
        ) +
        ggplot2::geom_hline(yintercept = 100, linetype = "dashed", colour = "#7b8c8c") +
        ggplot2::scale_x_continuous(breaks = 1:12, labels = month.abb) +
        ggplot2::labs(
          title = NULL,
          x = "Month",
          y = "Index"
        ) +
        ggplot2::theme_minimal(base_size = 12) +
        ggplot2::theme(
          plot.title = ggplot2::element_text(face = "bold"),
          panel.grid.minor = ggplot2::element_blank()
        )

      standard_girafe(gg, width_svg = 11.5, height_svg = 4.1)
    })

    geography_summary <- reactive({
      price_val <- price_column()
      dt <- price_records()[
        is.finite(get(price_val)) & !is.na(county) & !is.na(market)
      ]
      req(nrow(dt) > 0)

      if (!identical(selected_market(), "All")) {
        benchmark <- base_price_records()[
          is.finite(get(price_val)) & !is.na(county) & !is.na(market)
        ]
        if (!identical(selected_county(), "All")) {
          benchmark <- benchmark[county == selected_county()]
        }
        scope <- if (identical(selected_county(), "All")) {
          "All available markets"
        } else {
          paste("All available markets in", selected_county())
        }
        comparison <- data.table::rbindlist(list(
          data.table::data.table(
            location = selected_market(),
            mean_price = mean(dt[[price_val]]),
            records = nrow(dt),
            covered_months = data.table::uniqueN(
              format(dt$date, "%Y-%m")
            ),
            latest_month = max(as.Date(format(dt$date, "%Y-%m-01")))
          ),
          data.table::data.table(
            location = scope,
            mean_price = mean(benchmark[[price_val]]),
            records = nrow(benchmark),
            covered_months = data.table::uniqueN(
              format(benchmark$date, "%Y-%m")
            ),
            latest_month = max(as.Date(
              format(benchmark$date, "%Y-%m-01")
            ))
          )
        ))
      } else {
        grouping <- if (!identical(selected_county(), "All") ||
          data.table::uniqueN(dt$county) == 1L) {
          "market"
        } else {
          "county"
        }
        comparison <- dt[
          ,
          .(
            mean_price = mean(get(price_val)),
            records = .N,
            covered_months = data.table::uniqueN(
              format(date, "%Y-%m")
            ),
            latest_month = max(as.Date(format(date, "%Y-%m-01")))
          ),
          by = .(location = get(grouping))
        ]
      }
      comparison[order(-mean_price)]
    })

    output$geography_panel_ui <- renderUI({
      comparison <- geography_summary()
      if (nrow(comparison) < 2L) {
        return(tags$p(
          class = "kfp-trends-note",
          "Only one location has prices for this selection."
        ))
      }
      tags$div(
        tags$p(
          class = "kfp-trends-note",
          "Mean of raw price records in the selected period (",
          price_unit_label(), "). Locations can have different months and",
          " numbers of records. The chart shows up to 12 locations;",
          " search the table for all locations."
        ),
        shinycssloaders::withSpinner(
          visualization_frame(
            ggiraph::girafeOutput(
              session$ns("geography_bar_plot"), height = "100%"
            ),
            "trend-detail"
          ),
          color = "#00a2ab"
        ),
        DT::DTOutput(session$ns("geography_table"))
      )
    })

    output$geography_table <- DT::renderDT({
      comparison <- geography_summary()
      display <- comparison[
        ,
        .(
          Location = location,
          `Mean recorded price` = mean_price,
          Records = records,
          `Covered months` = covered_months,
          `Latest month` = format(latest_month, "%b %Y")
        )
      ]
      DT::formatRound(
        datatable_compact(display, page_length = 12),
        columns = "Mean recorded price", digits = 2
      )
    })

    output$geography_bar_plot <- ggiraph::renderGirafe({
      comparison <- data.table::copy(geography_summary())
      shiny::validate(shiny::need(
        nrow(comparison) > 1, "No location comparison is available."
      ))
      comparison <- comparison[seq_len(min(nrow(comparison), 12L))]
      comparison[, location_id := make.unique(as.character(location))]
      comparison[, hover_text := paste0(
        location,
        "<br>Mean recorded price: ",
        format_number(mean_price, 2), " ", price_unit_label(),
        "<br>Records: ", format_number(records),
        "<br>Covered months: ", covered_months,
        "<br>Latest month: ", format(latest_month, "%b %Y")
      )]

      gg <- ggplot2::ggplot(
        comparison,
        ggplot2::aes(x = mean_price, y = reorder(location, mean_price))
      ) +
        ggiraph::geom_col_interactive(
          ggplot2::aes(tooltip = hover_text, data_id = location_id),
          fill = "#008e96", width = 0.68
        ) +
        ggplot2::labs(
          x = paste("Mean recorded price", unit_denominator()),
          y = NULL
        ) +
        ggplot2::theme_minimal(base_size = 12) +
        ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

      standard_girafe(gg, width_svg = 12, height_svg = 4.4)
    })
  })
}
