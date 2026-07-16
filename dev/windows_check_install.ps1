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
  [string]$TempRoot = "",
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

function Resolve-Rscript {
  $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }

  $rRoots = @("C:\Program Files\R", "C:\Program Files (x86)\R")
  foreach ($root in $rRoots) {
    if (-not (Test-Path $root)) {
      continue
    }

    $candidate = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending |
      ForEach-Object {
        Join-Path $_.FullName "bin\x64\Rscript.exe"
        Join-Path $_.FullName "bin\Rscript.exe"
      } |
      Where-Object { Test-Path $_ } |
      Select-Object -First 1

    if ($candidate) {
      return $candidate
    }
  }

  throw "Rscript was not found. Install R or add Rscript.exe to PATH."
}

function Invoke-R {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Expression
  )

  & $script:RscriptPath --vanilla -e $Expression
  if ($LASTEXITCODE -ne 0) {
    throw "Rscript failed while running: $Expression"
  }
}

function Copy-CheckSource {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir
  )

  $stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kenyaFoodPrices-check-" + [System.Guid]::NewGuid().ToString("N"))
  $stagePkg = Join-Path $stageRoot "kenyaFoodPrices"
  New-Item -ItemType Directory -Force -Path $stagePkg | Out-Null

  $excludeNames = @(".git", ".Rproj.user", "kenyaFoodPrices.Rcheck")
  Get-ChildItem -LiteralPath $SourceDir -Force | Where-Object {
    ($excludeNames -notcontains $_.Name) -and ($_.Name -notlike "*.tar.gz")
  } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $stagePkg -Recurse -Force
  }

  return $stagePkg
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
$script:RscriptPath = Resolve-Rscript
if ($TempRoot) {
  New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null
  $env:TEMP = $TempRoot
  $env:TMP = $TempRoot
}
Remove-Item Env:TMPDIR -ErrorAction SilentlyContinue

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
Write-Host "TEMP/TMP   : $env:TEMP"
Write-Host "Check dir  : $CheckDir"
Write-Host "Build dir  : $BuildDir"
Write-Host "Pandoc dir : $($env:RSTUDIO_PANDOC)"
Write-Host "Rscript    : $script:RscriptPath"

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
  $stagedPkg = Copy-CheckSource -SourceDir $repoRoot
  Write-Host "Check src  : $stagedPkg"
  $checkDirR = $CheckDir.Replace("\", "/")
  $stagedPkgR = $stagedPkg.Replace("\", "/")
  try {
    Invoke-R "devtools::check(pkg = '$stagedPkgR', check_dir = '$checkDirR')"
  } finally {
    if (Test-Path $stagedPkg) {
      Remove-Item -LiteralPath (Split-Path -Parent $stagedPkg) -Recurse -Force
    }
  }
}

$builtPackage = $null
if (-not $SkipBuild) {
  Write-Step "Building source package"
  New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
  $stagedBuildPkg = Copy-CheckSource -SourceDir $repoRoot
  Write-Host "Build src  : $stagedBuildPkg"
  $buildDirR = $BuildDir.Replace("\", "/")
  $stagedBuildPkgR = $stagedBuildPkg.Replace("\", "/")
  try {
    Invoke-R "devtools::build(pkg = '$stagedBuildPkgR', path = '$buildDirR')"
  } finally {
    if (Test-Path $stagedBuildPkg) {
      Remove-Item -LiteralPath (Split-Path -Parent $stagedBuildPkg) -Recurse -Force
    }
  }
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