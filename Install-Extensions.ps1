<#
.SYNOPSIS
    Downloads and installs Visual Studio extensions listed in extensions.json.

.DESCRIPTION
    Reads an extensions.json file (array of { "name": "...", "url": "https://marketplace.visualstudio.com/items?itemName=Publisher.Extension" }),
    converts each Marketplace "items" page URL into its VSIX download URL, downloads the .vsix,
    and installs it silently using VSIXInstaller.exe (found via vswhere).

    Entries with no "url" field (built-in components, or ones without a resolvable Marketplace link)
    are skipped automatically and listed at the end.

.PARAMETER JsonPath
    Path to the extensions.json file. Defaults to .\extensions.json.

.PARAMETER DownloadFolder
    Folder to download .vsix files into. Defaults to .\vsix-downloads.

.EXAMPLE
    .\Install-Extensions.ps1
    .\Install-Extensions.ps1 -JsonPath C:\temp\extensions.json
#>

[CmdletBinding()]
param(
    [string]$JsonPath = ".\extensions.json",
    [string]$DownloadFolder = ".\vsix-downloads"
)

$ErrorActionPreference = "Stop"

function Get-VsixInstallerPath {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        throw "vswhere.exe not found at '$vswhere'. Is Visual Studio installed?"
    }

    $vsInstallPath = & $vswhere -latest -property installationPath
    if (-not $vsInstallPath) {
        throw "Could not determine a Visual Studio installation path via vswhere."
    }

    $vsixInstaller = Join-Path $vsInstallPath "Common7\IDE\VSIXInstaller.exe"
    if (-not (Test-Path $vsixInstaller)) {
        throw "VSIXInstaller.exe not found at '$vsixInstaller'."
    }

    return $vsixInstaller
}

function Get-ItemNameFromMarketplaceUrl {
    param([string]$Url)

    # Expected form: https://marketplace.visualstudio.com/items?itemName=Publisher.Extension
    if ($Url -notmatch "marketplace\.visualstudio\.com") {
        return $null
    }

    try {
        $uri = [System.Uri]$Url
        $query = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
        return $query["itemName"]
    } catch {
        return $null
    }
}

function Get-VsixDownloadUrl {
    param([string]$ItemName)

    # ItemName is "Publisher.Extension"
    $parts = $ItemName.Split(".", 2)
    if ($parts.Count -ne 2) {
        return $null
    }
    $publisher  = $parts[0]
    $extension  = $parts[1]

    return "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/$publisher/vsextensions/$extension/latest/vspackage"
}

# --- Main ---

Add-Type -AssemblyName System.Web

if (-not (Test-Path $JsonPath)) {
    throw "extensions.json not found at '$JsonPath'."
}

$extensions = Get-Content -Raw -Path $JsonPath | ConvertFrom-Json

if (-not (Test-Path $DownloadFolder)) {
    New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
}

$vsixInstaller = Get-VsixInstallerPath
Write-Host "Using VSIXInstaller: $vsixInstaller" -ForegroundColor Cyan

$installed = @()
$failed    = @()
$skipped   = @()

foreach ($ext in $extensions) {

    $name = $ext.name
    $url  = $ext.url

    if (-not $url) {
        Write-Host "Skipping '$name' - no Marketplace URL provided." -ForegroundColor Yellow
        $skipped += $name
        continue
    }

    $itemName = Get-ItemNameFromMarketplaceUrl -Url $url
    if (-not $itemName) {
        Write-Host "Skipping '$name' - could not resolve itemName from URL: $url" -ForegroundColor Yellow
        $skipped += $name
        continue
    }

    $downloadUrl = Get-VsixDownloadUrl -ItemName $itemName
    if (-not $downloadUrl) {
        Write-Host "Skipping '$name' - could not build download URL for itemName '$itemName'." -ForegroundColor Yellow
        $skipped += $name
        continue
    }

    $safeFileName = ($itemName -replace "[^\w\.-]", "_") + ".vsix"
    $outFile = Join-Path $DownloadFolder $safeFileName

    try {
        Write-Host "Downloading '$name' ($itemName)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $downloadUrl -OutFile $outFile -UseBasicParsing

        Write-Host "Installing '$name'..." -ForegroundColor Cyan
        # /quiet = silent, no UI; /admin = elevate for all-users install if needed
        $proc = Start-Process -FilePath $vsixInstaller -ArgumentList "/quiet", "`"$outFile`"" -Wait -PassThru

        # VSIXInstaller exit codes: 0 = success, 1001 = already installed / needs no action
        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 1001) {
            Write-Host "Installed '$name' (exit code $($proc.ExitCode))." -ForegroundColor Green
            $installed += $name
        } else {
            Write-Host "VSIXInstaller returned exit code $($proc.ExitCode) for '$name'." -ForegroundColor Red
            $failed += $name
        }
    } catch {
        Write-Host "Failed to download/install '$name': $($_.Exception.Message)" -ForegroundColor Red
        $failed += $name
    }
}

Write-Host ""
Write-Host "===== Summary =====" -ForegroundColor White
Write-Host ("Installed ({0}): {1}" -f $installed.Count, ($installed -join ", "))
Write-Host ("Failed ({0}): {1}"    -f $failed.Count,    ($failed -join ", "))
Write-Host ("Skipped ({0}): {1}"   -f $skipped.Count,   ($skipped -join ", "))
