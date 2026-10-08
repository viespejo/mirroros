# Install lifecycle procedure

**Availability:** `discover` and `plan` are implemented; confirmation and installation remain pending.

## Current behavior

Invoke the command by path from any working directory; it does not need to be installed on `PATH`. On the live medium it is available as `mirroros-install`, a symlink to the embedded `operations/install`.

| Invocation | Outcome |
| --- | --- |
| Sole `--help` argument | Returns `0`; writes help to stdout and nothing to stderr. |
| No arguments | Returns `2`; writes a pending-operation diagnostic to stderr that names `install` and links to this procedure. |
| Unsupported arguments, including `--help` with extra arguments | Returns `2`; writes a distinct unsupported-argument diagnostic to stderr. |
| Missing or unloadable `operations/lib/lifecycle-discovery.sh` helper | Returns `6`; reports an incomplete or damaged checkout and advises restoring the helper from Git or recloning. |
| `discover …` | Delegates to `install/discovery/discover`; see [Target discovery](#target-discovery). A missing orchestrator returns `6`. |
| `plan …` | Delegates to `install/plan/plan`; see [Installation plan](#installation-plan). A missing orchestrator returns `6`. |

Except for `discover` and `plan`, these invocations make no changes, use no privilege, and invoke no domain tool. Help does not require ShellCheck, Bats, or Gitleaks. No success message is emitted for pending installation work.

## Target discovery

```text
operations/install discover --target <id> [--output <dir>]
operations/install discover --help
```

Discovery inspects a supported target from the live environment without modifying it, records firmware, network, storage, and hardware facts, and normalizes them into `target-facts.json`. The format is documented in [`contracts/target-facts.md`](../../contracts/target-facts.md). Discovery is non-interactive: it prompts for nothing, uses no Gum, and never selects a disk.

### Inputs

- `--target <id>` names the supported target: `reference-vm` or `framework-13-pro-amd`. A missing, unknown, or malformed id exits `2` with a `target_missing` or `target_unknown` reason.
- `--output <dir>` names an absent or empty directory; otherwise the command returns `2` without writing. The default is `evidence/install/<run-id>/`, relative to the working directory.
- Prerequisites on the target: a 64-bit UEFI boot of the live medium with Secure Boot disabled, a ready network (default route, DNS for the probe host, and a bounded HTTPS probe, all configured beforehand because discovery never configures the network), and at least one eligible disk.

### Read-only guarantees

Discovery never invokes `sudo` or any other elevation mechanism and never writes to a device. It reads `/sys`, `/proc`, `lsblk`, `ip`, `getent`, `systemd-detect-virt`, and `uname`, and the HTTPS probe creates outbound traffic only. The live session is already privileged, so "no elevation" means that discovery never requests it. MAC addresses, SSIDs, Wi-Fi credentials, `iwd` state, DMI product, board, and chassis serials, the product UUID, and battery serials are never recorded. Disk identity (by-id link, WWN, serial, model, size) is recorded because later confirmation binds to it.

### Evidence

Each run writes a directory with `0700` permissions and `0600` files, using atomic writes:

| Path | Content |
| --- | --- |
| `target-facts.json` | The normalized document. Written for exits `0` and `2`; with exit `2` its `validation.status` is `invalid`. |
| `raw/<collector>.json`, `raw/<collector>.stderr` | Uninterpreted collector output and its stderr, for `firmware`, `hardware`, `storage`, and `network`. |
| `error.json` | The structured error (`code`, `stage`, `operation`, `message`, `next_step`, `child_exit_status`). Written only for exits `5` and `6`, which write no `target-facts.json`. |

The directory is local, ignored, and never committed. Stdout carries a plain-text summary of the key facts with their provenance; diagnostics go to stderr.

### Exit outcomes

| Status | Meaning |
| --- | --- |
| `0` | Valid facts, possibly with warnings (for example an unknown Secure Boot state). |
| `2` | Invalid arguments, an unknown or contradictory target, a missing required fact, unsupported firmware, a network that is not ready, no eligible disk, or an invalid target override. |
| `5` | An external command failed unexpectedly. `error.json` carries `child_exit_status` and the child's stderr stays in `raw/`. |
| `6` | Damaged embedded code, a missing identity file, or an internal invariant failure such as the produced document failing its own validator. |

### Identity of the embedded code

`target-facts.json` records the commit and dirty state of the code that produced it. On the live medium they come from the `IDENTITY` file at the root of the embedded code (`/usr/local/lib/mirroros/IDENTITY`, lines `commit=<40 hex>` and `dirty=<true|false>`); in a Git checkout they come from Git. Without either, discovery returns `6`.

### Pending Framework identity

The DMI identity of the Framework Laptop 13 Pro is not recorded yet, so `--target framework-13-pro-amd` returns `2` with a `target_identity_pending_capture` reason until `targets/framework-13-pro-amd/target.json` is completed from a real capture.

### Recovery

Discovery changes nothing, so recovery is to fix the reported cause and rerun it into a new output directory. For example, boot the medium in UEFI mode and disable CSM or legacy boot, disable Secure Boot, connect a cable or configure Wi-Fi with `iwctl`, or restore a damaged embedded tree by rebuilding the medium.

## Installation plan

```text
operations/install plan --facts <file> [--choices <file>] [--output <dir>]
operations/install plan --help
```

`plan` turns a valid `target-facts.json` and the installation policy into a validated installation plan bound to its inputs by a SHA-256 digest. The plan identifies the target disk, the ordered declarative operations with their `destructive` flags, every default with its provenance and source, the secret requirements by name, and the hardware selections. The format, the operation vocabulary, the validation codes, and the digest rules are documented in [`contracts/installation-plan.md`](../../contracts/installation-plan.md). Planning is non-interactive: it prompts for nothing, uses no Gum, executes no operation, and never approves the plan.

### Inputs

- `--facts <file>` names a `target-facts.json` produced by `discover`. Unreadable, malformed, unknown-format, or invalid facts exit `2`. The `target_id` is taken from the facts, and the facts file is never modified.
- `--choices <file>` optionally names a flat JSON object with `format_version: 1` that sets editable keys (`target_disk`, `storage_option`, `swapfile_size`, `locales`, `lang`, `console_keymap`, `timezone`, `hostname`, `user_name`, `root_account`). Unknown, non-editable, invalid, and secret-like keys (for example `password` or `user_password`) exit `2` without writing a plan; secrets are never accepted through this file.
- `--output <dir>` names the run directory. A directory that already contains a plan exits `2` without writing. The default is `evidence/install/<run-id>/`, relative to the working directory.
- With exactly one eligible disk, that disk is preselected. With several, `--choices` must name one through `target_disk`; otherwise the command exits `2` and lists the eligible candidates.

### Overrides and precedence

Values resolve as policy, then detected, then target override, then choice, and each plan value records its source. A target may set only `hostname` in `targets/<id>/overrides/plan.json`; for `reference-vm` it is `mirroros-ref`.

### Outputs

Each run writes a directory with `0700` permissions and `0600` files, each written through a temporary file that is re-read, revalidated, and renamed:

| Path | Content |
| --- | --- |
| `installation-plan.json` | The plan with its digest. Contains no timestamp or run id and no secret value. |
| `installation-plan.txt` | Plain-text render for review, within 80 columns where possible, with `DESTRUCTIVE` markers. |
| `plan-run.json` | Run metadata: `run_id`, timestamp, input paths, digest, exit status, reasons, and warnings. |

An invalid run writes only `plan-run.json` with its reasons. Stdout carries a summary (target, disk, storage option, destructive operation count, required secrets, digest, and plan path) ending with "Review installation-plan.txt; approval is not part of this stage."; diagnostics and warnings go to stderr.

### Exit outcomes

| Status | Meaning |
| --- | --- |
| `0` | Plan generated and persisted, possibly with warnings (for example a disk addressed by path or an experimental storage option). |
| `2` | Invalid arguments, facts, choices, or target override, an ambiguous or ineligible disk, or an output directory that already holds a plan. |
| `5` | An unexpected failure outside the plan contract, such as an unwritable output location or Node.js failing. |
| `6` | Damaged embedded code, or an internal invariant failure such as the generated plan failing its own validator. |

### Regeneration and approval

Changing a choice and rerunning `plan` creates a new run directory with a new plan and a different digest; the earlier plan stays byte-identical and unapproved. The plan has no approval field, and a plan carrying an `approved` or `approval` field is rejected by the validator. Reviewing and approving a plan, bound to its digest, belongs to Story 2.4, and executing it belongs to Story 2.5.

### Recovery

Planning changes nothing on the target. Fix the reported cause, such as the choices file or the facts, and rerun it into a new output directory.

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

The architecture defines `0` as success, `2` as invalid input or unmet precondition, `3` as explicit cancellation, `4` as execution completed but verification is not ready, `5` as execution or upstream-operation failure, and `6` as internal contract or invariant failure. Currently `0` applies to successful help, valid discovery, and a generated plan, `2` to pending work, invalid arguments, unmet discovery preconditions, or invalid plan inputs, `5` to an unexpected external command failure during discovery or planning, and `6` to a missing or unloadable helper or to damaged discovery or plan code. Install-specific use of `3` and `4` is **Pending**.
