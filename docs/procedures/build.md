# Build lifecycle procedure

**Availability:** help only; domain behavior pending.

## Current behavior

Invoke the command by path from any working directory; it does not need to be installed on `PATH`.

| Invocation | Outcome |
| --- | --- |
| Sole `--help` argument | Returns `0`; writes help to stdout and nothing to stderr. |
| No arguments | Returns `2`; writes a pending-operation diagnostic to stderr that names `build` and links to this procedure. |
| Unsupported arguments, including `--help` with extra arguments | Returns `2`; writes a distinct unsupported-argument diagnostic to stderr. |
| Missing or unloadable `operations/lib/lifecycle-discovery.sh` helper | Returns `6`; reports an incomplete or damaged checkout and advises restoring the helper from Git or recloning. |

These invocations make no changes, use no privilege, and invoke no domain tool. Help does not require ShellCheck, Bats, or Gitleaks. No success message is emitted for pending build work.

## Intended contract

### Purpose

Build a traceable MirrorOS installation artifact from the version-controlled Archiso profile. The lifecycle boundary assigns image construction to `build`; no build is currently implemented.

### Prerequisites

An Arch Linux build environment and Archiso tooling are anticipated by the architecture. Exact supported host conditions, tool versions, privilege requirements, network access, and package prerequisites are **Pending**.

### Inputs

The version-controlled `image/archiso/` profile is the known source input. Additional options, configuration inputs, and supported invocation forms are **Pending**.

### Consequential effects

A future build is expected to create generated work under `build/` and an installation artifact under `dist/`. Exact paths, cleanup behavior, and execution effects are **Pending**. No such effects occur with the current help-only entry point.

### Evidence

Architecture requires run-associated evidence with source and tool metadata, outcome, diagnostics, and generated artifacts or reports. The exact build evidence location within `evidence/`, contents, and retention policy are **Pending**.

### Failure and recovery

A supported build must preserve actionable, non-secret diagnostics and must not report an artifact as accepted after failure. Build-specific recovery and retry behavior are **Pending**. For the current help-only interface, restore a damaged checkout from Git or reclone it if the shared helper cannot be loaded.

## Normalized outcomes

The architecture defines `0` as success, `2` as invalid input or unmet precondition, `3` as explicit cancellation, `4` as execution completed but verification is not ready, `5` as execution or upstream-operation failure, and `6` as internal contract or invariant failure. Currently `0` applies only to successful help, `2` to pending work or invalid arguments, and `6` to a missing or unloadable helper. Build-specific use of the remaining outcomes is **Pending**.
