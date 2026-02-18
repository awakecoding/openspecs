BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\AwakeCoding.OpenSpecs\AwakeCoding.OpenSpecs.psd1'
    Import-Module $modulePath -Force
}

Describe 'AwakeCoding.OpenSpecs module load' {
    It 'exports expected cmdlets' {
        $expected = @(
            'Get-OpenSpecCatalog',
            'Find-OpenSpec',
            'Get-OpenSpecVersion',
            'Get-OpenSpecDownloadLink',
            'Save-OpenSpecDocument',
            'Test-OpenSpecDownload',
            'Convert-OpenSpecToMarkdown',
            'Invoke-OpenSpecConversionPipeline',
            'Get-OpenSpecConversionReport',
            'Test-OpenSpecMarkdownFidelity',
            'Update-OpenSpecIndex',
            'Compare-OpenSpecToLiveHtml'
        )

        foreach ($name in $expected) {
            (Get-Command -Name $name -ErrorAction Stop).Name | Should -Be $name
        }
    }
}

Describe 'OpenSpecs live discovery' -Tag 'Live' {
    It 'finds RDP entries from catalog' {
        $matches = Find-OpenSpec -Query RDP
        $matches.Count | Should -BeGreaterThan 0
    }

    It 'resolves download links for MS-RDPEWA in both formats' {
        $links = Get-OpenSpecDownloadLink -ProtocolId MS-RDPEWA -Format Both
        ($links | Where-Object Format -eq 'PDF').Count | Should -BeGreaterThan 0
        ($links | Where-Object Format -eq 'DOCX').Count | Should -BeGreaterThan 0
    }
}

Describe 'Conversion report aggregation' {
    It 'returns severity counts and headline issue count from report payload' {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("openspecs-test-" + [guid]::NewGuid().ToString('N'))
        $specDir = Join-Path -Path $tempRoot -ChildPath 'MS-TEST'
        $artifactDir = Join-Path -Path $specDir -ChildPath 'artifacts'
        [void](New-Item -Path $artifactDir -ItemType Directory -Force)

        $reportPath = Join-Path -Path $artifactDir -ChildPath 'conversion-report.json'
        [pscustomobject]@{
            ProtocolId = 'MS-TEST'
            SourceFormat = 'DOCX'
            Strategy = 'openxml-docx'
            IssueCount = 1
            InfoCount = 2
            WarningCount = 1
            ErrorCount = 0
            Issues = @(
                [pscustomobject]@{ Type = 'TableColspanExpanded'; Severity = 'Info' },
                [pscustomobject]@{ Type = 'LinkRewritten'; Severity = 'Info' },
                [pscustomobject]@{ Type = 'TableUnparsed'; Severity = 'Warning' }
            )
            GeneratedAtUtc = [DateTime]::UtcNow.ToString('o')
            MarkdownPath = (Join-Path -Path $specDir -ChildPath 'index.md')
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding UTF8

        $result = Get-OpenSpecConversionReport -OutputPath $tempRoot -ProtocolId MS-TEST | Select-Object -First 1

        $result.ProtocolId | Should -Be 'MS-TEST'
        $result.IssueCount | Should -Be 1
        $result.InfoCount | Should -Be 2
        $result.WarningCount | Should -Be 1
        $result.ErrorCount | Should -Be 0

        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Describe 'Section GUID link repair' {
    It 'is deterministic and prefers explicit section-number targets' {
        $markdown = @'
<a id="Section_2.2.1.3"></a>
## 2.2.1.3 MCS Connect Initial PDU
<a id="Section_3.2.5.3.3"></a>
## 3.2.5.3.3 MCS Connect Initial PDU
Numeric reference: [2.2.1.3](#Section_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)
Heading reference: [MCS Connect Initial PDU](#Section_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb)
'@

        $module = Get-Module AwakeCoding.OpenSpecs -ErrorAction Stop
        $results = 1..5 | ForEach-Object {
            & $module {
                param([string]$text)
                Repair-OpenSpecSectionGuidLinksByHeadingMatch -Markdown $text
            } $markdown
        }

        $firstMarkdown = $results[0].Markdown
        foreach ($item in $results) {
            $item.Markdown | Should -Be $firstMarkdown
        }

        $firstMarkdown | Should -Match '\[2\.2\.1\.3\]\(#Section_2\.2\.1\.3\)'
        $firstMarkdown | Should -Match '\[MCS Connect Initial PDU\]\(#Section_2\.2\.1\.3\)'
    }
}

Describe 'GUID anchor resolution precedence' {
    It 'prefers explicit numeric section text over conflicting source metadata' {
        $markdown = @'
<a id="section_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"></a>
<a id="Section_2.2.9"></a>
<a id="Section_2.2.11"></a>
From pair: [2.2.9](#Section_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)
From source-map fallback: [2.2.11](#Section_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb)
'@

        $sourceMap = @{
            aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 'Section_2.2.8'
            bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb = 'Section_9.9.9'
        }

        $module = Get-Module AwakeCoding.OpenSpecs -ErrorAction Stop
        $result = & $module {
            param([string]$text, [object]$map)
            Resolve-OpenSpecGuidSectionAnchors -Markdown $text -GuidToSectionMap $map
        } $markdown $sourceMap

        $result.Markdown | Should -Match '\[2\.2\.9\]\(#Section_2\.2\.9\)'
        $result.Markdown | Should -Match '\[2\.2\.11\]\(#Section_2\.2\.11\)'
        $result.Markdown | Should -Not -Match '\[2\.2\.9\]\(#Section_2\.2\.8\)'
        $result.Markdown | Should -Not -Match '\[2\.2\.11\]\(#Section_9\.9\.9\)'

        $issue = $result.Issues | Where-Object Type -eq 'GuidAnchorResolved' | Select-Object -First 1
        $issue | Should -Not -BeNullOrEmpty
        $issue.NumericPreferenceRewrites | Should -Be 2
    }
}

Describe 'Section number link strict repair' {
    It 'rewrites only when the referenced numeric section exists in the document' {
        $markdown = @'
<a id="Section_5.3.8"></a>
Known anchor: [5.3.8](#Section_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)
Unknown anchor: [7.7.7](#Section_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb)
## 8.1 Heading-derived section
Heading anchor: [8.1](#Section_cccccccccccccccccccccccccccccccc)
'@

        $module = Get-Module AwakeCoding.OpenSpecs -ErrorAction Stop
        $result = & $module {
            param([string]$text)
            Repair-OpenSpecSectionNumberLinks -Markdown $text
        } $markdown

        $result.Markdown | Should -Match '\[5\.3\.8\]\(#Section_5\.3\.8\)'
        $result.Markdown | Should -Match '\[8\.1\]\(#Section_8\.1\)'
        $result.Markdown | Should -Match '\[7\.7\.7\]\(#Section_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\)'

        $issue = $result.Issues | Where-Object Type -eq 'SectionNumberLinksRepaired' | Select-Object -First 1
        $issue | Should -Not -BeNullOrEmpty
        $issue.Count | Should -Be 2
    }
}
