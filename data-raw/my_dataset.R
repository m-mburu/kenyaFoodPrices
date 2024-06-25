## code to prepare `my_dataset` dataset goes here


#library(rhdx)
library(ggplot2)
library(dplyr)
library(data.table)

#remotes::install_github("dickoa/rhdx")

# set_rhdx_config(hdx_site = "prod")
#
# ke_food_prices <- pull_dataset("wfp-food-prices-for-kenya") %>%
#   get_resource(1) %>%
#   read_resource() %>%
#   setDT()

ke_food_prices <- fread("data_raw/ke_food_prices.csv")

usethis::use_data(ke_food_prices, overwrite = TRUE)

checkhelper::use_data_doc("ke_food_prices")
