# Prepare colours and labels without altering source measurements or geometry.
climate_leaflet_style <- function(
  areas, type, condition_view, selected_date, source_values,
  area_level = "county", focus_label = NULL
) {
  local_values <- identical(area_level, "subcounty")
  ids <- if (local_values) areas$adm2_pcode else areas$adm1_pcode
  area_names <- if (local_values) areas$subcounty else areas$county
  prefix <- if (local_values) "Sub-county: " else "County: "
  field <- if (identical(type, "rainfall")) "rainfall_mm" else "ndvi"
  z_field <- if (identical(type, "rainfall")) "rainfall_z" else "ndvi_z"
  values <- areas[[field]]
  conditions <- climate_condition(areas[[z_field]])
  condition_colours <- c(
    "Much below normal" = "#8c510a", "Below normal" = "#d95f0e",
    "Near normal" = "#f7f7f7", "Above normal" = "#4dac9d",
    "Much above normal" = "#01665e", "Not available" = "#d9d9d9"
  )
  rainfall <- identical(type, "rainfall")
  title <- if (rainfall) "Rainfall (mm/dekad)" else "Average NDVI"
  if (condition_view) {
    colours <- unname(condition_colours[conditions])
    legend <- list(colours = unname(condition_colours),
                   labels = names(condition_colours))
    title <- if (rainfall) "Rainfall condition" else "Greenness condition"
  } else {
    limits <- if (rainfall) {
      range(source_values$rainfall_mm, na.rm = TRUE)
    } else {
      c(0, 0.85)
    }
    palette <- leaflet::colorNumeric(
      if (rainfall) c("#eff3ff", "#08519c") else c("#ffffe5", "#006837"),
      domain = limits, na.color = "#d9d9d9"
    )
    # Match the existing maps' treatment of values outside the colour limits.
    colours <- palette(pmin(limits[2L], pmax(limits[1L], values)))
    breaks <- seq(limits[1L], limits[2L], length.out = 5L)
    legend <- list(
      colours = c(palette(breaks), "#d9d9d9"),
      labels = c(format_number(breaks, if (rainfall) 1 else 3),
                 "Not available")
    )
  }
  labels <- paste0(
    prefix, area_names,
    if (local_values) paste0("\nCounty: ", focus_label) else "",
    "\nMonth: ", format(selected_date, "%B %Y"),
    if (rainfall) "\nAverage rainfall: " else "\nAverage NDVI: ",
    format_number(values, if (rainfall) 1 else 3),
    if (rainfall) " mm/dekad" else "",
    "\nStandardised condition: ", format_number(areas[[z_field]], 2),
    "\nAssessment: ", conditions
  )
  list(ids = ids, colours = colours, labels = labels,
       legend = legend, title = title)
}

add_climate_leaflet_values <- function(map, areas, style, group) {
  leaflet::addPolygons(
    map, data = areas, layerId = style$ids, group = group,
    color = "#345151", weight = 1, opacity = 1,
    fillColor = style$colours, fillOpacity = 0.85,
    label = style$labels,
    labelOptions = leaflet::labelOptions(
      textsize = "14px", style = list("white-space" = "pre-line")
    ),
    popup = gsub("\n", "<br>", htmltools::htmlEscape(style$labels)),
    highlightOptions = leaflet::highlightOptions(weight = 3)
  )
}

# Empty widgets render once; ready events gate proxy work until they exist.
climate_leaflet_widget <- function(bounds) {
  map <- leaflet::leaflet(options = leaflet::leafletOptions(
    minZoom = 4, maxZoom = 14, scrollWheelZoom = FALSE
  ))
  map <- fit_climate_leaflet_bounds(map, bounds)
  htmlwidgets::onRender(map, paste(
    "function(el, x) {",
    "Shiny.setInputValue(el.id + '_ready', Date.now(),",
    "{priority: 'event'});",
    "}"
  ))
}

fit_climate_leaflet_bounds <- function(map, bounds) {
  leaflet::fitBounds(
    map, bounds[1L], bounds[2L], bounds[3L], bounds[4L],
    options = list(padding = c(16, 16), animate = FALSE)
  )
}

