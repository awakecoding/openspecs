function Invoke-MarkdownCleanupTransform {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$TransformFunction
    )

    $ErrorActionPreference = 'Stop'

    $fullPath = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "File not found: $fullPath"
    }

    $repoRoot = (Get-Item $PSScriptRoot).Parent.FullName
    $cleanupScript = Join-Path $repoRoot 'AwakeCoding.OpenSpecs\Private\Invoke-OpenSpecMarkdownCleanup.ps1'
    if (-not (Test-Path -LiteralPath $cleanupScript -PathType Leaf)) {
        throw "Cleanup script not found: $cleanupScript"
    }

    . $cleanupScript

    if (-not (Get-Command -Name $TransformFunction -CommandType Function -ErrorAction SilentlyContinue)) {
        throw "Transform function not found after loading cleanup script: $TransformFunction"
    }

    $markdown = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8
    & $TransformFunction -Markdown $markdown
}

function Save-MarkdownCleanupTransformResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Markdown
    )

    $fullPath = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
    Set-Content -LiteralPath $fullPath -Value $Markdown -Encoding UTF8 -NoNewline
    Write-Host 'File updated.'
}
