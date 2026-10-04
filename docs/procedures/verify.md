# Verify lifecycle procedure

**Availability:** help only; domain behavior pending.

## Current behavior

Invoke the command by path from any working directory; it does not need to be installed on `PATH`.

| Invocation | Outcome |
| --- | --- |
| Sole `--help` argument | Returns `0`; writes help to stdout and nothing to stderr. |
| No arguments | Returns `2`; writes a pending-operation diagnostic to stderr that names `verify` and links to this procedure. |
| Unsupported arguments, including `--help` with extra arguments | Returns `2`; writes a distinct unsupported-argument diagnostic to stderr. |
| Missing or unloadable `operations/lib/lifecycle-discovery.sh` helper | Returns `6`; reports an incomplete or damaged checkout and advises restoring the helper from Git or recloning. |

These invocations make no changes, use no privilege, and invoke no domain tool. Help does not require ShellCheck, Bats, or Gitleaks. No success message is emitted for pending verification work.

## Intended contract

### Purpose

Run readiness checks independently and report the state of each declared MVP capability. Verification owns checks and reporting, not configuration changes.

### Prerequisites

The target environment and capability declarations must be available. The exact supported system state, frozen capability inventory, check prerequisites, and external dependencies are **Pending**.

### Inputs

The declared capability inventory and verification checks are architectural inputs. Exact selectors, formats, and any target context required by checks are **Pending**.

### Consequential effects

Verification is intended to inspect readiness without applying configuration. It may create a human-readable or structured result artifact; exact outputs and paths are **Pending**. The current help-only interface makes no changes.

### Evidence

Architecture requires evidence for each check and an aggregate result associated with the run. The exact verify evidence location within `evidence/`, report format, schema, and retention policy are **Pending**.

### Failure and recovery

The architecture assigns status `4` when execution completes but verification is not ready; a failed or externally blocked capability must not be reported as ready. Check-specific remediation and rerun behavior are **Pending**. For the current help-only interface, restore a damaged checkout from Git or reclone it if the shared helper cannot be loaded.

## Normalized outcomes

The architecture defines `0` as success, `2` as invalid input or unmet precondition, `3` as explicit cancellation, `4` as completed execution with verification not ready, `5` as execution or upstream-operation failure, and `6` as internal contract or invariant failure. Currently `0` applies only to successful help, `2` to pending work or invalid arguments, and `6` to a missing or unloadable helper. Verify-specific use of other outcomes is **Pending**.
