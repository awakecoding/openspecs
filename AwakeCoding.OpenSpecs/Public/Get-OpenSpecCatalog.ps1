$script:OpenSpecReferenceDocsUri = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-winprotlp/1593dc07-6116-4e9e-8aeb-85c7438fab0a'
$script:OpenSpecOverviewDocsUri = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-winprotlp/4a1806f9-2979-491d-af3c-f82ed0a4c1ba'

# Reference specs (MS-DTYP, MS-ERREF, MS-LCID, MS-UCODEREF) from https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-winprotlp/1593dc07-6116-4e9e-8aeb-85c7438fab0a
$script:OpenSpecReferenceSpecs = @(
    [pscustomobject]@{ ProtocolId = 'MS-DTYP'; Title = 'Windows Data Types'; Slug = 'ms-dtyp'; SpecPageUrl = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/cca27429-5689-4a16-b2b4-9325d93e4ba2' }
    [pscustomobject]@{ ProtocolId = 'MS-ERREF'; Title = 'Windows Error Codes'; Slug = 'ms-erref'; SpecPageUrl = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/1bc92ddf-b79e-413c-bbaa-99a5281a6c90' }
    [pscustomobject]@{ ProtocolId = 'MS-LCID'; Title = 'Windows Language Code Identifier (LCID) Reference'; Slug = 'ms-lcid'; SpecPageUrl = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-lcid/70feba9f-294e-491e-b6eb-56532684c37f' }
    [pscustomobject]@{ ProtocolId = 'MS-UCODEREF'; Title = 'Windows Protocols Unicode Reference'; Slug = 'ms-ucoderef'; SpecPageUrl = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-ucoderef/4a045e08-fc29-4f22-baf4-16f38c2825fb' }
)

function Get-OpenSpecCatalog {
    [CmdletBinding()]
    param(
        [string]$Uri = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/MS-WINPROTLP/e36c976a-6263-42a8-b119-7a3cc41ddd2a',
        [switch]$IncludeReferenceSpecs,
        [switch]$IncludeOverviewDocs
    )

    $rowRegex = [regex]::new('(?is)<tr[^>]*>(?<row>.*?)</tr>')
    $specLinkRegex = [regex]::new(
        '(?is)<a\b[^>]*href\s*=\s*["''](?<href>\.\./(?<slug>(?:ms|mc)-[a-z0-9-]+)/(?<guid>[0-9a-f-]{36}))(?:["''][^>]*)?>(?<text>.*?)</a>'
    )
    $idRegex = [regex]::new('\[(?<id>(?:MS|MC)-[A-Z0-9-]+)\]', 'IgnoreCase')
    $cellRegex = [regex]::new('(?is)<td[^>]*>(?<content>.*?)</td>')

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $entries = New-Object System.Collections.Generic.List[object]

    $addFromPage = {
        param(
            [string]$SourceUri,
            [switch]$AllowFallback
        )

        $response = Invoke-OpenSpecRequest -Uri $SourceUri
        $html = $response.Content
        $addedCount = 0

        foreach ($rowMatch in $rowRegex.Matches($html)) {
            $rowHtml = $rowMatch.Groups['row'].Value
            $linkMatch = $specLinkRegex.Match($rowHtml)
            if (-not $linkMatch.Success) {
                continue
            }

            $labelText = ConvertFrom-OpenSpecHtml -Html $linkMatch.Groups['text'].Value
            $idMatch = $idRegex.Match($labelText)
            if (-not $idMatch.Success) {
                continue
            }

            $protocolId = $idMatch.Groups['id'].Value.ToUpperInvariant()
            if (-not $seen.Add($protocolId)) {
                continue
            }

            $slug = $linkMatch.Groups['slug'].Value.ToLowerInvariant()
            $specPageUrl = Resolve-OpenSpecAbsoluteUrl -BaseUrl $SourceUri -RelativeOrAbsoluteUrl ([System.Net.WebUtility]::HtmlDecode($linkMatch.Groups['href'].Value))
            $title = ($labelText -replace '^\s*\[(?:MS|MC)-[A-Z0-9-]+\]\s*:\s*', '').Trim()
            if ([string]::IsNullOrWhiteSpace($title)) {
                $title = $protocolId
            }

            $description = ''
            $cells = [regex]::Matches($rowHtml, $cellRegex)
            if ($cells.Count -ge 2) {
                $description = (ConvertFrom-OpenSpecHtml -Html $cells[1].Groups['content'].Value).Trim()
            }

            $entries.Add([pscustomobject]@{
                PSTypeName = 'AwakeCoding.OpenSpecs.Entry'
                ProtocolId = $protocolId
                Title = $title
                Description = $description
                SpecPageUrl = $specPageUrl
                Slug = $slug
                SourcePage = $SourceUri
            })
            $addedCount++
        }

        if ($AllowFallback -and $addedCount -eq 0) {
            $protocolPattern = '\[(?<id>(?:MS|MC)-[A-Z0-9-]+)\]'
            $idMatches = [regex]::Matches($html, $protocolPattern, 'IgnoreCase')
            $protocolIds = $idMatches |
                ForEach-Object { $_.Groups['id'].Value.ToUpperInvariant() } |
                Sort-Object -Unique

            foreach ($protocolId in $protocolIds) {
                if (-not $seen.Add($protocolId)) {
                    continue
                }

                $entries.Add([pscustomobject]@{
                    PSTypeName = 'AwakeCoding.OpenSpecs.Entry'
                    ProtocolId = $protocolId
                    Title = $protocolId
                    Description = ''
                    SpecPageUrl = "https://learn.microsoft.com/en-us/openspecs/windows_protocols/$($protocolId.ToLowerInvariant())"
                    Slug = $protocolId.ToLowerInvariant()
                    SourcePage = $SourceUri
                })
            }
        }
    }

    & $addFromPage -SourceUri $Uri -AllowFallback

    if ($IncludeOverviewDocs) {
        & $addFromPage -SourceUri $script:OpenSpecOverviewDocsUri
    }

    if ($IncludeReferenceSpecs) {
        foreach ($ref in $script:OpenSpecReferenceSpecs) {
            if ($seen.Add($ref.ProtocolId)) {
                $entries.Add([pscustomobject]@{
                    PSTypeName = 'AwakeCoding.OpenSpecs.Entry'
                    ProtocolId = $ref.ProtocolId
                    Title = $ref.Title
                    Description = ''
                    SpecPageUrl = $ref.SpecPageUrl
                    Slug = $ref.Slug
                    SourcePage = $script:OpenSpecReferenceDocsUri
                })
            }
        }
    }

    $entries
}
