# Install lifecycle procedure

**Availability:** `discover`, `plan`, and the guided live installer (`mirroros-install` without a subcommand) are implemented, and the guided installer installs the base system through the native engine (`install/engine/apply`, [`contracts/installation-engine.md`](../../contracts/installation-engine.md)). The engine implements all three storage options (`btrfs-limine`, the default, `btrfs-rescue`, and `ext4-systemd-boot`). The engine gates success on read-only pre-restart [installation postconditions](../../contracts/installation-postconditions.md) followed by target-context configure of the graphical environment; real VM qualification and attended acceptance are separate evidence gates.

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

`plan` turns a valid `target-facts.json` (version 2) and the installation policy into a validated installation plan (version 4; plans of earlier versions are rejected with regeneration guidance and never migrated) bound to its inputs by a SHA-256 digest. Hibernation is enabled by default and can be disabled; a disabled plan has no swapfile, `@swap`, or resume configuration. Planning requires detected memory and binds it, together with the SHA-256 of the zram and sysctl source assets, into the plan ([ADR 0007](../adr/0007-zram-and-hibernation-policy.md)); these operations are planned only and nothing is applied or activated. The plan identifies the target disk, the ordered declarative operations with their `destructive` flags, every default with its provenance and source, the secret requirements by name, and the hardware selections. The format, the operation vocabulary, the validation codes, and the digest rules are documented in [`contracts/installation-plan.md`](../../contracts/installation-plan.md). Planning is non-interactive: it prompts for nothing, uses no Gum, executes no operation, and never approves the plan.

### Inputs

- `--facts <file>` names a `target-facts.json` produced by `discover`. Unreadable, malformed, unknown-format, or invalid facts exit `2`. A profile is not required, and the facts file is never modified.
- `--choices <file>` optionally names a flat JSON object with `format_version: 3` that sets editable keys (`target_disk`, `storage_option`, `hibernation`, `swapfile_size` (only with hibernation enabled), `lang`, `regional_format`, `console_keymap`, `timezone`, `hostname`, `user_name`, `root_account`). Language, regional formats (`follow_language`, `en_US.UTF-8`, or `es_ES.UTF-8`), and keyboard are independent; required locales and the `LC_*` category values are derived, and `LC_ALL` is never set. Unknown, non-editable, invalid, and secret-like keys (for example `password` or `user_password`) exit `2` without writing a plan; secrets are never accepted through this file.
- `--output <dir>` names the run directory. A directory that already contains a plan exits `2` without writing. The default is `evidence/install/<run-id>/`, relative to the working directory.
- With exactly one eligible disk, that disk is preselected. With several, `--choices` must name one through `target_disk`; otherwise the command exits `2` and lists the eligible candidates.

### Overrides and precedence

Values resolve as policy, then detected, then target override, then choice, and each plan value records its source. The pure rules in `hardware/rules/` evaluate graphics, CPU vendor, battery, and virtualization with a detected value, outcome, and explanation. AMD and Intel CPUs select `amd-ucode` or `intel-ucode` in a separate rule-package list with `hardware_detection` provenance; it is not editable. AMD, Intel, and QEMU graphics use the kernel driver with nothing additional. NVIDIA, unknown graphics, and unknown or missing CPU vendors produce non-blocking review warnings with a next step; no package is guessed, and `nouveau` is neither configured nor blacklisted. Battery and virtualization are informational only. Rules never change policy or overrides, and target overrides never change rule outcomes. A target may set only `hostname` in `targets/<id>/overrides/plan.json`; for `reference-vm` it is `mirroros-ref`. An override applies only after an unambiguous verified profile match.

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

### Live display and text size

Under [ADR 0017](../adr/0017-live-console-display-preference.md), the default USB/UEFI entry is
**MirrorOS Live/Rescue - prefer 1280x720**. It requests `video=1280x720` for this live boot only. The kernel
and driver decide the effective mode; this is not a forced connector or a check that the panel advertises
720p. The font remains the kernel default. The boot menu itself need not change size.

