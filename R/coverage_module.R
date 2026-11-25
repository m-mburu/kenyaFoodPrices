# Observation coverage for the selected price records.

#' Build the Coverage tab
#'
#' @param id Namespace shared with the Coverage server.
#' @return A Shiny UI fragment with a headline, annual chart and detail table.
#' @noRd
coverage_module_ui <- function(id) {
  ns <- shiny::NS(id)

  fluidPage(
    uiOutput(ns("coverage_summary")),
    fluidRow(
      shiny::column(
        7,
        plot_panel(
          "Observation Coverage by Year",
          shinycssloaders::withSpinner(
            visualization_frame(
              ggiraph::girafeOutput(
                ns("coverage_year_plot"),
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
            DT::DTOutput(ns("coverage_table")),
            color = "#00a2ab"
          )
        )
      )
    )
  )
}

#' Count observation records, counties and markets for each observed year
#'
#' @param price_records A data.table with one row per price observation and
#'   year, date, county and market columns.
#' @return One row per observed year, with counts and Date bounds. Missing
#'   county names are excluded from county counts. A missing market name
#'   contributes one distinct value to the annual market count.
#' @noRd
summarise_annual_coverage <- function(price_records) {
  if (nrow(price_records) == 0L) {
    return(price_records[, .(
      year, records = integer(), counties = integer(), markets = integer(),
      first_date = date, latest_date = date
    )])
  }

  price_records[
    ,
    .(
      records = .N,
      counties = data.table::uniqueN(county, na.rm = TRUE),
      markets = data.table::uniqueN(market, na.rm = FALSE),
      first_date = min(date),
      latest_date = max(date)
    ),
    by = year
  ][order(year)]
}

#' Render coverage for the active observation filters
#'
#' @param id Namespace shared with the Coverage UI.
#' @param price_records Reactive returning the geographically filtered
#'   observation records.
#' @param selected_commodity Reactive returning the active commodity label for
#'   the headline.
#' @return Registers the Coverage outputs. The chart and table read the same
#'   annual summary.
#' @noRd
coverage_module_server <- function(
  id,
  price_records,
  selected_commodity
) {
  shiny::moduleServer(id, function(input, output, session) {
    annual_coverage <- reactive({
      summarise_annual_coverage(price_records())
    })

    output$coverage_summary <- renderUI({
      records <- price_records()
      req(nrow(records) > 0)

      first_date <- min(records$date)
      latest_date <- max(records$date)
      year_span <- paste(
        format(first_date, "%Y"), format(latest_date, "%Y"), sep = "-"
      )

      div(
        class = "kfp-kpi-grid kfp-coverage-grid",
        kpi_card("Records", format_number(nrow(records)), "selected filters"),
        kpi_card(
          "Date span", year_span, paste(first_date, "to", latest_date)
        ),
        kpi_card(
          "Counties",
          format_number(data.table::uniqueN(records$county, na.rm = TRUE)),
          "covered"
        ),
        # The headline counts only named markets.
        kpi_card(
          "Markets",
          format_number(data.table::uniqueN(records$market, na.rm = TRUE)),
          "covered"
        ),
        kpi_card(
          "Missing county", format_number(sum(is.na(records$county))), "records"
        ),
        kpi_card(
          "Latest record", as.character(max(records$date, na.rm = TRUE)),
          selected_commodity()
        )
      )
    })

    output$coverage_year_plot <- ggiraph::renderGirafe({
      summary <- annual_coverage()
      shiny::validate(shiny::need(
        nrow(summary) > 0, "No coverage data available."
      ))

      coverage <- data.table::copy(summary)
      coverage[, tooltip := paste0(
        "Year: ", year,
        "<br>Records: ", format_number(records),
        "<br>Counties: ", format_number(counties),
        "<br>Markets: ", format_number(markets)
      )]
      coverage[, year_id := as.character(year)]

      gg <- ggplot2::ggplot(
        coverage,
        ggplot2::aes(x = year, y = records)
      ) +
        ggiraph::geom_col_interactive(
          ggplot2::aes(tooltip = tooltip, data_id = year_id),
          fill = "#00a2ab",
          width = 0.7
        ) +
        ggplot2::labs(
          title = "Observation coverage by year",
          x = "Year",
          y = "Records"
        ) +
        ggplot2::theme_minimal(base_size = 12) +
        ggplot2::theme(
          plot.title = ggplot2::element_text(face = "bold"),
          panel.grid.minor = ggplot2::element_blank()
        )

      standard_girafe(gg, width_svg = 12, height_svg = 4.2)
    })

    output$coverage_table <- DT::renderDT({
      summary <- annual_coverage()
      shiny::validate(shiny::need(
        nrow(summary) > 0, "No coverage data available."
      ))

      display <- summary[order(-year), .(
        Year = year,
        Records = records,
        Counties = counties,
        Markets = markets,
        `First Date` = as.character(first_date),
        `Latest Date` = as.character(latest_date)
      )]
      datatable_compact(display, page_length = 6)
    })
  })
}