add_climate_leaflet_detail <- function(map, detail, area_level) {
  if (is.null(detail$sf) || !nrow(detail$sf)) return(map)
  labels <- paste0(
    detail$sf[[detail$name_col]], "\nReference boundary; ",
    area_level, " climate estimates"
  )
  leaflet::addPolygons(
    map, data = detail$sf, group = "detail",
    layerId = paste0("detail-", seq_len(nrow(detail$sf))),
    fill = FALSE, color = "#345151", weight = 1.5,
    label = labels,
    popup = gsub("\n", "<br>", htmltools::htmlEscape(labels))
  )
}

# Each map retains its national layer. County changes only send local layers
# and bounds; month/measure changes refresh values without changing extent.
register_climate_leaflet <- function(
  map_id, type, input, output, session, county_geometry, map_values,
  subcounty_values, selected_date, selected_county_name, value_level,
  detail_level, focus_detail, focus_bounds, climate_monthly,
  subcounty_monthly, active = NULL
) {
  # These arguments can come from a loop; capture before its binding changes.
  force(map_id)
  force(type)
  national_bounds <- as.numeric(sf::st_bbox(county_geometry))
  output[[map_id]] <- leaflet::renderLeaflet({
    climate_leaflet_widget(national_bounds)
  })
  # Plain session-local state avoids making the observer depend on itself.
  state <- new.env(parent = emptyenv())
  state$national_key <- state$focus_key <- state$extent_key <- NULL
  state$ready <- NULL
  shiny::observe({
    if (is.function(active)) shiny::req(active())
    ready <- input[[paste0(map_id, "_ready")]]
    shiny::req(ready, input$county, input$map_measure)
    if (!identical(ready, state$ready)) {
      state$national_key <- state$focus_key <- state$extent_key <- NULL
      state$ready <- ready
    }
    month <- selected_date()
    condition_view <- identical(input$map_measure, "condition")
    national_key <- c(as.character(month), input$map_measure)
    focus_key <- c(national_key, input$county, value_level(), detail_level())
    extent_key <- c(input$county, value_level())
    map <- leaflet::leafletProxy(map_id, session = session)
    if (!identical(national_key, state$national_key)) {
      style <- climate_leaflet_style(
        map_values(), type, condition_view, month, climate_monthly
      )
      map <- leaflet::clearGroup(map, "national")
      map <- add_climate_leaflet_values(map, map_values(), style, "national")
      state$national_key <- national_key
    }
    if (!identical(focus_key, state$focus_key)) {
      map <- leaflet::clearGroup(map, "focus")
      map <- leaflet::clearGroup(map, "detail")
      local_values <- input$county != "All" &&
        identical(value_level(), "subcounty")
      areas <- if (local_values) subcounty_values() else map_values()
      source <- if (local_values) subcounty_monthly else climate_monthly
      level <- if (local_values) "subcounty" else "county"
      style <- climate_leaflet_style(
        areas, type, condition_view, month, source,
        area_level = level, focus_label = selected_county_name()
      )
      if (local_values) {
        map <- leaflet::hideGroup(map, "national")
        map <- add_climate_leaflet_values(map, areas, style, "focus")
      } else {
        map <- leaflet::showGroup(map, "national")
        if (input$county != "All") {
          selected <- county_geometry[
            county_geometry$adm1_pcode == input$county, ]
          map <- leaflet::addPolygons(
            map, data = selected, group = "focus", fill = FALSE,
            color = "#f2a541", weight = 3,
            options = leaflet::pathOptions(interactive = FALSE)
          )
        }
      }
      map <- add_climate_leaflet_detail(map, focus_detail(), level)
      map <- leaflet::removeControl(map, "climate-legend")
      map <- leaflet::addLegend(
        map, position = "bottomleft", colors = style$legend$colours,
        labels = style$legend$labels, title = style$title,
        layerId = "climate-legend", opacity = 1
      )
      map <- leaflet::removeControl(map, "climate-focus")
      map <- leaflet::addControl(
        map, html = htmltools::htmlEscape(selected_county_name()),
        position = "topright", layerId = "climate-focus",
        className = "info kfp-map-focus"
      )
      state$focus_key <- focus_key
    }
    if (!identical(extent_key, state$extent_key)) {
      bounds <- focus_bounds() %||% national_bounds
      fit_climate_leaflet_bounds(map, bounds)
      state$extent_key <- extent_key
    }
  })
}