If the screen is blank, distorted, or unsuitable, reboot to the USB menu and select
**MirrorOS Live/Rescue - native display**. That entry omits the mode request and preserves the
firmware/kernel choice; automatic fallback is not guaranteed. Do not interrupt an installation that is
writing the disk just to adjust presentation. Neither entry changes installed boot parameters, desktop
scaling, or the greeter's monitor policy. GRUB configuration retains the same alternatives for compatibility;
Ventoy is not a qualified boot path.

Optional larger text is a temporary live-console adjustment, not the default. Before installation starts,
cancel the assistant to its root shell on the console you want to adjust, then run:

```bash
setfont -d default8x16
mirroros-install
```

This doubles the 8x16 font to 16x32. It can displace the logo or overflow long screens; check the review
and warnings before proceeding. Restarting the assistant redraws the screen with the new glyphs instead
of judging text left over from the previous rendering. Do not start a second assistant while one is active
on another console. To restore the boot font and its mapping, cancel back to that console's shell and run
`setfont -R`, then restart the assistant. Rebooting also discards the adjustment. No font setting is copied
to the installed system.

For a display check, read `cat /proc/cmdline`, `showconsolefont -i`, `stty size`, and, if present,
`cat /sys/class/graphics/fb0/virtual_size`; virtual framebuffer size alone is not proof of the active
connector mode. Record the effective connector mode too when qualifying the artifact. At effective
1280x720 with an 8x16 font expect roughly 160 columns and 45 rows, not a universal fit guarantee.

### Inputs and flow

- Stdin and stdout must both be terminals of the supported scope: a colored interactive console of the live ISO (`TERM` set and not `dumb`, `NO_COLOR` unset). Missing TTY, `NO_COLOR`, `TERM=dumb`, public `apply`, `--yes`, `--non-interactive`, `--target`, and unknown options return `2` before any prompt or discovery; there is no colorless variant and no bypass.
- Gum must be installed with major version `2`; missing or unqualified Gum returns `6` with `gum_not_qualified`. Node.js and the embedded discovery and plan components are also required. No path requests elevation or invokes `sudo`, and no prototype or Omarchy configurator code is needed at runtime.
- There is no profile selection: discovery identifies a known profile on its own, or reports an experimental, unqualified machine that meets the technical requirements. The assistant explains that admission without claiming compatibility or support.
- `--plan <file>` validates and copies an existing version 4 plan into `plans/01/`, preserving the original; plans of earlier versions are rejected with regeneration guidance, and a plan generated by a different build of the code (`engine_version_mismatch`) is rejected before review.
- Only one installation run can be active. The assistant takes a non-blocking lock on `/run/mirroros/install.lock` right after the terminal gate and holds it through the engine; a second `mirroros-install` exits `2` with `install_already_running` on stderr, with no run directory, no records, and no mount touched. The lock is released when the run ends, however it ends. `--output <dir>` names an absent or empty run directory, defaulting to `evidence/install/<run-id>/`.

After the TTY and Gum checks, the screens follow the frozen reference in `prototypes/frontend/guided-installer/`, in this order: welcome with the live keyboard; live connectivity and clock preparation; automatic machine discovery; installation disk (always shown, with real eligible candidates); storage; hibernation (with the swapfile size when enabled); timezone; system language; regional formats; installed console keyboard; hostname; username; root policy; compact review; real confirmation; password entry; final revalidation; installation progress; and the success or failure ending. Defaults, per-value validation, and plan generation come from the plan component (`plan preview-choices` and `plan validate-choice`); the assistant holds no policy of its own.

