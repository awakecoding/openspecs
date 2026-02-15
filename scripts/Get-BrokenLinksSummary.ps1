# Aggregate broken link counts from Get-BrokenLinksReport output
param([string]$Path = (Join-Path (Get-Location) 'artifacts\converted-specs'))

$reportScript = Join-Path $PSScriptRoot 'Get-BrokenLinksReport.ps1'
$tmp = [System.IO.Path]::GetTempFileName()
try {
    & $reportScript -Path $Path -OutputReport *> $tmp
    $lines = Get-Content -LiteralPath $tmp -Encoding utf8
} finally { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }
$total = 0
$gtTotal = 0
$sectionGuidTotal = 0
$sectionNumTotal = 0
$specsWithBroken = 0

foreach ($line in $lines) {
    $s = [string]$line
    if ($s -match 'Broken: (\d+).*gt_: (\d+).*Section_guid: (\d+).*Section_N\.N: (\d+)') {
        $n = [int]$Matches[1]
        if ($n -gt 0) {
            $total += $n
            $gtTotal += [int]$Matches[2]
            $sectionGuidTotal += [int]$Matches[3]
            $sectionNumTotal += [int]$Matches[4]
            $specsWithBroken++
        }
    }
}
Write-Host "Total broken link targets: $total"
Write-Host "  - gt_ (glossary): $gtTotal"
Write-Host "  - Section_<32hex>: $sectionGuidTotal"
Write-Host "  - Section_N.N: $sectionNumTotal"
Write-Host "Files with broken links: $specsWithBroken"
