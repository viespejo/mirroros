# Configure lifecycle procedure

**Availability:** help only; domain behavior pending.

## Current behavior

Invoke the command by path from any working directory; it does not need to be installed on `PATH`.

| Invocation | Outcome |
| --- | --- |
| Sole `--help` argument | Returns `0`; writes help to stdout and nothing to stderr. |
| No arguments | Returns `2`; writes a pending-operation diagnostic to stderr that names `configure` and links to this procedure. |
| Unsupported arguments, including `--help` with extra arguments | Returns `2`; writes a distinct unsupported-argument diagnostic to stderr. |
| Missing or unloadable `operations/lib/lifecycle-discovery.sh` helper | Returns `6`; reports an incomplete or damaged checkout and advises restoring the helper from Git or recloning. |

These invocations make no changes, use no privilege, and invoke no domain tool. Help does not require ShellCheck, Bats, or Gitleaks. No success message is emitted for pending configuration work.

## Intended contract

### Purpose

Apply the declared environment configuration through capability modules, independently of image construction and base-system installation, and converge the target toward that declaration. Selection of the production convergence mechanism remains gated on its prototype and ADR.

### Prerequisites

A prepared target system and applicable declarations are expected. The exact supported target state, prerequisites, package and network requirements, and privilege boundaries are **Pending**.

### Inputs

Version-controlled capability declarations, applicable hardware choices and target overrides, and runtime-only secret or private inputs where required are architectural input categories. Their exact formats, selection interface, and requirements are **Pending**.

### Consequential effects

Configuration is expected to change declared system or user state. The exact changes, privilege separation, idempotency guarantees, and generated paths are **Pending**. The current help-only interface makes no changes.

### Evidence

Architecture requires run-associated evidence with source and tool metadata, non-secret inputs, stage outcome, allowed diagnostics, and generated reports. The exact configure evidence location within `evidence/`, contents, and retention policy are **Pending**.

### Failure and recovery

The selected convergence mechanism, module-level recovery, and safe retry behavior are **Pending**. A future implementation must preserve failures and must not report success after incomplete application. For the current help-only interface, restore a damaged checkout from Git or reclone it if the shared helper cannot be loaded.

## Normalized outcomes

The architecture defines `0` as success, `2` as invalid input or unmet precondition, `3` as explicit cancellation, `4` as execution completed but verification is not ready, `5` as execution or upstream-operation failure, and `6` as internal contract or invariant failure. Currently `0` applies only to successful help, `2` to pending work or invalid arguments, and `6` to a missing or unloadable helper. Configure-specific use of the remaining outcomes is **Pending**.
