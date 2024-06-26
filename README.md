
<!-- README.md is generated from README.Rmd. Please edit that file -->

# kenyaFoodPrices

<!-- badges: start -->

[![R-CMD-check](https://github.com/m-mburu/kenyaFoodPrices/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/m-mburu/kenyaFoodPrices/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of kenyaFoodPrices is to …

## Installation

You can install the development version of kenyaFoodPrices from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
#devtools::install_github("m-mburu/kenyaFoodPrices")
```

``` r
library(kenyaFoodPrices)
library(ggplot2)
library(dplyr)
library(data.table)
data(ke_food_prices)
nairobi <- ke_food_prices[admin2 == "Nairobi" & pricetype == "Wholesale",]

admin2_select <- c("Nairobi", "Mombasa", "Nakuru", "Kisumu", "Eldoret")

nmk_counties <- ke_food_prices[admin2 %in% admin2_select]

# commodotiy Maize filter
nmk_counties_maize <- nmk_counties[commodity == "Maize" & pricetype == "Wholesale",]

## group by date and get the mean price
nmk_counties_maize[, .(mean_price = mean(price)), by = .(date, admin2)] %>%
    ggplot(aes(x = date, y = mean_price, color = admin2)) +
    geom_line() +
    labs(title = "Maize Prices in select Kenyan Towns",
         x = "Date",
         y = "Mean Price") +
    scale_x_date(date_labels = "%Y-%m", breaks = "24 month") +
    theme_minimal()+
    theme(legend.position = "bottom")
```

<img src="man/figures/README-unnamed-chunk-2-1.png" width="100%" />

``` r
library(lubridate)
#> 
#> Attaching package: 'lubridate'
#> The following objects are masked from 'package:data.table':
#> 
#>     hour, isoweek, mday, minute, month, quarter, second, wday, week,
#>     yday, year
#> The following objects are masked from 'package:base':
#> 
#>     date, intersect, setdiff, union
```

``` r

# Function to display the current time in a specific timezone
display_time_in_timezone <- function(timezone) {
  # Convert system time to specified timezone
  time_in_tz <- with_tz(Sys.time(), tzone = timezone)
  time_in_tz <- format(time_in_tz, "%Y-%m-%d %H:%M:%S")
  time_in_tz <- paste(time_in_tz, timezone)
  # Format system time and include the system's original timezone
  formatted_time <- sprintf("%s %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), Sys.timezone())
  
  # Combine and format the output using sprintf for better formatting
  output_message <- sprintf("Last Run On (Your System Timezone): %s\nLast Run On (Specified Timezone): %s", formatted_time, time_in_tz)
  
  # Print the result
  cat(output_message)
}

# Example usage of the function
display_time_in_timezone("Africa/Nairobi")
#> Last Run On (Your System Timezone): 2024-06-26 18:26:31 UTC
#> Last Run On (Specified Timezone): 2024-06-26 21:26:31 Africa/Nairobi
```

- **Thanks to WFP for providing the data on Humanitarian Data Exchange
  (HDX)**
