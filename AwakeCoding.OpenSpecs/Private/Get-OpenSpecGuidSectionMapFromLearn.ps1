<#
.SYNOPSIS
    Builds a GUID-to-section map by fetching section pages from Microsoft Learn.
.DESCRIPTION
    For Open Specs that have GuidToSection=0 from DOCX conversion (e.g. MS-RDPBCGR),
    fetches each section page from Learn (openspecs/windows_protocols/protocolId/{guid-with-hyphens}),
    parses the H1 for the section number (e.g. "2.2.1.4 Server MCS Connect Response PDU..."),
    and returns a hashtable: guid_no_hyphens -> Section_N.N.
.PARAMETER ProtocolId
    Protocol ID (e.g. MS-RDPBCGR).
.PARAMETER Guids
    Array of 32-character hex GUIDs (no hyphens) to resolve.
.PARAMETER ThrottleSeconds
    Delay between HTTP requests to avoid overloading Learn. Default 1.
.OUTPUTS
    Hashtable: lowercase guid (no hyphens) -> Section_N.N
#>
function Get-OpenSpecGuidSectionMapFromLearn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProtocolId,

        [Parameter(Mandatory)]
        [string[]]$Guids,

        [Parameter()]
        [int]$ThrottleSeconds = 1
    )

    $ErrorActionPreference = 'Stop'

    function ConvertTo-HyphenatedGuid {
        param([string]$Hex32)
        if ($Hex32.Length -ne 32) { return $null }
        $Hex32.Substring(0, 8) + '-' + $Hex32.Substring(8, 4) + '-' + $Hex32.Substring(12, 4) + '-' + $Hex32.Substring(16, 4) + '-' + $Hex32.Substring(20, 12)
    }

    $baseUrl = "https://learn.microsoft.com/en-us/openspecs/windows_protocols/$($ProtocolId.ToLowerInvariant())"
    $map = @{}
    $uniqueGuids = @($Guids | ForEach-Object { $_.ToLowerInvariant() } | Select-Object -Unique)
    $total = $uniqueGuids.Count
    $resolved = 0

    foreach ($i in 0..($uniqueGuids.Count - 1)) {
        $guidHex = $uniqueGuids[$i]
        $guidHyphenated = ConvertTo-HyphenatedGuid -Hex32 $guidHex
        if (-not $guidHyphenated) { continue }
        $url = "$baseUrl/$guidHyphenated"
        try {
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
            $html = $response.Content
            if ($html -match '<h1[^>]*>\s*(\d+(?:\.\d+)*)\s+' -or $html -match '(?:^|\n)#\s+(\d+(?:\.\d+)*)\s+') {
                $sectionNum = $Matches[1]
                $map[$guidHex] = "Section_$sectionNum"
                $resolved++
            }
        }
        catch {
            Write-Verbose "Failed to fetch $url : $_"
        }
        if ($ThrottleSeconds -gt 0 -and $i -lt $uniqueGuids.Count - 1) {
            Start-Sleep -Seconds $ThrottleSeconds
        }
    }

    Write-Verbose "Resolved $resolved / $total GUIDs from Learn"
    $map
}
