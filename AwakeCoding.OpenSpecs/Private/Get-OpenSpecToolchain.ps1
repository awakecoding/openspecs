function Get-OpenSpecToolchain {
    [CmdletBinding()]
    param(
        [switch]$RequireDocxConverter
    )

    $pythonCommand = Get-Command -Name 'python' -ErrorAction SilentlyContinue
    $doclingCommand = Get-Command -Name 'docling' -ErrorAction SilentlyContinue
    $markitdownCommand = Get-Command -Name 'markitdown' -ErrorAction SilentlyContinue
    $openXmlModule = Get-Module -ListAvailable -Name 'OpenXML' | Select-Object -First 1

    $toolchain = [pscustomobject]@{
        PSTypeName = 'AwakeCoding.OpenSpecs.Toolchain'
        PythonPath = $pythonCommand.Source
        DoclingPath = $doclingCommand.Source
        MarkItDownPath = $markitdownCommand.Source
        OpenXmlModulePath = if ($openXmlModule) { $openXmlModule.Path } else { $null }
        HasPython = $null -ne $pythonCommand
        HasDocling = $null -ne $doclingCommand
        HasMarkItDown = $null -ne $markitdownCommand
        HasOpenXml = $null -ne $openXmlModule
    }

    if ($RequireDocxConverter -and -not $toolchain.HasOpenXml) {
        throw 'No DOCX converter detected. Install the OpenXML PowerShell module.'
    }

    return $toolchain
}
