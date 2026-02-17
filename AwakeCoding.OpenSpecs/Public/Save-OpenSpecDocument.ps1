function Save-OpenSpecDocument {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline)]
        [object]$InputObject,

        [string[]]$ProtocolId,

        [string]$Query,

        [ValidateSet('PDF', 'DOCX', 'Both')]
        [string]$Format = 'Both',

        [string]$OutputPath = (Join-Path -Path (Get-Location) -ChildPath 'downloads'),

        [switch]$IncludePrevious,

        [switch]$AllVersions,

        [switch]$Force,

        [switch]$Parallel,
        [int]$ThrottleLimit = 8
    )

    begin {
        if (-not (Test-Path -LiteralPath $OutputPath)) {
            [void](New-Item -Path $OutputPath -ItemType Directory -Force)
        }

        $incoming = New-Object System.Collections.Generic.List[object]
    }

    process {
        if ($null -ne $InputObject) {
            [void]$incoming.Add($InputObject)
        }
    }

    end {
        $links = New-Object System.Collections.Generic.List[object]

        if ($incoming.Count -gt 0) {
            foreach ($item in $incoming) {
                if ($item.PSTypeNames -contains 'AwakeCoding.OpenSpecs.DownloadLink' -or ($item.Url -and $item.Format)) {
                    [void]$links.Add($item)
                    continue
                }

                if ($item.ProtocolId) {
                    if ($item.SpecPageUrl) {
                        foreach ($link in (Get-OpenSpecDownloadLink -InputObject $item -Format $Format -AllVersions:$AllVersions -IncludePrevious:$IncludePrevious)) {
                            [void]$links.Add($link)
                        }
                    }
                    else {
                        foreach ($link in (Get-OpenSpecDownloadLink -ProtocolId $item.ProtocolId -Format $Format -AllVersions:$AllVersions -IncludePrevious:$IncludePrevious)) {
                            [void]$links.Add($link)
                        }
                    }
                }
            }
        }
        else {
            $targetEntries = @()

            if ($ProtocolId) {
                foreach ($id in $ProtocolId) {
                    $targetEntries += Find-OpenSpec -ProtocolId $id
                }
            }
            elseif ($Query) {
                $targetEntries = Find-OpenSpec -Query $Query
            }
            else {
                throw 'You must provide InputObject, ProtocolId, or Query.'
            }

            foreach ($entry in $targetEntries) {
                foreach ($link in (Get-OpenSpecDownloadLink -ProtocolId $entry.ProtocolId -Format $Format -AllVersions:$AllVersions -IncludePrevious:$IncludePrevious)) {
                    [void]$links.Add($link)
                }
            }
        }

        $toDownload = [System.Collections.Generic.List[object]]::new()
        $existsResults = [System.Collections.Generic.List[object]]::new()
        foreach ($link in $links) {
            $fileName = $link.FileName
            if ([string]::IsNullOrWhiteSpace($fileName)) {
                $fileName = [System.IO.Path]::GetFileName([System.Uri]::new($link.Url).LocalPath)
            }

            $destination = Join-Path -Path $OutputPath -ChildPath $fileName

            if ((Test-Path -LiteralPath $destination) -and -not $Force) {
                [void]$existsResults.Add([pscustomobject]@{
                    PSTypeName = 'AwakeCoding.OpenSpecs.DownloadResult'
                    ProtocolId = $link.ProtocolId
                    Format = $link.Format
                    Url = $link.Url
                    Path = $destination
                    Status = 'Exists'
                    Size = (Get-Item -LiteralPath $destination).Length
                })
                continue
            }

            if ($PSCmdlet.ShouldProcess($link.Url, "Download to $destination")) {
                [void]$toDownload.Add([pscustomobject]@{ Link = $link; Destination = $destination })
            }
        }

        $downloadOne = {
            param($link, $destination)
            try {
                Invoke-OpenSpecWebDownloadWithRetry -Uri $link.Url -OutFile $destination
                [pscustomobject]@{
                    PSTypeName = 'AwakeCoding.OpenSpecs.DownloadResult'
                    ProtocolId = $link.ProtocolId
                    Format = $link.Format
                    Url = $link.Url
                    Path = $destination
                    Status = 'Downloaded'
                    Size = (Get-Item -LiteralPath $destination).Length
                }
            }
            catch {
                [pscustomobject]@{
                    PSTypeName = 'AwakeCoding.OpenSpecs.DownloadResult'
                    ProtocolId = $link.ProtocolId
                    Format = $link.Format
                    Url = $link.Url
                    Path = $destination
                    Status = 'Failed'
                    Error = $_.Exception.Message
                    Size = $null
                }
            }
        }

        $tryDocxFallback = {
            param($result, $destination)
            if ($result.Status -ne 'Failed' -or $result.Format -ne 'DOCX' -or -not $result.ProtocolId) { return $result }
            $fallbacks = Get-OpenSpecDocxFallbackUrls -ProtocolId $result.ProtocolId
            foreach ($url in $fallbacks) {
                if ($url -eq $result.Url) { continue }
                try {
                    Invoke-WebRequest -Uri $url -OutFile $destination -MaximumRedirection 8 -ErrorAction Stop
                    return [pscustomobject]@{
                        PSTypeName = 'AwakeCoding.OpenSpecs.DownloadResult'
                        ProtocolId = $result.ProtocolId
                        Format = $result.Format
                        Url = $url
                        Path = $destination
                        Status = 'Downloaded'
                        Size = (Get-Item -LiteralPath $destination).Length
                    }
                }
                catch { continue }
            }
            return $result
        }

        $moduleBase = (Get-Module -Name 'AwakeCoding.OpenSpecs' | Select-Object -First 1).ModuleBase
        $useParallel = $Parallel -and $PSVersionTable.PSVersion.Major -ge 7 -and $toDownload.Count -gt 1
        $results = if ($useParallel) {
            $toDownload | ForEach-Object -Parallel {
                $link = $_.Link
                $destination = $_.Destination
                try {
                    $currentModule = Get-Module -Name 'AwakeCoding.OpenSpecs' | Select-Object -First 1
                    if (-not $currentModule -and $using:moduleBase) {
                        Import-Module (Join-Path -Path $using:moduleBase -ChildPath 'AwakeCoding.OpenSpecs.psd1') -Force | Out-Null
                    }
                    Invoke-OpenSpecWebDownloadWithRetry -Uri $link.Url -OutFile $destination
                    [pscustomobject]@{
                        PSTypeName = 'AwakeCoding.OpenSpecs.DownloadResult'
                        ProtocolId = $link.ProtocolId
                        Format = $link.Format
                        Url = $link.Url
                        Path = $destination
                        Status = 'Downloaded'
                        Size = (Get-Item -LiteralPath $destination).Length
                    }
                }
                catch {
                    [pscustomobject]@{
                        PSTypeName = 'AwakeCoding.OpenSpecs.DownloadResult'
                        ProtocolId = $link.ProtocolId
                        Format = $link.Format
                        Url = $link.Url
                        Path = $destination
                        Status = 'Failed'
                        Error = $_.Exception.Message
                        Size = $null
                    }
                }
            } -ThrottleLimit $ThrottleLimit
        }
        else {
            foreach ($item in $toDownload) {
                & $downloadOne -link $item.Link -destination $item.Destination
            }
        }

        # Retry failed DOCX via RSS fallback URLs (e.g. MS-THCH, MS-MQOD with stale Learn-page links)
        $downloadResults = New-Object System.Collections.Generic.List[object]
        $i = 0
        foreach ($r in @($results)) {
            $dest = $toDownload[$i].Destination
            $r = & $tryDocxFallback -result $r -destination $dest
            [void]$downloadResults.Add($r)
            $i++
        }

        $existsResults
        $downloadResults
    }
}
