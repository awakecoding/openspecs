function ConvertFrom-OpenSpecDocx {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [object]$Toolchain,

        [Parameter()]
        [string]$MediaOutputDirectory
    )

    return ConvertFrom-OpenSpecDocxWithOpenXml -InputPath $InputPath -OutputPath $OutputPath -Toolchain $Toolchain -MediaOutputDirectory $MediaOutputDirectory
}

function ConvertFrom-OpenSpecDocxWithOpenXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [object]$Toolchain,

        [Parameter()]
        [string]$MediaOutputDirectory
    )

    if (-not (Test-Path -LiteralPath $InputPath)) {
        throw "DOCX file not found: $InputPath"
    }

    $outputDirectory = Split-Path -Path $OutputPath -Parent
    if (-not (Test-Path -LiteralPath $outputDirectory)) {
        [void](New-Item -Path $outputDirectory -ItemType Directory -Force)
    }

    $notes = New-Object System.Collections.Generic.List[string]
    if ($Toolchain.HasOpenXml) {
        try {
            Import-Module OpenXML -ErrorAction Stop | Out-Null
            $notes.Add('OpenXML PowerShell module loaded.')
        }
        catch {
            $notes.Add("OpenXML module was detected but failed to load: $($_.Exception.Message)")
        }
    }
    else {
        $notes.Add('OpenXML module not detected; using Open XML package parser implementation.')
    }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $archive = $null
    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($InputPath)
        $documentEntry = $archive.GetEntry('word/document.xml')
        if ($null -eq $documentEntry) {
            throw 'word/document.xml entry was not found in DOCX package.'
        }

        $stream = $documentEntry.Open()
        $reader = New-Object System.IO.StreamReader($stream)
        $documentXml = $reader.ReadToEnd()
        $reader.Dispose()
        $stream.Dispose()

        $document = New-Object System.Xml.XmlDocument
        $document.PreserveWhitespace = $false
        $document.LoadXml($documentXml)

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
        $nsmgr.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
        $nsmgr.AddNamespace('wp', 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
        $nsmgr.AddNamespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main')
        $nsmgr.AddNamespace('pic', 'http://schemas.openxmlformats.org/drawingml/2006/picture')
        $nsmgr.AddNamespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')

        $body = $document.SelectSingleNode('//w:body', $nsmgr)
        if ($null -eq $body) {
            throw 'Document body was not found in DOCX XML.'
        }

        $relationshipMap = Get-OpenSpecOpenXmlRelationshipMap -Archive $archive
        $lines = New-Object System.Collections.Generic.List[string]
        $emittedAnchors = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $linkMetadata = [ordered]@{
            GuidToSection = @{}
            SectionToTitle = @{}
            TocAlias = @{}
            GuidToGlossarySlug = @{}
            InternalHyperlinks = New-Object System.Collections.Generic.List[object]
            Stats = [ordered]@{
                ParagraphCount = 0
                HeadingCount = 0
                BookmarkCount = 0
                InternalHyperlinkCount = 0
                GuidSectionMapCount = 0
                TocAliasCount = 0
                GlossaryGuidMapCount = 0
            }
        }
        $inGlossary = $false
        $glossaryHeadingLevel = 0
        $pendingSectionGuids = New-Object System.Collections.Generic.List[string]

        # Resolve media output directory for image extraction.
        $resolvedMediaDir = $null
        if (-not [string]::IsNullOrWhiteSpace($MediaOutputDirectory)) {
            $resolvedMediaDir = $MediaOutputDirectory
        }

        foreach ($child in $body.ChildNodes) {
            if ($child.LocalName -eq 'p') {
                $linkMetadata.Stats.ParagraphCount++
                $text = ConvertFrom-OpenSpecOpenXmlParagraph -ParagraphNode $child -NamespaceManager $nsmgr -RelationshipMap $relationshipMap -Archive $archive -MediaOutputDirectory $resolvedMediaDir
                $styleNode = $child.SelectSingleNode('./w:pPr/w:pStyle', $nsmgr)
                $style = if ($styleNode -and $styleNode.Attributes) { $styleNode.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main') } else { '' }
                $anchorInfo = Get-OpenSpecOpenXmlParagraphAnchorInfo -ParagraphNode $child -NamespaceManager $nsmgr -ParagraphText $text -HeadingStyle $style
                $anchors = @($anchorInfo.Anchors)

                foreach ($anchor in $anchors) {
                    if ([string]::IsNullOrWhiteSpace($anchor)) {
                        continue
                    }

                    if (-not $emittedAnchors.Add($anchor)) {
                        continue
                    }

                    $lines.Add(('<a id="' + $anchor + '"></a>'))
                }
                $linkMetadata.Stats.BookmarkCount += @($anchorInfo.BookmarkNames).Count

                $internalLinks = Get-OpenSpecOpenXmlParagraphInternalHyperlinks -ParagraphNode $child -NamespaceManager $nsmgr
                foreach ($internalLink in $internalLinks) {
                    [void]$linkMetadata.InternalHyperlinks.Add($internalLink)
                }
                $linkMetadata.Stats.InternalHyperlinkCount += @($internalLinks).Count

                $numberingNode = $child.SelectSingleNode('./w:pPr/w:numPr', $nsmgr)
                if ([string]::IsNullOrWhiteSpace($text)) {
                    if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -ne '') {
                        $lines.Add('')
                    }
                    continue
                }

                if ($style -match '^Heading(?<level>[1-6])$') {
                    $level = [int]$Matches['level']
                    $linkMetadata.Stats.HeadingCount++
                    # Strip bold from heading text — the heading style (#) already implies bold.
                    # Keep italic and code formatting if present.
                    $headingText = ($text -replace '\*\*(?!\*)', '').Trim()
                    $lines.Add((('{0} ' -f ('#' * $level)) + $headingText))
                    $lines.Add('')

                    $isGlossaryHeading = $headingText -match '(?i)^\d+(?:\.\d+)*\s+Glossary$'
                    if ($isGlossaryHeading) {
                        $inGlossary = $true
                        $glossaryHeadingLevel = $level
                    }
                    elseif ($inGlossary -and $level -le $glossaryHeadingLevel) {
                        $inGlossary = $false
                    }

                    $sectionAnchor = $anchorInfo.SectionAnchor
                    if (-not [string]::IsNullOrWhiteSpace($sectionAnchor)) {
                        # Strategy B: Resolve cross-paragraph section GUIDs from previous paragraph
                        foreach ($g in $pendingSectionGuids) {
                            if (-not $linkMetadata.GuidToSection.ContainsKey($g)) {
                                $linkMetadata.GuidToSection[$g] = $sectionAnchor
                            }
                        }
                        $pendingSectionGuids.Clear()

                        if (-not $linkMetadata.SectionToTitle.ContainsKey($sectionAnchor)) {
                            $linkMetadata.SectionToTitle[$sectionAnchor] = $headingText
                        }

                        foreach ($bookmarkName in @($anchorInfo.BookmarkNames)) {
                            if ($bookmarkName -match '(?i)^section_(?<guid>[a-f0-9]{32})$') {
                                $guid = $Matches['guid'].ToLowerInvariant()
                                if (-not $linkMetadata.GuidToSection.ContainsKey($guid)) {
                                    $linkMetadata.GuidToSection[$guid] = $sectionAnchor
                                }
                            }
                            elseif ($bookmarkName -match '^_Toc\d+$') {
                                if (-not $linkMetadata.TocAlias.ContainsKey($bookmarkName)) {
                                    $linkMetadata.TocAlias[$bookmarkName] = $sectionAnchor
                                }
                            }
                        }
                    }
                }
                elseif ($numberingNode) {
                    $lines.Add(('- ' + $text.Trim()))
                }
                else {
                    $lines.Add($text.Trim())
                    $lines.Add('')
                }

                if ($inGlossary) {
                    $defMatch = [regex]::Match($text, '^\s*\*\*(?<term>[^*]+)\*\*\s*:\s*')
                    if ($defMatch.Success) {
                        $term = $defMatch.Groups['term'].Value.Trim()
                        $slug = Get-OpenSpecGlossarySlugFromTerm -Term $term
                        foreach ($bookmarkName in @($anchorInfo.BookmarkNames)) {
                            if ($bookmarkName -match '(?i)^gt_(?<guid>[a-f0-9\-]{36})$') {
                                $guid = $Matches['guid'].ToLowerInvariant()
                                if (-not $linkMetadata.GuidToGlossarySlug.ContainsKey($guid)) {
                                    $linkMetadata.GuidToGlossarySlug[$guid] = $slug
                                }
                            }
                        }
                    }
                }

                # Strategy B: Paragraph has section_<guid> bookmarks but no SectionAnchor — defer to next paragraph
                if ([string]::IsNullOrWhiteSpace($anchorInfo.SectionAnchor)) {
                    foreach ($bookmarkName in @($anchorInfo.BookmarkNames)) {
                        if ($bookmarkName -match '(?i)^section_(?<guid>[a-f0-9]{32})$') {
                            $g = $Matches['guid'].ToLowerInvariant()
                            if (-not $linkMetadata.GuidToSection.ContainsKey($g) -and -not $pendingSectionGuids.Contains($g)) {
                                [void]$pendingSectionGuids.Add($g)
                            }
                        }
                    }
                }
            }
            elseif ($child.LocalName -eq 'tbl') {
                $tableLines = ConvertFrom-OpenSpecOpenXmlTable -TableNode $child -NamespaceManager $nsmgr -RelationshipMap $relationshipMap -Archive $archive -MediaOutputDirectory $resolvedMediaDir
                foreach ($line in $tableLines) {
                    $lines.Add($line)
                }
                $lines.Add('')
            }
        }

        $markdown = ($lines.ToArray() -join [Environment]::NewLine).Trim()
        $markdown = Add-OpenSpecSectionAnchorsFromToc -Markdown $markdown
        if ([string]::IsNullOrWhiteSpace($markdown)) {
            throw 'OpenXml conversion produced empty markdown output.'
        }

        # Strategy A: Build GuidToSection from InternalHyperlinks by matching link text to SectionToTitle
        if ($linkMetadata.SectionToTitle.Count -eq 0) {
            $headingRegex = [regex]::new('^(?<level>#{1,6})\s+(?<num>\d+(?:\.\d+)*)\s+(?<title>.+)$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            foreach ($m in $headingRegex.Matches($markdown)) {
                $sectionAnchor = "Section_$($m.Groups['num'].Value)"
                $fullTitle = "$($m.Groups['num'].Value) $($m.Groups['title'].Value.Trim())"
                if (-not $linkMetadata.SectionToTitle.ContainsKey($sectionAnchor)) {
                    $linkMetadata.SectionToTitle[$sectionAnchor] = $fullTitle
                }
            }
        }
        $getSectionSortKey = {
            param([string]$sectionId)

            if ($sectionId -match '^Section_(?<num>\d+(?:\.\d+)*)$') {
                $parts = @($Matches['num'] -split '\.' | ForEach-Object {
                    if ($_ -match '^\d+$') { [int]$_ } else { 0 }
                })
                $padded = @($parts | ForEach-Object { '{0:D8}' -f $_ })
                return ('0|' + ($padded -join '.'))
            }

            return ('1|' + $sectionId.ToLowerInvariant())
        }

        $sectionEntries = New-Object System.Collections.Generic.List[object]
        foreach ($entry in $linkMetadata.SectionToTitle.GetEnumerator()) {
            $sectionId = [string]$entry.Key
            $title = ([string]$entry.Value -replace '\s+', ' ').Trim()
            if ([string]::IsNullOrWhiteSpace($sectionId) -or [string]::IsNullOrWhiteSpace($title)) {
                continue
            }

            $titleWithoutNum = ($title -replace '^\d+(?:\.\d+)*\s+', '').Trim()
            [void]$sectionEntries.Add([pscustomobject]@{
                SectionId = $sectionId
                TitleNormalized = $title
                TitleWithoutNumber = $titleWithoutNum
                SortKey = (& $getSectionSortKey $sectionId)
            })
        }

        $orderedSectionEntries = @($sectionEntries | Sort-Object -Property @(
            @{ Expression = { $_.SortKey } },
            @{ Expression = { $_.SectionId.ToLowerInvariant() } },
            @{ Expression = { $_.TitleNormalized.ToLowerInvariant() } }
        ))

        $sectionIdSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $titleToSections = @{}
        $titleWithoutNumToSections = @{}

        foreach ($entry in $orderedSectionEntries) {
            [void]$sectionIdSet.Add($entry.SectionId)

            $titleKey = $entry.TitleNormalized.ToLowerInvariant()
            if (-not $titleToSections.ContainsKey($titleKey)) {
                $titleToSections[$titleKey] = New-Object System.Collections.Generic.List[string]
            }
            if (-not $titleToSections[$titleKey].Contains($entry.SectionId)) {
                [void]$titleToSections[$titleKey].Add($entry.SectionId)
            }

            if (-not [string]::IsNullOrWhiteSpace($entry.TitleWithoutNumber)) {
                $withoutNumKey = $entry.TitleWithoutNumber.ToLowerInvariant()
                if (-not $titleWithoutNumToSections.ContainsKey($withoutNumKey)) {
                    $titleWithoutNumToSections[$withoutNumKey] = New-Object System.Collections.Generic.List[string]
                }
                if (-not $titleWithoutNumToSections[$withoutNumKey].Contains($entry.SectionId)) {
                    [void]$titleWithoutNumToSections[$withoutNumKey].Add($entry.SectionId)
                }
            }
        }

        $findUniqueSection = {
            param([System.Collections.Generic.List[string]]$candidateSections)

            if ($null -eq $candidateSections) {
                return $null
            }

            $candidates = @($candidateSections | Sort-Object)
            if ($candidates.Count -eq 1) {
                return $candidates[0]
            }

            return $null
        }

        $sectionGuidRegex = [regex]::new('^(?:[Ss]ection_)?([a-f0-9]{32})$')
        $internalLinksArray = $linkMetadata.InternalHyperlinks.ToArray()
        foreach ($link in $internalLinksArray) {
            $anchor = [string]$link.Anchor
            $text = ([string]$link.Text -replace '\s+', ' ').Trim()
            $m = $sectionGuidRegex.Match($anchor)
            if (-not $m.Success) { continue }
            $guid = $m.Groups[1].Value.ToLowerInvariant()
            if ($linkMetadata.GuidToSection.ContainsKey($guid)) { continue }
            $matchedSection = $null

            if ($text -match '^(?:section\s+)?(?<num>\d+(?:\.\d+)*)$') {
                $directSection = "Section_$($Matches['num'])"
                if ($sectionIdSet.Contains($directSection)) {
                    $matchedSection = $directSection
                }
            }

            $textKey = $text.ToLowerInvariant()
            if (-not $matchedSection -and $titleToSections.ContainsKey($textKey)) {
                $matchedSection = & $findUniqueSection $titleToSections[$textKey]
            }

            $textWithoutNum = ($text -replace '^\d+(?:\.\d+)*\s+', '').Trim()
            if (-not $matchedSection -and -not [string]::IsNullOrWhiteSpace($textWithoutNum)) {
                $textWithoutNumKey = $textWithoutNum.ToLowerInvariant()
                if ($titleWithoutNumToSections.ContainsKey($textWithoutNumKey)) {
                    $matchedSection = & $findUniqueSection $titleWithoutNumToSections[$textWithoutNumKey]
                }
            }

            if (-not $matchedSection -and $text.Length -ge 8) {
                $fuzzyCandidates = New-Object System.Collections.Generic.List[object]
                foreach ($entry in $orderedSectionEntries) {
                    $candidateTitle = $entry.TitleNormalized
                    if ([string]::IsNullOrWhiteSpace($candidateTitle) -or $candidateTitle.Length -lt 8) {
                        continue
                    }

                    $containsText = $candidateTitle.IndexOf($text, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
                    $containsCandidate = $text.IndexOf($candidateTitle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
                    if (-not $containsText -and -not $containsCandidate) {
                        continue
                    }

                    $score = if ($containsText -and $containsCandidate) {
                        0
                    }
                    elseif ($containsText) {
                        1
                    }
                    else {
                        2
                    }

                    [void]$fuzzyCandidates.Add([pscustomobject]@{
                        Score = $score
                        LengthDelta = [Math]::Abs($candidateTitle.Length - $text.Length)
                        SortKey = $entry.SortKey
                        SectionId = $entry.SectionId
                    })
                }

                if ($fuzzyCandidates.Count -gt 0) {
                    $orderedCandidates = @($fuzzyCandidates | Sort-Object -Property @(
                        @{ Expression = { $_.Score } },
                        @{ Expression = { $_.LengthDelta } },
                        @{ Expression = { $_.SortKey } },
                        @{ Expression = { $_.SectionId } }
                    ))

                    $best = $orderedCandidates[0]
                    $isUniqueBest = $true
                    if ($orderedCandidates.Count -gt 1) {
                        $second = $orderedCandidates[1]
                        if (
                            $second.Score -eq $best.Score -and
                            $second.LengthDelta -eq $best.LengthDelta -and
                            $second.SortKey -eq $best.SortKey
                        ) {
                            $isUniqueBest = $false
                        }
                    }

                    if ($isUniqueBest) {
                        $matchedSection = $best.SectionId
                    }
                }
            }

            if ($matchedSection) {
                $linkMetadata.GuidToSection[$guid] = $matchedSection
            }
        }

        # Strategy D: Build GuidToGlossarySlug from InternalHyperlinks with gt_<guid> anchors
        $termToSlug = @{}
        $glossaryDefRegex = [regex]::new('^\s*\*\*(?<term>[^*]+)\*\*\s*:\s*', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        foreach ($gm in $glossaryDefRegex.Matches($markdown)) {
            $term = $gm.Groups['term'].Value.Trim()
            $slug = Get-OpenSpecGlossarySlugFromTerm -Term $term
            $termToSlug[$term] = $slug
            if ($term -match '^(.+?)\s+\(([^)]+)\)\s*$') {
                $termToSlug[$Matches[2].Trim()] = $slug
            }
        }
        $gtGuidRegex = [regex]::new('^gt_([a-f0-9\-]{36})$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        foreach ($link in $internalLinksArray) {
            $anchor = [string]$link.Anchor
            $text = ([string]$link.Text -replace '\s+', ' ').Trim()
            $m = $gtGuidRegex.Match($anchor)
            if (-not $m.Success) { continue }
            $guid = $m.Groups[1].Value.ToLowerInvariant()
            if ($linkMetadata.GuidToGlossarySlug.ContainsKey($guid)) { continue }
            if ($termToSlug.ContainsKey($text)) {
                $linkMetadata.GuidToGlossarySlug[$guid] = $termToSlug[$text]
            }
        }

        $linkMetadata.Stats.GuidSectionMapCount = $linkMetadata.GuidToSection.Count
        $linkMetadata.Stats.TocAliasCount = $linkMetadata.TocAlias.Count
        $linkMetadata.Stats.GlossaryGuidMapCount = $linkMetadata.GuidToGlossarySlug.Count
        $notes.Add("Link metadata captured: guidToSection=$($linkMetadata.Stats.GuidSectionMapCount), tocAlias=$($linkMetadata.Stats.TocAliasCount), guidToGlossarySlug=$($linkMetadata.Stats.GlossaryGuidMapCount), internalLinks=$($linkMetadata.Stats.InternalHyperlinkCount).")

        $markdown | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    }
    finally {
        if ($archive) {
            $archive.Dispose()
        }
    }

    $linkMetadataOut = [ordered]@{
        GuidToSection = $linkMetadata.GuidToSection
        SectionToTitle = $linkMetadata.SectionToTitle
        TocAlias = $linkMetadata.TocAlias
        GuidToGlossarySlug = $linkMetadata.GuidToGlossarySlug
        InternalHyperlinks = @($linkMetadata.InternalHyperlinks.ToArray())
        Stats = $linkMetadata.Stats
    }

    return [pscustomobject]@{
        PSTypeName = 'AwakeCoding.OpenSpecs.ConversionStep'
        Strategy = 'openxml-docx'
        OutputPath = $OutputPath
        Notes = $notes.ToArray()
        LinkMetadata = $linkMetadataOut
    }
}

function Get-OpenSpecOpenXmlNodeText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$Node,

        [Parameter(Mandatory)]
        [System.Xml.XmlNamespaceManager]$NamespaceManager
    )

    # Walk paragraph and run structure to extract text properly.
    # Word splits text across multiple <w:r> runs at arbitrary boundaries
    # (spell-check, formatting, revisions). Concatenating <w:t> content
    # directly (no extra spaces) gives the correct text. Breaks, tabs, and
    # carriage returns between runs are represented by <w:br/>, <w:tab/>,
    # and <w:cr/> elements that must be converted to spaces.
    $paragraphParts = New-Object System.Collections.Generic.List[string]
    $paragraphNodes = $Node.SelectNodes('.//w:p', $NamespaceManager)

    if ($null -eq $paragraphNodes -or $paragraphNodes.Count -eq 0) {
        # Fallback: node may not contain paragraphs (e.g., a single run).
        # Collect text directly from runs or text nodes.
        $runNodes = $Node.SelectNodes('.//w:r', $NamespaceManager)
        if ($null -ne $runNodes -and $runNodes.Count -gt 0) {
            $parts = New-Object System.Collections.Generic.List[string]
            foreach ($runNode in $runNodes) {
                $runText = ConvertFrom-OpenSpecOpenXmlRunText -RunNode $runNode -NamespaceManager $NamespaceManager
                if (-not [string]::IsNullOrEmpty($runText)) {
                    $parts.Add($runText)
                }
            }
            return (($parts.ToArray() -join '') -replace '\s+', ' ').Trim()
        }

        # Last resort: just get raw inner text
        return ($Node.InnerText -replace '\s+', ' ').Trim()
    }

    foreach ($paragraphNode in $paragraphNodes) {
        $runNodes = $paragraphNode.SelectNodes('./w:r', $NamespaceManager)
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($runNode in $runNodes) {
            $runText = ConvertFrom-OpenSpecOpenXmlRunText -RunNode $runNode -NamespaceManager $NamespaceManager
            if (-not [string]::IsNullOrEmpty($runText)) {
                $parts.Add($runText)
            }
        }

        $paraText = ($parts.ToArray() -join '').Trim()
        if (-not [string]::IsNullOrWhiteSpace($paraText)) {
            $paragraphParts.Add($paraText)
        }
    }

    return (($paragraphParts.ToArray() -join ' ') -replace '\s+', ' ').Trim()
}

