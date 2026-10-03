test_that("Leaflet styles retain source values and missing conditions", {
  climate <- app_climate()
  areas <- prepare_climate_geometry(
    app_display_counties(), climate$county_lookup
  )
  observations <- climate$county_monthly[date == as.Date("2026-08-01")]
  for (field in c("rainfall_mm", "rainfall_z", "ndvi", "ndvi_z")) {
    areas[[field]] <- observations[[field]][
      match(areas$adm1_pcode, observations$adm1_pcode)
    ]
  }
  original <- areas
  style <- climate_leaflet_style(
    areas, "vegetation", FALSE, as.Date("2026-08-01"),
    climate$county_monthly
  )
  expect_identical(areas, original)
  expect_identical(style$ids, areas$adm1_pcode)
  expect_true(all(style$colours == "#d9d9d9"))
  expect_true(all(grepl("Average NDVI: Not available", style$labels)))
  expect_true(all(vapply(seq_len(nrow(areas)), function(index) {
    grepl(paste0("Assessment: ", climate_condition(areas$ndvi_z[index])),
          style$labels[index], fixed = TRUE)
  }, logical(1))))
  expect_true(all(grepl("August 2026", style$labels)))
  local <- prepare_subcounty_map_values(
    app_cod_subcounties(),
    climate$subcounty_monthly[date == as.Date("2026-07-01")], "KE001"
  )
  local_style <- climate_leaflet_style(
    local, "rainfall", TRUE, as.Date("2026-07-01"),
    climate$subcounty_monthly, "subcounty", "Mombasa"
  )
  expect_identical(local_style$ids, local$adm2_pcode)
  expect_true(all(grepl("County: Mombasa", local_style$labels)))
  expect_equal(local_style$colours, unname(c(
    "Much below normal" = "#8c510a", "Below normal" = "#d95f0e",
    "Near normal" = "#f7f7f7", "Above normal" = "#4dac9d",
    "Much above normal" = "#01665e", "Not available" = "#d9d9d9"
  )[climate_condition(local$rainfall_z)]))
})

test_that("missing reference geometry retains focus with an explanation", {
  testthat::local_mocked_bindings(app_wards = function() NULL)
  shiny::testServer(
    climate_module_server,
    args = list(
      price_data = shiny::reactive(app_food_prices()[0]),
      price_column = shiny::reactive("price"),
      price_unit_label = shiny::reactive("KES per kg")
    ),
    {
      session$setInputs(
        month = "2026-07-01", county = "KE001", map_measure = "actual",
        value_level = "subcounty", detail_level = "ward"
      )
      expect_null(focus_detail()$sf)
      expect_match(output$drill_controls$html,
                   "Local reference boundaries are unavailable.",
                   fixed = TRUE)
      expect_identical(selected_county_name(), "Mombasa")
      expect_true(nrow(subcounty_values()) > 0L)
      expect_true(length(focus_bounds()) == 4L)
      expect_error(price_series(), "No price observations")
    }
  )
})

test_that("county focus sends local layers without national geometry", {
  captured <- new.env(parent = emptyenv())
  captured$calls <- list()
  captured$county <- NULL
  active <- shiny::reactiveVal(TRUE)
  test_session <- shiny::MockShinySession$new()
  test_session$sendCustomMessage <- function(type, message) {
    if (identical(type, "leaflet-calls")) {
      calls <- lapply(message$calls, function(call) {
        call$map_id <- message$id
        call
      })
      captured$calls <- c(captured$calls, calls)
    }
  }
  has_call <- function(method, group = NULL) {
    any(vapply(captured$calls, function(call) {
      identical(call$method, method) &&
        (is.null(group) || identical(call$args[[3L]], group))
    }, logical(1)))
  }
  shiny::testServer(
    climate_module_server,
    session = test_session,
    args = list(
      price_data = shiny::reactive(app_food_prices()[commodity == "Maize"]),
      price_column = shiny::reactive("price"),
      price_unit_label = shiny::reactive("KES per 90 kg"),
      set_global_county = function(county) captured$county <- county,
      active = active
    ),
    {
      session$setInputs(
        month = "2026-07-01", county = "All", map_measure = "actual",
        rainfall_map_ready = 1L, vegetation_map_ready = 1L,
        value_level = "subcounty", detail_level = "subcounty"
      )
      expect_true(has_call("addPolygons", "national"))
      expect_true(has_call("fitBounds"))
      legends <- Filter(function(call) {
        identical(call$method, "addLegend")
      }, captured$calls)
      rainfall <- Filter(function(call) {
        grepl("rainfall_map$", call$map_id)
      }, legends)
      vegetation <- Filter(function(call) {
        grepl("vegetation_map$", call$map_id)
      }, legends)
      expect_identical(rainfall[[1L]]$args[[1L]]$title,
                       "Rainfall (mm/dekad)")
      expect_identical(vegetation[[1L]]$args[[1L]]$title, "Average NDVI")
      captured$calls <- list()
      session$setInputs(county = "KE001")
      expect_false(has_call("addPolygons", "national"))
      expect_true(has_call("addPolygons", "focus"))
      expect_true(has_call("fitBounds"))
      expect_identical(captured$county, "Mombasa")
      captured$calls <- list()
      session$setInputs(county = "KE001")
      expect_length(captured$calls, 0L)
      session$setInputs(month = "2026-06-01")
      expect_true(has_call("addPolygons", "national"))
      expect_true(has_call("addPolygons", "focus"))
      expect_false(has_call("fitBounds"))
      captured$calls <- list()
      session$setInputs(map_measure = "condition")
      expect_false(has_call("fitBounds"))
      captured$calls <- list()
      session$setInputs(county = "All")
      expect_false(has_call("addPolygons", "national"))
      expect_true(has_call("showGroup"))
      expect_true(has_call("fitBounds"))
      expect_identical(captured$county, "All")
      captured$calls <- list()
      session$setInputs(vegetation_map_shape_click = list(id = "KE001"))
      # Mock sessions do not apply updateSelectInput messages automatically.
      expect_identical(captured$county, "Mombasa")
      expect_length(captured$calls, 0L)
      active(FALSE)
      session$flushReact()
      session$setInputs(month = "2026-05-01")
      expect_length(captured$calls, 0L)
      active(TRUE)
      session$flushReact()
      expect_true(has_call("addPolygons", "national"))
    }
  )
})
