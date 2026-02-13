# Phase 5: Re-conversion & Final Validation

**Status**: ⏳ Pending
**Phase Number**: 5 of 5
**Estimated Duration**: 1-2 hours

## Overview

Re-convert all 41 RDP specs with all applied fixes and validate the output quality using updated fidelity tests.

## Dependencies

Phases 1-4 must be complete (all fixes applied).

## Tasks in This Phase

| ID | Title | Dependencies | Risk | Status |
|---|---|---|---|---|
| TASK-011 | Re-convert all 41 specs | TASK-010 | Low | ⏳ Pending |
| TASK-012 | Update fidelity tests and generate report | TASK-011 | Low | ⏳ Pending |

## Detailed Task Breakdown

### TASK-011: Re-convert all 41 specs with applied fixes

**Description**: Run the full conversion pipeline on all 41 RDP specs using the updated module.

**Execution**:
```powershell
Import-Module ./AwakeCoding.OpenSpecs -Force
$results = Get-ChildItem downloads-all/*.docx | Convert-OpenSpecToMarkdown -OutputPath converted-specs-all -Force
$results | Format-Table ProtocolId, Status, IssueCount, WarningCount, ErrorCount
```

**Verification**:
- All 41 return Status = 'Converted'
- No new ErrorCount > 0
- Compare total file sizes with previous conversion

**Acceptance Criteria**:
- [ ] All 41 specs converted successfully
- [ ] No new errors introduced
- [ ] Output file sizes comparable to previous

**Dependencies**: TASK-010

**Estimated Time**: 1 hour

**Files Likely Affected**: All files in `converted-specs-all/`

---

### TASK-012: Update fidelity tests and generate quality report

**Description**: Extend `Test-OpenSpecMarkdownFidelity` to validate anchor/link quality in addition to existing checks.

**New test checks**:
1. **HasWorkingTocLinks**: All TOC links point to anchors that exist in the document
2. **NoTocAnchors**: No `_Toc` anchors remain in output
3. **HasSectionAnchors**: Numbered headings have `Section_X.Y` anchors
4. **NoMidWordSpaces**: No common mid-word space patterns (regex check)

**Implementation**:
```powershell
# Extract all anchor IDs
$anchorIds = [regex]::Matches($markdown, '<a id="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }

# Extract all TOC link targets
$tocTargets = [regex]::Matches($markdown, '\]\(#([^)]+)\)') | ForEach-Object { $_.Groups[1].Value }

# Check all targets resolve
$brokenLinks = $tocTargets | Where-Object { $_ -notin $anchorIds }
```

**Quality report fields**:
- ProtocolId
- Pass (overall)
- HasWorkingTocLinks
- NoTocAnchors
- HasSectionAnchors
- NoMidWordSpaces
- BrokenLinkCount
- TotalLinkCount
- TotalAnchorCount

**Acceptance Criteria**:
- [ ] Fidelity test checks anchor links
- [ ] No _Toc anchors in any output
- [ ] Section_X.Y anchors present for all numbered headings
- [ ] Quality report generated

**Dependencies**: TASK-011

**Estimated Time**: 1 hour

**Files Likely Affected**:
- `AwakeCoding.OpenSpecs/Public/Test-OpenSpecMarkdownFidelity.ps1`

---

## Success Criteria

This phase is complete when:
- [ ] All 41 specs re-converted
- [ ] Fidelity tests pass with anchor validation
- [ ] Quality report generated

## Phase Execution Strategy

Sequential: convert all specs first, then run updated fidelity tests.

## Rollback Plan

Previous converted output is in git. If re-conversion produces worse results, revert to the pre-fix conversion.

## Notes Section

*Space for adding notes during execution*

---

**After Completion**: Project complete. Archive plan and clean up tracking files.