function Get-OpenSpecOpenXmlRelationshipMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.Compression.ZipArchive]$Archive
    )

    $map = @{}
    $relsEntry = $Archive.GetEntry('word/_rels/document.xml.rels')
    if ($null -eq $relsEntry) {
        return $map
    }

    $stream = $relsEntry.Open()
    $reader = New-Object System.IO.StreamReader($stream)
    $relsXml = $reader.ReadToEnd()
    $reader.Dispose()
    $stream.Dispose()

    $relsDoc = New-Object System.Xml.XmlDocument
    $relsDoc.PreserveWhitespace = $false
    $relsDoc.LoadXml($relsXml)

    $nsmgr = New-Object System.Xml.XmlNamespaceManager($relsDoc.NameTable)
    $nsmgr.AddNamespace('r', 'http://schemas.openxmlformats.org/package/2006/relationships')

    $relationshipNodes = $relsDoc.SelectNodes('//r:Relationship', $nsmgr)
    foreach ($relationshipNode in $relationshipNodes) {
        $id = $relationshipNode.GetAttribute('Id')
        $target = $relationshipNode.GetAttribute('Target')
        $targetMode = $relationshipNode.GetAttribute('TargetMode')

        if ([string]::IsNullOrWhiteSpace($id) -or [string]::IsNullOrWhiteSpace($target)) {
            continue
        }

        $resolvedTarget = $target
        if ($targetMode -ne 'External' -and -not ($target -match '^(?i)https?://')) {
            if ($target.StartsWith('/')) {
                $resolvedTarget = $target.TrimStart('/')
            }
            else {
                $resolvedTarget = "word/$target"
            }
        }

        $map[$id] = [pscustomobject]@{
            Target = $resolvedTarget
            TargetMode = $targetMode
        }
    }

    return $map
}

