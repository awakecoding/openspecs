<#
.SYNOPSIS
    Analyzes DOCX link metadata from Open Spec conversion for broken-link repair strategies.
.DESCRIPTION
    Converts a spec DOCX to markdown, dumps LinkMetadata (GuidToSection, InternalHyperlinks,
    SectionToTitle, GuidToGlossarySlug) to JSON, and reports which InternalHyperlink anchors
    could be resolved via SectionToTitle or glossary term matching.
.EXAMPLE
    .\Analyze-DocxLinkMetadata.ps1 -ProtocolId MS-RDPBCGR
.EXAMPLE
    .\Analyze-DocxLinkMetadata.ps1 -DocxPath path\to\[MS-RDPBCGR].docx
#>
[CmdletBinding()]
param(
    [Parameter(ParameterSetName = 'ByProtocol')]
    [string]$ProtocolId = 'MS-RDPBCGR',

    [Parameter(ParameterSetName = 'ByPath')]
    [string]$DocxPath,

    [string]$DownloadsPath = (Join-Path (Get-Location) 'downloads-convert'),
    [string]$OutputDir = (Join-Path (Get-Location) 'artifacts\docx-analysis')
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Get-Item $PSScriptRoot).Parent.FullName
$privateDir = Join-Path $repoRoot 'AwakeCoding.OpenSpecs\Private'
Get-ChildItem -LiteralPath $privateDir -Filter '*.ps1' | ForEach-Object { . $_.FullName }

if (-not (Test-Path -LiteralPath $OutputDir)) {
    [void](New-Item -Path $OutputDir -ItemType Directory -Force)
}

$docxFile = $null
if ($DocxPath) {
    if (-not (Test-Path -LiteralPath $DocxPath)) {
        throw "DOCX not found: $DocxPath"
    }
    $docxFile = $DocxPath
}
else {
    Import-Module (Join-Path $repoRoot 'AwakeCoding.OpenSpecs') -Force
    $dl = Save-OpenSpecDocument -ProtocolId $ProtocolId -Format DOCX -OutputPath $DownloadsPath -Force
    $docxFile = $dl.Path
    if (-not $docxFile -or -not (Test-Path -LiteralPath $docxFile)) {
        throw "Failed to download DOCX for $ProtocolId"
    }
}

$outMd = Join-Path $OutputDir "raw-$([System.IO.Path]::GetFileNameWithoutExtension($docxFile)).md"
$toolchain = [pscustomobject]@{ HasOpenXml = $false }

$result = ConvertFrom-OpenSpecDocxWithOpenXml -InputPath $docxFile -OutputPath $outMd -Toolchain $toolchain
$meta = $result.LinkMetadata

$metaPath = Join-Path $OutputDir "link-metadata.json"
$metaForJson = [ordered]@{
    GuidToSection = $meta.GuidToSection
    SectionToTitle = $meta.SectionToTitle
    TocAlias = $meta.TocAlias
    GuidToGlossarySlug = $meta.GuidToGlossarySlug
    InternalHyperlinksCount = @($meta.InternalHyperlinks).Count
    InternalHyperlinks = @($meta.InternalHyperlinks | Select-Object -First 500)
}
$metaForJson | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $metaPath -Encoding UTF8

Write-Host "`n=== Link Metadata Summary ==="
Write-Host "GuidToSection: $($meta.GuidToSection.Count)"
Write-Host "SectionToTitle: $($meta.SectionToTitle.Count)"
Write-Host "GuidToGlossarySlug: $($meta.GuidToGlossarySlug.Count)"
Write-Host "InternalHyperlinks: $(@($meta.InternalHyperlinks).Count)"
Write-Host "Metadata dumped to: $metaPath"

