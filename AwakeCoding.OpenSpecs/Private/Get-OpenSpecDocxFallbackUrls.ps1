# Returns fallback DOCX URLs for a protocol by fetching its RSS feed.
# Used when the primary Learn-page link fails (e.g. stale dates on MS-THCH, MS-MQOD).
# Azure Front Door works when blob storage returns 404; we try it first, then blob.
function Get-OpenSpecDocxFallbackUrls {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProtocolId
    )

    $rssBase = 'https://winprotocoldocs-bhdugrdyduf5h2e4.b02.azurefd.net'
    $encodedBrackets = [System.Uri]::EscapeDataString("[$ProtocolId]")
    $rssUrl = "$rssBase/$ProtocolId/$encodedBrackets.rss"

    try {
        $response = Invoke-WebRequest -Uri $rssUrl -MaximumRedirection 8 -TimeoutSec 30 -ErrorAction Stop
    }
    catch {
        Write-Verbose "RSS fetch failed for $ProtocolId : $($_.Exception.Message)"
        return @()
    }

    $content = $response.Content
    if ($content -is [byte[]]) {
        $content = [System.Text.Encoding]::UTF8.GetString($content)
    }
    # Strip BOM if present (can break XML parsing)
    if ($content.Length -gt 0 -and [int][char]$content[0] -eq 0xFEFF) {
        $content = $content.Substring(1)
    }
    try {
        [xml]$xml = $content
    }
    catch {
        Write-Verbose "RSS parse failed for $ProtocolId : $($_.Exception.Message)"
        return @()
    }

    $items = $xml.SelectNodes('//item')
    if (-not $items -or $items.Count -eq 0) {
        return @()
    }

    $fallbacks = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $items) {
        $desc = $item.description
        if (-not $desc) { continue }

        # Match DOCX href (blob or azurefd), typically .../[MS-XYZ]-YYMMDD.docx
        $docxMatch = [regex]::Match($desc, 'href="([^"]+\.docx)(?:\?[^"]*)?"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $docxMatch.Success) { continue }

        $url = [System.Net.WebUtility]::HtmlDecode($docxMatch.Groups[1].Value)
        if (-not $url -or $url -notmatch '\.docx') { continue }

        # Extract date suffix (YYMMDD) for Azure FD URL construction
        $dateMatch = [regex]::Match($url, '-(\d{6})\.docx')
        $dateSuffix = if ($dateMatch.Success) { $dateMatch.Groups[1].Value } else { $null }

        # Azure Front Door works when blob returns 404; add first
        if ($dateSuffix) {
            $azureFdUrl = "$rssBase/$ProtocolId/$encodedBrackets-$dateSuffix.docx"
            if ($azureFdUrl -notin $fallbacks) {
                [void]$fallbacks.Add($azureFdUrl)
            }
        }

        # Include original blob URL as fallback
        if ($url -match 'winprotocoldoc\.blob\.core\.windows\.net' -and $url -notin $fallbacks) {
            [void]$fallbacks.Add($url)
        }

        # First item is latest version; we have enough fallbacks
        if ($fallbacks.Count -gt 0) { break }
    }

    return @($fallbacks)
}
