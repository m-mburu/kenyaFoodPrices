#' Generate Welcome Message
#'
#' This function generates an HTML welcome message for the Kenya Food Prices Dashboard.
#'
#' @return An HTML formatted welcome message to be displayed in the dashboard.
#' @examples
#' generate_welcome_message()
#' @export
generate_welcome_message <- function() {
  HTML(
    '<h4>Welcome to the Kenya Food Prices Dashboard!</h4>
    <p>This interactive tool allows users to explore detailed food price data across different regions and markets in Kenya. The data provided here is sourced from the <strong>World Food Programme\'s Price Database</strong>, which is part of their efforts to monitor food prices in different countries and contribute to global food security. Navigate to other tabs to visualize price trends, compare prices of different commodities, or view the geographical distribution of food prices. This dashboard aims to provide valuable insights for researchers, policymakers, and anyone interested in the dynamics of food markets in Kenya.</p>'
  )
}



#' Line Plot Prices
#'
#' This function creates a line plot of prices for a specified commodity and price type.
#'
#' @param data A data.table containing the food price data.
#' @param commodity The commodity to filter the data by.
#' @param pricetype The price type to filter the data by.
#' @param palette The color palette to use for the plot. Default is "Set1".
#' @importFrom plotly ggplotly
#' @return A plotly object containing the line plot.
#' @export
line_plot_prices <- function(mean_prices, commodity, pricetype, palette = "Set1") {

  # Create the line plot
  p <- ggplot(mean_prices, aes(x = year_quarter_date, y = mean_price)) +
    geom_line(color = "steelblue") +
    labs(
      title = paste("Price of", commodity, "in Kenya (", pricetype, ")", sep = " "),
      x = "Date",
      y = "Mean Price"
    ) +
    scale_color_brewer(palette = palette, type = "qual") +
    scale_x_date(date_labels = "%m/%y", breaks = "24 month") +
    theme_minimal() +
    theme(legend.position = "bottom")

  # Convert the ggplot object to a ggplotly object
  ggplotly(p)
}

