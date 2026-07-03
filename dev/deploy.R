# Building a Prod-Ready, Robust Shiny Application.
#
# README: each step of the dev files is optional, and you don't have to
# fill every dev scripts before getting started.
# 01_start.R should be filled at start.
# 02_dev.R should be used to keep track of your development during the project.
# 03_deploy.R should be used once you need to deploy your app.
#
#
######################################
#### CURRENT FILE: DEPLOY SCRIPT #####
######################################

# Test your app

repo_url <- "https://cloud.r-project.org"
options(repos = c(RSPM = repo_url, CRAN = repo_url))
Sys.setenv(
  RSPM = repo_url,
  RENV_CONFIG_REPOS_OVERRIDE = paste0("RSPM=", repo_url, ";CRAN=", repo_url)
)

## Run checks ----
## Check the package before sending to prod
install.packages("stringr", repos = getOption("repos"))
#golem::add_shinyserver_file()




# Deploy to Posit Connect or ShinyApps.io
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
  forceUpdate = TRUE,
  packageRepositoryResolutionR = "lax",
  dependencyResolution = "library"
)