function ConvertFrom-OpenSpecOpenXmlParagraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$ParagraphNode,

        [Parameter(Mandatory)]
        [System.Xml.XmlNamespaceManager]$NamespaceManager,

        [Parameter(Mandatory)]
        [hashtable]$RelationshipMap,

        [Parameter()]
        [System.IO.Compression.ZipArchive]$Archive,

        [Parameter()]
        [string]$MediaOutputDirectory
    )

    $segments = New-Object System.Collections.Generic.List[string]
    foreach ($child in $ParagraphNode.ChildNodes) {
        $rendered = ConvertFrom-OpenSpecOpenXmlInlineNode -Node $child -NamespaceManager $NamespaceManager -RelationshipMap $RelationshipMap -Archive $Archive -MediaOutputDirectory $MediaOutputDirectory
        if (-not [string]::IsNullOrEmpty($rendered)) {
            $segments.Add($rendered)
        }
    }

    $joined = ($segments.ToArray() -join '')
    $joined = $joined -replace "`r?`n", ' '
    $joined = $joined -replace '\s{2,}', ' '

    # Merge adjacent formatting markers (close marker + open marker = nothing).
    # This collapses adjacent same-format runs that Word split arbitrarily.
    $bm = [string][char]0xFDD0
    $im = [string][char]0xFDD1
    $cm = [string][char]0xFDD2
    # Direct adjacency: close + open with nothing between
    $joined = $joined.Replace("$bm$bm", '')
    $joined = $joined.Replace("$im$im", '')
    $joined = $joined.Replace("$cm$cm", '')
    # Adjacency with single space (from whitespace moved outside markers):
    # e.g., {B}text1{B} {B}text2{B} → {B}text1 text2{B}
    $joined = $joined.Replace("$bm $bm", ' ')
    $joined = $joined.Replace("$im $im", ' ')
    $joined = $joined.Replace("$cm $cm", ' ')

    # Convert formatting markers to markdown syntax
    $joined = $joined.Replace($bm, '**')
    $joined = $joined.Replace($im, '*')
    $joined = $joined.Replace($cm, '`')

    return $joined.Trim()
}

