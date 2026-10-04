# Clean lifecycle procedure

**Availability:** help only; domain behavior pending.

## Current behavior

Invoke the command by path from any working directory; it does not need to be installed on `PATH`.

| Invocation | Outcome |
| --- | --- |
| Sole `--help` argument | Returns `0`; writes help to stdout and nothing to stderr. |
| No arguments | Returns `2`; writes a pending-operation diagnostic to stderr that names `clean` and links to this procedure. |
| Unsupported arguments, including `--help` with extra arguments | Returns `2`; writes a distinct unsupported-argument diagnostic to stderr. |
| Missing or unloadable `operations/lib/lifecycle-discovery.sh` helper | Returns `6`; reports an incomplete or damaged checkout and advises restoring the helper from Git or recloning. |

These invocations make no changes, use no privilege, and invoke no domain tool. Help does not require ShellCheck, Bats, or Gitleaks. No success message is emitted for pending cleanup work.

## Intended contract

### Purpose

The architecture assigns `clean` to removal of generated local outputs while preserving accepted external recovery artifacts. No cleanup policy exists yet.

### Prerequisites

A cleanup policy must first identify managed resources, retention requirements, and recovery boundaries. These prerequisites and any privilege requirements are **Pending**.

### Inputs

The exact resource selection, confirmation requirements, and supported invocation interface are **Pending**.

### Consequential effects

A future clean operation may delete explicitly managed generated local outputs. The scope, safeguards, evidence-retention behavior, and deletion semantics are **Pending**. The existence of `build/`, `dist/`, `evidence/`, or any other generated directory does not by itself authorize deletion. The current help-only interface deletes nothing.

### Evidence

Whether cleanup produces or retains evidence, and its location and retention policy, are **Pending**. Cleanup must not silently remove accepted external recovery artifacts.

### Failure and recovery

The cleanup policy, recovery process, and retry behavior are **Pending**. Do not infer authorization to delete from a directory name or ignore rule. For the current help-only interface, restore a damaged checkout from Git or reclone it if the shared helper cannot be loaded.

## Normalized outcomes

The architecture defines `0` as success, `2` as invalid input or unmet precondition, `3` as explicit cancellation, `4` as execution completed but verification is not ready, `5` as execution or upstream-operation failure, and `6` as internal contract or invariant failure. Currently `0` applies only to successful help, `2` to pending work or invalid arguments, and `6` to a missing or unloadable helper. Clean-specific use of the remaining outcomes is **Pending**.
