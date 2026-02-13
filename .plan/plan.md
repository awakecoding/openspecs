# Fix Markdown Conversion Fidelity for MS Open Specs

**Status**: 🔵 Not Started
**Created**: 2026-02-12
**Estimated Duration**: 2-3 days

## Overview

The AwakeCoding.OpenSpecs PowerShell module converts Microsoft Open Specifications DOCX files to clean markdown. The current output has several fidelity issues discovered through analysis of the converted markdown and comparison with the live HTML on Microsoft Learn. This plan addresses the most impactful problems: broken TOC/anchor links, mid-word text extraction artifacts, and other conversion discrepancies.

## Project Strategy

- **Approach**: Incremental, fix highest-impact issues first
- **Total Tasks**: 12
- **Total Phases**: 5
- **Success Metric**: All TOC links resolve to correct headings; no mid-word space artifacts; fidelity tests pass
- **Risk Management**: Each fix is isolated to one function; test after each change

## Architecture/Design Principles

- Keep `Section_X.Y` as the primary TOC anchor format (human-readable, predictable)
- Keep bookmark GUID anchors (e.g., `section_3cca2157...`) for internal cross-references (matches MS Learn URL structure)
- Remove `_Toc` anchors entirely once TOC links no longer reference them
- Preserve glossary term anchors (`gt_GUID` format) as-is since they work correctly
- All changes are in the `AwakeCoding.OpenSpecs/Private/` functions

## Phases

### Phase 1: Fix Text Extraction Fidelity

**Goal**: Eliminate mid-word spaces caused by DOCX text run boundaries

**Duration Estimate**: 2-3 hours

**Tasks**:
- [x] **TASK-001**: Fix `Get-OpenSpecOpenXmlNodeText` space-join bug
  - **Acceptance Criteria**: Table cell text no longer has spurious mid-word spaces (e.g., `W EBAUTHN` → `WEBAUTHN`, `10/8/20 10` → `10/8/2010`)
  - **Dependencies**: None
  - **Risk**: Medium (must handle xml:space="preserve" correctly)
- [x] **TASK-002**: Fix whitespace handling for `<w:t>` elements with xml:space attribute
  - **Acceptance Criteria**: Intentional spaces (xml:space="preserve") are preserved; unintentional run-boundary joins produce no extra spaces
  - **Dependencies**: TASK-001
  - **Risk**: Low

**Success Criteria**:
- No mid-word space artifacts in table cells or body text
- Intentional whitespace preserved correctly
- No regressions in existing output

**Phase Completion Checklist**:
- [ ] All tasks completed
- [ ] Manual spot-check of output for 2-3 specs
- [ ] No blockers for next phase

**Detailed Plan**: See `.plan/phases/phase-001.md`

---

### Phase 2: Fix TOC & Anchor Links

**Goal**: Make all TOC links work by rewriting them to use `Section_X.Y` anchors and stripping page numbers

**Duration Estimate**: 3-4 hours

**Dependencies**: Phase 1 (text extraction fixes affect heading text used for anchor generation)

**Tasks**:
- [x] **TASK-003**: Rewrite TOC links from `_Toc` anchors to `Section_X.Y` anchors
  - **Acceptance Criteria**: TOC entries like `[1 Introduction 17](#_Toc194624320)` become `[1 Introduction](#Section_1)`
  - **Dependencies**: None
  - **Risk**: Low
- [x] **TASK-004**: Strip page numbers from TOC entry labels
  - **Acceptance Criteria**: Page numbers removed from all TOC labels; section number and title preserved
  - **Dependencies**: TASK-003 (combined in same function)
  - **Risk**: Low
- [ ] **TASK-005**: Consolidate heading anchors — remove `_Toc` anchors, keep `Section_X.Y` + bookmark GUIDs
  - **Acceptance Criteria**: Each heading has at most 2 anchors: bookmark GUID + `Section_X.Y`; no `_Toc` anchors in output
  - **Dependencies**: TASK-003
  - **Risk**: Low
- [ ] **TASK-006**: Generate slug-based anchors for non-numbered headings
  - **Acceptance Criteria**: Non-numbered headings (e.g., "Table of Contents", "Revision Summary") get slug-based anchors; TOC links to them work
  - **Dependencies**: TASK-005
  - **Risk**: Low

**Success Criteria**:
- All TOC links point to existing anchors
- No `_Toc` anchors remain in output
- Page numbers removed from TOC labels

**Phase Completion Checklist**:
- [ ] All tasks completed
- [ ] TOC links validated for MS-RDPEWA and MS-RDPBCGR
- [ ] No blockers for next phase

**Detailed Plan**: See `.plan/phases/phase-002.md`

---

### Phase 3: Validate Against Live HTML

**Goal**: Compare converted markdown with the live Microsoft Learn HTML to identify remaining conversion discrepancies

**Duration Estimate**: 2-3 hours

**Dependencies**: Phases 1 and 2 complete

**Tasks**:
- [ ] **TASK-007**: Compare markdown output with live HTML for MS-RDPEWA (small spec)
  - **Acceptance Criteria**: Section-by-section comparison completed; all discrepancies documented
  - **Dependencies**: TASK-005
  - **Risk**: Low
- [ ] **TASK-008**: Compare markdown output with live HTML for MS-RDPBCGR (large spec)
  - **Acceptance Criteria**: Spot-check comparison of representative sections; additional issues documented
  - **Dependencies**: TASK-007
  - **Risk**: Low