function ConvertFrom-OpenSpecOpenXmlInlineNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$Node,

        [Parameter(Mandatory)]
        [System.Xml.XmlNamespaceManager]$NamespaceManager,

        [Parameter(Mandatory)]
        [hashtable]$RelationshipMap,

        [Parameter()]
        [System.IO.Compression.ZipArchive]$Archive,

        [Parameter()]
        [string]$MediaOutputDirectory
    )

    if ($null -eq $Node) {
        return ''
    }

    switch ($Node.LocalName) {
        'r' {
            # Check if this run contains a drawing (image) instead of text.
            $drawingNode = $Node.SelectSingleNode('./w:drawing', $NamespaceManager)
            if ($null -ne $drawingNode) {
                $imageMarkdown = ConvertFrom-OpenSpecOpenXmlDrawing -DrawingNode $drawingNode -NamespaceManager $NamespaceManager -RelationshipMap $RelationshipMap -Archive $Archive -MediaOutputDirectory $MediaOutputDirectory
                if (-not [string]::IsNullOrWhiteSpace($imageMarkdown)) {
                    return $imageMarkdown
                }
            }

            $text = ConvertFrom-OpenSpecOpenXmlRunText -RunNode $Node -NamespaceManager $NamespaceManager
            if (-not [string]::IsNullOrEmpty($text)) {
                $rPr = $Node.SelectSingleNode('./w:rPr', $NamespaceManager)
                if ($null -ne $rPr) {
                    $isBold = $false
                    $isItalic = $false
                    $isCode = $false

                    $boldNode = $rPr.SelectSingleNode('./w:b', $NamespaceManager)
                    if ($null -ne $boldNode) {
                        $val = $boldNode.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
                        $isBold = [string]::IsNullOrEmpty($val) -or $val -eq 'true' -or $val -eq '1'
                    }

                    $italicNode = $rPr.SelectSingleNode('./w:i', $NamespaceManager)
                    if ($null -ne $italicNode) {
                        $val = $italicNode.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
                        $isItalic = [string]::IsNullOrEmpty($val) -or $val -eq 'true' -or $val -eq '1'
                    }

                    # Detect code formatting via character style (e.g., InlineCode)
                    $rStyleNode = $rPr.SelectSingleNode('./w:rStyle', $NamespaceManager)
                    if ($null -ne $rStyleNode) {
                        $styleName = $rStyleNode.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
                        if ($styleName -match '(?i)(Code|Monospace|Console|Verbatim)') {
                            $isCode = $true
                        }
                    }

                    # Detect code formatting via monospace font name
                    if (-not $isCode) {
                        $fontsNode = $rPr.SelectSingleNode('./w:rFonts', $NamespaceManager)
                        if ($null -ne $fontsNode) {
                            $fontName = $fontsNode.GetAttribute('ascii', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
                            if ($fontName -match '^(Courier|Consolas|Lucida Console|Menlo|Monaco)') {
                                $isCode = $true
                            }
                        }
                    }

                    # Use Unicode noncharacters as temporary formatting markers.
                    # These are merged in ConvertFrom-OpenSpecOpenXmlParagraph and
                    # converted to markdown ** / * / ` markers.
                    $bm = [char]0xFDD0  # bold marker
                    $im = [char]0xFDD1  # italic marker
                    $cm = [char]0xFDD2  # code marker

                    if ($isCode -or $isBold -or $isItalic) {
                        # Trim whitespace from the text and move it outside
                        # the formatting markers. CommonMark requires closing
                        # markers to be preceded by non-whitespace.
                        $trimmedText = $text.Trim()
                        if ($trimmedText.Length -gt 0) {
                            $leading = if ($text -ne $text.TrimStart()) { ' ' } else { '' }
                            $trailing = if ($text -ne $text.TrimEnd()) { ' ' } else { '' }
                            if ($isCode) {
                                $text = "$leading$cm$trimmedText$cm$trailing"
                            } elseif ($isBold -and $isItalic) {
                                $text = "$leading$bm$im$trimmedText$im$bm$trailing"
                            } elseif ($isBold) {
                                $text = "$leading$bm$trimmedText$bm$trailing"
                            } elseif ($isItalic) {
                                $text = "$leading$im$trimmedText$im$trailing"
                            }
                        }
                    }
                }
            }
            return $text
        }
        'hyperlink' {
            $linkTextParts = New-Object System.Collections.Generic.List[string]
            foreach ($inner in $Node.ChildNodes) {
                $part = ConvertFrom-OpenSpecOpenXmlInlineNode -Node $inner -NamespaceManager $NamespaceManager -RelationshipMap $RelationshipMap -Archive $Archive -MediaOutputDirectory $MediaOutputDirectory
                if (-not [string]::IsNullOrEmpty($part)) {
                    $linkTextParts.Add($part)
                }
            }

            $linkText = ($linkTextParts.ToArray() -join '')
            $linkText = ($linkText -replace '\s{2,}', ' ').Trim()
            if ([string]::IsNullOrWhiteSpace($linkText)) {
                return ''
            }

            $anchor = $Node.GetAttribute('anchor', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
            if (-not [string]::IsNullOrWhiteSpace($anchor)) {
                return "[$linkText](#$anchor)"
            }

            $relationshipId = $Node.GetAttribute('id', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
            if (-not [string]::IsNullOrWhiteSpace($relationshipId) -and $RelationshipMap.ContainsKey($relationshipId)) {
                $target = $RelationshipMap[$relationshipId].Target
                if (-not [string]::IsNullOrWhiteSpace($target)) {
                    return "[$linkText]($target)"
                }
            }

            return $linkText
        }
        'bookmarkStart' {
            return ''
        }
        'drawing' {
            # Handle <w:drawing> that appears directly as a paragraph child (outside a run).
            $imageMarkdown = ConvertFrom-OpenSpecOpenXmlDrawing -DrawingNode $Node -NamespaceManager $NamespaceManager -RelationshipMap $RelationshipMap -Archive $Archive -MediaOutputDirectory $MediaOutputDirectory
            if (-not [string]::IsNullOrWhiteSpace($imageMarkdown)) {
                return $imageMarkdown
            }
            return ''
        }
        default {
            if ($Node.ChildNodes -and $Node.ChildNodes.Count -gt 0) {
                $parts = New-Object System.Collections.Generic.List[string]
                foreach ($innerChild in $Node.ChildNodes) {
                    $part = ConvertFrom-OpenSpecOpenXmlInlineNode -Node $innerChild -NamespaceManager $NamespaceManager -RelationshipMap $RelationshipMap -Archive $Archive -MediaOutputDirectory $MediaOutputDirectory
                    if (-not [string]::IsNullOrEmpty($part)) {
                        $parts.Add($part)
                    }
                }
                return ($parts.ToArray() -join '')
            }

            return ''
        }
    }
}

function ConvertFrom-OpenSpecOpenXmlDrawing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$DrawingNode,

        [Parameter(Mandatory)]
        [System.Xml.XmlNamespaceManager]$NamespaceManager,

        [Parameter(Mandatory)]
        [hashtable]$RelationshipMap,

        [Parameter()]
        [System.IO.Compression.ZipArchive]$Archive,

        [Parameter()]
        [string]$MediaOutputDirectory
    )

    # Navigate to the <a:blip> element that contains the image relationship ID.
    # Structure: <w:drawing> → <wp:inline|wp:anchor> → <a:graphic> → <a:graphicData> → <pic:pic> → <pic:blipFill> → <a:blip r:embed="rIdN"/>
    $blipNode = $DrawingNode.SelectSingleNode('.//a:blip', $NamespaceManager)
    if ($null -eq $blipNode) {
        return $null
    }

    $embedId = $blipNode.GetAttribute('embed', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
    if ([string]::IsNullOrWhiteSpace($embedId)) {
        return $null
    }

    if (-not $RelationshipMap.ContainsKey($embedId)) {
        return $null
    }

    $rel = $RelationshipMap[$embedId]
    $imageArchivePath = $rel.Target  # e.g., "word/media/image1.png"

    # Extract alt text from <wp:docPr descr="..."> or <pic:cNvPr descr="...">.
    $altText = ''
    $docPrNode = $DrawingNode.SelectSingleNode('.//wp:docPr', $NamespaceManager)
    if ($null -ne $docPrNode) {
        $descr = $docPrNode.GetAttribute('descr')
        if (-not [string]::IsNullOrWhiteSpace($descr)) {
            $altText = $descr
        }
        elseif (-not [string]::IsNullOrWhiteSpace($docPrNode.GetAttribute('title'))) {
            $altText = $docPrNode.GetAttribute('title')
        }
    }

    if ([string]::IsNullOrWhiteSpace($altText)) {
        $cNvPrNode = $DrawingNode.SelectSingleNode('.//pic:cNvPr', $NamespaceManager)
        if ($null -ne $cNvPrNode) {
            $descr = $cNvPrNode.GetAttribute('descr')
            if (-not [string]::IsNullOrWhiteSpace($descr)) {
                $altText = $descr
            }
        }
    }

    # Extract the image file from the DOCX archive.
    $imageFilename = [System.IO.Path]::GetFileName($imageArchivePath)
    if ([string]::IsNullOrWhiteSpace($altText)) {
        $altText = [System.IO.Path]::GetFileNameWithoutExtension($imageFilename)
    }

    if ($null -eq $Archive -or [string]::IsNullOrWhiteSpace($MediaOutputDirectory)) {
        # No archive/output directory — emit placeholder.
        return "![${altText}](media/${imageFilename})"
    }

    $imageEntry = $Archive.GetEntry($imageArchivePath)
    if ($null -eq $imageEntry) {
        # Try without the word/ prefix.
        $fallbackPath = $imageArchivePath -replace '^word/', ''
        $imageEntry = $Archive.GetEntry("word/$fallbackPath")
        if ($null -eq $imageEntry) {
            return "![${altText}](media/${imageFilename})"
        }
    }

    if (-not (Test-Path -LiteralPath $MediaOutputDirectory)) {
        [void](New-Item -Path $MediaOutputDirectory -ItemType Directory -Force)
    }

    # Extract the image to a temporary buffer to detect its actual format,
    # then save with the correct file extension.
    $sourceStream = $imageEntry.Open()
    try {
        $memStream = New-Object System.IO.MemoryStream
        try {
            $sourceStream.CopyTo($memStream)
            [void]$memStream.Seek(0, [System.IO.SeekOrigin]::Begin)

            # Detect actual image format from magic bytes.
            $header = New-Object byte[] 8
            $bytesRead = $memStream.Read($header, 0, 8)
            [void]$memStream.Seek(0, [System.IO.SeekOrigin]::Begin)

            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($imageFilename)
            $detectedExt = $null
            if ($bytesRead -ge 8 -and $header[0] -eq 0x89 -and $header[1] -eq 0x50 -and $header[2] -eq 0x4E -and $header[3] -eq 0x47) {
                $detectedExt = '.png'
            }
            elseif ($bytesRead -ge 3 -and $header[0] -eq 0xFF -and $header[1] -eq 0xD8 -and $header[2] -eq 0xFF) {
                $detectedExt = '.jpg'
            }
            elseif ($bytesRead -ge 3 -and $header[0] -eq 0x47 -and $header[1] -eq 0x49 -and $header[2] -eq 0x46) {
                $detectedExt = '.gif'
            }
            elseif ($bytesRead -ge 4 -and $header[0] -eq 0x52 -and $header[1] -eq 0x49 -and $header[2] -eq 0x46 -and $header[3] -eq 0x46) {
                $detectedExt = '.webp'
            }
            elseif ($bytesRead -ge 4 -and $header[0] -eq 0x01 -and $header[1] -eq 0x00 -and $header[2] -eq 0x00 -and $header[3] -eq 0x00) {
                $detectedExt = '.emf'
            }
            elseif ($bytesRead -ge 4 -and $header[0] -eq 0xD7 -and $header[1] -eq 0xCD -and $header[2] -eq 0xC6 -and $header[3] -eq 0x9A) {
                $detectedExt = '.wmf'
            }

            if ($null -ne $detectedExt) {
                $imageFilename = "${baseName}${detectedExt}"
            }

            $outputFilePath = Join-Path -Path $MediaOutputDirectory -ChildPath $imageFilename
            if (-not (Test-Path -LiteralPath $outputFilePath)) {
                $destStream = [System.IO.File]::Create($outputFilePath)
                try {
                    $memStream.CopyTo($destStream)
                }
                finally {
                    $destStream.Dispose()
                }
            }
        }
        finally {
            $memStream.Dispose()
        }
    }
    finally {
        $sourceStream.Dispose()
    }

    return "![${altText}](media/${imageFilename})"
}

function ConvertFrom-OpenSpecOpenXmlRunText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$RunNode,

        [Parameter(Mandatory)]
        [System.Xml.XmlNamespaceManager]$NamespaceManager
    )

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($runChild in $RunNode.ChildNodes) {
        switch ($runChild.LocalName) {
            't' {
                $parts.Add($runChild.InnerText)
            }
            'tab' {
                $parts.Add(' ')
            }
            'br' {
                $parts.Add(' ')
            }
            'cr' {
                $parts.Add(' ')
            }
        }
    }

    return ($parts.ToArray() -join '')
}

