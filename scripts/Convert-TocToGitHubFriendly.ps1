# Run ConvertTo-OpenSpecGitHubFriendlyToc on a spec file.
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Invoke-MarkdownCleanupTransform.ps1')
$r = Invoke-MarkdownCleanupTransform -Path $Path -TransformFunction 'ConvertTo-OpenSpecGitHubFriendlyToc'
Write-Host 'Rewritten:' $r.Rewritten
if ($r.Rewritten) {
    Save-MarkdownCleanupTransformResult -Path $Path -Markdown $r.Markdown
}
