<#
.SYNOPSIS
    Injects missing Section_N.N anchors into an already-converted spec using TOC titles.
.DESCRIPTION
    Runs Add-OpenSpecMissingSectionAnchorsFromToc on the given markdown file and overwrites it.
    Use this to fix "Section_X.Y.Z (numeric)" broken links without reconverting from DOCX.
.EXAMPLE
    .\Repair-MissingSectionAnchors.ps1 -Path artifacts\converted-specs\MS-RDPBCGR\MS-RDPBCGR.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Invoke-MarkdownCleanupTransform.ps1')
$result = Invoke-MarkdownCleanupTransform -Path $Path -TransformFunction 'Add-OpenSpecMissingSectionAnchorsFromToc'
if ($result.InjectedCount -gt 0) {
    Save-MarkdownCleanupTransformResult -Path $Path -Markdown $result.Markdown
    $fullPath = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
    Write-Host "Injected $($result.InjectedCount) missing section anchor(s). File updated: $fullPath"
} else {
    Write-Host "No missing section anchors to inject."
}
