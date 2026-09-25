# Repository rules

- Treat [`docs/architecture.md`](docs/architecture.md) and accepted ADRs as normative.
- Follow the architecture's language and privilege boundaries; use the [Archiso update procedure](docs/procedures/update-archiso.md) for vendor updates.
- Leave ignored local documentation tooling, including `docs/.obsidian/`, untouched.
- Keep MirrorOS-owned content off `vendor/archiso-releng`.
- Never commit secrets, personal configuration, or generated outputs (`build/`, `dist/`, or `evidence/`).
- Do not resolve prototype-gated decisions prematurely; route them through an ADR.
- Update attribution, tests, and documentation together with the change they govern.
- Never add MirrorOS license headers to unmodified vendor files.
