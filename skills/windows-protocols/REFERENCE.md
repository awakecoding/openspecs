# Windows Protocols Reference

Use this file only when the main workflow in `SKILL.md` is not enough.

## Domain Clusters

| Domain | Key Protocols / Families |
|---|---|
| Authentication | Kerberos, NTLM, SPNEGO |
| File Access | SMB/CIFS, DFS, WebDAV, FSCC, FSA |
| Remote Desktop | Base + graphics, gateway, virtual channels |
| Storage | Disk and volume management, shadow copies, EFS, backup |
| Group Policy | Core plus extensions; depends on AD and file access |
| Network Access Protection | SoH and SoHR over PEAP; DHCP, VPN, TSGU, and IPsec enforcement |
| Content Caching | Peer discovery, retrieval, and hosted cache over SMB and HTTP |
| File Services Management | FSRM, remote VSS, classification |
| Rights Management | Publish and consume protected content |
| Virtual Storage | Remote shared virtual disks over SMB |

## Canonical Spec Structure

| Section | Typical contents |
|---|---|
| `1 Introduction` | Glossary (`1.1`), References (`1.2`), Overview (`1.3`), Relationship to Other Protocols (`1.4`), Prerequisites (`1.5`), Versioning (`1.7`) |
| `2 Messages` | Message syntax, common data types, wire-format structures |
| `3 Protocol Details` | Abstract Data Model, timers, initialization, triggers, message processing, sequencing, and local events |
| `4 Protocol Examples` | Annotated message traces |
| `5 Security` | Security considerations and product behavior notes |

Outlier variants: Section 2 may appear as `Structures`, `Attributes`, `Data Types`, or `Message Transport`; Section 3 may appear as `Structure Examples`, `Details`, or an algorithm-specific title; Section 4 or 5 may shift when section 4 is `Security Considerations`; appendices may contain IDL, WSDL, XML, or JSON schema and product behavior notes.

## Section-First Routing

- "What is this protocol or where does it fit?" → `1.3`, `1.4`, `1.7`
- "How is data encoded or what are the fields?" → `2.2` and related message syntax or common data type sections
- "What is the runtime behavior or state machine?" → `3.x` details and `3.x.y` sequencing sections
- "What security guarantees or knobs exist?" → `5.*` security sections
- "What differs by product or version?" → product behavior appendices and change tracking sections

When structure spans multiple specs, resolve in this order: base or core protocol semantics, extension-specific modifications, then shared type dependencies such as `MS-DTYP`.