$sectionGuidRegex = [regex]::new('^(?:[Ss]ection_)?([a-f0-9]{32})$')
$gtGuidRegex = [regex]::new('^gt_([a-f0-9\-]{36})$', 'IgnoreCase')
$titleToSection = @{}
foreach ($entry in $meta.SectionToTitle.GetEnumerator()) {
    $title = ([string]$entry.Value -replace '\s+', ' ').Trim()
    if (-not [string]::IsNullOrWhiteSpace($title) -and -not $titleToSection.ContainsKey($title)) {
        $titleToSection[$title] = [string]$entry.Key
    }
}
$resolvableFromHyperlinks = [System.Collections.Generic.List[object]]::new()
$unresolvableSectionGuids = [System.Collections.Generic.List[string]]::new()
$unresolvableGtGuids = [System.Collections.Generic.List[string]]::new()

foreach ($link in @($meta.InternalHyperlinks)) {
    $anchor = [string]$link.Anchor
    $text = ([string]$link.Text -replace '\s+', ' ').Trim()

    $m = $sectionGuidRegex.Match($anchor)
    if ($m.Success) {
        $guid = $m.Groups[1].Value.ToLowerInvariant()
        if (-not $meta.GuidToSection.ContainsKey($guid)) {
            $matchedSection = $null
            foreach ($key in $titleToSection.Keys) {
                if ($key -eq $text) { $matchedSection = $titleToSection[$key]; break }
                $textEsc = [Management.Automation.WildcardPattern]::Escape($text)
                $keyEsc = [Management.Automation.WildcardPattern]::Escape($key)
                if ($key -like "*$textEsc*" -and $text.Length -ge 10) { $matchedSection = $titleToSection[$key]; break }
                if ($text -like "*$keyEsc*" -and $key.Length -ge 10) { $matchedSection = $titleToSection[$key]; break }
            }
            if ($matchedSection) {
                [void]$resolvableFromHyperlinks.Add([pscustomobject]@{ Type = 'Section'; Guid = $guid; Text = $text; MatchedSection = $matchedSection })
            }
            else {
                [void]$unresolvableSectionGuids.Add($guid)
            }
        }
    }
    else {
        $gtm = $gtGuidRegex.Match($anchor)
        if ($gtm.Success) {
            $guid = $gtm.Groups[1].Value.ToLowerInvariant()
            if (-not $meta.GuidToGlossarySlug.ContainsKey($guid)) {
                [void]$unresolvableGtGuids.Add($guid)
            }
        }
    }
}

Write-Host "`n=== Strategy A: InternalHyperlinks + SectionToTitle ==="
Write-Host "Resolvable (section guid -> section number via link text): $($resolvableFromHyperlinks.Count)"
foreach ($r in ($resolvableFromHyperlinks | Select-Object -First 10)) {
    Write-Host "  $($r.Guid) -> $($r.MatchedSection) (text: $($r.Text))"
}
if ($resolvableFromHyperlinks.Count -gt 10) {
    Write-Host "  ... and $($resolvableFromHyperlinks.Count - 10) more"
}
Write-Host "Unresolvable section GUIDs (no SectionToTitle match): $(($unresolvableSectionGuids | Select-Object -Unique).Count)"
Write-Host "Unresolvable glossary GUIDs: $(($unresolvableGtGuids | Select-Object -Unique).Count)"

$reportPath = Join-Path $OutputDir "analysis-report.txt"
@"
Docx: $docxFile
Generated: $(Get-Date -Format 'o')

Metadata: $metaPath

GuidToSection: $($meta.GuidToSection.Count)
SectionToTitle: $($meta.SectionToTitle.Count)
GuidToGlossarySlug: $($meta.GuidToGlossarySlug.Count)
InternalHyperlinks: $(@($meta.InternalHyperlinks).Count)

Strategy A - Resolvable from InternalHyperlinks: $($resolvableFromHyperlinks.Count)
Unresolvable section GUIDs: $(($unresolvableSectionGuids | Select-Object -Unique).Count)
Unresolvable glossary GUIDs: $(($unresolvableGtGuids | Select-Object -Unique).Count)
"@ | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Host "`nReport: $reportPath"
