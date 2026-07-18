# Shared ggiraph configuration for interactive dashboard graphics.

standard_girafe <- function(
  plot,
  width_svg,
  height_svg,
  selectable = FALSE,
  selected = character()
) {
  options <- list(
    ggiraph::opts_hover(
      css = "stroke:#132f2f;stroke-width:2px;fill-opacity:0.9;"
    ),
    ggiraph::opts_tooltip(
      css = paste(
        "background:#132f2f;color:white;padding:10px;",
        "border-radius:5px;font-size:13px;line-height:1.35;"
      )
    ),
    ggiraph::opts_sizing(rescale = TRUE, width = 1)
  )

  if (isTRUE(selectable)) {
    options <- c(
      options,
      list(
        ggiraph::opts_selection(
          css = "stroke:#f2a541;stroke-width:4px;fill-opacity:0.9;",
          type = "single",
          selected = selected
        )
      )
    )
  }

  ggiraph::girafe(
    ggobj = plot,
    width_svg = width_svg,
    height_svg = height_svg,
    pointsize = 13,
    options = options
  )
}

market_price_map <- function(map_df, counties, price_unit, currency) {
  county_sf <- sf::st_as_sf(
    data.table::copy(counties),
    sf_column_name = "geometry"
  )
  county_sf <- sf::st_transform(county_sf, 4326)
  map_df <- data.table::copy(map_df)
  map_df$map_tooltip <- paste0(
    "Market: ", map_df$market,
    "\nCounty: ", map_df$county,
    "\nAverage price: ", format_number(map_df$avg_price, 2), " ", price_unit,
    "\nLatest date: ", map_df$latest_date,
    "\nRecords: ", map_df$records
  )

  plot <- ggplot2::ggplot() +
    ggplot2::geom_sf(
      data = county_sf,
      fill = "#eef5f3",
      colour = "#ffffff",
      linewidth = 0.3
    ) +
    ggiraph::geom_point_interactive(
      data = map_df,
      ggplot2::aes(
        x = longitude,
        y = latitude,
        colour = avg_price,
        size = records,
        tooltip = map_tooltip,
        data_id = market
      ),
      alpha = 0.82,
      stroke = 0.5
    ) +
    ggplot2::coord_sf(datum = NA) +
    ggplot2::scale_colour_distiller(
      palette = "YlOrRd",
      direction = 1,
      name = paste("Average", currency),
      oob = scales::squish
    ) +
    ggplot2::scale_size_continuous(
      range = c(3, 9),
      name = "Records"
    ) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      plot.margin = ggplot2::margin(8, 8, 8, 8)
    )

  standard_girafe(plot, width_svg = 8, height_svg = 6.4)
}

climate_map_plot <- function(
  map_sf,
  type,
  condition_view,
  selected_date,
  climate_monthly
) {
  if (identical(type, "rainfall")) {
    map_sf$display_value <- if (condition_view) map_sf$rainfall_condition else map_sf$rainfall_mm
    map_sf$map_tooltip <- paste0(
      "County: ", map_sf$county,
      "\nMonth: ", format(selected_date, "%B %Y"),
      "\nAverage rainfall: ", format_number(map_sf$rainfall_mm, 1), " mm/dekad",
      "\nStandardised condition: ", format_number(map_sf$rainfall_z, 2),
      "\nAssessment: ", map_sf$rainfall_condition
    )
    legend_title <- if (condition_view) "Rainfall condition" else "Rainfall\n(mm/dekad)"
  } else {
    map_sf$display_value <- if (condition_view) map_sf$ndvi_condition else map_sf$ndvi
    map_sf$map_tooltip <- paste0(
      "County: ", map_sf$county,
      "\nMonth: ", format(selected_date, "%B %Y"),
      "\nAverage NDVI: ", format_number(map_sf$ndvi, 3),
      "\nStandardised condition: ", format_number(map_sf$ndvi_z, 2),
      "\nAssessment: ", map_sf$ndvi_condition
    )
    legend_title <- if (condition_view) "Greenness condition" else "Average NDVI"
  }

  plot <- ggplot2::ggplot(map_sf) +
    ggiraph::geom_sf_interactive(
      ggplot2::aes(
        fill = display_value,
        tooltip = map_tooltip,
        data_id = adm1_pcode
      ),
      colour = "#ffffff",
      linewidth = 0.35
    ) +
    ggplot2::coord_sf(datum = NA) +
    ggplot2::labs(fill = legend_title) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      legend.key.width = grid::unit(24, "pt"),
      plot.margin = ggplot2::margin(8, 8, 8, 8)
    )

  if (condition_view) {
    plot + ggplot2::scale_fill_manual(
      values = c(
        "Much below normal" = "#8c510a",
        "Below normal" = "#d95f0e",
        "Near normal" = "#f7f7f7",
        "Above normal" = "#4dac9d",
        "Much above normal" = "#01665e",
        "Not available" = "#d9d9d9"
      ),
      drop = FALSE,
      na.value = "#d9d9d9"
    )
  } else if (identical(type, "rainfall")) {
    plot + ggplot2::scale_fill_gradient(
      low = "#eff3ff",
      high = "#08519c",
      limits = range(climate_monthly$rainfall_mm, na.rm = TRUE),
      oob = scales::squish,
      na.value = "#d9d9d9"
    )
  } else {
    plot + ggplot2::scale_fill_gradient(
      low = "#ffffe5",
      high = "#006837",
      limits = c(0, 0.85),
      oob = scales::squish,
      na.value = "#d9d9d9"
    )
  }
}