**Success Criteria**:
- All significant conversion discrepancies documented
- Issues categorized by severity and type

**Phase Completion Checklist**:
- [ ] All tasks completed
- [ ] Issue list created for remaining fixes
- [ ] No blockers for next phase

**Detailed Plan**: See `.plan/phases/phase-003.md`

---

### Phase 4: Fix Remaining Conversion Issues

**Goal**: Address additional fidelity issues discovered during comparison

**Duration Estimate**: 2-3 hours

**Dependencies**: Phase 3 (comparison identifies issues to fix)

**Tasks**:
- [ ] **TASK-009**: Fix inline formatting boundary detection (bold/italic/code spans)
  - **Acceptance Criteria**: Bold, italic, and code formatting correctly applied at word boundaries
  - **Dependencies**: TASK-008
  - **Risk**: Medium (formatting spans complex in OpenXML)
- [ ] **TASK-010**: Fix table cell content extraction issues
  - **Acceptance Criteria**: Multi-paragraph table cells render correctly; nested formatting preserved
  - **Dependencies**: TASK-008
  - **Risk**: Medium

**Success Criteria**:
- Improved formatting fidelity
- Table content matches live HTML

**Phase Completion Checklist**:
- [ ] All tasks completed
- [ ] Manual comparison shows improved fidelity
- [ ] No blockers for next phase

**Detailed Plan**: See `.plan/phases/phase-004.md`

---

### Phase 5: Re-conversion & Final Validation

**Goal**: Re-convert all 41 specs and validate quality

**Duration Estimate**: 1-2 hours

**Dependencies**: Phases 1-4 complete

**Tasks**:
- [ ] **TASK-011**: Re-convert all 41 specs with applied fixes
  - **Acceptance Criteria**: All 41 specs successfully converted; no new errors
  - **Dependencies**: TASK-010
  - **Risk**: Low
- [ ] **TASK-012**: Update fidelity tests and generate quality report
  - **Acceptance Criteria**: `Test-OpenSpecMarkdownFidelity` checks anchor links; conversion report shows improvement
  - **Dependencies**: TASK-011
  - **Risk**: Low

**Success Criteria**:
- All 41 specs re-converted successfully
- Fidelity tests pass with anchor validation
- Quality report shows measurable improvement

**Phase Completion Checklist**:
- [ ] All tasks completed
- [ ] All specs re-converted
- [ ] Fidelity tests pass
- [ ] Planning tracking files cleaned up

**Detailed Plan**: See `.plan/phases/phase-005.md`

---

## Key Issues Identified

### Issue 1: Mid-word spaces from DOCX text run boundaries
- **Root Cause**: `Get-OpenSpecOpenXmlNodeText` joins `<w:t>` text nodes with space separators (`-join ' '`), but Word splits text across multiple `<w:r>` runs at arbitrary points (spell-check, formatting, revisions)
- **Examples**: `W EBAUTHN` → `WEBAUTHN`, `10/8/20 10` → `10/8/2010`, `technica l` → `technical`
- **Fix**: Join `<w:t>` nodes without spaces; use `xml:space="preserve"` attribute to determine when actual spaces exist

### Issue 2: TOC links use `_Toc` anchors with embedded page numbers
- **Root Cause**: DOCX TOC entries contain `_Toc` bookmark references and page numbers. `Add-OpenSpecSectionAnchorsFromToc` adds `Section_X.Y` aliases but doesn't rewrite the TOC links themselves
- **Examples**: `[1 Introduction 17](#_Toc194624320)` should be `[1 Introduction](#Section_1)`
- **Fix**: Rewrite TOC links to use `Section_X.Y` and strip page numbers

### Issue 3: Three types of anchors per heading (redundant)
- **Current**: Each heading gets bookmark GUID + Section_X.Y + _Toc anchors
- **Desired**: Bookmark GUID + Section_X.Y only (remove _Toc)
- **Fix**: Stop emitting _Toc anchors once TOC links use Section_X.Y

### Issue 4: Cross-references use bookmark GUIDs
- **Status**: Working correctly — these resolve to existing `<a id="section_GUID">` tags
- **No fix needed**: Keep as-is; matches MS Learn URL structure

### Issue 5: Glossary term anchors use gt_GUID format
- **Status**: Working correctly — `[term](#gt_GUID)` links resolve to `<a id="gt_GUID">` tags
- **No fix needed**: Keep as-is

## Risk Assessment

**Medium Risk Items**:
- **TASK-001**: Text extraction space-join fix must correctly handle edge cases where spaces ARE intended between runs (e.g., separate sentences in a table cell)
  - **Mitigation**: Use `xml:space="preserve"` attribute; test with multiple specs
- **TASK-009**: Inline formatting detection in OpenXML is complex (run properties can nest)
  - **Mitigation**: Start with bold/italic only; defer complex cases

**Low Risk Items**:
- TOC rewriting is regex-based and pattern is well-defined
- Anchor consolidation is additive (remove _Toc, keep others)

## Definition of Done

Project is complete when:
- [ ] All 12 tasks completed
- [ ] All phases marked complete
- [ ] TOC links work in standard markdown renderers
- [ ] No mid-word space artifacts in output
- [ ] All 41 specs re-converted
- [ ] Fidelity tests pass with anchor validation
- [ ] Quality report generated

---

**Next Steps**:
1. Review and approve this plan
2. Run `.plan/execute.prompt.md` to begin execution
3. Execute repeatedly until completion