function Get-OpenSpecOpenXmlParagraphAnchorInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$ParagraphNode,

        [Parameter(Mandatory)]
        [System.Xml.XmlNamespaceManager]$NamespaceManager,

        [Parameter()]
        [string]$ParagraphText,

        [Parameter()]
        [string]$HeadingStyle
    )

    $anchors = New-Object System.Collections.Generic.List[string]
    $bookmarkNames = New-Object System.Collections.Generic.List[string]
    $sectionAnchor = $null

    $bookmarkNodes = $ParagraphNode.SelectNodes('.//w:bookmarkStart', $NamespaceManager)
    foreach ($bookmarkNode in $bookmarkNodes) {
        $bookmarkName = $bookmarkNode.GetAttribute('name', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
        if ([string]::IsNullOrWhiteSpace($bookmarkName)) {
            continue
        }

        if ($bookmarkName -eq '_GoBack') {
            continue
        }

        $anchors.Add($bookmarkName)
        $bookmarkNames.Add($bookmarkName)
    }

    if ($HeadingStyle -match '^Heading[1-6]$') {
        $sectionAnchor = Get-OpenSpecSectionAnchorFromHeadingText -HeadingText $ParagraphText
        if (-not [string]::IsNullOrWhiteSpace($sectionAnchor)) {
            $anchors.Add($sectionAnchor)
        }
    }

    [pscustomobject]@{
        Anchors = @($anchors.ToArray() | Select-Object -Unique)
        BookmarkNames = @($bookmarkNames.ToArray() | Select-Object -Unique)
        SectionAnchor = $sectionAnchor
    }
}

