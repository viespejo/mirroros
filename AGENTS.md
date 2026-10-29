# Repository rules

- Treat [`docs/architecture.md`](docs/architecture.md) and accepted ADRs as normative.
- Follow the architecture's language and privilege boundaries; use the [Archiso update procedure](docs/procedures/update-archiso.md) for vendor updates.
- Leave ignored local documentation tooling, including `docs/.obsidian/`, untouched.
- Keep MirrorOS-owned content off `vendor/archiso-releng`.
- Never commit secrets, personal configuration, or generated outputs (`build/`, `dist/`, or `evidence/`).
- Do not resolve prototype-gated decisions prematurely; route them through an ADR.
- Require an ADR only under [When an ADR is required](docs/adr/README.md#when-an-adr-is-required). Applying an
  accepted decision to a new consumer within its boundaries is routine: record provenance in the governing
  `sources.md` or `UPSTREAM.md`, not in a new ADR.
- Update attribution, tests, and documentation together with the change they govern.
- Never add MirrorOS license headers to unmodified vendor files.
- Treat `.agents/` as local workflow tooling outside the product runtime and authoritative source control; see [README.md — Workflow tooling](README.md#workflow-tooling).
