# Phase 2: Fix TOC & Anchor Links

**Status**: ⏳ Pending
**Phase Number**: 2 of 5
**Estimated Duration**: 3-4 hours

## Overview

The primary user-reported issue: TOC links don't work because they point to `_Toc` anchors (Word's internal TOC bookmark IDs) instead of the meaningful `Section_X.Y` anchors. Additionally, TOC labels contain meaningless page numbers from the DOCX. This phase rewrites the TOC to be clean and functional.

## Dependencies

Phase 1 (text extraction fixes may affect heading text used for anchor generation).

## Tasks in This Phase

| ID | Title | Dependencies | Risk | Status |
|---|---|---|---|---|
| TASK-003 | Rewrite TOC links from _Toc to Section_X.Y | None | Low | ⏳ Pending |
| TASK-004 | Strip page numbers from TOC labels | TASK-003 | Low | ⏳ Pending |
| TASK-005 | Consolidate heading anchors | TASK-003 | Low | ⏳ Pending |
| TASK-006 | Generate slug anchors for non-numbered headings | TASK-005 | Low | ⏳ Pending |

## Detailed Task Breakdown

### TASK-003: Rewrite TOC links from _Toc anchors to Section_X.Y anchors

**Description**: The `Add-OpenSpecSectionAnchorsFromToc` function in `ConvertFrom-OpenSpecDocx.ps1` (lines 423-482) already builds a mapping from `_Toc` anchors to `Section_X.Y` anchors. It uses this to add `Section_X.Y` `<a id>` tags next to existing `_Toc` tags. Extend this function to ALSO rewrite the TOC hyperlinks themselves.

**Current TOC output**:
```markdown
[1 Introduction 17](#_Toc194624320)
[1.1 Glossary 17](#_Toc194624321)
```

**Desired TOC output**:
```markdown
[1 Introduction](#Section_1)
[1.1 Glossary](#Section_1.1)
```

**Implementation approach**:
1. In `Add-OpenSpecSectionAnchorsFromToc`, after building the `$aliasMap`, add a second pass
2. Use regex to find TOC links: `\[...\](#_TocNNNNNN)`
3. Replace `#_TocNNNNNN` with `#Section_X.Y` using the alias map
4. Simultaneously strip the page number from the label (TASK-004)

**Acceptance Criteria**:
- [ ] All TOC links use `#Section_X.Y` format
- [ ] The mapping from _Toc to Section_X.Y is correct for all numbered sections
- [ ] Non-numbered TOC entries are handled (may need TASK-006)

**Dependencies**: None

**Estimated Time**: 1 hour

**Files Likely Affected**:
- `AwakeCoding.OpenSpecs/Private/ConvertFrom-OpenSpecDocx.ps1` (function `Add-OpenSpecSectionAnchorsFromToc`)

---

### TASK-004: Strip page numbers from TOC entry labels

**Description**: TOC labels contain trailing page numbers from the DOCX (e.g., `1 Introduction 17`). The "17" is the page number in the printed document and is meaningless in markdown.

**Pattern to match**: `[<section_num> <title> <page_num>](#anchor)` where page_num is 1-3 digits at the end of the label.

**Regex approach**:
```
\[(?<label>(?<num>\d+(?:\.\d+)*)\s+(?<title>.+?))\s+\d+\]\(#(?<toc>_Toc\d+)\)
```

Replace with: `[<num> <title>](#Section_<num>)`

**Edge cases**:
- Titles ending with numbers: `2.2.1 CTAPCBOR_CMD_MAKE_CREDENTIAL Request 12` — the "12" is the page, but "1" in "2.2.1" is part of the section number. The regex handles this by matching section number at the start.
- Appendix sections: `6 Appendix A: Product Behavior 25` — "25" is the page number.
- Non-numbered sections in TOC (rare but possible)

**Acceptance Criteria**:
- [ ] Page numbers removed from all TOC labels
- [ ] Section numbers preserved
- [ ] Multi-word titles with embedded numbers not mangled

**Dependencies**: TASK-003 (combined in same regex replacement)

**Estimated Time**: 0.5 hours

**Files Likely Affected**:
- `AwakeCoding.OpenSpecs/Private/ConvertFrom-OpenSpecDocx.ps1`

---

### TASK-005: Consolidate heading anchors — remove _Toc, keep Section_X.Y + bookmark GUIDs

**Description**: Once TOC links use `Section_X.Y` (TASK-003), `_Toc` anchors become dead targets. Remove them from the output to reduce clutter. Each heading should have at most:
1. Bookmark GUID anchor (e.g., `<a id="section_3cca2157...">`) — used by cross-references
2. Section_X.Y anchor (e.g., `<a id="Section_1.2">`) — used by TOC

**Implementation approach**:
Filter `_Toc` prefixed bookmarks in `Get-OpenSpecOpenXmlParagraphAnchors` (line 380-392). Add a condition to skip bookmarks starting with `_Toc`.

**Acceptance Criteria**:
- [ ] No `<a id="_Toc...">` tags in output
- [ ] Bookmark GUID anchors preserved
- [ ] Section_X.Y anchors preserved
- [ ] Internal cross-references still resolve

**Dependencies**: TASK-003

**Estimated Time**: 0.5 hours

**Files Likely Affected**:
- `AwakeCoding.OpenSpecs/Private/ConvertFrom-OpenSpecDocx.ps1` (function `Get-OpenSpecOpenXmlParagraphAnchors`)

---

### TASK-006: Generate slug-based anchors for non-numbered headings

**Description**: The `Get-OpenSpecSectionAnchorFromHeadingText` function only generates anchors for headings that start with a section number (e.g., "1 Introduction" → `Section_1`). Non-numbered headings like "Table of Contents", "Revision Summary", "Index" only get bookmark GUID anchors. Add a fallback that generates a slug-based anchor for non-numbered headings.

**Slug generation rules**:
1. Convert to lowercase
2. Replace spaces with hyphens
3. Remove special characters (keep alphanumeric, hyphens)
4. Trim leading/trailing hyphens
5. Collapse multiple hyphens

**Examples**:
- "Table of Contents" → `table-of-contents`
- "Revision Summary" → `revision-summary`
- "Appendix A: Product Behavior" → `appendix-a-product-behavior`

**Acceptance Criteria**:
- [ ] Non-numbered headings get slug-based anchors
- [ ] TOC links to non-numbered sections use slug anchors
- [ ] Slug generation handles special characters correctly
- [ ] No conflicts with existing Section_X.Y anchors

**Dependencies**: TASK-005

**Estimated Time**: 1 hour

**Files Likely Affected**:
- `AwakeCoding.OpenSpecs/Private/ConvertFrom-OpenSpecDocx.ps1` (functions `Get-OpenSpecSectionAnchorFromHeadingText`, `Add-OpenSpecSectionAnchorsFromToc`)

---

## Success Criteria

This phase is complete when:
- [ ] All 4 tasks marked complete
- [ ] TOC links validated for MS-RDPEWA and MS-RDPBCGR
- [ ] All TOC links resolve to existing anchors
- [ ] No `_Toc` anchors remain in output
- [ ] Page numbers removed from TOC labels

## Phase Execution Strategy

Execute in order: TASK-003 + TASK-004 together (same regex), then TASK-005 (filter _Toc bookmarks), then TASK-006 (slug generation).

## Rollback Plan

If TOC rewriting breaks links, the `_Toc` anchors can be restored by reverting the bookmark filter in TASK-005. The original behavior is fully preserved in git history.

## Notes Section

*Space for adding notes during execution*

---

**After Completion**: Update state.yaml to mark phase complete and transition to Phase 3
