# Monthly price estimates and historical location rankings.

#' Build the Overview tab
#'
#' @param id Namespace shared with the Overview server.
#' @return A Shiny UI fragment with the latest estimates, monthly chart and
#'   location rankings.
#' @noRd
overview_module_ui <- function(id) {
  ns <- shiny::NS(id)

  fluidPage(
    class = "kfp-overview",
    uiOutput(ns("summary_kpis")),
    div(
      class = "kfp-overview-trend",
      div(
        class = "kfp-overview-section-heading",
        h3("Monthly price trend"),
        shiny::actionLink(ns("overview_to_trends"), "Explore trends")
      ),
      shinycssloaders::withSpinner(
        visualization_frame(
          ggiraph::girafeOutput(
            ns("overview_trend"),
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
          DT::DTOutput(ns("recent_change_table")),
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
          DT::DTOutput(ns("top_county_table")),
          color = "#00a2ab"
        )
      ),
      h4("Market estimates"),
      div(
        class = "kfp-overview-table",
        shinycssloaders::withSpinner(
          DT::DTOutput(ns("top_market_table")),
          color = "#00a2ab"
        )
      )
    )
  )
}

#' Render the main price summary and historical location rankings
#'
#' @param id Namespace shared with the Overview UI.
#' @param price_records Reactive returning geographically filtered observation
#'   records.
#' @param monthly_summary Reactive returning national monthly estimates and
#'   changes.
#' @param market_month Reactive returning market-month estimates and counts.
#' @param county_month Reactive returning county-month estimates and counts.
#' @param calculation Reactive returning the selected estimator key.
#' @param calculation_label Reactive returning the full estimator label.
#' @param calculation_short Reactive returning the short estimator label.
#' @param selected_unit Reactive returning the physical unit selection.
#' @param unit_denominator Reactive returning the parenthesised price unit.
#' @param price_unit_label Reactive returning the currency and physical unit.
#' @param currency_label Reactive returning the currency code.
#' @param open_trends Function that selects the Trends tab in the parent
#'   navigation.
#' @return Registers Overview outputs and the link to Trends.
#' @noRd
overview_module_server <- function(
  id,
  price_records,
  monthly_summary,
  market_month,
  county_month,
  calculation,
  calculation_label,
  calculation_short,
  selected_unit,
  unit_denominator,
  price_unit_label,
  currency_label,
  open_trends
) {
  shiny::moduleServer(id, function(input, output, session) {
    output$summary_kpis <- renderUI({
      dt <- price_records()
      shiny::validate(shiny::need(
        nrow(dt) > 0,
        "No price records match these filters. Broaden the selection or reset."
      ))
      monthly <- monthly_summary()
      latest_row <- monthly[.N]
      latest_month <- latest_row$year_month_date
      previous_month <- seq(latest_month, by = "-1 month", length.out = 2L)[2L]
      year_ago <- as.Date(sprintf(
        "%s-%s-01",
        as.integer(format(latest_month, "%Y")) - 1L,
        format(latest_month, "%m")
      ))
      year_row <- monthly[year_month_date == year_ago]
      year_price <- if (nrow(year_row)) year_row$price_estimate else NA_real_
      year_pct <- if (is.finite(year_price) && year_price != 0) {
        (latest_row$price_estimate - year_price) / year_price
      } else {
        NA_real_
      }
      method <- if (identical(
        calculation(), "record_weighted_mean"
      )) {
        "Record-weighted mean"
      } else {
        "Balanced median"
      }
      method_note <- if (identical(
        calculation(), "record_weighted_mean"
      )) {
        paste(
          "Each market-month mean contributes in proportion to its records;",
          "the record weights carry through county and selected-area means."
        )
      } else {
        paste(
          "Take the median of records in each market-month, then the median",
          "across markets in each county-month, then across available counties."
        )
      }
      record_word <- if (latest_row$observations == 1L) "record" else "records"
      market_word <- if (latest_row$markets == 1L) "market" else "markets"
      county_word <- if (latest_row$counties == 1L) "county" else "counties"

      div(
        class = "kfp-overview-summary",
        div(
          class = "kfp-overview-summary-heading",
          tags$span("Latest available price"),
          tags$span(
            class = "kfp-overview-date",
            paste(format(latest_month, "%b %Y"), "within selected period")
          )
        ),
        div(
          class = "kfp-overview-price",
          tags$strong(paste(
            currency_label(),
            format_number(latest_row$price_estimate, 2)
          )),
          tags$span(paste("per", tolower(selected_unit())))
        ),
        div(class = "kfp-overview-method", method),
        div(
          class = "kfp-overview-comparisons",
          div(
            class = "kfp-overview-comparison",
            tags$span(class = "kfp-overview-comparison-label",
                      paste("From", format(previous_month, "%b %Y"))),
            tags$strong(format_price_comparison(
              latest_row$percent_change
            )),
            if (!isTRUE(latest_row$consecutive_month)) {
              tags$span("No estimate for the prior calendar month.")
            }
          ),
          div(
            class = "kfp-overview-comparison",
            tags$span(class = "kfp-overview-comparison-label",
                      paste("From", format(year_ago, "%b %Y"))),
            tags$strong(format_price_comparison(year_pct)),
            if (!is.finite(year_pct)) {
              tags$span("No valid estimate for the same month last year.")
            }
          )
        ),
        p(
          class = "kfp-overview-coverage",
          paste0(
            "Based on ", format_number(latest_row$observations),
            " ", record_word, " from ", format_number(latest_row$markets),
            " ", market_word, " in ", format_number(latest_row$counties),
            " ", county_word, " this month."
          )
        ),
        tags$details(
          class = "kfp-overview-method-note",
          tags$summary("How is this estimate calculated?"),
          p(method_note),
          p("Available markets can change between months.")
        )
      )
    })

    observeEvent(input$overview_to_trends, {
      open_trends()
    })

    output$overview_trend <- ggiraph::renderGirafe({
      shiny::validate(shiny::need(
        nrow(price_records()) > 0,
        "No price records match these filters. Broaden the selection or reset."
      ))
      monthly <- data.table::copy(monthly_summary())
      shiny::validate(shiny::need(
        sum(is.finite(monthly$price_estimate)) > 1L,
        "There is not enough monthly data for a trend."
      ))

      monthly[, tooltip := paste0(
        "Month: ", format(year_month_date, "%b %Y"),
        "<br>", calculation_short(), ": ",
        format_number(price_estimate, 2), " ", price_unit_label(),
        "<br>", calculation_label(),
        "<br>Coverage: ",
        price_coverage_label(observations, markets, counties)
      )]
      monthly[, segment := cumsum(!is.finite(price_estimate))]
      observed <- is.finite(monthly$price_estimate)
      isolated <- observed &
        !data.table::shift(observed, fill = FALSE) &
        !data.table::shift(observed, type = "lead", fill = FALSE)
      points <- monthly[observed]
      if (nrow(points) > 36L) {
        points <- monthly[which(isolated |
          seq_along(observed) == length(observed))]
      }
      points[, month_id := as.character(year_month_date)]
      span_months <- nrow(monthly)
      date_breaks <- if (span_months <= 24L) {
        "3 months"
      } else if (span_months <= 72L) {
        "1 year"
      } else {
        "2 years"
      }

      gg <- ggplot2::ggplot(
        monthly,
        ggplot2::aes(x = year_month_date, y = price_estimate)
      ) +
        ggiraph::geom_line_interactive(
          ggplot2::aes(group = segment, tooltip = tooltip),
          colour = "#008d98",
          linewidth = 1.1,
          na.rm = TRUE
        ) +
        ggiraph::geom_point_interactive(
          data = points,
          ggplot2::aes(tooltip = tooltip, data_id = month_id),
          colour = "#008d98",
          size = 2.7
        ) +
        ggplot2::labs(
          x = NULL,
          y = price_unit_label()
        ) +
        ggplot2::scale_x_date(
          date_labels = "%b %Y",
          date_breaks = date_breaks
        ) +
        ggplot2::theme_minimal(base_size = 14) +
        ggplot2::theme(
          panel.grid.minor = ggplot2::element_blank(),
          panel.grid.major.x = ggplot2::element_blank(),
          axis.title.y = ggplot2::element_text(margin =
            ggplot2::margin(r = 10))
        )

      standard_girafe(gg, width_svg = 12, height_svg = 4.2)
    })

    output$recent_change_table <- DT::renderDT({
      monthly <- copy(monthly_summary())
      shiny::validate(shiny::need(nrow(monthly) > 0,
      "No monthly data available."))

      monthly[, pct_change := percent_change]

      estimate_heading <- paste0(calculation_short(), "\n", unit_denominator())
      display <- monthly[order(-year_month_date)][1:min(.N, 12)][
        ,
        .(
          Month = format(year_month_date, "%b %Y"),
          Estimate = format_number(price_estimate, 2),
          Change = vapply(change, format_change, character(1),
           unit_label = price_unit_label()),
          `% Change` = vapply(pct_change, format_percent, character(1)),
          Coverage = vapply(seq_len(.N),
           function(i) price_coverage_label(observations[i],
            markets[i], counties[i]),
             character(1))
        )
      ]
      data.table::setnames(display, "Estimate", estimate_heading)

      datatable_compact(display, page_length = 12, scroll_x = FALSE)
    })

    output$top_county_table <- DT::renderDT({
      monthly <- data.table::copy(county_month())
      shiny::validate(shiny::need(
        nrow(monthly) > 0,
        paste(
          "No county data available. Try all counties, broaden the",
          "date range, or reset the county filter."
        )
      ))
      estimate_heading <- paste0(calculation_short(), "\n", unit_denominator())
      display <- monthly[
        ,
        .(
          Estimate = if (
            identical(calculation(), "record_weighted_mean")
          ) {
            stats::weighted.mean(estimate, records)
          } else {
            stats::median(estimate)
          },
          `Latest observation month` = max(year_month_date),
          Records = sum(records),
          Markets = max(markets),
          `Covered Months` = .N
        ),
        by = .(County = county)
      ][order(-Estimate)][1:min(.N, 10)]

      display[, Estimate := vapply(Estimate,
       format_number, character(1), digits = 2)]
      display[
        ,
        `Latest observation month` := format(
          `Latest observation month`, "%b %Y"
        )
      ]
      data.table::setnames(display, "Estimate", estimate_heading)
      datatable_compact(display, page_length = 10, scroll_x = FALSE)
    })

    output$top_market_table <- DT::renderDT({
      monthly <- data.table::copy(market_month())
      shiny::validate(shiny::need(
        nrow(monthly) > 0,
        "No market data available. Try all markets, broaden the date range, or reset the market filter."
      ))
      estimate_heading <- paste0(calculation_short(), "\n", unit_denominator())
      display <- monthly[
        ,
        .(
          County = county[which.max(year_month_date)],
          Estimate = if (
            identical(calculation(), "record_weighted_mean")
          ) {
            stats::weighted.mean(estimate, records)
          } else {
            stats::median(estimate)
          },
          `Latest observation month` = max(year_month_date),
          Records = sum(records),
          `Covered Months` = .N
        ),
        by = .(Market = market)
      ][order(-Estimate)][1:min(.N, 10)]

      display[, Estimate := vapply(Estimate, format_number, character(1), digits = 2)]
      display[
        ,
        `Latest observation month` := format(
          `Latest observation month`, "%b %Y"
        )
      ]
      data.table::setnames(display, "Estimate", estimate_heading)
      datatable_compact(display, page_length = 10, scroll_x = FALSE)
    })
  })
}
