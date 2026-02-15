[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DocxPath,

    [Parameter(Mandatory)]
    [string]$OutputMarkdownPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Get-Item $PSScriptRoot).Parent.FullName
$privateDir = Join-Path $repoRoot 'AwakeCoding.OpenSpecs\Private'
Get-ChildItem -LiteralPath $privateDir -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
}

$toolchain = [pscustomobject]@{
    HasOpenXml = $false
}

try {
    $result = ConvertFrom-OpenSpecDocxWithOpenXml -InputPath $DocxPath -OutputPath $OutputMarkdownPath -Toolchain $toolchain
}
catch {
    Write-Host "Exception type: $($_.Exception.GetType().FullName)"
    Write-Host "Message: $($_.Exception.Message)"
    if ($_.InvocationInfo) {
        Write-Host "Position: $($_.InvocationInfo.PositionMessage)"
    }
    if ($_.ScriptStackTrace) {
        Write-Host "Stack:"
        Write-Host $_.ScriptStackTrace
    }
    if ($_.Exception.InnerException) {
        Write-Host "Inner: $($_.Exception.InnerException.GetType().FullName): $($_.Exception.InnerException.Message)"
    }
    throw
}

if (-not $result.PSObject.Properties['LinkMetadata']) {
    throw 'LinkMetadata was not returned from DOCX conversion step.'
}

$meta = $result.LinkMetadata
Write-Host "GuidToSection: $($meta.GuidToSection.Count)"
Write-Host "SectionToTitle: $($meta.SectionToTitle.Count)"
Write-Host "TocAlias: $($meta.TocAlias.Count)"
Write-Host "GuidToGlossarySlug: $($meta.GuidToGlossarySlug.Count)"
Write-Host "InternalHyperlinks: $(@($meta.InternalHyperlinks).Count)"
