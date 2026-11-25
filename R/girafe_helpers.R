# Shared ggiraph configuration for interactive dashboard graphics.

#' Apply the common interaction settings to a dashboard plot
#'
#' @param plot A ggplot with any interactive layers already defined.
#' @param width_svg Width of the SVG drawing area in inches.
#' @param height_svg Height of the SVG drawing area in inches.
#' @param selectable Whether to enable single-mark selection.
#' @param selected IDs to select when the widget first renders.
#' @return A rescalable ggiraph widget with consistent hover and tooltip
#'   styling.
#' @noRd
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

# Build a county or sub-county climate choropleth.
# - `focus_bounds` (optional numeric xmin/ymin/xmax/ymax) zooms the map to a
#   selected county while keeping the national fill for context.
# - `detail_sf` (optional sf) draws uncoloured internal unit outlines (sub-
#   counties or wards) inside the focused county. These are reference only;
#   `detail_name` is the label column used on hover.
#' Draw a climate choropleth with the ggiraph renderer
#'
#' @param map_sf County or ADM2 polygons with their selected-month
#'   measurements.
#' @param type Indicator key for rainfall or vegetation.
#' @param condition_view Whether to colour polygons by standardised condition.
#' @param selected_date Observation month as a Date.
#' @param climate_monthly Historical records used to establish the rainfall
#'   colour scale.
#' @param focus_bounds Optional focused bounding box.
#' @param detail_sf Optional geographic reference outlines.
#' @param detail_name Name of the column containing reference outline labels.
#' @param focus_label Optional name of the focused county.
#' @param area_level Geographic level of the shaded values.
#' @return An interactive ggiraph map showing climate measurements and optional
#'   reference outlines.
#' @noRd
climate_map_plot <- function(
  map_sf,
  type,
  condition_view,
  selected_date,
  climate_monthly,
  focus_bounds = NULL,
  detail_sf = NULL,
  detail_name = NULL,
  focus_label = NULL,
  area_level = "county"
) {
  subcounty_view <- identical(area_level, "subcounty")
  map_sf$map_id <- if (subcounty_view) {
    map_sf$adm2_pcode
  } else {
    map_sf$adm1_pcode
  }
  area_label <- if (subcounty_view) {
    paste0(
      "Sub-county: ", map_sf$subcounty,
      "\nCounty: ", focus_label
    )
  } else {
    paste0("County: ", map_sf$county)
  }
  if (identical(type, "rainfall")) {
    map_sf$display_value <- if (condition_view) {
      map_sf$rainfall_condition
    } else {
      map_sf$rainfall_mm
    }
    map_sf$map_tooltip <- paste0(
      area_label,
      "\nMonth: ", format(selected_date, "%B %Y"),
      "\nAverage rainfall: ", format_number(map_sf$rainfall_mm, 1), " mm/dekad",
      "\nStandardised condition: ", format_number(map_sf$rainfall_z, 2),
      "\nAssessment: ", map_sf$rainfall_condition
    )
    legend_title <- if (condition_view) "Rainfall condition" else "Rainfall\n(mm/dekad)"
  } else {
    map_sf$display_value <- if (condition_view) {
      map_sf$ndvi_condition
    } else {
      map_sf$ndvi
    }
    map_sf$map_tooltip <- paste0(
      area_label,
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
        data_id = map_id
      ),
      colour = "#ffffff",
      linewidth = 0.35
    )

  # Detail outlines (sub-counties/wards) are reference geometry, not observed
  # values, so they are drawn as uncoloured boundaries with a name tooltip.
  if (!is.null(detail_sf) && nrow(detail_sf) > 0 && !is.null(detail_name)) {
    detail_sf <- sf::st_set_geometry(detail_sf, attr(detail_sf, "sf_column"))
    estimate_level <- if (subcounty_view) "sub-county" else "county"
    detail_sf$detail_tooltip <- paste0(
      detail_sf[[detail_name]],
      "\n(reference boundary - climate values are ",
      estimate_level, " estimates)"
    )
    detail_sf$detail_id <- paste0(
      "boundary-", seq_len(nrow(detail_sf))
    )
    plot <- plot +
      ggiraph::geom_sf_interactive(
        data = detail_sf,
        ggplot2::aes(
          tooltip = detail_tooltip,
          data_id = detail_id
        ),
        fill = NA,
        colour = "#345151",
        linewidth = 0.5
      )
  }

  # Zoom to the focused county when its bounds are supplied.
  if (!is.null(focus_bounds) && length(focus_bounds) == 4L) {
    pad_x <- (focus_bounds[3] - focus_bounds[1]) * 0.06
    pad_y <- (focus_bounds[4] - focus_bounds[2]) * 0.06
    plot <- plot +
      ggplot2::coord_sf(
        datum = NA,
        xlim = focus_bounds[c(1, 3)] + c(-pad_x, pad_x),
        ylim = focus_bounds[c(2, 4)] + c(-pad_y, pad_y),
        expand = FALSE
      )
  } else {
    plot <- plot + ggplot2::coord_sf(datum = NA)
  }

  plot <- plot +
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
