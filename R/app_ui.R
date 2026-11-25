#' Assemble the dashboard navigation and shared controls
#'
#' @param request HTTP request supplied by Shiny when it builds the page.
#' @return A Shiny tag list comprising the resources, filter panel and tabs.
#' @import shinycssloaders
#' @importFrom DT DTOutput
#' @importFrom ggiraph girafeOutput
#' @importFrom plotly plotlyOutput
#' @importFrom shinycssloaders withSpinner
#' @importFrom shiny column div fluidPage fluidRow h3 h4 navbarPage
#'   p radioButtons selectInput tabPanel tagList uiOutput
#' @noRd
app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),
    shinyjs::useShinyjs(),
    shiny::tags$a(
      class = "kfp-skip-link",
      href = "#main-content",
      "Skip to main content"
    ),
    tags$div(
      id = "kfp-live-status",
      class = "sr-only",
      `aria-live` = "polite",
      `aria-atomic` = "true"
    ),
    tags$main(
      id = "main-content", `aria-label` = "Kenya Food Prices Dashboard",
      navbarPage(
        title = "Kenya Food Prices Dashboard",
        id = "main_nav",
        header = filters_module_ui("filters"),
        tabPanel("Overview", overview_module_ui("overview")),
        tabPanel("Trends", trends_module_ui("trends")),
        tabPanel(
          "Climate",
          fluidPage(
            climate_module_ui("climate")
          )
        ),
        tabPanel("Compare", compare_module_ui("compare")),
        tabPanel("Coverage", coverage_module_ui("coverage"))
      )
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @return Head tags with the bundled assets, metadata and analytics script.
#'   Registers the local assets directory with Shiny.
#' @importFrom shiny HTML tags
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path(
    "www",
    app_sys("app/www")
  )

  tags$head(
    favicon(),
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "kenyaFoodPrices"
    ),
    tags$script(
      async = NA,
      src = paste0(
        "https://www.googletagmanager.com/gtag/js?id=",
        "G-BFNZ97VTLJ"
      )
    ),
    tags$script(
      HTML(
        paste(
          "window.dataLayer = window.dataLayer || [];",
          "function gtag(){dataLayer.push(arguments);}",
          "gtag('js', new Date());",
          "gtag('config', 'G-BFNZ97VTLJ');",
          sep = "\n"
        )
      )
    ),
    tags$meta(
      name = "description",
      content = "Kenya food prices and climate conditions dashboard"
    )
  )
}