function Get-OpenSpecOpenXmlParagraphInternalHyperlinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$ParagraphNode,

        [Parameter(Mandatory)]
        [System.Xml.XmlNamespaceManager]$NamespaceManager
    )

    $links = New-Object System.Collections.Generic.List[object]
    $hyperlinkNodes = $ParagraphNode.SelectNodes('.//w:hyperlink[@w:anchor]', $NamespaceManager)
    foreach ($hyperlinkNode in $hyperlinkNodes) {
        $anchor = $hyperlinkNode.GetAttribute('anchor', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
        if ([string]::IsNullOrWhiteSpace($anchor)) {
            continue
        }

        $textNodes = $hyperlinkNode.SelectNodes('.//w:t', $NamespaceManager)
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($textNode in $textNodes) {
            if (-not [string]::IsNullOrWhiteSpace($textNode.InnerText)) {
                [void]$parts.Add($textNode.InnerText)
            }
        }
        $text = (($parts.ToArray() -join '') -replace '\s+', ' ').Trim()

        [void]$links.Add([pscustomobject]@{
            Anchor = $anchor
            Text = $text
        })
    }

    return @($links.ToArray())
}

function Get-OpenSpecGlossarySlugFromTerm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Term
    )

    $slug = $Term -replace '\s+', '-' -replace '[^\w\-]', '' -replace '-+', '-' -replace '^-|-$', ''
    $slug = $slug.ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($slug)) {
        $slug = 'term'
    }
    return "gt_$slug"
}

