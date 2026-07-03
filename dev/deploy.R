cran_repo <- "https://cloud.r-project.org"
options(repos = c(RSPM = cran_repo, CRAN = cran_repo))
Sys.setenv(RSPM = cran_repo)
rsconnect::setAccountInfo(name='mmburu',
                          token=Sys.getenv("RS_CONNECT_TOKEN"),
                          secret= Sys.getenv("RS_CONNECT_SECRET"))

#golem::add_shinyappsio_file()
rsconnect::deployApp(
  appName = desc::desc_get_field("Package"),
  appTitle = desc::desc_get_field("Package"),
  appFiles = c(
    # Add any additional files unique to your app here.
    "R/",
    "inst/",
    "data/",
    "NAMESPACE",
    "DESCRIPTION",
    "app.R"
  ),
  appId = rsconnect::deployments(".")$appID,
  lint = FALSE,
  forceUpdate = TRUE
)
