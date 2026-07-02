<#
.SYNOPSIS
Run the Windows-safe package workflow for kenyaFoodPrices.

.DESCRIPTION
This script applies the local Windows fixes needed for this project before
running the package workflow:

1. Use C:\tmp as the R temp location so R CMD build does not hit long paths
   while staging the repository.
2. Point R Markdown at Quarto's bundled Pandoc when it is available.
3. Clear Unix-style LC_* locale variables that make R CMD check fail on
   Windows with DESCRIPTION metadata warnings.
4. Leave TMPDIR unset because Quarto on Windows can misread it when rmarkdown
   probes `quarto -V`.

The workflow is:
  document -> check in the current package directory -> build here -> install
#>

[CmdletBinding()]
param(
  [string]$TempRoot = "C:\tmp",
  [string]$CheckDir = "",
  [string]$BuildDir = "",
  [string]$PandocDir = "C:\Program Files\Quarto\bin\tools",
  [switch]$SkipDocument,
  [switch]$SkipCheck,
  [switch]$SkipBuild,
  [switch]$SkipInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-R {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Expression
  )

  & Rscript -e $Expression
  if ($LASTEXITCODE -ne 0) {
    throw "Rscript failed while running: $Expression"
  }
}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptPath "..")).Path
Set-Location $repoRoot

if (-not (Test-Path ".\DESCRIPTION")) {
  throw "DESCRIPTION was not found. Run this script from inside the package repository."
}

if (-not $CheckDir) {
  $CheckDir = $repoRoot
}

if (-not $BuildDir) {
  $BuildDir = $repoRoot
}

Write-Step "Preparing Windows check environment"
$env:TEMP = $TempRoot
$env:TMP = $TempRoot
Remove-Item Env:TMPDIR -ErrorAction SilentlyContinue


New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

foreach ($name in @("LC_COLLATE", "LC_CTYPE", "LC_MONETARY", "LC_TIME", "LC_ALL", "LANG")) {
  Remove-Item "Env:$name" -ErrorAction SilentlyContinue
}

if ((Test-Path (Join-Path $PandocDir "pandoc.exe")) -and -not $env:RSTUDIO_PANDOC) {
  $env:RSTUDIO_PANDOC = $PandocDir
}

if (-not $env:RSTUDIO_PANDOC -or -not (Test-Path (Join-Path $env:RSTUDIO_PANDOC "pandoc.exe"))) {
  throw "Pandoc was not found. Set -PandocDir or RSTUDIO_PANDOC to the folder containing pandoc.exe."
}

# Keep Pandoc available through RSTUDIO_PANDOC, but avoid the Quarto launcher
# during checks. On this Windows setup rmarkdown can pass TMPDIR to
# `quarto -V` in a way that Quarto treats as a command.
$env:PATH = ($env:PATH -split ";" | Where-Object {
  $_ -and ($_ -notmatch "Quarto[\\/]bin$")
}) -join ";"

Write-Host "Repository : $repoRoot"
Write-Host "TEMP/TMP   : $TempRoot"
Write-Host "Check dir  : $CheckDir"
Write-Host "Build dir  : $BuildDir"
Write-Host "Pandoc dir : $($env:RSTUDIO_PANDOC)"

Write-Step "Checking required R tooling"
Invoke-R "required <- c('devtools', 'rmarkdown', 'roxygen2'); missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]; if (length(missing)) stop('Install missing R packages first: ', paste(missing, collapse = ', '), call. = FALSE); cat('R tooling OK\n')"

if (-not $SkipDocument) {
  Write-Step "Documenting package"
  Invoke-R "devtools::document()"
}

if (-not $SkipCheck) {
  Write-Step "Checking package"
  $checkOutputDir = Join-Path $CheckDir "kenyaFoodPrices.Rcheck"
  if (Test-Path $checkOutputDir) {
    Remove-Item -LiteralPath $checkOutputDir -Recurse -Force
  }
  $checkDirR = $CheckDir.Replace("\", "/")
  Invoke-R "devtools::check(check_dir = '$checkDirR')"
}

$builtPackage = $null
if (-not $SkipBuild) {
  Write-Step "Building source package"
  New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
  $buildDirR = $BuildDir.Replace("\", "/")
  Invoke-R "devtools::build(path = '$buildDirR')"
  $builtPackage = Get-ChildItem -Path $BuildDir -Filter "kenyaFoodPrices_*.tar.gz" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName
}

if (-not $SkipInstall) {
  Write-Step "Installing package"
  if ($builtPackage -and (Test-Path $builtPackage)) {
    $builtPackageR = $builtPackage.Replace("\", "/")
    Invoke-R "install.packages('$builtPackageR', repos = NULL, type = 'source')"
  } else {
    Invoke-R "devtools::install(upgrade = 'never')"
  }
}

Write-Step "Done"
Write-Host "Windows package workflow completed successfully." -ForegroundColor Green
