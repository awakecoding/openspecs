---
name: windows-protocols
description: Local Microsoft Open Specifications corpus navigator for Windows protocols. Use this skill when the user asks protocol-level questions, needs message/structure details, wants section-by-section summaries, or needs cross-references across related specifications.
---

# Windows Protocols Corpus Navigator

## Overview

- The markdown corpus is already extracted locally, next to `SKILL.md`.
- Use local files only. Do not use network lookup for this skill.
- Do not run download or setup commands as part of normal usage.

This skill is optimized for structure-first navigation of Microsoft Open Specifications markdown and evidence-grounded answers.

## Corpus Layout

- `README.md` — curated quick index (RDP-focused list retained for convenience).
- `LEGAL.md` — legal and redistribution notice.
- `MS-*/` — full Microsoft protocol directories, directly under this folder.
- `MS-*/<PROTOCOL-ID>.md` — primary markdown spec content.
- `MS-*/media/` — extracted figures and image assets referenced by the markdown.

Use this selection strategy:

1. Resolve `MS-*` protocols directly under this folder first.
2. If required context is not present in local `MS-*` specs, explicitly call that out and request a narrower scope or additional source material.

## Protocol Naming and Scope

- `MS-...` documents are Microsoft protocol specifications (wire formats, behavior, state machines, structures).
- Families share prefixes (for example `MS-RDP*`, `MS-AD*`, `MS-MQ*`).

When a user asks a broad question, start from family prefixes and narrow to specific protocol IDs.

## When to Use / When Not to Use

Use this skill when the user asks for:

- Protocol semantics, message flow, field definitions, or sequencing rules.
- Cross-reference analysis between related specs.
- Security semantics and product-behavior distinctions in Open Specifications docs.

Do not use this skill as the primary source for:

- API usage tutorials, SDK how-to steps, or implementation quickstarts.
- Product configuration guidance not grounded in protocol specs.

If a required protocol is missing from root-level `MS-*` directories, state that explicitly and ask the user for the exact protocol ID or a narrower feature scope.

## Navigation Workflow

1. Normalize request terms into candidate protocol IDs (feature keyword -> family prefix -> likely IDs).
2. Validate candidates in `README.md` and directory names (`<PROTOCOL-ID>/`).
3. Start from the spec TOC (`<summary>` blocks and numbered entries) before deep reading.
4. Read sections in this order by intent:
	- orientation/versioning,
	- message or structure syntax,
	- behavior and sequencing,
	- security and product behavior notes.
5. Cross-check base vs extension specs when requirements may be split.
6. Answer with explicit protocol IDs and exact section headings; separate confirmed facts from inference.

## Canonical Spec Structure (Corpus-Guided)

The corpus is highly consistent. In a 425-spec analysis (`artifacts/reports/windows-protocols-structure-analysis-2026-02-16.md`), the most common top-level sequence is:

- `1 Introduction` (424 files)
- `2 Messages` (373 files)
- `3 Protocol Details` (371 files)
- `4 Protocol Examples` (362 files)
- `5 Security` (364 files)

Common `1.x` orientation subsections include:

- `1.1 Glossary`, `1.2 References`, `1.3 Overview`
- `1.4 Relationship to Other Protocols`
- `1.5 Prerequisites/Preconditions`
- `1.7 Versioning and Capability Negotiation`

Common `3.x.y` behavioral subsections include:

- `Abstract Data Model`
- `Timers`
- `Initialization`
- `Higher-Layer Triggered Events`
- `Message Processing Events and Sequencing Rules`
- `Timer Events`
- `Other Local Events`

Use these sections as the default reading spine unless the document is an outlier.

## Section-First Reading Playbook

Prioritize sections by question type:

- “What is this protocol / where does it fit?” -> `1.3`, `1.4`, `1.7`
- “How is data encoded / what are fields?” -> `2.2` (`Message Syntax`, `Common Data Types`, structures)
- “What is the runtime behavior / state machine?” -> `3.x` details and `3.x.y` sequencing sections
- “What security guarantees or knobs exist?” -> `5.*` security sections
- “Implementation differences by product/version?” -> `Appendix ... Product Behavior` and change tracking sections

When structure spans multiple specs, resolve in this order:

1. Base/core protocol semantics.
2. Extension-specific modifications.
3. Shared type dependencies (for example `MS-DTYP`).

## Outlier Handling

Not all specs use the exact canonical headings. Handle these common variants:

- `2 Structures`, `2 Attributes`, `2 Data Types`, `2 Message Transport` instead of `2 Messages`.
- `3 Structure Examples`, `3 Details`, or algorithm-specific section names.
- `4 Security` or `4 Security Considerations` when numbering shifts.
- Appendix variants such as `Full IDL`, `Full WSDL`, `Full XML Schema`, `Full JSON Schema`.
- Change tracking may appear as section `7`, `8`, `9`, or higher.

Rule: match by semantic intent first, section number second.

## Quick Discovery Patterns

- Query by protocol ID when the user provides a specific code (for example `MS-RDPEUDP`).
- Query by feature terms when ID is unknown (for example `capability`, `PDU`, `virtual channel`, `security exchange`, `compression`).
- For extension behavior, verify whether requirements are in a base protocol or an extension.
- For ambiguous acronyms, list 2-4 likely protocols and ask the user to choose before deep analysis.

## Answer Contract (Semi-Structured)

Default answer shape:

1. `Protocols consulted`: list exact IDs.
2. `Sections used`: list exact section titles (and numbers when available).
3. `Findings`: concise facts tied to those sections.
4. `Inference / uncertainty`: explicit separation from confirmed text.

Evidence policy:

- For non-obvious, contested, or security-sensitive claims, include section-grounded evidence.
- For straightforward facts, concise section references are enough.
- If two specs disagree, report both and identify likely version/context scope.

## Working Style

- Prefer section-grounded answers over high-level paraphrase.
- Include the exact protocol IDs used for the answer.
- If the corpus does not clearly answer a point, state uncertainty explicitly.
- Never present inferred behavior as normative requirement text.

## Typical Protocol Clusters

- RDP base and capabilities: `MS-RDPBCGR`
- Graphics pipeline: `MS-RDPEGFX`, `MS-RDPEGDI`
- Input/display: `MS-RDPEDISP`, `MS-RDPEI`
- Clipboard/device/channel extensions: `MS-RDPECLIP`, `MS-RDPEFS`, `MS-RDPEUSB`, `MS-RDPEV`
- Transport/security-related extensions: `MS-RDPEUDP`, `MS-RDPEUDP2`, `MS-RDPBCGR` security sections

Use these as starting points, then confirm against exact headings in the corpus.