- **Live settings are not installed settings.** The live keyboard and the live connection affect only this session. Wi-Fi credentials are never requested or retained and live connections are not copied to the installed system. Preparation gives the ISO's enabled time synchronization a bounded readiness check (60 seconds per attempt, measured by counted one-second waits); a clock failure offers help, retry, or cancellation and never bypasses TLS or signature verification. After the network and clock checks, preparation also waits visibly for `pacman-init.service` (the live package keyring, up to 10 minutes) and draws a screen only when it has to wait or fail; a failure offers help, retry, or cancellation with `live_keyring_not_ready`, before any confirmation or password is requested.
- **Review and regeneration.** A validated plan is generated on entering review and regenerated whenever an answer changed, in a new `plans/NN/` with its `choices.json`. An invalid combination reports `message` and `next_step`, keeps the last valid plan, and grants no approval. Unchanged proposals keep their provenance and source. The compact review shows every hardware rule outcome and all warnings before confirmation, plus the fixed line "After the base system is verified, the graphical environment is configured." It can open the complete plan (disk and layout, choices with provenance, operations, warnings, secret requirements, and the plan reference) in the `gum pager`; returning keeps the answers and authorizes nothing. The pager has no dedicated feature test, an accepted limitation.
- **Password.** One account password is requested after the bound confirmation and before any disk write, in two protected fields (`Password>` and `Confirm>`). It must be non-empty and match; a blank or mismatched pair asks both again, and there is no attempt limit or strength policy. Esc returns to the review and clears the approval; Ctrl+C cancels with exit `3` before the engine starts. The value is handed to the engine only on a dedicated file descriptor and reaches `chpasswd` on its stdin inside the target; the root account receives it only with the `password` root policy, otherwise root is locked. It never appears in arguments, the environment, the plan, the review, logs, records, or evidence.

Confirmation starts focused on No and shows the disk, its path, and the plan reference. After Yes, type the kernel device name shown by the prompt, such as `vda` (not the plan reference); a mismatch cancels without retry. Backward navigation after authorization clears it. After the password explanation, final rediscovery checks the machine projection, profile binding, firmware, Secure Boot state, disk identity, eligibility and layout, policy and override hashes, and the plan file's digest. A change invalidates approval with a specific reason and the next step "Regenerate and review the installation plan." The engine then starts as a non-interactive child. Before it touches the disk it validates the plan and its digest, rejects a different operation set or code identity, and re-reads the disk one last time; a disk that changed ends the run `invalidated` and a disk that is mounted, swap, or held by LVM, dm-crypt, or md ends it `blocked`, both with the disk untouched. At the start of every run only `/run/mirroros/target` and a swapfile beneath it are released; no other mount is ever touched. The progress bar counts completed plan operations plus one final unit for configure; every fixed engine-phase line fits 80 columns including its prefix, and operation descriptions are limited to 72 characters. After the last operation, the engine checks the still-mounted target read-only: kernel and initramfs, mounts and UUID-based fstab, bootloader and root UUID, zswap and resume parameters, swapfile when enabled, zram and sysctl assets, NetworkManager prerequisites, and planned microcode in the initramfs. Only after those base postconditions pass, the engine copies configure's rerun code and `identity.json` to `/usr/local/lib/mirroros/` on the target and creates `/usr/local/bin/mirroros-configure`. It runs its embedded `operations/configure --target-root /run/mirroros/target --user <planned user>`, with package, user, and unit commands inside `arch-chroot`, target package transactions using `SNAP_PAC_SKIP=y`, and SDDM enabled but never started. The final progress line is "[N+1/N+1] Configure the graphical environment." with numeric positions; a second line shows "Configure step: <k>/<total> <step>" instead of a package count. Configure output is appended to `engine.log`; only outcome `0` permits `installed`/`0`, followed by normal target cleanup. On success the screen states the installed duration and "Base system verified and graphical environment configured.", and offers "Restart now" or "Return to shell"; on failure it states the failed operation and child status, warns that the disk was partially modified, shows the log tail and the run path, and offers "View full log", "Return to shell", "Restart", and "Power off". A failed postcondition produces `not_verified`/`4`, not success: its screen names every failed check and its non-secret detail, warns not to rely on the installed system, and offers the same diagnostic menu with "Return to shell" selected. A configure failure or interruption produces `not_configured`/`4`: the screen names the failed step, states that the base system is installed and verified, and directs you to boot it, log in at the console, and run `sudo mirroros-configure`. Its menu offers "View configure log", "Restart", "Return to shell" (selected), and "Power off", with no live-medium retry. Long lines on the failure, `not_verified`, `not_configured`, and engine no-valid-record screens are wrapped to the terminal width, including paths and log lines. Nothing restarts or powers off unless you choose it.

### Evidence and exits

