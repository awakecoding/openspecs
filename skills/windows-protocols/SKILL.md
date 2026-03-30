---
name: windows-protocols
description: Local Microsoft Open Specifications corpus navigator for Windows protocols. Parses protocol message formats, looks up field definitions, maps data types, traces protocol state machines, and performs cross-reference analysis across related specifications. Use when the user asks protocol-level questions, needs message/structure details or wire-format field definitions, wants section-by-section summaries, needs to trace protocol state machines or sequencing rules, or requires cross-references across related MS-* specifications.
---

# Windows Protocols Corpus Navigator

## Overview

- The corpus is already extracted next to `SKILL.md`.
- Use local files only; do not use network lookup, downloads, or setup commands.

## Corpus Layout

- `README.md` — top-level index. Start with Overview Documents for topical discovery.
- `LEGAL.md` — legal and redistribution notice.
- `<PROTOCOL-ID>/` — protocol directories.
- `<PROTOCOL-ID>/<PROTOCOL-ID>.md` — primary markdown spec content.
- `<PROTOCOL-ID>/media/` — extracted figures and image assets referenced by the markdown.

When the question is broad, start from Overview Documents or protocol families such as `MS-RDP*`, `MS-AD*`, or `MS-MQ*`.

## Reference File

- Use `SKILL.md` for the default workflow, worked example, and answer contract.
- Open `REFERENCE.md` only for these lookup aids: Domain Clusters, Canonical Spec Structure, and Section-First Routing.

## Navigation Workflow

Use this unified workflow for all queries:

1. **Topical questions**: identify the domain, open the matching Overview document from `README.md`, and follow its member-spec links.
   - **Anti-pattern**: do not rely on README keyword search alone; Overview documents provide the authoritative topic-to-protocol mapping.
2. **Known protocol ID**: Validate against `README.md` and directory names (`<PROTOCOL-ID>/`), then open the spec directly.
   - If the protocol is missing, say so and ask for the exact protocol ID or a narrower scope.
3. **Ambiguous acronyms**: List 2–4 likely protocols (via Overview docs) and ask the user to choose before deep analysis.
4. Scan the spec TOC (`<summary>` blocks and numbered entries) before deep reading.
5. Read sections in this order: orientation/versioning → syntax → behavior/sequencing → security/product behavior.
6. Cross-check base vs. extension specs when requirements are split, following cross-reference links as needed.
7. Answer with explicit protocol IDs and exact section headings; separate confirmed facts from inference.

### Link-Following

- Follow Overview-document references and inline links rather than guessing paths.
- Treat Overview → spec → related spec as the intended path.
- When a spec references another spec for types, extensions, or dependencies, follow that link to the authoritative source.
- Do not stop at the first mention; keep following links until the authoritative section answers the question.

## Worked Example

**User question**: "In SMB2, how does the server signal that it supports persistent handles?"

Path: File Access Overview → `MS-SMB2` → `2.2.4 NEGOTIATE Response` → `3.3.5.4 Receiving an SMB2 NEGOTIATE Request`.

Answer: cite `MS-SMB2`, note that the server signals support by setting `SMB2_GLOBAL_CAP_PERSISTENT_HANDLES (0x00000010)` in the NEGOTIATE Response `Capabilities` field, and put version-specific caveats under uncertainty or product behavior notes.

## Answer Contract

Default answer shape:

1. `Protocols consulted`: list exact IDs.
2. `Sections used`: list exact section titles (and numbers when available).
3. `Findings`: concise facts tied to those sections.
4. `Inference / uncertainty`: explicit separation from confirmed text.

Guidance:

- Prefer section-grounded answers and include exact protocol IDs.
- For non-obvious, contested, or security-sensitive claims, include section-grounded evidence.
- For straightforward facts, concise section references are enough.
- If two specs disagree, report both and identify likely version or context scope.
- State uncertainty explicitly, and never present inferred behavior as normative requirement text.
