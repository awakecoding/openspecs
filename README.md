# OpenSpecs — Windows Protocols Skill

Agent skill for navigating the Microsoft Open Specifications corpus locally. Use when asking protocol-level questions, message/structure details, section-by-section summaries, or cross-references across related specs.

## Installation

**[skills.sh](https://skills.sh)** — Add the skill globally:

```bash
npx skills add awakecoding/openspecs --skill windows-protocols -y -g
```

Or install from the GitHub repo directly:

```bash
npx skills add https://github.com/awakecoding/openspecs --skill windows-protocols -y -g
```

## Usage

Once installed, the agent has read access to the Windows Protocols corpus. Ask questions such as:

- "What is the structure of the MS-RDPBCGR handshake?"
- "Summarize the MS-DTYP security considerations."
- "Compare MS-SMB and MS-SMB2 connection establishment."
- "Where does MS-PCHC define the Hosted Cache protocol?"

The skill uses the extracted markdown corpus (Overview, Technical, and Reference documents) with no additional setup.

## Non-skill usage

The `skills/windows-protocols/` directory contains the entire [Microsoft Open Specifications Windows Protocols](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-winprotlp/92b33e19-6fff-496b-86c3-d168206f9845) corpus converted to Markdown, optimized for AI agent consumption. It is more token-efficient than using the PDFs or the live HTML on Microsoft's site, and the compact Markdown format is convenient for `grep`-based search.

## This repository

The rest of this repo is a PowerShell module and helper scripts that fetch the source DOCX material for all Microsoft Open Specifications specs, convert them to Markdown with various transformations, and produce the current corpus. The result is far smaller than the 600+ MB Windows Protocols PDF `.zip` offered by Microsoft: the zipped markdown corpus is under 50 MB.
