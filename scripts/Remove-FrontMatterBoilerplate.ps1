# One-off: run Remove-OpenSpecFrontMatterBoilerplate on a spec file.
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Invoke-MarkdownCleanupTransform.ps1')
$r = Invoke-MarkdownCleanupTransform -Path $Path -TransformFunction 'Remove-OpenSpecFrontMatterBoilerplate'
Write-Host 'Removed:' $r.Removed
if ($r.Removed) {
    Save-MarkdownCleanupTransformResult -Path $Path -Markdown $r.Markdown
}
