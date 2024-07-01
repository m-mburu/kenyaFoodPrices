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
line_plot_prices <- function(mean_prices, commodity, pricetype) {

  # Create the line plot
  p <- ggplot(mean_prices, aes(x = year_quarter_date, y = mean_price)) +
    geom_line(color = "#2D708EFF" ) +
    labs(
      title = paste("Price of", commodity, "in Kenya (", pricetype, ")", sep = " "),
      x = "Date",
      y = "Mean Price"
    ) +
    #scale_color_brewer(palette = palette, type = "qual") +
    scale_x_date(date_labels = "%m/%y", breaks = "24 month") +
    theme_minimal() +
    theme(legend.position = "bottom")

  # Convert the ggplot object to a ggplotly object
  ggplotly(p)
}

#' Display the current time in a specific timezone
#'
#' This function takes a timezone as input and displays the current time in that timezone
#' along with the system's local time and timezone.
#'
#' @importFrom lubridate with_tz
#' @param timezone A character string specifying the timezone.
#' @return A character string with the formatted current times.
#' @examples
#' display_time_in_timezone("America/New_York")
#' @export

display_time_in_timezone <- function(timezone) {

  # Convert system time to specified timezone using lubridate::with_tz
  time_in_tz <- lubridate::with_tz(Sys.time(), tzone = timezone)
  time_in_tz <- format(time_in_tz, "%Y-%m-%d %H:%M:%S")
  time_in_tz <- paste(time_in_tz, timezone)

  # Format system time and include the system's original timezone using lubridate::Sys.timezone
  formatted_time <- sprintf("%s %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), Sys.timezone())

  # Combine and format the output using sprintf for better formatting
  output_message <- sprintf("Last Run On (Your System Timezone): %s\nLast Run On (Specified Timezone): %s", formatted_time, time_in_tz)

  # Print the result
  cat(output_message)
}



#' Sample Colors from the Viridis Palette
#'
#' This function randomly samples 'n' colors from the Viridis color palette,
#' which is designed to be perceptually uniform (in terms of human vision),
#' both in regular and colorblind vision. The palette generated includes 12 distinct colors.
#'
#' @importFrom scales viridis_pal
#' @param n The number of colors to sample from the palette.
#' @return A character vector of hexadecimal color values.
#' @examples
#' mycolors()  # Sample and print a single color from the Viridis palette
#' mycolors(5) # Sample and print five colors from the Viridis palette
#' @export
#'
mycolors <- function(n = 12){
  # Generate the full Viridis palette with 12 distinct colors
  full_palette <- viridis_pal()(12)

  # Sample 'n' colors from the generated palette
  sampled_colors <- sample(full_palette, size = n, replace = FALSE)

  return(sampled_colors)
}


#' Generate a Bar Plot for Time-Based Data Aggregations
#'
#' This function creates a bar plot for given dataframe, aggregated by time periods
#' such as months or quarters, using ggplot2 and optionally converts it to a
#' plotly object for interactivity.
#'
#' @importFrom ggplot2 ggplot aes_string geom_bar labs scale_fill_manual theme theme_minimal
#' @importFrom plotly ggplotly
#' @param df Data frame containing the data to plot.
#' @param time_var Name of the column in df that contains the time variable (e.g., "month" or "quarter").
#' @param price_var Name of the column in df that contains the price variable.
#' @param commodity Name of the commodity (for title generation).
#' @param pricetype Type of the price (for title generation).
#' @param interactive Logical, whether to convert the plot to an interactive plotly plot.
#' @param mytitle Title for the plot.
#' @param x_lab Label for the x-axis.
#' @param y_lab Label for the y-axis.
#' @return A ggplot or plotly object, depending on the 'interactive' flag.
#' @export
bar_plot_time <- function(df,
                          time_var,
                          price_var,
                          commodity,
                          pricetype,
                          interactive = TRUE,
                          mytitle =  "Mean Price per Month for",
                          x_lab = "Month",
                          y_lab = "Mean Price") {
  mytitle <- paste(mytitle, commodity,  pricetype)
  # Create the ggplot object
  p <- ggplot(df, aes(x = {{time_var}}, y = {{price_var}}, fill = {{time_var}})) +
    geom_bar(stat = "identity", width = .5) +
    labs(
      title =mytitle,
      x =x_lab,
      y =y_lab
    ) +
    scale_fill_manual(values =mycolors(n=12) ) +
    theme_minimal() +
    theme(legend.position = "none")

  # Convert to plotly if interactive is TRUE
  if (interactive) {
    p <- ggplotly(p)
  }

  return(p)
}

# library(ggplot2)
# library(data.table)
# iris <- iris
#
# setDT(iris)
#
# df <- iris[, .(mean_sepal_length = mean(Sepal.Length)), by = Species]
#
# bar_plot <- function(df, x, y, title, xlab, ylab) {
#
#   ggplot(data = df, aes(x = {{x}}, y = {{y}})) +
#     geom_bar(stat = "identity") +
#     labs(title = title, x = xlab, y = ylab)
# }
#
# bar_plot(df, Species, mean_sepal_length, "Mean Sepal Length by Species", "Species", "Mean Sepal Length")
