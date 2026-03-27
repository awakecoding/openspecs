---
name: windows-protocols
description: "Look up Microsoft Open Specifications for Windows protocols — find packet structures, field definitions, protocol handshakes, and security semantics for SMB, NTLM, Kerberos, RDP, DFS, and more. Use this skill when the user asks about Windows protocol wire formats, needs to trace message flows, wants to extract structure definitions, compare protocol extensions, or cross-reference related specs like MS-SMB2, MS-NLMP, MS-RDPBCGR."
---

# Windows Protocols Corpus Navigator

## Overview

- The markdown corpus is already extracted locally, next to `SKILL.md`.
- Use local files only. Do not use network lookup for this skill.
- Do not run download or setup commands as part of normal usage.

This skill is optimized for structure-first navigation of Microsoft Open Specifications markdown and evidence-grounded answers.

## Corpus Layout

- `README.md` — index with three sections: Overview Documents (domain maps), Technical Documents (full spec list), and Reference Documents. Overview Documents are at the top; use them for topical discovery.
- `LEGAL.md` — legal and redistribution notice.
- `<PROTOCOL-ID>/` — protocol directories (Overview, Technical, or Reference), directly under this folder.
- `<PROTOCOL-ID>/<PROTOCOL-ID>.md` — primary markdown spec content.
- `<PROTOCOL-ID>/media/` — extracted figures and image assets referenced by the markdown.

## Corpus Document Types

- **Overview Documents** — Domain maps that group related protocols under a topic (file access, authentication, storage, remote desktop, etc.). Each describes system capabilities, lists member protocols with their roles, and contains many links to specifications. Use as the primary entry point for topical discovery.
- **Technical Documents** — Individual protocol specifications with full wire-format, message syntax, and behavior details.
- **Reference Documents** — Supplemental references (error codes, shared types, etc.).

## Protocol Clusters by Domain

For a full domain-to-protocol mapping, see [REFERENCE.md](REFERENCE.md). Key clusters: Authentication (Kerberos, NTLM, SPNEGO), File Access (SMB/CIFS, DFS), Remote Desktop (MS-RDP*), Storage, Group Policy. Use Overview documents for authoritative cluster membership.

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

1. **Domain/topic questions** — find the matching Overview document in README first; use it as a map to the relevant specs. Do not rely on README keyword search alone — Overview documents provide the curated topic-to-protocol mapping.
2. **Known protocol IDs** — validate the ID exists in `README.md` and as a `<PROTOCOL-ID>/` directory, then open the spec directly.
3. Start from the spec TOC (`<summary>` blocks and numbered entries) before deep reading.
4. Read sections by intent: orientation/versioning → message/structure syntax → behavior/sequencing → security and product behavior notes.
5. Cross-check base vs extension specs when requirements may be split.
6. Answer with explicit protocol IDs and exact section headings; separate confirmed facts from inference.

## Link-Following

- Overview documents contain References sections (often 1.3) and extensive inline links to member specifications. Follow these links rather than guessing paths.
- The link graph (Overview → spec → related spec) is the intended navigation structure.
- When a spec references another spec for types, extensions, or dependencies, follow that link to reach the authoritative source.
- Continue following links until the relevant information is found; do not stop at the first document that mentions the topic.

## Canonical Spec Structure

Specs follow a consistent layout: `1 Introduction` → `2 Messages` → `3 Protocol Details` → `4 Protocol Examples` → `5 Security`. Use these as the default reading spine. For detailed subsection maps (1.x orientation, 3.x.y behavioral), see [REFERENCE.md](REFERENCE.md).

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

Not all specs use exact canonical headings (e.g. `2 Structures` instead of `2 Messages`, shifted security numbering). Match by **semantic intent first, section number second**. See [REFERENCE.md](REFERENCE.md) for the full list of known heading variants.

## Quick Discovery Patterns

- **Unknown protocol ID** — identify the domain from question keywords, open the matching Overview document, use its Protocol Summary or References section to find the right specs. Do not select from README's flat Technical Documents list without consulting an Overview when the domain is ambiguous.
- **Ambiguous acronyms** — list 2–4 likely protocols (via Overview docs) and ask the user to choose before deep analysis.
- **Extension behavior** — verify whether requirements live in the base protocol or an extension; Overview docs and spec cross-references clarify dependencies.

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

