<#
.SYNOPSIS
    Builds the publish tree the same way convert-and-publish.yml does, for local validation.
.DESCRIPTION
    Downloads all Open Specs DOCX, converts to markdown, repairs broken links,
    builds the publish directory, generates the README index, and optionally creates
    Windows_Protocols.zip (Microsoft publishes a PDF zip with the same name; this is the markdown equivalent).
    Use -Filter for faster local iteration (e.g. -Filter 'MS-RDP' for RDP-related specs).
.EXAMPLE
    .\Build-Publish.ps1
    .\Build-Publish.ps1 -ZipPath ''  # skip zip, publish folder only
.EXAMPLE
    .\Build-Publish.ps1 -Filter 'MS-RDP'  # RDP-related specs only (faster local iteration)
.EXAMPLE
    .\Build-Publish.ps1 -Filter 'MS-RDP','MS-NLMP','MS-KILE'  # RDP + auth specs
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Get-Location),
    [string]$DownloadsPath = 'downloads-convert',
    [string]$ConvertedPath = 'converted-specs',
    [string]$PublishPath = 'publish',
    [string]$ZipPath = 'Windows_Protocols.zip',
    [string]$IndexTitle = 'Microsoft Open Specifications',
    [string[]]$Filter = @(),
    [int]$ThrottleLimit = 8,
    [switch]$SkipOpenXmlInstall
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path -LiteralPath $WorkspaceRoot

if (-not $SkipOpenXmlInstall) {
    Write-Host 'Ensuring OpenXML module is installed...'
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    if (-not (Get-Module -ListAvailable -Name OpenXML)) {
        Install-Module -Name OpenXML -Force -Scope CurrentUser
    }
}

Push-Location $root
try {
    $dlPath = Join-Path $root $DownloadsPath
    $convPath = Join-Path $root $ConvertedPath
    $pubPath = Join-Path $root $PublishPath

    Write-Host 'Importing module and downloading catalog...'
    Import-Module (Join-Path $root 'AwakeCoding.OpenSpecs') -Force

    Write-Host 'Downloading DOCX files...'
    $catalog = Get-OpenSpecCatalog -IncludeReferenceSpecs
    $patterns = @()
    if ($Filter.Count -gt 0) {
        $patterns = @($Filter | Where-Object { $_ } | ForEach-Object {
            if ($_ -match '[*?\[\]]') { $_ } else { "$_*" }
        })
    }
    if ($patterns.Count -gt 0) {
        $catalog = $catalog | Where-Object {
            $protocolId = $_.ProtocolId
            foreach ($p in $patterns) {
                if ($protocolId -like $p) { return $true }
            }
            return $false
        }
        Write-Host "Filter ($($Filter -join ', ')) -> $($catalog.Count) specs"
    }
    $downloadResults = $catalog |
        Save-OpenSpecDocument -Format DOCX -OutputPath $dlPath -Force -Parallel -ThrottleLimit $ThrottleLimit |
        Where-Object { $_.Status -in 'Downloaded', 'Exists' }

    $toConvert = @($downloadResults)
    Write-Host "Convert: $($toConvert.Count) specs"

    Write-Host 'Converting to markdown (parallel)...'
    $toConvert | Convert-OpenSpecToMarkdown -OutputPath $convPath -Force -Parallel -ThrottleLimit $ThrottleLimit | Out-Null

    Write-Host 'Repairing broken links...'
    $repairScript = Join-Path $root 'scripts\Repair-AllBrokenLinks.ps1'
    & $repairScript -Path $convPath -Parallel -ThrottleLimit $ThrottleLimit

    Write-Host 'Building publish directory...'
    New-Item -Path $pubPath -ItemType Directory -Force | Out-Null

    Get-ChildItem -LiteralPath $convPath -Directory | ForEach-Object {
        $name = $_.Name
        $md = Join-Path $_.FullName "$name.md"
        if (-not (Test-Path -LiteralPath $md)) { $md = Join-Path $_.FullName 'README.md' }
        if (-not (Test-Path -LiteralPath $md)) { $md = Join-Path $_.FullName 'index.md' }
        if (-not (Test-Path -LiteralPath $md)) { return }

        $dest = Join-Path $pubPath $name
        New-Item -Path $dest -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath $md -Destination $dest -Force

        $media = Join-Path $_.FullName 'media'
        if (Test-Path -LiteralPath $media -PathType Container) {
            Copy-Item -LiteralPath $media -Destination $dest -Recurse -Force
        }
    }

    $legalSource = Join-Path (Join-Path $convPath '_legal') 'LEGAL.md'
    $legalFallback = Join-Path (Join-Path (Join-Path $root 'scripts') 'templates') 'LEGAL.md'
    $legalDest = Join-Path $pubPath 'LEGAL.md'
    if (Test-Path -LiteralPath $legalSource) {
        Copy-Item -LiteralPath $legalSource -Destination $legalDest -Force
    }
    elseif (Test-Path -LiteralPath $legalFallback) {
        Copy-Item -LiteralPath $legalFallback -Destination $legalDest -Force
    }
    else {
        Write-Warning 'LEGAL.md was not created (filter may have excluded MS-DTYP). Add scripts/templates/LEGAL.md as fallback.'
    }

    Write-Host 'Updating index (README.md)...'
    Update-OpenSpecIndex -Path $pubPath -Title $IndexTitle

    Write-Host 'Optimizing publish PNG files...'
    $optimizePngScript = Join-Path $root 'scripts\Optimize-PublishPng.ps1'
    if (Test-Path -LiteralPath $optimizePngScript -PathType Leaf) {
        & $optimizePngScript -PublishPath $pubPath -ThrottleLimit $ThrottleLimit | Out-Null
    }
    else {
        Write-Warning "PNG optimization script not found: $optimizePngScript"
    }

    if ($ZipPath) {
        $zipFull = if ([System.IO.Path]::IsPathRooted($ZipPath)) { $ZipPath } else { Join-Path $root $ZipPath }
        Write-Host "Creating $zipFull ..."
        Compress-Archive -Path (Join-Path $pubPath '*') -DestinationPath $zipFull -Force
        Write-Host "Zip created: $zipFull"
    }

    $entryCount = (Get-Content (Join-Path $pubPath 'README.md') | Select-String '^\| \[.*\]').Count
    Write-Host "Done. Publish folder: $pubPath ($entryCount specs)"
}
finally {
    Pop-Location
}
