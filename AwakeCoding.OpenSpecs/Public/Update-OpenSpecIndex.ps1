function Update-OpenSpecIndex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Title = 'Microsoft Open Specifications',

        [switch]$UseCatalogTitles = $true,

        [switch]$IncludeDescription = $false,

        [string[]]$OverviewProtocolIds = @()
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Output directory not found: $Path"
    }

    $overviewDocsUri = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-winprotlp/4a1806f9-2979-491d-af3c-f82ed0a4c1ba'
    $technicalDocsUri = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-winprotlp/e36c976a-6263-42a8-b119-7a3cc41ddd2a'
    $referenceDocsUri = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-winprotlp/1593dc07-6116-4e9e-8aeb-85c7438fab0a'

    $normalizeUri = {
        param([string]$Uri)
        if ([string]::IsNullOrWhiteSpace($Uri)) {
            return ''
        }
        return $Uri.Trim().TrimEnd('/').ToLowerInvariant()
    }

    $normalizedOverviewUri = & $normalizeUri $overviewDocsUri
    $normalizedReferenceUri = & $normalizeUri $referenceDocsUri

    $catalogMap = @{}
    if ($UseCatalogTitles) {
        try {
            $catalog = @(Get-OpenSpecCatalog -IncludeReferenceSpecs -IncludeOverviewDocs)
            foreach ($entry in $catalog) {
                $catalogMap[$entry.ProtocolId] = $entry
                $normalized = $entry.ProtocolId -replace '-', '_'
                if (-not $catalogMap[$normalized]) { $catalogMap[$normalized] = $entry }
            }
        }
        catch {
            Write-Warning "Could not fetch catalog for titles: $($_.Exception.Message). Using markdown fallback."
        }
    }

    $specDirs = Get-ChildItem -LiteralPath $Path -Directory | Sort-Object Name
    $entries = New-Object System.Collections.Generic.List[pscustomobject]
    $boilerplatePatterns = @('Intellectual Property Rights', 'Open Specifications Documentation')

    foreach ($dir in $specDirs) {
        $specName = $dir.Name
        $mdFile = Join-Path -Path $dir.FullName -ChildPath "$specName.md"

        if (-not (Test-Path -LiteralPath $mdFile)) {
            $mdFile = Join-Path -Path $dir.FullName -ChildPath 'README.md'
        }
        if (-not (Test-Path -LiteralPath $mdFile)) {
            $mdFile = Join-Path -Path $dir.FullName -ChildPath 'index.md'
        }

        if (-not (Test-Path -LiteralPath $mdFile)) {
            continue
        }

        $mdFileName = [System.IO.Path]::GetFileName($mdFile)
        $entryTitle = ''
        $description = ''

        $catalogEntry = $catalogMap[$specName]
        if ($catalogEntry) {
            $entryTitle = $catalogEntry.Title
            if ($IncludeDescription -and $catalogEntry.Description) {
                $description = $catalogEntry.Description
            }
        }

        if ([string]::IsNullOrWhiteSpace($entryTitle)) {
            $lines = Get-Content -LiteralPath $mdFile -TotalCount 30 -ErrorAction SilentlyContinue
            $protocolLabelRegex = [regex]::new('^\*\*\[?(?:MS|MC)-[A-Z0-9-]+\]?\s*:\s*\*\*$', 'IgnoreCase')
            $boldLineRegex = [regex]::new('^\*\*(.+)\*\*$')
            $foundLabel = $false
            foreach ($line in $lines) {
                if ($protocolLabelRegex.IsMatch($line.Trim())) {
                    $foundLabel = $true
                    continue
                }
                if ($foundLabel -and $boldLineRegex.IsMatch($line.Trim())) {
                    $candidate = ($line -replace '^\*\*(.+)\*\*$', '$1').Trim()
                    $isBoilerplate = $false
                    foreach ($pat in $boilerplatePatterns) {
                        if ($candidate -like "*$pat*") { $isBoilerplate = $true; break }
                    }
                    if (-not $isBoilerplate -and $candidate.Length -gt 2) {
                        $entryTitle = $candidate
                        break
                    }
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($entryTitle)) {
            $entryTitle = $specName
        }

        [void]$entries.Add([pscustomobject]@{
            Name        = $specName
            Title       = $entryTitle
            Description = $description
            Link        = "$specName/$mdFileName"
        })
    }

    $overviewIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($id in $OverviewProtocolIds) {
        $trimmed = $id.Trim()
        if ($trimmed) { [void]$overviewIds.Add($trimmed) }
    }

    $overviewEntries = New-Object System.Collections.Generic.List[object]
    $technicalEntries = New-Object System.Collections.Generic.List[object]
    $referenceEntries = New-Object System.Collections.Generic.List[object]

    foreach ($entry in $entries) {
        if ($overviewIds.Contains($entry.Name)) {
            [void]$overviewEntries.Add($entry)
            continue
        }

        $catalogEntry = $catalogMap[$entry.Name]
        $sourcePage = ''
        if ($catalogEntry -and $catalogEntry.PSObject.Properties.Match('SourcePage').Count -gt 0) {
            $sourcePage = & $normalizeUri $catalogEntry.SourcePage
        }

        if ($sourcePage -eq $normalizedOverviewUri) {
            [void]$overviewEntries.Add($entry)
        }
        elseif ($sourcePage -eq $normalizedReferenceUri) {
            [void]$referenceEntries.Add($entry)
        }
        else {
            [void]$technicalEntries.Add($entry)
        }
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# $Title")
    [void]$sb.AppendLine()
    $totalCount = $entries.Count
    [void]$sb.AppendLine("$totalCount documents converted to Markdown.")
    [void]$sb.AppendLine()

    $writeTable = {
        param($list, $includeDesc)
        if ($includeDesc) {
            [void]$sb.AppendLine('| Protocol | Title | Description |')
            [void]$sb.AppendLine('|---|---|---|')
            foreach ($entry in $list) {
                $descEscaped = ($entry.Description -replace '\|', ', ' -replace '\r?\n', ' ').Trim()
                [void]$sb.AppendLine("| [$($entry.Name)]($($entry.Link)) | $($entry.Title) | $descEscaped |")
            }
        }
        else {
            [void]$sb.AppendLine('| Protocol | Title |')
            [void]$sb.AppendLine('|---|---|')
            foreach ($entry in $list) {
                [void]$sb.AppendLine("| [$($entry.Name)]($($entry.Link)) | $($entry.Title) |")
            }
        }
    }

    [void]$sb.AppendLine('## Overview Documents')
    [void]$sb.AppendLine($overviewDocsUri)
    [void]$sb.AppendLine()
    & $writeTable $overviewEntries $IncludeDescription
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## Technical Documents')
    [void]$sb.AppendLine($technicalDocsUri)
    [void]$sb.AppendLine()
    & $writeTable $technicalEntries $IncludeDescription
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## Reference Documents')
    [void]$sb.AppendLine($referenceDocsUri)
    [void]$sb.AppendLine()
    & $writeTable $referenceEntries $IncludeDescription

    $readmePath = Join-Path -Path $Path -ChildPath 'README.md'
    $sb.ToString() | Set-Content -LiteralPath $readmePath -Encoding UTF8

    Write-Verbose "Generated index at $readmePath with $($entries.Count) entries."

    [pscustomobject]@{
        PSTypeName = 'AwakeCoding.OpenSpecs.IndexResult'
        Path       = $readmePath
        EntryCount = $entries.Count
    }
}
