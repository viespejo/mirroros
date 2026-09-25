# Attribution

## Policy

This index covers all externally incorporated material in the repository. Each entry records the project, its SPDX license identifier, the material incorporated into MirrorOS, and a link to a detailed provenance record. Version-specific values belong in that provenance record and are not duplicated in this index.

Original MirrorOS material is licensed under `GPL-3.0-only` unless a document states otherwise. Incorporated material keeps its own license terms and required notices; incorporation does not convert it to the MirrorOS license.

At this baseline there is no external incorporation entry. The applicable entry is added with the first vendor merge, together with its detailed provenance record.

## Entry format

Add one entry per externally incorporated project:

```markdown
### <Project name>

- **License (SPDX):** `<SPDX identifier>`
- **Incorporated material:** <paths or other material included in MirrorOS>
- **Detailed provenance:** [<provenance record>](<relative path>)
```

Keep this index stable and concise. Record changing tags, commits, package versions, digests, dates, acquisition methods, and integrity evidence only in the linked provenance record.
