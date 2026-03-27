# Windows Protocols Reference

Supplementary reference material for the windows-protocols skill. See SKILL.md for the primary navigation guide.

## Protocol Clusters by Domain

When using Overview documents for discovery, expect these cluster themes:

- **Authentication**: Kerberos, NTLM, SPNEGO — core for file access, RDP, Group Policy.
- **File Access**: SMB/CIFS family, DFS, WebDAV, shared types (FSCC, FSA).
- **Remote Desktop**: Base + graphics pipeline, gateway, virtual channels (clipboard, devices, transport).
- **Storage**: Disk/volume management, shadow copies, EFS, backup, removable media.
- **Group Policy**: Core protocol + extensions; depends on AD and file access.
- **Network Access Protection**: SoH/SoHR over PEAP; DHCP/VPN/TSGU/IPsec enforcement.
- **Content Caching**: Peer discovery, retrieval, hosted cache; integrates with SMB/HTTP.
- **File Services Management**: FSRM, remote VSS, classification.
- **Rights Management**: Publish/consume protected content.
- **Virtual Storage**: Remote shared virtual disks over SMB.

## Canonical Spec Structure — Detailed Subsections

### Top-Level Sequence

- `1 Introduction`
- `2 Messages`
- `3 Protocol Details`
- `4 Protocol Examples`
- `5 Security`

### Common 1.x Orientation Subsections

- `1.1 Glossary`, `1.2 References`, `1.3 Overview`
- `1.4 Relationship to Other Protocols`
- `1.5 Prerequisites/Preconditions`
- `1.7 Versioning and Capability Negotiation`

### Common 3.x.y Behavioral Subsections

- `Abstract Data Model`
- `Timers`
- `Initialization`
- `Higher-Layer Triggered Events`
- `Message Processing Events and Sequencing Rules`
- `Timer Events`
- `Other Local Events`

## Outlier Heading Variants

Not all specs use exact canonical headings. Common variants:

- `2 Structures`, `2 Attributes`, `2 Data Types`, `2 Message Transport` instead of `2 Messages`.
- `3 Structure Examples`, `3 Details`, or algorithm-specific section names.
- `4 Security` or `4 Security Considerations` when numbering shifts.
- Appendix variants: `Full IDL`, `Full WSDL`, `Full XML Schema`, `Full JSON Schema`.
- Change tracking may appear as section `7`, `8`, `9`, or higher.

Rule: match by semantic intent first, section number second.
