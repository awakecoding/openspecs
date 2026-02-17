function Invoke-RepairAllBrokenLinksFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$CleanupPath,

        [switch]$WhatIf
    )

    if (-not (Get-Command -Name 'Repair-OpenSpecSectionGuidLinksByHeadingMatch' -CommandType Function -ErrorAction SilentlyContinue)) {
        . $CleanupPath
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $sectionResult = Repair-OpenSpecSectionGuidLinksByHeadingMatch -Markdown $content
    $content = $sectionResult.Markdown

    $glossaryResult = Add-OpenSpecGlossaryAnchorsAndRepairLinks -Markdown $content
    $content = $glossaryResult.Markdown

    $changed = ($sectionResult.LinksRepaired -gt 0) -or ($glossaryResult.AnchorsInjected -gt 0) -or ($glossaryResult.LinksRepaired -gt 0)
    if ($changed -and -not $WhatIf) {
        Set-Content -LiteralPath $Path -Value $content -Encoding UTF8 -NoNewline
    }

    [pscustomobject]@{
        SectionRepaired = $sectionResult.LinksRepaired
        GlossaryRepaired = $glossaryResult.LinksRepaired
        AnchorsInjected = $glossaryResult.AnchorsInjected
        Updated = $changed -and -not $WhatIf
        SpecName = [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($Path))
    }
}
