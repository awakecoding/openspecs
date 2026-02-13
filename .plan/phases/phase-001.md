# Phase 1: Fix Text Extraction Fidelity

**Status**: ⏳ Pending
**Phase Number**: 1 of 5
**Estimated Duration**: 2-3 hours

## Overview

The most visible conversion artifact is mid-word spaces caused by how DOCX text runs are joined. Word frequently splits text across multiple `<w:r>` (run) elements for internal reasons like spell-checking, formatting changes, revision tracking, and field codes. The current code in `Get-OpenSpecOpenXmlNodeText` joins all `<w:t>` text nodes with space separators, which creates spurious spaces inside words.

## Dependencies

None — this is the first phase.

## Tasks in This Phase

| ID | Title | Dependencies | Risk | Status |
|---|---|---|---|---|
| TASK-001 | Fix Get-OpenSpecOpenXmlNodeText space-join bug | None | Medium | ⏳ Pending |
| TASK-002 | Handle xml:space=preserve attribute on w:t elements | TASK-001 | Low | ⏳ Pending |

## Detailed Task Breakdown

### TASK-001: Fix Get-OpenSpecOpenXmlNodeText space-join bug

**Description**: The function at line 157-176 of `ConvertFrom-OpenSpecDocx.ps1` collects all `<w:t>` text nodes and joins them with spaces. This is incorrect because Word splits text into multiple runs at arbitrary boundaries.

**Current code (broken)**:
```powershell
$segments = New-Object System.Collections.Generic.List[string]
$textNodes = $Node.SelectNodes('.//w:t', $NamespaceManager)
foreach ($textNode in $textNodes) {
    if ($textNode -and -not [string]::IsNullOrWhiteSpace($textNode.InnerText)) {
        $segments.Add($textNode.InnerText)
    }
}
return (($segments.ToArray() -join ' ') -replace '\s+', ' ').Trim()
```

**Problems**:
1. `-join ' '` adds a space between every text node, even when they're part of the same word
2. The whitespace-only filter (`-not [string]::IsNullOrWhiteSpace`) drops nodes that are just spaces, which may be significant

**Fix approach**: Join with empty string (`-join ''`) instead of space. Then let the content's own spaces handle word separation.

**Acceptance Criteria**:
- [ ] Table cell text no longer has spurious mid-word spaces
- [ ] Verified against these known examples:
  - `W EBAUTHN_AUTHENTICATOR_ATTACHMENT_ANY` → `WEBAUTHN_AUTHENTICATOR_ATTACHMENT_ANY`
  - `10/8/20 10` → `10/8/2010`
  - `technica l content` → `technical content`
  - `CTAPC LT_U2F_FLAG` → `CTAPCLT_U2F_FLAG`
  - `[W3C-WebAu thPKC2]` → `[W3C-WebAuthPKC2]`

**Dependencies**: None

**Estimated Time**: 1 hour

**Files Likely Affected**:
- `AwakeCoding.OpenSpecs/Private/ConvertFrom-OpenSpecDocx.ps1` (lines 157-176)

**Implementation Notes**:
- Change the join from `' '` to `''`
- Must also handle `<w:t>` nodes that ARE just whitespace (spaces between words) - these should be included, not skipped
- The `xml:space="preserve"` attribute on `<w:t>` elements indicates the node may contain significant leading/trailing whitespace

**Testing Requirements**:
- Re-convert MS-RDPEWA and MS-RDPBCGR
- Search output for known mid-word space patterns
- Verify no words are concatenated that should be separate

---

### TASK-002: Handle xml:space=preserve attribute on w:t elements

**Description**: Word uses `xml:space="preserve"` on `<w:t>` elements that contain significant whitespace (leading spaces, trailing spaces, or whitespace-only nodes that represent actual spaces between content). The current filter drops these nodes entirely.

**Fix approach**: 
- Include ALL `<w:t>` nodes in the concatenation, not just non-whitespace ones
- Use `xml:space="preserve"` to decide whether to include whitespace-only nodes
- A `<w:t>` with no `xml:space="preserve"` and only whitespace can be dropped
- A `<w:t>` with `xml:space="preserve"` should always be included

**Acceptance Criteria**:
- [ ] Intentional spaces between words in table cells are preserved
- [ ] Leading/trailing whitespace with xml:space=preserve is respected
- [ ] No empty content introduced (trim final result)

**Dependencies**: TASK-001

**Estimated Time**: 1 hour

**Files Likely Affected**:
- `AwakeCoding.OpenSpecs/Private/ConvertFrom-OpenSpecDocx.ps1` (lines 157-176)

**Implementation Notes**:
- The xml:space attribute is in the XML namespace, not the Word namespace
- Check with: `$textNode.GetAttribute('space', 'http://www.w3.org/XML/1998/namespace')`
- If value is "preserve", include the node even if it's whitespace-only

**Testing Requirements**:
- Verify table cells with multi-word content still have proper spacing
- Check that glossary term definitions maintain word separation
- Spot-check 5+ specs for regression

---

## Success Criteria

This phase is complete when:
- [ ] All 2 tasks marked complete
- [ ] No mid-word space artifacts in converted output
- [ ] Intentional whitespace preserved
- [ ] Manual spot-check of MS-RDPEWA and MS-RDPBCGR shows improvement

## Phase Execution Strategy

Execute TASK-001 first (change join separator), then TASK-002 (handle xml:space). These can potentially be combined into a single code change since they affect the same function.

## Rollback Plan

If the fix causes regression (words concatenated without spaces), revert to the original `' '` join and investigate the specific DOCX XML structure to understand the actual whitespace pattern.

## Notes Section

*Space for adding notes during execution*

---

**After Completion**: Update state.yaml to mark phase complete and transition to Phase 2
