test_that("display county geometry preserves all county identifiers", {
  climate <- app_climate()
  original <- app_counties()
  display <- app_display_counties()
  prepared <- prepare_climate_geometry(
    display,
    climate$county_lookup
  )

  expect_equal(nrow(display), 47L)
  expect_setequal(display$GID_1, original$GID_1)
  expect_equal(data.table::uniqueN(prepared$adm1_pcode), 47L)
  expect_false(anyNA(prepared$adm1_pcode))
  expect_equal(sf::st_crs(display)$epsg, 4326)
  expect_true(all(sf::st_is_valid(display)))
  expect_false(any(sf::st_is_empty(display)))
})

test_that("display simplification retains county parts and click locations", {
  original <- sf::st_as_sf(
    app_counties(),
    sf_column_name = "geometry"
  )
  original <- sf::st_transform(original, 6933)
  display <- sf::st_transform(app_display_counties(), 6933)

  original <- original[match(display$GID_1, original$GID_1), ]
  original_parts <- vapply(
    sf::st_geometry(original),
    length,
    integer(1)
  )
  display_parts <- vapply(
    sf::st_geometry(display),
    length,
    integer(1)
  )
  original_points <- sf::st_point_on_surface(
    sf::st_geometry(original)
  )
  point_matches <- sf::st_covered_by(
    original_points,
    sf::st_geometry(display),
    sparse = TRUE
  )

  expect_equal(display_parts, original_parts)
  expect_true(all(lengths(point_matches) == 1L))
  expect_lt(
    sum(lengths(sf::st_coordinates(display))),
    0.05 * sum(lengths(sf::st_coordinates(original)))
  )

  area_difference <- sum(as.numeric(sf::st_area(display))) -
    as.numeric(sf::st_area(sf::st_union(display)))
  expect_lt(abs(area_difference), 1)
  expect_equal(attr(app_display_counties(), "simplify_tolerance_m"), 1000)
})
