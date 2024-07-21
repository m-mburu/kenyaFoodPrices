## code to prepare `my_dataset` dataset goes here


library(rhdx)
library(ggplot2)
library(dplyr)
library(data.table)

#remotes::install_github("dickoa/rhdx")

set_rhdx_config(hdx_site = "prod")

ke_food_prices <- pull_dataset("wfp-food-prices-for-kenya") %>%
  get_resource(1) %>%
  read_resource() %>%
  setDT()




# Function to create unique identifiers for GPS coordinates
create_unique_ids <- function(data) {
  # Create a combined column of longitude and latitude
  data[, coord := paste(longitude, latitude, sep = "_")]

  # Assign a unique identifier to each unique set of coordinates
  data[, unique_id := .GRP, by = coord]

  # Drop the combined coord column
  data[, coord := NULL]

  #return(data)
}

ke_food_prices[, year_month := format(date, "%Y-%m")]
ke_food_prices[, year_month_date := as.Date(paste(year_month, "-01", sep = ""))]
ke_food_prices[, year := format(date, "%Y")]
ke_food_prices[, month := format(date, "%b")]

months_levels <- c("Jan", "Feb", "Mar",
                   "Apr", "May", "Jun",
                   "Jul", "Aug", "Sep",
                   "Oct", "Nov", "Dec")

ke_food_prices[, month := factor(month, levels = months_levels)]
ke_food_prices[, quarter := quarter(date)]
ke_food_prices[, year_quarter := paste(year, quarter, sep = "-")]

ke_food_prices[, year_quarter_date := median(date), by = .(year_quarter)]

all_maize <- c("Maize", "Maize (white)", "Maize (white, dry)")

ke_food_prices[commodity %in% all_maize, commodity := "Maize"]

## grepl beans
#ke_food_prices[grepl("Beans", commodity), unique(commodity)]

# "Beans (dry)"  to "Beans"
ke_food_prices[commodity == "Beans (dry)", commodity := "Beans"]

ke_food_prices[grepl("Beans", commodity), table(commodity)]
ke_food_prices <- create_unique_ids(ke_food_prices)




load("data-raw/kenya_counties.rda")

library(sf)

# Function to assign counties to GPS coordinates
assign_counties <- function(data_points, counties_sf) {
  # Convert data points to an sf object
  data_points_sf <- data_points %>%
    distinct(unique_id, longitude, latitude)
  data_points_sf <- st_as_sf(data_points_sf, coords = c("longitude", "latitude"), crs = 4326)
  counties_sf <- st_set_geometry(counties_sf, "geometry")
  # Transform the coordinates to match the CRS of the counties
  data_points_transformed <- st_transform(data_points_sf, crs = st_crs(counties_sf))

  # Perform a spatial join to find which county each point falls into
  joined_data <- st_join(data_points_transformed, counties_sf, join = st_within)

  # Extract the county names or any relevant column from the joined data
  result <- joined_data %>%
    select(county, unique_id)

  return(result)
}

kenya_counties[, county := stringr::str_to_title(county)]

kenya_counties_ids <- assign_counties(ke_food_prices, kenya_counties)

setDT(kenya_counties_ids)

#delete geometry column
kenya_counties_ids[, geometry := NULL]

#stop("check data")
ke_food_prices <- merge(ke_food_prices, kenya_counties_ids, by = "unique_id", all.x = TRUE)
usethis::use_data(ke_food_prices, overwrite = TRUE)

checkhelper::use_data_doc("ke_food_prices")


usethis::use_data(kenya_counties_ids, overwrite = TRUE)

checkhelper::use_data_doc("kenya_counties_ids")

## kenya counties
usethis::use_data(kenya_counties, overwrite = TRUE)
checkhelper::use_data_doc("kenya_counties")

