# Test direct download of MS-MQOD and MS-THCH
# Also check if the Learn page has different/current URLs
Write-Host "Fetching MS-MQOD spec page..."
$r = Invoke-WebRequest -Uri 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-mqod/644be85f-7a78-4bcc-b8a1-389e4b24b2cc'
$docxLinks = [regex]::Matches($r.Content, 'href="([^"]+\.docx[^"]*)"') | ForEach-Object { $_.Groups[1].Value }
Write-Host "DOCX links found on page: $($docxLinks.Count)"
$docxLinks | Select-Object -First 3 | ForEach-Object { Write-Host "  $_" }

Write-Host "`nDirect download tests:"
$urls = @(
    'https://winprotocoldocs-bhdugrdyduf5h2e4.b02.azurefd.net/MS-MQOD/%5bMS-MQOD%5d-220902.docx',
    'https://winprotocoldocs-bhdugrdyduf5h2e4.b02.azurefd.net/MS-THCH/%5bMS-THCH%5d-210625.docx'
)
foreach ($url in $urls) {
    Write-Host "--- Testing $url ---"
    try {
        $out = Join-Path $PSScriptRoot "test-$(Split-Path $url -Leaf)"
        Invoke-WebRequest -Uri $url -OutFile $out -MaximumRedirection 8
        Write-Host "OK: $((Get-Item $out).Length) bytes"
    }
    catch {
        Write-Host "FAILED: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            Write-Host "StatusCode: $([int]$_.Exception.Response.StatusCode)"
        }
    }
}