Once the run starts, it writes `install-run.json`, non-authorizing `approval-record.json` (both format 7; readers also accept pre-timing format 6), and plain `install.log` (no ANSI or secrets), plus `discovery/initial/`, `discovery/final/` when reached, and `plans/NN/` with the plan, render, plan-run record, and choices. When the engine starts it also writes `engine/` with `engine.log` (plain native output), `state.json`, `engine-run.json` (format 4, with pre-timing format 3 also readable: timing, failed operation, child command and status, completed and not-started operations, resolved values, per-check base postconditions, and configure outcome, failed step, and target-relative evidence path when applicable), and the target package list. Directories are `0700`, files `0600`; generated evidence is local and never committed. `state.json` is also format 3 and includes optional `configure_step` and `configure_position` fields. Configure's own private evidence stays on the installed system under `/var/log/mirroros/configure/<run-id>/`, recording `context target` and source identity from `identity.json`. Argument and TTY failures before the run starts report on stderr without records.

| Status | Meaning |
| --- | --- |
| `0` | `installed`: every plan operation and base postcondition passed, and configure returned `0`; not a claim of full runtime readiness. |
| `4` | `not_verified`: operations completed but a base postcondition failed; configure did not run. `not_configured`: base verification passed but configure failed or was interrupted. Both unmount the target and retain records. |
| `2` | `invalidated` after a safety or digest change (including a disk that changed before the first write), or `blocked` by invalid input, discovery preconditions, a disk in use, a keyring that is not ready, or a concurrent run (`install_already_running`). |
| `3` | `cancelled`: Cancel, No, Esc at confirmation, Ctrl+C during the interactive phase including the password prompt, or a wrong device name (`confirmation_mismatch`). |
| `5` | `failed`: an external tool or an engine operation failed; the disk was partially modified. |
| `6` | `failed`: damaged code or assets (including a hash mismatch), internal contract failure, or unqualified Gum. |
| `128+n` | Signals outside the interactive phase; during the engine, outside configure, they end `failed` with `engine_interrupted`. During configure the engine waits and records `not_configured`/`4` with configure's outcome (`3` for SIGINT, `5` for SIGTERM/SIGHUP). |

