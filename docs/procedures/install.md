# Install lifecycle procedure

**Availability:** `discover`, `plan`, and the guided live installer (`mirroros-install` without a subcommand) are implemented, and the guided installer installs the base system through the native engine (`install/engine/apply`, [`contracts/installation-engine.md`](../../contracts/installation-engine.md)). The engine implements all three storage options (`btrfs-limine`, the default, `btrfs-rescue`, and `ext4-systemd-boot`). Installation postconditions are not verified yet (Story 2.6).

## Current behavior

Invoke the command by path from any working directory; it does not need to be installed on `PATH`. On the live medium it is available as `mirroros-install`, a symlink to the embedded `operations/install`.

| Invocation | Outcome |
| --- | --- |
| Sole `--help` argument | Returns `0`; writes help to stdout and nothing to stderr. |
| No arguments, or only `--plan <file>` and `--output <dir>` | Starts the guided installer; see [Guided live installer](#guided-live-installer). |
| Unsupported arguments, including `apply`, bypass flags, and `--help` with extra arguments | Returns `2`; writes a distinct unsupported-argument diagnostic to stderr. |
| Missing or unloadable `operations/lib/lifecycle-discovery.sh` helper | Returns `6`; reports an incomplete or damaged checkout and advises restoring the helper from Git or recloning. |
| `discover …` | Delegates to `install/discovery/discover`; see [Target discovery](#target-discovery). A missing orchestrator returns `6`. |
| `plan …` | Delegates to `install/plan/plan`; see [Installation plan](#installation-plan). A missing orchestrator returns `6`. |

Except for `discover`, `plan`, and the guided installer, these invocations make no changes, use no privilege, and invoke no domain tool. Help does not require ShellCheck, Bats, or Gitleaks. No success message is emitted for pending installation work.

## Target discovery

```text
operations/install discover [--target <id>] [--output <dir>]
operations/install discover --help
```

Discovery inspects the machine from the live environment without modifying it, records firmware, network, storage, and hardware facts, and normalizes them into `target-facts.json` (format version 2). Without `--target` it identifies a known profile only from a verifiable defined identity; otherwise it records an unqualified machine and invents no generic profile. Recognizing a profile is not qualification of the individual machine. The format is documented in [`contracts/target-facts.md`](../../contracts/target-facts.md). Discovery is non-interactive: it prompts for nothing, uses no Gum, and never selects a disk.

### Inputs

- `--target <id>` is optional and only asserts an expected profile: `reference-vm` or `framework-13-pro-amd`. An unknown or malformed id exits `2` with a `target_unknown` reason, and an assertion that the observed identity contradicts, or whose capture is pending, exits `2` with a specific reason.
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

The DMI identity of the Framework Laptop 13 Pro is not recorded yet, so asserting `--target framework-13-pro-amd` returns `2` with a `target_identity_pending_capture` reason until `targets/framework-13-pro-amd/target.json` is completed from a real capture.

### Recovery

Discovery changes nothing, so recovery is to fix the reported cause and rerun it into a new output directory. For example, boot the medium in UEFI mode and disable CSM or legacy boot, disable Secure Boot, connect a cable or configure Wi-Fi with `iwctl`, or restore a damaged embedded tree by rebuilding the medium.

## Installation plan

```text
operations/install plan --facts <file> [--choices <file>] [--output <dir>]
operations/install plan --help
```

`plan` turns a valid `target-facts.json` (version 2) and the installation policy into a validated installation plan (version 3; plans of earlier versions are rejected with regeneration guidance and never migrated) bound to its inputs by a SHA-256 digest. Hibernation is enabled by default and can be disabled; a disabled plan has no swapfile, `@swap`, or resume configuration. Planning requires detected memory and binds it, together with the SHA-256 of the zram and sysctl source assets, into the plan ([ADR 0007](../adr/0007-zram-and-hibernation-policy.md)); these operations are planned only and nothing is applied or activated. The plan identifies the target disk, the ordered declarative operations with their `destructive` flags, every default with its provenance and source, the secret requirements by name, and the hardware selections. The format, the operation vocabulary, the validation codes, and the digest rules are documented in [`contracts/installation-plan.md`](../../contracts/installation-plan.md). Planning is non-interactive: it prompts for nothing, uses no Gum, executes no operation, and never approves the plan.

### Inputs

- `--facts <file>` names a `target-facts.json` produced by `discover`. Unreadable, malformed, unknown-format, or invalid facts exit `2`. A profile is not required, and the facts file is never modified.
- `--choices <file>` optionally names a flat JSON object with `format_version: 3` that sets editable keys (`target_disk`, `storage_option`, `hibernation`, `swapfile_size` (only with hibernation enabled), `lang`, `regional_format`, `console_keymap`, `timezone`, `hostname`, `user_name`, `root_account`). Language, regional formats (`follow_language`, `en_US.UTF-8`, or `es_ES.UTF-8`), and keyboard are independent; required locales and the `LC_*` category values are derived, and `LC_ALL` is never set. Unknown, non-editable, invalid, and secret-like keys (for example `password` or `user_password`) exit `2` without writing a plan; secrets are never accepted through this file.
- `--output <dir>` names the run directory. A directory that already contains a plan exits `2` without writing. The default is `evidence/install/<run-id>/`, relative to the working directory.
- With exactly one eligible disk, that disk is preselected. With several, `--choices` must name one through `target_disk`; otherwise the command exits `2` and lists the eligible candidates.

### Overrides and precedence

Values resolve as policy, then detected, then target override, then choice, and each plan value records its source. A target may set only `hostname` in `targets/<id>/overrides/plan.json`; for `reference-vm` it is `mirroros-ref`. An override applies only after an unambiguous verified profile match.

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

Changing a choice and rerunning `plan` creates a new run directory with a new plan and a different digest; the earlier plan stays byte-identical and unapproved. The plan has no approval field, and a plan carrying an `approved` or `approval` field is rejected by the validator. The guided installer reviews and confirms the plan through ephemeral, single-use, in-process approval bound to the target and digest. Its `approval-record.json` is evidence only and cannot authorize a later run; every retry requires fresh confirmation. Only the guided installer executes a plan, and only after the bound confirmation, the password entry, and the final revalidation; there is no separate apply command.

### Recovery

Planning changes nothing on the target. Fix the reported cause, such as the choices file or the facts, and rerun it into a new output directory.

## Guided live installer

```text
mirroros-install [--plan <file>] [--output <dir>]
mirroros-install --help
```

On the live ISO the same assistant opens automatically on tty1 as root (ADR 0006); cancelling or finishing returns to the shell, `mirroros-install` restarts it, and other consoles stay plain shells. A seeded qualification boot suppresses only the automatic start. The assistant performs preparation, read-only discovery, choice collection, review, confirmation, protected password entry, final revalidation, and then runs the installation engine as a non-interactive child while it presents progress. The live-root decision (re-evaluated for the reachable engine in ADR 0008) does not change the installed system: installed-user configuration keeps its privilege separation. The full format, safety projection, reason codes, and records are specified in [`contracts/installation-confirmation.md`](../../contracts/installation-confirmation.md).

### Inputs and flow

- Stdin and stdout must both be terminals of the supported scope: a colored interactive console of the live ISO (`TERM` set and not `dumb`, `NO_COLOR` unset). Missing TTY, `NO_COLOR`, `TERM=dumb`, public `apply`, `--yes`, `--non-interactive`, `--target`, and unknown options return `2` before any prompt or discovery; there is no colorless variant and no bypass.
- Gum must be installed with major version `2`; missing or unqualified Gum returns `6` with `gum_not_qualified`. Node.js and the embedded discovery and plan components are also required. No path requests elevation or invokes `sudo`, and no prototype or Omarchy configurator code is needed at runtime.
- There is no profile selection: discovery identifies a known profile on its own, or reports an experimental, unqualified machine that meets the technical requirements. The assistant explains that admission without claiming compatibility or support.
- `--plan <file>` validates and copies an existing version 3 plan into `plans/01/`, preserving the original; plans of earlier versions are rejected with regeneration guidance, and a plan generated by a different build of the code (`engine_version_mismatch`) is rejected before review.
- Only one installation run can be active. The assistant takes a non-blocking lock on `/run/mirroros/install.lock` right after the terminal gate and holds it through the engine; a second `mirroros-install` exits `2` with `install_already_running` on stderr, with no run directory, no records, and no mount touched. The lock is released when the run ends, however it ends. `--output <dir>` names an absent or empty run directory, defaulting to `evidence/install/<run-id>/`.

After the TTY and Gum checks, the screens follow the frozen reference in `prototypes/frontend/guided-installer/`, in this order: welcome with the live keyboard; live connectivity and clock preparation; automatic machine discovery; installation disk (always shown, with real eligible candidates); storage; hibernation (with the swapfile size when enabled); timezone; system language; regional formats; installed console keyboard; hostname; username; root policy; compact review; real confirmation; password entry; final revalidation; installation progress; and the success or failure ending. Defaults, per-value validation, and plan generation come from the plan component (`plan preview-choices` and `plan validate-choice`); the assistant holds no policy of its own.

- **Live settings are not installed settings.** The live keyboard and the live connection affect only this session. Wi-Fi credentials are never requested or retained and live connections are not copied to the installed system. Preparation gives the ISO's enabled time synchronization a bounded readiness check (60 seconds per attempt, measured by counted one-second waits); a clock failure offers help, retry, or cancellation and never bypasses TLS or signature verification. After the network and clock checks, preparation also waits visibly for `pacman-init.service` (the live package keyring, up to 10 minutes) and draws a screen only when it has to wait or fail; a failure offers help, retry, or cancellation with `live_keyring_not_ready`, before any confirmation or password is requested.
- **Review and regeneration.** A validated plan is generated on entering review and regenerated whenever an answer changed, in a new `plans/NN/` with its `choices.json`. An invalid combination reports `message` and `next_step`, keeps the last valid plan, and grants no approval. Unchanged proposals keep their provenance and source. The compact review can open the complete plan (disk and layout, choices with provenance, operations, warnings, secret requirements, and the plan reference) in the `gum pager`; returning keeps the answers and authorizes nothing. The pager has no dedicated feature test, an accepted limitation.
- **Password.** One account password is requested after the bound confirmation and before any disk write, in two protected fields (`Password>` and `Confirm>`). It must be non-empty and match; a blank or mismatched pair asks both again, and there is no attempt limit or strength policy. Esc returns to the review and clears the approval; Ctrl+C cancels with exit `3` before the engine starts. The value is handed to the engine only on a dedicated file descriptor and reaches `chpasswd` on its stdin inside the target; the root account receives it only with the `password` root policy, otherwise root is locked. It never appears in arguments, the environment, the plan, the review, logs, records, or evidence.

Confirmation starts focused on No and shows the disk, its path, and the plan reference. After Yes, type the kernel device name shown by the prompt, such as `vda` (not the plan reference); a mismatch cancels without retry. Backward navigation after authorization clears it. After the password explanation, final rediscovery checks the machine projection, profile binding, firmware, Secure Boot state, disk identity, eligibility and layout, policy and override hashes, and the plan file's digest. A change invalidates approval with a specific reason and the next step "Regenerate and review the installation plan." The engine then starts as a non-interactive child. Before it touches the disk it validates the plan and its digest, rejects a different operation set or code identity, and re-reads the disk one last time; a disk that changed ends the run `invalidated` and a disk that is mounted, swap, or held by LVM, dm-crypt, or md ends it `blocked`, both with the disk untouched. At the start of every run only `/run/mirroros/target` and a swapfile beneath it are released; no other mount is ever touched. The progress screen shows only completed operations. On success the screen states the installed duration and that installation postconditions are not verified in this version, and offers "Restart now" or "Return to shell"; on failure it states the failed operation and child status, warns that the disk was partially modified, shows the log tail and the run path, and offers "View full log", "Return to shell", "Restart", and "Power off". Nothing restarts or powers off unless you choose it.

### Evidence and exits

Once the run starts, it writes `install-run.json`, non-authorizing `approval-record.json` (both format 4), and plain `install.log` (no ANSI or secrets), plus `discovery/initial/`, `discovery/final/` when reached, and `plans/NN/` with the plan, render, plan-run record, and choices. When the engine starts it also writes `engine/` with `engine.log` (plain native output), `state.json`, `engine-run.json` (failed operation, child command and status, completed and not-started operations, resolved values), and the target package list. Directories are `0700`, files `0600`; generated evidence is local and never committed. Argument and TTY failures before the run starts report on stderr without records.

| Status | Meaning |
| --- | --- |
| `0` | `installed`: every operation completed. Postconditions are not verified in this version (Story 2.6). |
| `2` | `invalidated` after a safety or digest change (including a disk that changed before the first write), or `blocked` by invalid input, discovery preconditions, a disk in use, a keyring that is not ready, or a concurrent run (`install_already_running`). |
| `3` | `cancelled`: Cancel, No, Esc at confirmation, Ctrl+C during the interactive phase including the password prompt, or a wrong device name (`confirmation_mismatch`). |
| `5` | `failed`: an external tool or an engine operation failed; the disk was partially modified. |
| `6` | `failed`: damaged code or assets (including a hash mismatch), internal contract failure, or unqualified Gum. |
| `128+n` | Signals outside the interactive phase; a signal during the engine ends the run `failed` with `engine_interrupted`. |

The guided installer returns `0` only after a completed installation; help alone also returns `0`. Ctrl+C mapping belongs to the orchestrator, not the ADR 0004 wrapper. Qualification boots exercise the route up to the confirmation in [Confirmation qualification](test.md#confirmation-qualification), and real installations in [Installation qualification](test.md#installation-qualification).

### Recovery

Before the engine writes, no target change needs undoing: keep the private evidence, fix the reported cause, and rerun into a new output directory with fresh discovery and confirmation. For invalidation, regenerate and review the plan; never reuse an approval record as permission. After a `failed` outcome the disk is partially modified and the engine never resumes or retries: read `engine/engine.log` and `engine/engine-run.json`, fix the cause, and start a new run, which needs a new plan and a new confirmation and erases the disk again. A second console showing `install_already_running` means a run is still active there; wait for it. Leftover mounts from an interrupted run are released at the start of the next run, only under `/run/mirroros/target`.

## Intended engine contract

### Purpose

Coordinate target discovery, reviewable installation planning, confirmation, and application of the native Arch engine (ADR 0002) to install the base operating system. The engine is `install/engine/apply`; its boundary is ADR 0008 and its contract is [`contracts/installation-engine.md`](../../contracts/installation-engine.md).

### Prerequisites

A completed reference-VM reconstruction must precede physical installation. An external backup, independent rescue medium, and known-good ISO are architectural prerequisites before physical migration. The discovery, planning, and confirmation prerequisites are documented above. The engine runs as root in the live session (ADR 0006, ADR 0008), needs the live package keyring to be ready, and needs working mirrors: the live mirror list is used unchanged, with signatures always verified.

### Inputs

A selected target, discovered target state, and a reviewable plan are architectural inputs, with formats and selection documented above. The single account password is collected by the assistant at a protected prompt and passed on a dedicated descriptor; see [Guided live installer](#guided-live-installer).

### Consequential effects

Installation is expected to modify the selected target and may include destructive storage operations. The architecture requires explicit target-bound confirmation for destructive actions; after the confirmation, the password, and the final revalidation, the engine wipes the confirmed disk, creates a GPT with a 2 GiB FAT32 ESP and an unencrypted root, installs the base packages with `pacstrap`, and configures the system from the plan. Discovery, planning, and the confirmation steps before the engine do not modify the target.

### Evidence

Architecture requires run-associated evidence identifying source, target-relevant non-secret context, stage outcome, diagnostics, and generated reports. Discovery, plan, and confirmation evidence are documented above; the engine adds `engine/` to the run directory. Evidence stays local, private, and uncommitted.

### Failure and recovery

The first failure stops all later operations, best-effort cleanup unmounts the target without re-wiping, and nothing is retried or resumed (see the recovery notes of the [Guided live installer](#guided-live-installer)). Do not begin a supported physical installation until the required VM qualification, backup, rescue, and known-good-artifact gates are met. Restore a damaged checkout from Git or reclone it if the shared helper cannot be loaded.

## Normalized outcomes

The architecture defines `0` as success, `2` as invalid input or unmet precondition, `3` as explicit cancellation, `4` as execution completed but verification is not ready, `5` as execution or upstream-operation failure, and `6` as internal contract or invariant failure. Currently `0` applies to successful help, valid discovery, a generated plan, and a completed installation; never to an approval alone. `2` covers pending work, invalid arguments, unmet preconditions, invalid plan inputs, invalidated approval, blocked runs, and concurrent runs. `3` is install-specific cancellation during interactive review or confirmation. `5` covers unexpected external command failures, and `6` covers missing or unloadable helpers, damaged code, internal contract failures, or unqualified Gum. Install-specific use of `4` remains **Pending**; signals retain `128+n` except SIGINT during interactive review or confirmation, which maps to `3`.