function Get-OpenSpecSectionAnchorFromHeadingText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HeadingText
    )

    if ([string]::IsNullOrWhiteSpace($HeadingText)) {
        return $null
    }

    $normalized = ($HeadingText -replace '^\s+', '').Trim()
    if ($normalized -match '^(?<num>\d+(?:\.\d+){0,6})(?:\.|\s|$)') {
        return "Section_$($Matches['num'])"
    }

    return $null
}

function Add-OpenSpecSectionAnchorsFromToc {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Markdown
    )

    $result = $Markdown
    $tocRegex = [regex]::new(
        '(?im)^\[(?<label>(?<num>\d+(?:\.\d+)*)[^\]]*)\]\(#(?<toc>_Toc\d+)\)\s*$',
        [System.Text.RegularExpressions.RegexOptions]::None
    )

    # Build map from _Toc anchors to Section_X.Y anchors.
    $aliasMap = @{}
    foreach ($match in $tocRegex.Matches($result)) {
        $sectionNum = $match.Groups['num'].Value
        $tocAnchor = $match.Groups['toc'].Value

        if ([string]::IsNullOrWhiteSpace($sectionNum) -or [string]::IsNullOrWhiteSpace($tocAnchor)) {
            continue
        }

        $sectionAnchor = "Section_$sectionNum"
        if (-not $aliasMap.ContainsKey($tocAnchor)) {
            $aliasMap[$tocAnchor] = $sectionAnchor
        }
    }

    # Rewrite TOC links: replace _Toc targets with Section_X.Y and strip page numbers.
    $result = $tocRegex.Replace($result, {
        param($m)
        $label = $m.Groups['label'].Value
        $sectionNum = $m.Groups['num'].Value
        $tocAnchor = $m.Groups['toc'].Value

        # Determine the target anchor.
        $targetAnchor = if ($aliasMap.ContainsKey($tocAnchor)) {
            $aliasMap[$tocAnchor]
        } else {
            $tocAnchor
        }

        # Strip the trailing page number from the label.
        # Label format: "<section_num> <title> <page_num>"
        # The page number is the last group of digits at the end.
        $cleanLabel = $label
        if ($cleanLabel -match '^(?<num>\d+(?:\.\d+)*)\s+(?<title>.+?)\s+\d+$') {
            $cleanLabel = "$($Matches['num']) $($Matches['title'])"
        }
        elseif ($cleanLabel -match '^(?<num>\d+(?:\.\d+)*)\s+\d+$') {
            # Edge case: section with only a number and page number (no title text)
            $cleanLabel = $Matches['num']
        }

        "[$cleanLabel](#$targetAnchor)"
    })

    # Ensure Section_X.Y anchor tags exist at each heading that has a _Toc anchor.
    foreach ($tocAnchor in $aliasMap.Keys) {
        $sectionAnchor = $aliasMap[$tocAnchor]
        $sectionPattern = '<a id="' + [regex]::Escape($sectionAnchor) + '"></a>'
        if ($result -match $sectionPattern) {
            continue
        }

        # Insert Section anchor alongside the _Toc anchor tag.
        $anchorPattern = '<a id="' + [regex]::Escape($tocAnchor) + '"></a>'
        $anchorRegex = [regex]::new($anchorPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $anchorMatch = $anchorRegex.Match($result)
        if (-not $anchorMatch.Success) {
            continue
        }

        $newAnchor = '<a id="' + $sectionAnchor + '"></a>'
        $replacement = $newAnchor + [Environment]::NewLine + $anchorMatch.Value
        $result = $result.Substring(0, $anchorMatch.Index) + $replacement + $result.Substring($anchorMatch.Index + $anchorMatch.Length)
    }

    # Remove _Toc anchor tags — they are no longer referenced by TOC links
    # (which now use Section_X.Y) and were only kept for positioning above.
    $result = [regex]::Replace($result, '(?m)^\s*<a id="_Toc\d+"></a>\s*\r?\n?', '')

    # Prepend section numbers to heading lines that follow a Section_X.Y anchor.
    # Word uses auto-numbering for headings, so the section number isn't in the
    # paragraph text. The TOC tells us the number; inject it into the heading.
    $result = [regex]::Replace(
        $result,
        '(?m)^(?<anchor><a id="Section_(?<num>\d+(?:\.\d+)*)"></a>\r?\n)(?<hashes>#{1,6}) (?<title>.+)$',
        {
            param($m)
            $num = $m.Groups['num'].Value
            $hashes = $m.Groups['hashes'].Value
            $title = $m.Groups['title'].Value
            # Only prepend if the title doesn't already start with the section number.
            if ($title -match "^$([regex]::Escape($num))[\.\s]") {
                return $m.Value
            }
            "$($m.Groups['anchor'].Value)$hashes $num $title"
        }
    )

    return $result
}

