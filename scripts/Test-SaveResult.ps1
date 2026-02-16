# Check what Save-OpenSpecDocument returns for MS-MQOD/MS-THCH
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'AwakeCoding.OpenSpecs') -Force

$catalog = Get-OpenSpecCatalog -IncludeReferenceSpecs -IncludeOverviewDocs
$mqod = $catalog | Where-Object { $_.ProtocolId -in 'MS-MQOD','MS-THCH' }
$results = $mqod | Save-OpenSpecDocument -Format DOCX -OutputPath (Join-Path $root 'downloads-test') -Force

$results | Format-Table ProtocolId, Status, Error -AutoSize
$results | Format-List *
