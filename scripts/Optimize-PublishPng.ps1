<#
.SYNOPSIS
    Optimizes PNG images in the publish output using oxipng.
.DESCRIPTION
    Recursively finds PNG files under the publish directory and runs:
      oxipng --strip safe -- <file>

    If oxipng is not available, the script emits a non-critical warning and skips optimization.
.EXAMPLE
    .\Optimize-PublishPng.ps1 -PublishPath .\publish -ThrottleLimit 8
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$PublishPath = (Join-Path (Get-Location) 'publish'),

    [Parameter()]
    [int]$ThrottleLimit = 8
)

$ErrorActionPreference = 'Stop'

$resolvedPublishPath = [System.IO.Path]::GetFullPath($PublishPath)
if (-not (Test-Path -LiteralPath $resolvedPublishPath -PathType Container)) {
    throw "Publish path not found: $resolvedPublishPath"
}

$oxipngCommand = Get-Command -Name 'oxipng' -ErrorAction SilentlyContinue
if (-not $oxipngCommand) {
    Write-Warning 'oxipng was not found in PATH. Skipping PNG optimization.'
    return [pscustomobject]@{
        PSTypeName = 'AwakeCoding.OpenSpecs.PngOptimizationResult'
        Path = $resolvedPublishPath
        ToolFound = $false
        Skipped = $true
        TotalPngFiles = 0
        OptimizedCount = 0
        FailedCount = 0
        DurationSeconds = 0
    }
}

$pngFiles = @(Get-ChildItem -LiteralPath $resolvedPublishPath -Recurse -File -Filter '*.png')
if ($pngFiles.Count -eq 0) {
    Write-Host "No PNG files found under $resolvedPublishPath."
    return [pscustomobject]@{
        PSTypeName = 'AwakeCoding.OpenSpecs.PngOptimizationResult'
        Path = $resolvedPublishPath
        ToolFound = $true
        Skipped = $false
        TotalPngFiles = 0
        OptimizedCount = 0
        FailedCount = 0
        DurationSeconds = 0
    }
}

$effectiveThrottle = [Math]::Max(1, $ThrottleLimit)
$useParallel = $PSVersionTable.PSVersion.Major -ge 7 -and $pngFiles.Count -gt 1 -and $effectiveThrottle -gt 1
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$oxipngPath = $oxipngCommand.Source

Write-Host "Optimizing $($pngFiles.Count) PNG files with oxipng (--strip safe)..."

if ($useParallel) {
    $results = $pngFiles | ForEach-Object -Parallel {
        $filePath = $_.FullName
        & $using:oxipngPath '--strip' 'safe' '--' $filePath 2>$null | Out-Null
        $exitCode = $LASTEXITCODE
        [pscustomobject]@{
            Path = $filePath
            Success = ($exitCode -eq 0)
            ExitCode = $exitCode
        }
    } -ThrottleLimit $effectiveThrottle
}
else {
    $results = foreach ($png in $pngFiles) {
        & $oxipngPath '--strip' 'safe' '--' $png.FullName 2>$null | Out-Null
        $exitCode = $LASTEXITCODE
        [pscustomobject]@{
            Path = $png.FullName
            Success = ($exitCode -eq 0)
            ExitCode = $exitCode
        }
    }
}

$stopwatch.Stop()

$failed = @($results | Where-Object { -not $_.Success })
$failedCount = $failed.Count
$optimizedCount = $results.Count - $failedCount

if ($failedCount -gt 0) {
    Write-Warning "oxipng failed for $failedCount of $($results.Count) files."
    foreach ($failure in ($failed | Select-Object -First 10)) {
        Write-Warning "Failed: $($failure.Path) (exit code $($failure.ExitCode))"
    }
    if ($failedCount -gt 10) {
        Write-Warning 'Additional failures omitted from output.'
    }
}

Write-Host "PNG optimization complete. Optimized: $optimizedCount, Failed: $failedCount, Total: $($results.Count), Duration: $([Math]::Round($stopwatch.Elapsed.TotalSeconds, 2))s"

[pscustomobject]@{
    PSTypeName = 'AwakeCoding.OpenSpecs.PngOptimizationResult'
    Path = $resolvedPublishPath
    ToolFound = $true
    Skipped = $false
    TotalPngFiles = $results.Count
    OptimizedCount = $optimizedCount
    FailedCount = $failedCount
    DurationSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
}
