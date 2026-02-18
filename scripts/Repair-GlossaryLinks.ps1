# Run Add-OpenSpecGlossaryAnchorsAndRepairLinks on a spec file to fix gt_ GUID links.
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Invoke-MarkdownCleanupTransform.ps1')
$r = Invoke-MarkdownCleanupTransform -Path $Path -TransformFunction 'Add-OpenSpecGlossaryAnchorsAndRepairLinks'
Write-Host 'AnchorsInjected:' $r.AnchorsInjected 'LinksRepaired:' $r.LinksRepaired
if ($r.LinksRepaired -gt 0) {
    Save-MarkdownCleanupTransformResult -Path $Path -Markdown $r.Markdown
}
