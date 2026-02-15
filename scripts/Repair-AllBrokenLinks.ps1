<#
.SYNOPSIS
    Runs Section GUID and Glossary link repairs on all converted specs.
.DESCRIPTION
    Iterates over main .md files in converted-specs, runs Repair-OpenSpecSectionGuidLinksByHeadingMatch
    and Add-OpenSpecGlossaryAnchorsAndRepairLinks, and overwrites files when repairs are made.
.EXAMPLE
    .\Repair-AllBrokenLinks.ps1 -Path artifacts\converted-specs
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Path = (Join-Path (Get-Location) 'artifacts\converted-specs'),
    [switch]$WhatIf,
    [switch]$Parallel,
    [int]$ThrottleLimit = 8
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Get-Item $PSScriptRoot).Parent.FullName
$cleanupPath = Join-Path $repoRoot 'AwakeCoding.OpenSpecs\Private\Invoke-OpenSpecMarkdownCleanup.ps1'
if (-not (Test-Path -LiteralPath $cleanupPath)) {
    Write-Error "Cleanup script not found: $cleanupPath"
}
. $cleanupPath

$resolved = [System.IO.Path]::GetFullPath($Path)
if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
    Write-Error "Path not found: $resolved"
}

# Main spec files: <ProtocolId>/<ProtocolId>.md, exclude artifacts subdirs and reports
$specFiles = @(Get-ChildItem -LiteralPath $resolved -Directory | ForEach-Object {
    $dir = $_
    $name = $dir.Name
    $mdPath = Join-Path $dir.FullName "$name.md"
    if (Test-Path -LiteralPath $mdPath -PathType Leaf) { $mdPath }
} | Where-Object { $_ })

$useParallel = $Parallel -and $PSVersionTable.PSVersion.Major -ge 7 -and $specFiles.Count -gt 1
$whatIfArg = $WhatIf

if ($useParallel) {
    $results = $specFiles | ForEach-Object -Parallel {
        . $using:cleanupPath
        $mdPath = $_
        $content = Get-Content -LiteralPath $mdPath -Raw -Encoding UTF8
        $sectionResult = Repair-OpenSpecSectionGuidLinksByHeadingMatch -Markdown $content
        $content = $sectionResult.Markdown
        $glossaryResult = Add-OpenSpecGlossaryAnchorsAndRepairLinks -Markdown $content
        $content = $glossaryResult.Markdown
        $changed = ($sectionResult.LinksRepaired -gt 0) -or ($glossaryResult.AnchorsInjected -gt 0) -or ($glossaryResult.LinksRepaired -gt 0)
        if ($changed -and -not $using:whatIfArg) {
            Set-Content -LiteralPath $mdPath -Value $content -Encoding UTF8 -NoNewline
        }
        [pscustomobject]@{
            SectionRepaired = $sectionResult.LinksRepaired
            GlossaryRepaired = $glossaryResult.LinksRepaired
            AnchorsInjected = $glossaryResult.AnchorsInjected
            Updated = $changed -and -not $using:whatIfArg
            SpecName = [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($mdPath))
        }
    } -ThrottleLimit $ThrottleLimit

    $totalSection = ($results | Measure-Object -Property SectionRepaired -Sum).Sum
    $totalGlossary = ($results | Measure-Object -Property GlossaryRepaired -Sum).Sum
    $updated = ($results | Where-Object Updated).Count
    foreach ($r in ($results | Where-Object Updated)) {
        Write-Host "Updated: $($r.SpecName) (Section:$($r.SectionRepaired) Glossary:$($r.GlossaryRepaired)+$($r.AnchorsInjected))"
    }
}
else {
    $totalSection = 0
    $totalGlossary = 0
    $updated = 0
    foreach ($mdPath in $specFiles) {
        $content = Get-Content -LiteralPath $mdPath -Raw -Encoding UTF8
        $sectionResult = Repair-OpenSpecSectionGuidLinksByHeadingMatch -Markdown $content
        $content = $sectionResult.Markdown
        $totalSection += $sectionResult.LinksRepaired

        $glossaryResult = Add-OpenSpecGlossaryAnchorsAndRepairLinks -Markdown $content
        $content = $glossaryResult.Markdown
        $totalGlossary += $glossaryResult.LinksRepaired

        $changed = ($sectionResult.LinksRepaired -gt 0) -or ($glossaryResult.AnchorsInjected -gt 0) -or ($glossaryResult.LinksRepaired -gt 0)
        if ($changed -and -not $WhatIf) {
            Set-Content -LiteralPath $mdPath -Value $content -Encoding UTF8 -NoNewline
            $updated++
            $rel = [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($mdPath))
            Write-Host "Updated: $rel (Section:$($sectionResult.LinksRepaired) Glossary:$($glossaryResult.LinksRepaired)+$($glossaryResult.AnchorsInjected))"
        }
    }
}

Write-Host "`nTotal: Section GUID links repaired=$totalSection, Glossary links repaired=$totalGlossary, Files updated=$updated"
