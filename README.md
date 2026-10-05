# MirrorOS

MirrorOS is a governed, version-controlled project for reconstructing an Arch Linux environment through independently discoverable lifecycle stages.

## Current state

The repository provides governance and lifecycle discovery, and the `build` and `test` commands implement traceable ISO construction and reference VM bootstrap qualification. The Archiso `releng` profile has been imported; boot qualification has **not yet been performed** formally. The other four lifecycle entry points provide help and safe refusal only; their domain behavior is pending. Repository validation is not ISO or VM qualification.

## Lifecycle commands

| Command | Availability | Procedure |
| --- | --- | --- |
| `build` | implemented | [Build procedure](docs/procedures/build.md) |
| `test` | implemented | [Test procedure](docs/procedures/test.md) |
| `install` | help only; domain behavior pending | [Install procedure](docs/procedures/install.md) |
| `configure` | help only; domain behavior pending | [Configure procedure](docs/procedures/configure.md) |
| `verify` | help only; domain behavior pending | [Verify procedure](docs/procedures/verify.md) |
| `clean` | help only; domain behavior pending | [Clean procedure](docs/procedures/clean.md) |

See [repository validation](docs/procedures/repository-validation.md) for static checks, contract tests, secret-scanning coverage, and the clean-clone acceptance gate. These checks do not qualify an ISO or VM.

## Repository governance and references

- [License](LICENSE)
- [Repository rules](AGENTS.md)
- [Claude guidance](CLAUDE.md)
- [Ignored paths](.gitignore)
- [ShellCheck configuration](.shellcheckrc)
- [Attribution process and records](docs/attribution.md)
- [ADR index and guidance](docs/adr/README.md)
- [ADR template](docs/adr/0000-template.md)
- [Archiso update procedure](docs/procedures/update-archiso.md)
- [Architecture](docs/architecture.md)

## Workflow tooling

The root `.agents/` directory holds local workflow-tooling content such as plans and execution records. It is outside the product runtime and authoritative source control, is excluded by the root-anchored rule in [.gitignore](.gitignore), and is never incorporated into runtime artifacts. Its local contents are not product source.
