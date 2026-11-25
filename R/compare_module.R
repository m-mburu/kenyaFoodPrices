# County and commodity comparisons of recorded prices.

#' Build the Compare tab
#'
#' @param id Namespace shared with the Compare server.
#' @return A Shiny UI fragment with county and commodity selection and chart
#'   outputs.
#' @noRd
compare_module_ui <- function(id) {
  ns <- shiny::NS(id)

  fluidPage(
    fluidRow(
      shiny::column(6, uiOutput(ns("compare_counties_ui"))),
      shiny::column(6, uiOutput(ns("compare_commodities_ui")))
    ),
    fluidRow(
      shiny::column(
        6,
        plot_panel(
          "County Comparison",
          shinycssloaders::withSpinner(
            visualization_frame(
              ggiraph::girafeOutput(
                ns("county_compare_plot"),
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
                ns("commodity_compare_plot"),
                height = "100%"
              )
            ),
            color = "#00a2ab"
          )
        )
      )
    )
  )
}

# Use the shared attributes and date range to find comparable commodities.
# This scope also supplies the choice list, before users choose commodities.
#' Find comparable commodities for the selected product attributes and dates
#'
#' @param price_records Observation-level price data.table.
#' @param selected_category Selected product category.
#' @param selected_unit Selected physical unit.
#' @param selected_price_type Selected retail or wholesale price type.
#' @param selected_dates Two observation dates defining the inclusive range.
#' @return Observation records in the requested scope, across all commodities
#'   that satisfy it.
#' @noRd
compare_commodity_records <- function(
  price_records,
  selected_category,
  selected_unit,
  selected_price_type,
  selected_dates
) {
  price_records[
    category == selected_category &
      unit == selected_unit &
      pricetype == selected_price_type &
      data.table::between(date, selected_dates[1L], selected_dates[2L])
  ]
}

# Each point is the mean of the selected records for one group and month.
#' Calculate mean recorded prices by location or commodity and month
#'
#' @param price_records Observation-level records in the comparison scope.
#' @param price_column Name of the price column to average.
#' @param group Name of the county or commodity grouping column.
#' @return One row per observed group-month with its mean in the selected price
#'   units. Missing prices are omitted from the mean.
#' @noRd
summarise_comparison_prices <- function(price_records, price_column, group) {
  price_records[
    ,
    .(mean_price = mean(get(price_column), na.rm = TRUE)),
    by = c("year_month_date", group)
  ][order(year_month_date)]
}

