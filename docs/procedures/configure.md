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

Prepare the complete MVP environment, including system, desktop, and user tools, on a newly installed system through bounded Bash scripts and native Arch and application formats ([ADR 0010](../adr/0010-environment-configuration-mechanism-and-scope.md)). The stage is independently invocable, and the guided installation runs it before the first normal reboot so that no required setup is deferred to post-login background work. `configure` checks its own postconditions; independent readiness verification remains the role of `verify`. Remaining details are owned by Story 4.2.

### Prerequisites

A newly installed target system is expected. The exact supported target state, prerequisites, package and network requirements, and privilege boundaries are **Pending**.

### Inputs

Native Arch and application configuration, applicable hardware choices and target overrides, and runtime-only secret or private inputs where required are architectural input categories. Their exact selection interface and requirements are **Pending**.

### Consequential effects

Configuration is expected to change system and user state to complete the MVP environment. The exact changes, privilege separation, rerun guarantees, and generated paths are **Pending**. The current help-only interface makes no changes.

### Evidence

Architecture requires run-associated evidence with source and tool metadata, non-secret inputs, stage outcome, allowed diagnostics, and generated reports. The exact configure evidence location within `evidence/`, contents, and retention policy are **Pending**.

### Failure and recovery

The exact recovery steps and failure reporting are **Pending**. A future implementation must be safe to rerun in full after an interruption, must identify the failed step, must preserve failures, and must not report a ready environment after a configuration failure. For the current help-only interface, restore a damaged checkout from Git or reclone it if the shared helper cannot be loaded.

## Normalized outcomes

The architecture defines `0` as success, `2` as invalid input or unmet precondition, `3` as explicit cancellation, `4` as execution completed but verification is not ready, `5` as execution or upstream-operation failure, and `6` as internal contract or invariant failure. Currently `0` applies only to successful help, `2` to pending work or invalid arguments, and `6` to a missing or unloadable helper. Configure-specific use of the remaining outcomes is **Pending**.
