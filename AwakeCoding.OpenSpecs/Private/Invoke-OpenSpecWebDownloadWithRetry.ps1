function Invoke-OpenSpecWebDownloadWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$OutFile,

        [Parameter()]
        [int]$MaxRetries = 4,

        [Parameter()]
        [int]$InitialDelaySeconds = 1
    )

    $attempt = 0
    $delay = [Math]::Max(1, $InitialDelaySeconds)
    while ($true) {
        $attempt++
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -MaximumRedirection 8 -ErrorAction Stop
            return
        }
        catch {
            $statusCode = $null
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            $transient = ($statusCode -in 429, 500, 502, 503, 504) -or (-not $statusCode)
            if ($attempt -ge $MaxRetries -or -not $transient) {
                throw
            }
            Start-Sleep -Seconds $delay
            $delay = [Math]::Min($delay * 2, 16)
        }
    }
}
