# Run Repair-OpenSpecSectionGuidLinksByHeadingMatch on a spec file.
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Invoke-MarkdownCleanupTransform.ps1')
$r = Invoke-MarkdownCleanupTransform -Path $Path -TransformFunction 'Repair-OpenSpecSectionGuidLinksByHeadingMatch'
Write-Host 'LinksRepaired:' $r.LinksRepaired
if ($r.LinksRepaired -gt 0) {
    Save-MarkdownCleanupTransformResult -Path $Path -Markdown $r.Markdown
}
