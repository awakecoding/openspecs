# Phase 4: Fix Remaining Conversion Issues

**Status**: ⏳ Pending
**Phase Number**: 4 of 5
**Estimated Duration**: 2-3 hours

## Overview

Address additional conversion fidelity issues discovered during the Phase 3 comparison with live HTML. Focus on inline formatting and table cell content, which are the most likely remaining issues.

## Dependencies

Phase 3 (comparison identifies specific issues to fix).

## Tasks in This Phase

| ID | Title | Dependencies | Risk | Status |
|---|---|---|---|---|
| TASK-009 | Fix inline formatting boundary detection | TASK-008 | Medium | ⏳ Pending |
| TASK-010 | Fix table cell content extraction issues | TASK-008 | Medium | ⏳ Pending |

## Detailed Task Breakdown

### TASK-009: Fix inline formatting boundary detection

**Description**: The current `ConvertFrom-OpenSpecOpenXmlRunText` function extracts raw text from runs without applying formatting. Word stores bold/italic/code information in `<w:rPr>` (run properties) child elements. Add detection of these properties and wrap text in appropriate markdown formatting.

**OpenXML run properties**:
- `<w:b/>` or `<w:b w:val="true"/>` → bold → `**text**`
- `<w:i/>` or `<w:i w:val="true"/>` → italic → `*text*`
- `<w:rFonts w:ascii="Courier New"/>` or similar monospace → code → `` `text` ``

**Implementation approach**:
1. In `ConvertFrom-OpenSpecOpenXmlRunText`, check for `w:rPr` child node
2. Detect bold, italic, and monospace properties
3. Wrap the run text with appropriate markdown markers
4. Handle adjacent runs with same formatting (merge them, don't produce `**text****more**`)

**Edge cases**:
- Runs with both bold and italic: `***text***`
- Empty runs (formatting change only, no text)
- Runs inside hyperlinks (don't double-format)

**Acceptance Criteria**:
- [ ] Bold text renders as **bold** in markdown
- [ ] Italic text renders as *italic*
- [ ] Monospace renders as `code`
- [ ] No mid-word formatting markers

**Dependencies**: TASK-008

**Estimated Time**: 2 hours

**Files Likely Affected**:
- `AwakeCoding.OpenSpecs/Private/ConvertFrom-OpenSpecDocx.ps1` (function `ConvertFrom-OpenSpecOpenXmlRunText`)

---

### TASK-010: Fix table cell content extraction issues

**Description**: Table cells currently use `Get-OpenSpecOpenXmlNodeText` which flattens all content into a single text string. This loses structure like:
- Multi-paragraph cells (separate paragraphs in a cell)
- Links within table cells
- Formatting within table cells

**Implementation approach**:
1. Replace `Get-OpenSpecOpenXmlNodeText` usage in table extraction with paragraph-aware extraction
2. For each `<w:p>` in a table cell, use `ConvertFrom-OpenSpecOpenXmlParagraph` to get formatted text
3. Join paragraphs with `<br>` or spaces (markdown tables don't support multi-line cells)
4. Preserve hyperlinks within cells

**Acceptance Criteria**:
- [ ] Links inside table cells preserved as markdown links
- [ ] Formatting inside cells (bold, code) preserved
- [ ] Multi-paragraph cells joined with appropriate separator

**Dependencies**: TASK-008

**Estimated Time**: 2 hours

**Files Likely Affected**:
- `AwakeCoding.OpenSpecs/Private/ConvertFrom-OpenSpecDocx.ps1` (function `ConvertFrom-OpenSpecOpenXmlTable`)

---

## Success Criteria

This phase is complete when:
- [ ] Both tasks completed
- [ ] Inline formatting improved in output
- [ ] Table cell content more accurate

## Phase Execution Strategy

TASK-009 and TASK-010 can be developed in parallel as they affect different functions. However, TASK-009 should be done first since TASK-010's cell extraction can benefit from the formatting-aware run extraction.

## Rollback Plan

Each change is isolated to a specific function. If formatting causes issues, revert that specific function while keeping other improvements.

## Notes Section

*Tasks may be adjusted based on Phase 3 findings.*

---

**After Completion**: Update state.yaml to mark phase complete and transition to Phase 5
