<#
.SYNOPSIS
    Runs the same steps as convert-and-publish.yml locally.
.DESCRIPTION
    Downloads specs, converts to markdown, builds the publish tree, creates
    windows-protocols.zip, and replaces the extracted corpus in the skill folder.
#>
param(
    [int]$ThrottleLimit = 4
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $root

try {
    # 1. Install oxipng (same as workflow)
    Write-Host 'Installing oxipng...'
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/oxipng/oxipng/releases/latest'
    $asset = $release.assets | Where-Object { $_.name -match 'x86_64-pc-windows-msvc\.zip$' } | Select-Object -First 1
    if (-not $asset) { throw 'Could not find Windows x86_64 zip asset in latest oxipng release.' }
    $zipPath = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
    $extractPath = Join-Path $env:TEMP 'oxipng'
    if (Test-Path -LiteralPath $extractPath) { Remove-Item -LiteralPath $extractPath -Recurse -Force }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
    $binPath = Get-ChildItem -LiteralPath $extractPath -Recurse -File -Filter 'oxipng.exe' | Select-Object -First 1
    if (-not $binPath) { throw 'oxipng.exe was not found after extracting.' }
    $binDir = Split-Path -Path $binPath.FullName -Parent
    $env:PATH = "$binDir;$env:PATH"
    & $binPath.FullName --version

    # 2. OpenXML - Build-Publish handles this
    # 3. Build publish tree
    Write-Host ''
    if (Test-Path -LiteralPath .\publish) {
        Remove-Item -LiteralPath .\publish -Recurse -Force
    }
    .\scripts\Build-Publish.ps1 -PublishPath publish -ThrottleLimit $ThrottleLimit -AllowPartial

    # 4. Stage zip in publish tree for the orphan publish branch equivalent.
    Write-Host 'Staging windows-protocols.zip in publish...'
    Copy-Item -LiteralPath .\windows-protocols.zip -Destination .\publish\windows-protocols.zip -Force

    # 5. Replace extracted skill corpus from the bundle. The zip remains ignored.
    Write-Host 'Replacing extracted corpus in skills/windows-protocols...'
    .\scripts\Replace-WindowsProtocolsCorpus.ps1 -ZipPath .\windows-protocols.zip -SkillPath .\skills\windows-protocols

    Write-Host 'Done. Corpus at: skills/windows-protocols'
}
finally {
    Pop-Location
}
