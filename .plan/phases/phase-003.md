# Phase 3: Validate Against Live HTML

**Status**: ⏳ Pending
**Phase Number**: 3 of 5
**Estimated Duration**: 2-3 hours

## Overview

After applying text extraction and TOC/anchor fixes, compare the updated markdown output with the live HTML on Microsoft Learn to identify remaining conversion discrepancies. This phase is diagnostic — it produces a list of issues for Phase 4.

## Dependencies

Phases 1 and 2 must be complete (text extraction and TOC fixes applied).

## Tasks in This Phase

| ID | Title | Dependencies | Risk | Status |
|---|---|---|---|---|
| TASK-007 | Compare markdown with live HTML for MS-RDPEWA | TASK-005 | Low | ⏳ Pending |
| TASK-008 | Compare markdown with live HTML for MS-RDPBCGR | TASK-007 | Low | ⏳ Pending |

## Detailed Task Breakdown

### TASK-007: Compare markdown with live HTML for MS-RDPEWA (small spec)

**Description**: Re-convert MS-RDPEWA with all Phase 1-2 fixes applied, then compare section-by-section with the live HTML at `https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rdpewa/`.

**Comparison checklist**:
1. Heading text matches (section numbers, titles)
2. Body text content matches (paragraph text, no missing content)
3. Table structure matches (correct rows, columns, cell content)
4. Internal links work (TOC, cross-references, glossary terms)
5. External links preserved (RFC references, go.microsoft.com links)
6. Formatting matches (bold, italic, code)
7. List formatting (numbered, bulleted)
8. Special content (footnotes, product behavior notes)

**MS Learn URL pattern**: `ms-rdpewa/{section-guid}` where GUID matches bookmark anchors.

**Key sections to compare**:
- `3cca2157-ae15-4ec4-91f6-503bef9600fa` → 1 Introduction
- `34ba89cf-ac4d-48d0-85eb-f94e5c9ae0a7` → 1.1 Glossary
- `d9fb0d9a-fbcd-4222-8458-55747eb4fc04` → 2.2 Message Syntax
- `3012640f-f57a-45a4-aa87-e2afbad42a68` → 2.2.1 WebAuthN_Channel Request Message (has tables)

**Acceptance Criteria**:
- [ ] All 8 top-level sections compared
- [ ] All discrepancies documented with type and severity
- [ ] Issue list created for Phase 4

**Dependencies**: TASK-005

**Estimated Time**: 1.5 hours

**Files Likely Affected**: None (diagnostic task)

---

### TASK-008: Compare markdown with live HTML for MS-RDPBCGR (large spec)

**Description**: Spot-check comparison of MS-RDPBCGR (24K+ lines) with live HTML. Focus on sections that exercise complex conversion features: packet layout tables, extensive cross-references, long glossary, deep heading nesting.

**Key areas to verify**:
1. **Packet layout tables** (sections 2.2.x) — bit-field tables with 32-column layouts
2. **Cross-protocol references** — links to [MS-RDPELE], [MS-CSSP], etc.
3. **Deep heading nesting** — sections like 2.2.1.3.1.2 (6+ levels deep)
4. **Glossary** (section 1.1) — many term definitions with gt_GUID anchors
5. **Product behavior notes** — footnote-style references like `<1>`, `<2>`
6. **Connection sequence diagrams** — ASCII art or text descriptions
7. **Large tables** — capability sets, flag tables

**Acceptance Criteria**:
- [ ] At least 10 representative sections compared
- [ ] Packet layout tables verified
- [ ] Cross-reference links validated
- [ ] Additional issues documented and categorized

**Dependencies**: TASK-007

**Estimated Time**: 1.5 hours

**Files Likely Affected**: None (diagnostic task)

---

## Success Criteria

This phase is complete when:
- [ ] Both comparison tasks completed
- [ ] All significant discrepancies documented
- [ ] Issues categorized for Phase 4 work

## Phase Execution Strategy

Start with MS-RDPEWA (smaller, faster to compare), then move to MS-RDPBCGR for deeper validation. Use browser automation to navigate the live HTML and compare content.

## Rollback Plan

N/A — this is a diagnostic phase with no code changes.

## Notes Section

*Space for adding notes during execution*

---

**After Completion**: Update state.yaml to mark phase complete and transition to Phase 4
