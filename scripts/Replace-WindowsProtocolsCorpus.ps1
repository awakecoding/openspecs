<#
.SYNOPSIS
    Replaces the protocol corpus in skills/windows-protocols with contents from a zip file.
.DESCRIPTION
    Removes all MS-* and MC-* directories from skills/windows-protocols, then extracts
    the specified windows-protocols.zip into that folder.
.PARAMETER ZipPath
    Path to the windows-protocols.zip file to extract.
.PARAMETER SkillPath
    Target skill folder (default: skills/windows-protocols).
.EXAMPLE
    .\Replace-WindowsProtocolsCorpus.ps1 -ZipPath .\windows-protocols.zip
.EXAMPLE
    .\Replace-WindowsProtocolsCorpus.ps1 -ZipPath C:\builds\windows-protocols.zip -SkillPath .\skills\windows-protocols
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ZipPath,

    [string]$SkillPath = (Join-Path (Join-Path (Get-Location) 'skills') 'windows-protocols')
)

$ErrorActionPreference = 'Stop'

$zipFull = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ZipPath))
$skillFull = [System.IO.Path]::GetFullPath($SkillPath)

if (-not (Test-Path -LiteralPath $zipFull -PathType Leaf)) {
    throw "Zip file not found: $zipFull"
}

if (-not (Test-Path -LiteralPath $skillFull -PathType Container)) {
    throw "Skill path not found: $skillFull"
}

Write-Host "Removing existing MS-* and MC-* directories from $skillFull ..."
$removed = 0
Get-ChildItem -LiteralPath $skillFull -Directory | Where-Object { $_.Name -like 'MS-*' -or $_.Name -like 'MC-*' } | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse -Force
    $removed++
    Write-Host "  Removed $($_.Name)"
}
Write-Host "Removed $removed directories."

Write-Host "Extracting $zipFull to $skillFull ..."
Expand-Archive -LiteralPath $zipFull -DestinationPath $skillFull -Force

Write-Host "Done. Corpus replaced."
