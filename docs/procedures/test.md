# Test lifecycle procedure

**Availability:** help only; domain behavior pending.

## Current behavior

Invoke the command by path from any working directory; it does not need to be installed on `PATH`.

| Invocation | Outcome |
| --- | --- |
| Sole `--help` argument | Returns `0`; writes help to stdout and nothing to stderr. |
| No arguments | Returns `2`; writes a pending-operation diagnostic to stderr that names `test` and links to this procedure. |
| Unsupported arguments, including `--help` with extra arguments | Returns `2`; writes a distinct unsupported-argument diagnostic to stderr. |
| Missing or unloadable `operations/lib/lifecycle-discovery.sh` helper | Returns `6`; reports an incomplete or damaged checkout and advises restoring the helper from Git or recloning. |

These invocations make no changes, use no privilege, and invoke no domain tool. Help does not require ShellCheck, Bats, or Gitleaks. No success message is emitted for pending VM testing.

## Intended contract

### Purpose

Validate a MirrorOS artifact in the disposable reference VM. The architecture assigns VM validation to `test`; running repository checks does not boot, test, or qualify an ISO or VM.

### Prerequisites

A built artifact and a reference virtualization environment based on QEMU/KVM and UEFI/OVMF are architectural expectations. Exact host packages, VM resources, configuration, and qualification gates are **Pending**.

### Inputs

The artifact to test and the reference VM definition are expected inputs. Their exact paths, selection interface, and any additional inputs are **Pending**.

### Consequential effects

A future test may execute an artifact in a disposable VM and create temporary VM state and test evidence. Exact isolation guarantees, generated paths, and host effects are **Pending**. Repository-validation commands are separate and are not VM qualification.

### Evidence

Architecture requires run-associated evidence sufficient to identify the tested source and artifact, tool metadata, outcomes, diagnostics, and reports. The exact test evidence location within `evidence/`, format, and retention policy are **Pending**.

### Failure and recovery

Test-specific failure classification, VM disposal, recovery, and retry behavior are **Pending**. A failure must not be described as a passing qualification. For the current help-only interface, restore a damaged checkout from Git or reclone it if the shared helper cannot be loaded.

## Normalized outcomes

The architecture defines `0` as success, `2` as invalid input or unmet precondition, `3` as explicit cancellation, `4` as execution completed but verification is not ready, `5` as execution or upstream-operation failure, and `6` as internal contract or invariant failure. Currently `0` applies only to successful help, `2` to pending work or invalid arguments, and `6` to a missing or unloadable helper. Test-specific use of the remaining outcomes is **Pending**.
