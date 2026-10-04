# Install lifecycle procedure

**Availability:** help only; domain behavior pending.

## Current behavior

Invoke the command by path from any working directory; it does not need to be installed on `PATH`.

| Invocation | Outcome |
| --- | --- |
| Sole `--help` argument | Returns `0`; writes help to stdout and nothing to stderr. |
| No arguments | Returns `2`; writes a pending-operation diagnostic to stderr that names `install` and links to this procedure. |
| Unsupported arguments, including `--help` with extra arguments | Returns `2`; writes a distinct unsupported-argument diagnostic to stderr. |
| Missing or unloadable `operations/lib/lifecycle-discovery.sh` helper | Returns `6`; reports an incomplete or damaged checkout and advises restoring the helper from Git or recloning. |

These invocations make no changes, use no privilege, and invoke no domain tool. Help does not require ShellCheck, Bats, or Gitleaks. No success message is emitted for pending installation work.

## Intended contract

### Purpose

Coordinate target discovery, reviewable installation planning, confirmation, and application of the selected engine to install the base operating system. The production installation engine remains gated on its prototype and ADR.

### Prerequisites

A completed reference-VM reconstruction must precede physical installation. An external backup, independent rescue medium, and known-good ISO are architectural prerequisites before physical migration. Exact host and target requirements, privilege boundaries, installation-engine selection, and confirmation implementation are **Pending**.

### Inputs

A selected target, discovered target state, and a reviewable plan are architectural inputs. Exact input format, plan interface, secret requirements, and supported target selection are **Pending**.

### Consequential effects

Installation is expected to modify the selected target and may include destructive storage operations. The architecture requires explicit target-bound confirmation for destructive actions; the production implementation and exact effects are **Pending**. The current help-only interface changes nothing.

### Evidence

Architecture requires run-associated evidence identifying source, target-relevant non-secret context, stage outcome, diagnostics, and generated reports. The exact install evidence location within `evidence/`, contents, and retention policy are **Pending**.

### Failure and recovery

The target-specific recovery process, retry boundaries, and installation failure handling are **Pending**. Do not begin a supported physical installation until the required VM qualification, backup, rescue, and known-good-artifact gates are met. For the current help-only interface, restore a damaged checkout from Git or reclone it if the shared helper cannot be loaded.

## Normalized outcomes

The architecture defines `0` as success, `2` as invalid input or unmet precondition, `3` as explicit cancellation, `4` as execution completed but verification is not ready, `5` as execution or upstream-operation failure, and `6` as internal contract or invariant failure. Currently `0` applies only to successful help, `2` to pending work or invalid arguments, and `6` to a missing or unloadable helper. Install-specific use of the remaining outcomes is **Pending**.
