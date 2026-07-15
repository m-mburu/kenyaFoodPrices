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

# Configure the package repository recorded in the deployment manifest.

repo_url <- "https://cloud.r-project.org"
options(repos = c(RSPM = repo_url, CRAN = repo_url))
Sys.setenv(
  RSPM = repo_url,
  RENV_CONFIG_REPOS_OVERRIDE = paste0("RSPM=", repo_url, ";CRAN=", repo_url)
)

# Deploy to Posit Connect or ShinyApps.io
rsconnect::setAccountInfo(name='mmburu',
                          token=Sys.getenv("RS_CONNECT_TOKEN"),
                          secret= Sys.getenv("RS_CONNECT_SECRET"))

# rsconnect 1.7 uses renv.lock strictly by default. Newer rsconnect releases
# expose equivalent controls as explicit arguments, so pass them when present.
deploy_args <- list(
  appName = desc::desc_get_field("Package"),
  appTitle = desc::desc_get_field("Package"),
  appFiles = c(
    # Add any additional files unique to your app here.
    "R/",
    "inst/",
    "data/",
    "NAMESPACE",
    "DESCRIPTION",
    "renv.lock",
    "app.R"
  ),
  appId = rsconnect::deployments(".")$appID,
  lint = FALSE,
  forceUpdate = TRUE
)

optional_deploy_args <- list(
  packageRepositoryResolutionR = "lax",
  dependencyResolution = "strict"
)
supported_args <- intersect(
  names(optional_deploy_args),
  names(formals(rsconnect::deployApp))
)
deploy_args[supported_args] <- optional_deploy_args[supported_args]

do.call(rsconnect::deployApp, deploy_args)