The guided installer returns `0` only after a completed installation; help alone also returns `0`. Ctrl+C mapping belongs to the orchestrator, not the ADR 0004 wrapper. Qualification boots exercise the route up to the confirmation in [Confirmation qualification](test.md#confirmation-qualification), and real installations in [Installation qualification](test.md#installation-qualification).

### Timing boundaries

`install-run.json` owns guided total and accumulated reached-stage intervals; `engine-run.json` owns engine
total, prechecks and their nested subchecks, plan operations, postconditions, configure, and cleanup.
Configure owns total, validation, and started-step timings in `configure-run.tsv`; allowlisted native TSV
copies are retained under `engine/configure/` for existing VM evidence collection. Supported legacy records
remain readable without historical timing fields.

New elapsed values use the first `/proc/uptime` reading, integer milliseconds at 10 ms resolution, independent
of UTC clock adjustments. Unreadable, malformed, or regressing samples produce explicit unavailable timing
with a safe reason and no duration; they never change lifecycle outcomes. Unstarted items have no duration.
Guided total starts at flow entry and stops at outcome finalization before final serialization: live boot and
the final outcome menu are excluded. Repeated visits accumulate actual intervals, not the deduplicated stage
list. Review, confirmation, and password are interactive; preparation is mixed; discovery, plan, final
discovery, and engine are automated. This is not exact human-time subtraction.

Engine timing ends after cleanup, before record serialization. Configure validation is separate from the
first step. Configure steps are inside configure, engine phases inside engine total, and engine inside guided
engine time; never add nested totals. Hard kills and unwritable evidence gain no persistence guarantee.
The existing success-duration line remains unchanged; no timing table or live step durations are added.
See the [guided contract](../../contracts/installation-confirmation.md#guided-timing),
[engine contract](../../contracts/installation-engine.md#engine-timing), and the separately authorized
[three-run measurement protocol](installation-time-measurements.md). Driver timings are not representative
human reading times, and QEMU qualification duration has a different boundary and clock.

### Recovery

Before the engine writes, no target change needs undoing: keep the private evidence, fix the reported cause, and rerun into a new output directory with fresh discovery and confirmation. For invalidation, regenerate and review the plan; never reuse an approval record as permission. After `not_verified`, retain the records and inspect the failed checks in `engine/engine-run.json`; the checker never repairs, retries, or converts the result into success. A new installation requires a new plan and confirmation. After `not_configured`, boot the installed system, log in at a text console (tty2 is available if the greeter occupies tty1), inspect `/var/log/mirroros/configure/<run-id>/`, fix the reported cause, and run `sudo mirroros-configure`. The launcher and code copy require no clone, are not automatically updated, and permit a full rerun from the beginning, not a resume. The assistant does not remount the target or retry configure from the live medium. After a `failed` outcome the disk is partially modified and the engine never resumes or retries: read `engine/engine.log` and `engine/engine-run.json`, fix the cause, and start a new run, which needs a new plan and a new confirmation and erases the disk again. A second console showing `install_already_running` means a run is still active there; wait for it. Leftover mounts from an interrupted run are released at the start of the next run, only under `/run/mirroros/target`.

## Intended engine contract

### Purpose

Coordinate target discovery, reviewable installation planning, confirmation, and application of the native Arch engine (ADR 0002) to install the base operating system and then configure the graphical environment after base verification. The engine is `install/engine/apply`; its boundary is ADR 0008 and its contract is [`contracts/installation-engine.md`](../../contracts/installation-engine.md).

### Prerequisites

A completed reference-VM reconstruction must precede physical installation. An external backup, independent rescue medium, and known-good ISO are architectural prerequisites before physical migration. The discovery, planning, and confirmation prerequisites are documented above. The engine runs as root in the live session (ADR 0006, ADR 0008), needs the live package keyring to be ready, and needs working mirrors, with signatures always verified. Just before the engine, the assistant moves the mirrors of the plan's time-zone country first and Worldwide second in the live mirror list ([ADR 0013](../adr/0013-regional-live-mirror-selection.md)); the result is logged in `install.log`. A mirror given with the `mirror=` boot parameter, or a list without that country's servers, is left unchanged. The engine then uses the live mirror list unchanged.

### Inputs

A selected target, discovered target state, and a reviewable plan are architectural inputs, with formats and selection documented above. The single account password is collected by the assistant at a protected prompt and passed on a dedicated descriptor; see [Guided live installer](#guided-live-installer).

### Consequential effects

Installation is expected to modify the selected target and may include destructive storage operations. The architecture requires explicit target-bound confirmation for destructive actions; after the confirmation, the password, and the final revalidation, the engine wipes the confirmed disk, creates a GPT with a 2 GiB FAT32 ESP and an unencrypted root, installs the base packages with `pacstrap`, and configures the system from the plan. Discovery, planning, and the confirmation steps before the engine do not modify the target.

The base package selection explicitly includes `xkeyboard-config`, the XKB keyboard definitions also used by
Wayland. This lets `configure` validate the system layout against `base.lst` before changing packages or
configuration files; it does not enable an X11 server.

### Evidence

Architecture requires run-associated evidence identifying source, target-relevant non-secret context, stage outcome, diagnostics, and generated reports. Discovery, plan, and confirmation evidence are documented above; the engine adds `engine/` to the run directory. Evidence stays local, private, and uncommitted.

### Failure and recovery

The first failure stops all later operations, best-effort cleanup unmounts the target without re-wiping, and nothing is retried or resumed (see the recovery notes of the [Guided live installer](#guided-live-installer)). Do not begin a supported physical installation until the required VM qualification, backup, rescue, and known-good-artifact gates are met. Restore a damaged checkout from Git or reclone it if the shared helper cannot be loaded.

## Normalized outcomes

The architecture defines `0` as success, `2` as invalid input or unmet precondition, `3` as explicit cancellation, `4` as execution completed but verification is not ready, `5` as execution or upstream-operation failure, and `6` as internal contract or invariant failure. Currently `0` applies to successful help, valid discovery, a generated plan, and a completed installation; never to an approval alone. `2` covers pending work, invalid arguments, unmet preconditions, invalid plan inputs, invalidated approval, blocked runs, and concurrent runs. `3` is install-specific cancellation during interactive review or confirmation. `5` covers unexpected external command failures, and `6` covers missing or unloadable helpers, damaged code, internal contract failures, or unqualified Gum. `4` means `not_verified` after a failed base postcondition or `not_configured` after configure failure or interruption; signals otherwise retain `128+n` except SIGINT during interactive review or confirmation, which maps to `3`.
