# Run Add-OpenSpecGlossaryAnchorsAndRepairLinks on a spec file to fix gt_ GUID links.
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
$repoRoot = (Get-Item $PSScriptRoot).Parent.FullName
. (Join-Path $repoRoot 'AwakeCoding.OpenSpecs\Private\Invoke-OpenSpecMarkdownCleanup.ps1')
$md = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
$r = Add-OpenSpecGlossaryAnchorsAndRepairLinks -Markdown $md
Write-Host 'AnchorsInjected:' $r.AnchorsInjected 'LinksRepaired:' $r.LinksRepaired
if ($r.LinksRepaired -gt 0) {
    Set-Content -LiteralPath $Path -Value $r.Markdown -Encoding UTF8 -NoNewline
    Write-Host 'File updated.'
}