function Test-OpenSpecOpenXmlPacketDiagram {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$TableNode,

        [Parameter(Mandatory)]
        [System.Xml.XmlNamespaceManager]$NamespaceManager
    )

    # Detect packet layout tables by checking if the first row contains
    # cells with a known packet diagram paragraph style.
    $firstRow = $TableNode.SelectSingleNode('./w:tr[1]', $NamespaceManager)
    if ($null -eq $firstRow) {
        return $false
    }

    $firstCell = $firstRow.SelectSingleNode('./w:tc[1]', $NamespaceManager)
    if ($null -eq $firstCell) {
        return $false
    }

    $styleNode = $firstCell.SelectSingleNode('.//w:pStyle', $NamespaceManager)
    if ($null -eq $styleNode) {
        return $false
    }

    $styleName = $styleNode.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')

    # Primary match: 'PacketDiagramHeaderText' and 'Packetdiagramheaderrow' variants.
    if ($styleName -like 'PacketDiagram*') {
        return $true
    }

    # Secondary match: 'Definition-Field' / 'Definition-Field2' styles used for packet
    # diagrams in some specs. Require >=30 columns to avoid matching non-packet tables.
    if ($styleName -like 'Definition-Field*') {
        $cellCount = $firstRow.SelectNodes('./w:tc', $NamespaceManager).Count
        return ($cellCount -ge 30)
    }

    return $false
}

function ConvertFrom-OpenSpecOpenXmlPacketDiagram {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$TableNode,

        [Parameter(Mandatory)]
        [System.Xml.XmlNamespaceManager]$NamespaceManager
    )

    $wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    $rowNodes = $TableNode.SelectNodes('./w:tr', $NamespaceManager)
    if ($null -eq $rowNodes -or $rowNodes.Count -lt 2) {
        return @()
    }

    $bitOffset = 0
    # Each entry: @{ StartBit; EndBit; Label }
    $fields = New-Object System.Collections.Generic.List[hashtable]

    # Skip the first row (header with bit position labels).
    for ($rowIdx = 1; $rowIdx -lt $rowNodes.Count; $rowIdx++) {
        $rowNode = $rowNodes[$rowIdx]
        $cellNodes = $rowNode.SelectNodes('./w:tc', $NamespaceManager)

        foreach ($cellNode in $cellNodes) {
            # Determine the column span (bit width) from w:gridSpan.
            $gridSpanNode = $cellNode.SelectSingleNode('./w:tcPr/w:gridSpan', $NamespaceManager)
            $span = 1
            if ($null -ne $gridSpanNode) {
                $spanVal = $gridSpanNode.GetAttribute('val', $wNs)
                if (-not [string]::IsNullOrWhiteSpace($spanVal)) {
                    $span = [int]$spanVal
                }
            }

            # Extract the cell text.
            $textParts = New-Object System.Collections.Generic.List[string]
            $textNodes = $cellNode.SelectNodes('.//w:t', $NamespaceManager)
            foreach ($tNode in $textNodes) {
                if (-not [string]::IsNullOrWhiteSpace($tNode.InnerText)) {
                    $textParts.Add($tNode.InnerText)
                }
            }
            $cellText = ($textParts.ToArray() -join '').Trim()

            # Continuation cells ("...") or empty cells extend the previous field.
            if ($cellText -eq '...' -or [string]::IsNullOrWhiteSpace($cellText)) {
                if ($fields.Count -gt 0) {
                    $fields[$fields.Count - 1].EndBit = $bitOffset + $span - 1
                }
                $bitOffset += $span
                continue
            }

            $startBit = $bitOffset
            $endBit = $bitOffset + $span - 1
            $fields.Add(@{ StartBit = $startBit; EndBit = $endBit; Label = $cellText })
            $bitOffset += $span
        }
    }

    if ($fields.Count -eq 0) {
        return @()
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('```mermaid')
    $lines.Add('packet-beta')
    foreach ($field in $fields) {
        $s = $field.StartBit
        $e = $field.EndBit
        $label = $field.Label
        $lines.Add("  ${s}-${e}: `"${label}`"")
    }
    $lines.Add('```')
    $lines.Add('')

    return $lines.ToArray()
}

function ConvertFrom-OpenSpecOpenXmlTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$TableNode,

        [Parameter(Mandatory)]
        [System.Xml.XmlNamespaceManager]$NamespaceManager,

        [Parameter()]
        [hashtable]$RelationshipMap = @{},

        [Parameter()]
        [System.IO.Compression.ZipArchive]$Archive,

        [Parameter()]
        [string]$MediaOutputDirectory
    )

    # Check if this is a packet diagram table — route to mermaid converter if so.
    if (Test-OpenSpecOpenXmlPacketDiagram -TableNode $TableNode -NamespaceManager $NamespaceManager) {
        $mermaidResult = ConvertFrom-OpenSpecOpenXmlPacketDiagram -TableNode $TableNode -NamespaceManager $NamespaceManager
        if ($mermaidResult.Count -gt 0) {
            return $mermaidResult
        }
    }

    $rows = New-Object System.Collections.Generic.List[object]
    $maxColumns = 0

    $rowNodes = $TableNode.SelectNodes('./w:tr', $NamespaceManager)
    foreach ($rowNode in $rowNodes) {
        $cells = New-Object System.Collections.Generic.List[string]
        $cellNodes = $rowNode.SelectNodes('./w:tc', $NamespaceManager)
        foreach ($cellNode in $cellNodes) {
            # Extract cell content with formatting and links preserved.
            # Each <w:tc> contains one or more <w:p> paragraphs.
            $paragraphNodes = $cellNode.SelectNodes('./w:p', $NamespaceManager)
            if ($null -ne $paragraphNodes -and $paragraphNodes.Count -gt 0) {
                $cellParts = New-Object System.Collections.Generic.List[string]
                foreach ($pNode in $paragraphNodes) {
                    $pText = ConvertFrom-OpenSpecOpenXmlParagraph -ParagraphNode $pNode -NamespaceManager $NamespaceManager -RelationshipMap $RelationshipMap -Archive $Archive -MediaOutputDirectory $MediaOutputDirectory
                    if (-not [string]::IsNullOrWhiteSpace($pText)) {
                        $cellParts.Add($pText)
                    }
                }
                $cells.Add(($cellParts.ToArray() -join ' '))
            } else {
                # Fallback to plain text extraction
                $cells.Add((Get-OpenSpecOpenXmlNodeText -Node $cellNode -NamespaceManager $NamespaceManager))
            }
        }

        if ($cells.Count -gt $maxColumns) {
            $maxColumns = $cells.Count
        }

        $rows.Add($cells)
    }

    if ($rows.Count -eq 0 -or $maxColumns -eq 0) {
        return @('[Table with row/column spans - textual fallback]')
    }

    $header = @($rows[0])
    while ($header.Count -lt $maxColumns) {
        $header += "Column $($header.Count + 1)"
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('| ' + (($header | ForEach-Object { ConvertTo-OpenSpecEscapedPipeText $_ }) -join ' | ') + ' |')
    $lines.Add('| ' + ((1..$maxColumns | ForEach-Object { '---' }) -join ' | ') + ' |')

    for ($rowIndex = 1; $rowIndex -lt $rows.Count; $rowIndex++) {
        $row = @($rows[$rowIndex])
        while ($row.Count -lt $maxColumns) {
            $row += ''
        }

        $renderedRow = $row | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace($_)) { '-' } else { ConvertTo-OpenSpecEscapedPipeText $_ }
        }
        $lines.Add('| ' + ($renderedRow -join ' | ') + ' |')
    }

    return $lines.ToArray()
}