#' Render county and commodity comparisons with independent choice sets
#'
#' @param id Namespace shared with the Compare UI.
#' @param county_price_records Reactive returning records for the selected
#'   commodity before county and market restrictions.
#' @param commodity_price_records Reactive returning records across the
#'   eligible commodities.
#' @param price_column Reactive returning the price column name.
#' @param price_unit_label Reactive returning the currency and physical unit
#'   for display.
#' @param unit_denominator Reactive returning a parenthesised unit label for
#'   axes.
#' @return Registers Compare outputs within the session.
#' @noRd
compare_module_server <- function(
  id,
  county_price_records,
  commodity_price_records,
  price_column,
  price_unit_label,
  unit_denominator
) {
  shiny::moduleServer(id, function(input, output, session) {
    output$compare_counties_ui <- renderUI({
      dt <- county_price_records()[!is.na(county)]
      shiny::validate(shiny::need(nrow(dt) > 0, "No counties are available for this selection."))

      ranked <- dt[, .N, by = county][order(-N, county)]
      choices <- ranked$county
      selected <- ranked[1:min(.N, 4)]$county

      div(
        class = "kfp-toggle-control kfp-compare-control",
        checkboxGroupInput(
          session$ns("compare_counties"),
          "Counties to compare",
          choices = choices,
          selected = selected,
          inline = TRUE
        )
      )
    })

    output$compare_commodities_ui <- renderUI({
      dt <- commodity_price_records()
      shiny::validate(shiny::need(nrow(dt) > 0, "No commodities are available for this selection."))

      ranked <- dt[, .N, by = commodity][order(-N, commodity)]
      choices <- ranked$commodity
      selected <- ranked[1:min(.N, 5)]$commodity

      div(
        class = "kfp-toggle-control kfp-compare-control",
        checkboxGroupInput(
          session$ns("compare_commodities"),
          "Commodities to compare",
          choices = choices,
          selected = selected,
          inline = TRUE
        )
      )
    })

    output$county_compare_plot <- ggiraph::renderGirafe({
      req(input$compare_counties)
      dt <- county_price_records()[county %in% input$compare_counties]
      price_val <- price_column()
      shiny::validate(shiny::need(nrow(dt) > 1, "Select at least one county with available data."))

      compare <- summarise_comparison_prices(dt, price_val, "county")
      compare[, tooltip := paste0(
        county, "<br>", format(year_month_date, "%b %Y"),
        "<br>Mean recorded price: ", format_number(mean_price, 2),
        " ", price_unit_label()
      )]
      compare[, county_id := as.character(county)]
      compare[, county_point_id := paste(county, year_month_date, sep = "|")]
      county_levels <- sort(unique(compare$county))
      county_palette <- stats::setNames(
        rep(c("#00a2ab", "#f2a541", "#647acb", "#23845f", "#c94a32", "#7a5fa3"), length.out = length(county_levels)),
        county_levels
      )

      gg <- ggplot2::ggplot(
        compare,
        ggplot2::aes(x = year_month_date, y = mean_price, colour = county, group = county)
      ) +
        ggiraph::geom_line_interactive(
          ggplot2::aes(tooltip = tooltip, data_id = county_id, group = county),
          linewidth = 1
        ) +
        ggiraph::geom_point_interactive(
          ggplot2::aes(tooltip = tooltip, data_id = county_point_id),
          size = 1.8
        ) +
        ggplot2::labs(
          title = "County price comparison",
          x = "Month",
          y = paste("Mean recorded price", unit_denominator()),
          colour = "County"
        ) +
        ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
        ggplot2::scale_colour_manual(values = county_palette) +
        ggplot2::theme_minimal(base_size = 12) +
        ggplot2::theme(
          plot.title = ggplot2::element_text(face = "bold"),
          legend.position = "bottom",
          panel.grid.minor = ggplot2::element_blank()
        )

      standard_girafe(gg, width_svg = 12, height_svg = 4.2)
    })

    output$commodity_compare_plot <- ggiraph::renderGirafe({
      req(input$compare_commodities)
      price_val <- price_column()
      dt <- commodity_price_records()[commodity %in% input$compare_commodities]
      shiny::validate(shiny::need(nrow(dt) > 1, "Select commodities with available data for the current unit and price type."))

      compare <- summarise_comparison_prices(dt, price_val, "commodity")
      compare[, tooltip := paste0(
        commodity, "<br>", format(year_month_date, "%b %Y"),
        "<br>Mean recorded price: ", format_number(mean_price, 2),
        " ", price_unit_label()
      )]
      compare[, commodity_id := as.character(commodity)]
      compare[, commodity_point_id := paste(commodity, year_month_date, sep = "|")]
      commodity_levels <- sort(unique(compare$commodity))
      commodity_palette <- stats::setNames(
        rep(c("#00a2ab", "#f2a541", "#647acb", "#23845f", "#c94a32", "#7a5fa3"), length.out = length(commodity_levels)),
        commodity_levels
      )

      gg <- ggplot2::ggplot(
        compare,
        ggplot2::aes(x = year_month_date, y = mean_price, colour = commodity, group = commodity)
      ) +
        ggiraph::geom_line_interactive(
          ggplot2::aes(tooltip = tooltip, data_id = commodity_id, group = commodity),
          linewidth = 1
        ) +
        ggiraph::geom_point_interactive(
          ggplot2::aes(tooltip = tooltip, data_id = commodity_point_id),
          size = 1.8
        ) +
        ggplot2::labs(
          title = "Commodity price comparison",
          x = "Month",
          y = paste("Mean recorded price", unit_denominator()),
          colour = "Commodity"
        ) +
        ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
        ggplot2::scale_colour_manual(values = commodity_palette) +
        ggplot2::theme_minimal(base_size = 12) +
        ggplot2::theme(
          plot.title = ggplot2::element_text(face = "bold"),
          legend.position = "bottom",
          panel.grid.minor = ggplot2::element_blank()
        )

      standard_girafe(gg, width_svg = 12, height_svg = 4.2)
    })
  })
}
