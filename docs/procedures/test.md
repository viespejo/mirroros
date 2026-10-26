# Test procedure

The `operations/test` command qualifies the bootstrap medium of a MirrorOS bundle in one fixed, headless reference VM. Success shows that the selected ISO boots through the supported UEFI/OVMF path and reaches a usable, networked live installation environment. It does not install anything, and it does not verify capabilities, accept an artifact as known-good, or make it eligible for a target laptop. A passing run only makes the artifact eligible for later installation-engine prototypes.

## Invocation

Run the command by path from any working directory; it does not need to be installed on `PATH`.

| Invocation | Behavior |
| --- | --- |
| `operations/test <bundle-directory>` | Validates the bundle, boots its ISO in the reference VM, runs the guest checks, and writes evidence. |
| `operations/test --help` | Prints help and exits `0` without side effects. It is also available when invoked as root and needs no QEMU, KVM, OVMF, or Gitleaks. |

These are the only accepted forms. A missing argument, an unknown option, several arguments, or `--help` combined with anything else exits `2` with a stderr diagnostic before any file is created or any domain tool is invoked. The no-argument diagnostic names the missing bundle directory. A relative bundle path resolves against the caller's working directory, and paths with spaces are supported. A missing or unloadable shared helper or domain implementation exits `6` as an incomplete or damaged checkout; restore it from Git or reclone.

The shared lifecycle help header may retain generic availability wording; this procedure is authoritative for test-specific behavior.

## Prerequisites and privilege boundary

The test must run as a normal user; a root invocation exits `2`. The following must be installed and usable by that user:

- Functional KVM: `/dev/kvm` must actually work for the invoking user, not merely exist.
- OVMF firmware code and variables from the edk2 package (`/usr/share/edk2/x64/OVMF_CODE.4m.fd` and `/usr/share/edk2/x64/OVMF_VARS.4m.fd`).
- `qemu-system-x86_64`, `qemu-img`, `xorriso` (builds the NoCloud medium), Node.js, Gitleaks, Git, and `timeout`.

If a prerequisite is missing, the command exits `2` with guidance and creates no VM resource. It never uses `sudo`, installs packages, changes groups, device permissions, or services, or falls back to software emulation. Enable virtualization and grant your user access to `/dev/kvm` yourself, then retry.

## Input bundle

The argument must be a Story 1.3 bundle directory (for example `dist/<run-id>/`) containing the ISO, `SHA256SUMS`, `artifact-metadata.json`, and the native package manifest. Before any VM resource exists, the test checks that the required files are present, that the checksum file matches the ISO, and that the metadata is coherent with the checksums and the manifest. Any missing, incoherent, or mismatched item exits `2`. The bundle is read-only input and is never modified.

## Reference VM

The configuration is versioned in `vm/reference/reference-vm.conf`; changing it changes the qualification contract and requires an explicit decision.

| Setting | Value |
| --- | --- |
| Machine and acceleration | x86_64 `q35`, KVM, CPU `host` |
| Resources | 2 vCPUs, 4 GiB memory |
| Disk | New sparse 32 GiB qcow2 on a VirtIO controller, empty |
| Network | One VirtIO NIC on SLIRP user-mode NAT, no port forwarding |
| Firmware | Read-only OVMF code, fresh per-run vars copy, Secure Boot disabled |
| Display | Headless, with a serial channel to a private file |

Configuration version 2 adds `REFERENCE_VM_INSTALL_DEADLINE_SECONDS` (2700), the deadline of an installation run, and the two login timings (`REFERENCE_VM_LOGIN_FIRST_WAIT_SECONDS`, `REFERENCE_VM_LOGIN_INTERVAL_SECONDS`) that only `qualify-install` uses; the other settings are unchanged, and bootstrap and discovery runs keep the global deadline above.

The guest receives only the ISO, the empty disk, the NoCloud medium, the firmware, and the control channels. No host directory, credential, device, or environment is shared. The effective configuration and the QEMU and OVMF versions are recorded in the result.

## Guest checks

A per-run, temporary cloud-init NoCloud medium carries the checks and the run ID. Its text is scanned with Gitleaks before the medium is attached. The checks install no packages, start no installer, and do not touch the disk. They emit one JSON report on the serial console. The harness accepts only a complete, consistent report bound to the current run ID, validated in Node. Log keywords or the absence of failures never grant qualification.

The checks confirm:

- UEFI boot mode;
- a working root shell;
- runtime availability of `pacstrap`, `genfstab`, and `arch-chroot` (archinstall is removed and is not required);
- a usable IPv4 address and a default route;
- DNS resolution of `archlinux.org`;
- an HTTPS request to `https://archlinux.org/` with TLS validation, the body discarded, and HTTP `200`, within at most 30 seconds.

## Reduced-profile static checks and attended acceptance

Run the profile and complementary builder/reference contracts without constructing an ISO or launching a real VM:

```sh
bats tests/image/live-profile.contract.bats tests/image/guided-installer.contract.bats \
  tests/image/builder/ tests/vm/reference/
node --test tests/image/live-display.test.mjs tests/image/builder/*.test.mjs tests/vm/reference/*.test.mjs
grub-script-check image/archiso/grub/grub.cfg
grub-script-check image/archiso/grub/loopback.cfg
git diff --check
```

These check approved declarations, MirrorOS metadata/date behavior, live Arch lineage, removed resources, unchanged SSH policy, startup and native-tool failure handling. The live-display contracts check the 720p preference and native-display recovery pair without changing the font or installed-system code. [ADR 0017](../adr/0017-live-console-display-preference.md) still requires new-artifact UEFI/OVMF and physical observations, effective-mode checks, and an ignored/unavailable-mode recovery test. Reference/builder contracts use doubles, not actual runtime qualification. Supply `MIRROROS_BASELINE_BUNDLE` and `MIRROROS_REDUCED_BUNDLE` as documented in [Build](build.md#reduced-live-profile-and-identity) to check actual dependency-resolved manifests; otherwise that check is explicitly skipped.

The [live-package audit and attended QEMU/UEFI acceptance procedure](iso-size-and-live-branding.md#manual-acceptance-and-optimization-measurements) is the manual acceptance path for this reduction. It provides [graphical launch and separate installed/rescue boots](iso-size-and-live-branding.md#graphical-launch-installed-boot-and-rescue-boot), a three-option [installation matrix](iso-size-and-live-branding.md#installation-matrix), [ext4/Btrfs mounting and arch-chroot](iso-size-and-live-branding.md#rescue-mounting-and-arch-chroot), a separate Wi-Fi-device checklist, and private verdict/size/timing worksheets. Until required attended verdicts and a comparable size/timing comparison are recorded and approved, runtime acceptance remains pending; unavailable Wi-Fi evidence is pending, never inferred from virtual Ethernet. Each build, each VM launch (including disk-only and rescue boots), and each destructive case requires explicit authorization. These graphical unseeded observations complement, but do not change or replace, the reference VM configuration, qualification IDs, counted-run rules or Story 2.6 gate.

## Deadlines, stopping, and cleanup

The global deadline is 5 minutes from QEMU launch. When the checks finish, fail, exceed the deadline, or the run is interrupted, only this run's QEMU process is stopped: `SIGTERM`, then after at most 10 seconds `SIGKILL`, then a wait of at most 5 seconds. The test disk, vars copy, and NoCloud medium are deleted only after QEMU exit is confirmed. Evidence is retained. If exit cannot be confirmed, the resources are preserved and reported, and success is never claimed. No other VM is affected, and nothing is retried automatically.

## Paths and permissions

Each run uses an ID of the form `YYYYMMDDTHHMMSSZ-<uuid>`. Directories are created `0700` and generated files `0600`. An occupied reserved run location or a symlinked output base is refused without being touched. No earlier run is recovered, reused, or deleted.

| Path | Contents and handling |
| --- | --- |
| `build/reference-vm/<run-id>/` | Temporary disk, vars copy, NoCloud medium, and guest report. Removed after confirmed QEMU exit; preserved otherwise. |
| `evidence/reference-vm/<run-id>/` | Retained evidence, described below. |

Both locations are ignored by Git and must never be committed.

## Evidence and secret scanning

`evidence/reference-vm/<run-id>/` holds one `result.json` with the artifact identity and checksum, the test-code identity (commit and dirty state), the effective VM configuration, QEMU and OVMF versions, per-check results, duration, the failing stage and next action, the final status, original tool statuses, scan outcomes, cleanup outcomes, and an explicit note that an auxiliary NoCloud medium was used.

Logs are limited to the guest serial output (`guest-serial.log`) and QEMU diagnostics (`qemu-diagnostics.log`), plus redacted Gitleaks reports. The NoCloud text, the result, the logs, and the reports are scanned before qualification is accepted; the scope follows [ADR 0001](../adr/0001-build-secret-scan-scope.md). Findings block qualification and stay private. The terminal shows only progress and a summary derived from the same result, never raw guest logs. No screenshots, memory dumps, or host inventories are collected.

## Normalized outcomes

| Status | Meaning |
| --- | --- |
| `0` | Checks passed, evidence passed scanning, and cleanup completed. |
| `2` | Invalid arguments, inadmissible bundle, unmet prerequisite, or secret-scan findings. |
| `4` | Checks ran but the guest failed a criterion, including external connectivity. |
| `5` | QEMU, deadline, tool, scanner-execution, or cleanup failure. |
| `6` | Damaged checkout or internal contract violation. |
| `130` / `143` | Interrupted by `SIGINT` / `SIGTERM`. |

The first non-success outcome is kept; a later cleanup failure never replaces it. A cleanup failure after an otherwise successful run yields `5`.

## Limits and eligibility

A passing run shows only what the checks above observed. It does not establish:

- an unseeded boot: the NoCloud medium is an auxiliary input, so the guest was seeded;
- an orderly guest shutdown: the guest is stopped by the harness;
- Wi-Fi, LAN, or laptop networking: only SLIRP NAT is exercised;
- a graphical console or desktop;
- the availability of any mirror, or the absolute absence of secrets;
- installation, capability verification, known-good status, or target-laptop eligibility.

Contract tests exercise the logic with simulated tools; only a real run exercises the real KVM, OVMF, NoCloud, and serial integration, and evidence must be read with that distinction in mind.

## Recovering a residual run

A run that could not confirm QEMU exit, or that was killed abruptly, can leave `build/reference-vm/<run-id>/` behind. There is no recovery command and no automatic cleanup; recover manually:

1. Identify the run ID from the diagnostic, or from the directory name under `build/reference-vm/`.
2. Confirm that this run's QEMU has exited, for example with `pgrep -af "reference-vm/<run-id>"`. If it is still running, stop only that process.
3. Remove only `build/reference-vm/<run-id>/`.
4. Keep `evidence/reference-vm/<run-id>/`; it documents the failed run.

Never remove directories of other runs, and never remove the bundle under `dist/`.

## Discovery qualification

`vm/reference/qualify-discovery` qualifies read-only target discovery (Story 2.2) in the same reference VM. It is separate from `operations/test`, whose contract stays unchanged. It reuses the VM configuration, the NoCloud medium, the serial report channel, the deadlines, the stop and cleanup rules, and the evidence scan described above.

| Invocation | Behavior |
| --- | --- |
| `vm/reference/qualify-discovery --scenario <name> <bundle-directory>` | Boots the bundle ISO, runs the embedded `mirroros-install discover`, and writes evidence. |
| `vm/reference/qualify-discovery --scenario <name> --development-overlay <bundle-directory>` | Also copies the working-tree embedded subtrees over `/usr/local/lib/mirroros/` through the NoCloud medium. The run is never counted. |
| `vm/reference/qualify-discovery --help` | Prints help and exits `0` without side effects. |

The prerequisites are those of `operations/test`, plus `sfdisk` and `truncate` for the `layout` scenario and `tar` and `base64` for the overlay. Any other argument form exits `2` before a run resource is created.

| Scenario | Disk | Target | Expected discovery exit |
| --- | --- | --- | --- |
| `empty` | Fresh sparse 32 GiB qcow2 | `reference-vm` | `0` |
| `layout` | GPT with two labeled partitions, built without root through `sfdisk` on a raw file and `qemu-img convert` | `reference-vm` | `0` |
| `framework-target` | Fresh sparse 32 GiB qcow2 | `framework-13-pro-amd` | `2` (identity pending capture) |
| `plan` | Fresh sparse 32 GiB qcow2 | `reference-vm` | `0`, then the plan runs below |
| `confirmation` | Fresh sparse 32 GiB qcow2, one per case | none asserted; the reference VM must be recognized | `0`, then the guided installer runs below |
| `confirmation-experimental` | Fresh sparse 32 GiB qcow2, one per case | none asserted; synthetic SMBIOS identity | `0` (unqualified), then the guided installer runs below |

The `plan` scenario (Story 2.3) runs, in the guest and in order: `discover`, `plan` with defaults (expects `0`), `plan` with a choices file that sets `hostname` and `storage_option` to `btrfs-rescue` (expects `0`), and `plan` with an invalid choices file (expects `2`). The report also carries both plans, their renders, and their `plan-run.json` files, plus the checksum of the first plan taken right after it was written and again after the last run. The run is qualified only when the exits are `0,0,0,2`, the two digests differ, the first plan is byte-identical to its first checksum, the default hostname resolves from the override (`mirroros-ref`), the edited plan shows `choice` as the source of the new hostname and storage option, and the invalid run wrote no plan. A failed plan check yields `4`. Besides the usual evidence, the run keeps `plan-default/`, `plan-edited/`, and `plan-invalid/` with `0700` directories and `0600` files, and `result.json` gains a `plan` object with the exits, digests, and each check.

The guest waits for a default route and DNS, runs discovery with a private output directory on tmpfs, and returns one run-bound JSON report over the serial console. The report carries the discovery exit status, `target-facts.json`, and `error.json` when present. The harness accepts only a complete report bound to the current run ID and checks that the exit status agrees with the facts.

A copy of the disk is kept before launch. After QEMU exit is confirmed, `qemu-img compare` of the copy and the final disk must report identical images; a different disk yields `4`, and a comparison tool failure yields `5`. The comparison is skipped when QEMU exit cannot be confirmed.

Evidence is written to `evidence/reference-vm/discovery/<run-id>/` with `0700` directories and `0600` files: `result.json`, `target-facts.json`, `error.json` when present, `guest-serial.log`, `qemu-diagnostics.log`, and redacted Gitleaks reports. Run resources live in `build/reference-vm/<run-id>/` and follow the cleanup rules above. `result.json` records the artifact identity, the test-code commit and dirty state, the scenario, the expected and actual discovery exit, the disk comparison, the scans, the cleanup outcome, and `counted`.

## Confirmation qualification

`vm/reference/qualify-discovery --scenario confirmation <bundle-directory>` and `--scenario confirmation-experimental <bundle-directory>` qualify the guided live installer (ADR 0006) using the existing launch, private evidence, scan, and cleanup machinery. Each case uses an isolated boot and a fresh disposable disk, so the host can confirm QEMU exit before comparing that case's disk. A development run uses `--development-overlay` with an ISO that already contains Gum and is never counted: the overlay supplies code, not packages.

The two scenarios differ only in machine identity:

| Scenario | Machine identity | Expected classification |
| --- | --- | --- |
| `confirmation` | The normal `reference-vm.conf` (SMBIOS manufacturer `QEMU`) | `matched`, `profile_id` `reference-vm` |
| `confirmation-experimental` | Only the SMBIOS manufacturer (`MirrorOS Test`) and product (`Unqualified Test Machine`) change, through fixed values, not a pass-through | `unqualified`, no `profile_id` |

`reference-vm.conf` is not modified. `result.json` records the SMBIOS variation as `smbios_identity_variation` for the experimental scenario, and each case records the actual classification. Neither scenario asserts `--target`: discovery identifies the machine on its own, and the host rejects a case whose classification, machine identity, or evidence set differs from the expectation.

Before each case the guest runs a read-only `mirroros-install discover` as a precheck, then starts plain `mirroros-install` (no subcommand) under util-linux `script` with `TERM=linux`, no `NO_COLOR`, real Gum, and a 100x50 terminal. The driver is prompt-driven: it sends each answer only after the widget's header or prompt is on screen and the output has been quiet for 250 ms, with no unconditional sleeps and no TTY or confirmation bypass. The full guided route is exercised: welcome, preparation, machine check, disk, storage, hibernation (the sizing screen only when enabled), timezone, language, formats, keyboard, hostname, username, root policy, review, real confirmation, and the protected password prompt. Every case ends before the installation engine writes anything. Four cases must produce:

| Case | Command exit | Outcome / reason | Disk check |
| --- | --- | --- | --- |
| Password cancel (Ctrl+C at the password prompt) | `3` | `cancelled` | Identical before and after |
| Cancel | `3` | `cancelled` | Identical before and after |
| Wrong device name | `3` | `cancelled` / `confirmation_mismatch` | Identical before and after |
| Layout change | `2` | `invalidated` / `target_layout_changed` | Intentional fixture write only |

Only the layout-change case writes to the disposable VM disk: when the password prompt appears, after the real confirmation, the guest uses `sgdisk` to write a GPT on `/dev/vda` and then types a fixed throwaway password, so that the final revalidation invalidates the run before the engine starts. The installer executes no destructive operation in any case; real installations are qualified by [Installation qualification](#installation-qualification). The layout write and every VM or build side effect require explicit approval before they run. The host must check exits and records, compare the disks for the first three cases with `qemu-img compare`, and scan the evidence with redacted Gitleaks. Retain `install-run.json`, `approval-record.json`, `discovery/initial/`, `discovery/final/` when reached, `plans/NN/`, and plain `install.log` under `<case>/install/` for each case, with `0700` directories and `0600` files. Each case also keeps private serial and QEMU logs; the top-level `result.json` contains `confirmation.cases` with exits, outcomes, reasons, profile classification, checks, and individual disk comparisons. The installer's cancellation status `3` is an expected case result, not the qualification command's success status. No real account password is used and no engine operation runs.

Before counted qualification, run `operations/test` on the clean-commit bundle and inspect its package manifest for the installed Gum version and its ISO for executable `operations/install`, `confirm-plan`, and `live-startup` entries. Automated keystrokes do not establish readability or fidelity. The maintainer must also boot the development ISO with a graphical VM console (VT, `TERM=linux`) without a seed medium, check the automatic welcome on tty1 and the return to the shell, and walk the screens, Back/Esc, review, complete-plan pager, cancellation, restart, and confirmation against the frozen reference in `prototypes/frontend/guided-installer/`. Record a private attended verdict on palette, logo, font, centering, margins, labels, and readability, with the actual terminal geometry; fitting 80x25 is not required. The pager has no dedicated feature test, which is an accepted limitation. No Framework or other physical-hardware run is part of this qualification, and recognition of a profile is not qualification of an individual machine.

## Installation qualification

`vm/reference/qualify-install` qualifies the real base-system installation with hardware adaptation and postconditions (Stories 2.5 and 2.6), followed by target-context configure (Story 4.2), in the same reference VM. Unlike the scenarios above, its cases ERASE the disposable 32 GiB disk of the run; the host disk and every other resource stay untouched. It reuses the launch, NoCloud, stop and cleanup, and evidence machinery, and it is separate from `operations/test` and `qualify-discovery`, whose contracts stay unchanged.

| Invocation | Behavior |
| --- | --- |
| `vm/reference/qualify-install --case <name> <bundle-directory>` | Runs one case and writes evidence. |
| `vm/reference/qualify-install --case <name> --development-overlay <bundle-directory>` | Also copies the working-tree embedded subtrees over `/usr/local/lib/mirroros/`. The run is never counted. |
| `vm/reference/qualify-install --help` | Prints help and exits `0` without side effects. |

The prerequisites are those of `operations/test`, plus `tar` and `base64` for the overlay. Any other argument form, and any case that is not enabled yet, exits `2` before a run resource is created. Cases that exist and are enabled in this version:

| Case | Choices | Expected result |
| --- | --- | --- |
| `default` | `btrfs-limine`, hibernation on, root account `locked` | `installed`, exit `0`; the disk boots alone through Limine and the planned user logs in; the engine resolved a `resume_offset`, the Limine entry carries `resume=` and `resume_offset=`, and the observation lists the snapshot entries of the baseline |
| `limine-nohib` | `btrfs-limine`, hibernation off, root account `locked` | `installed`, exit `0`; the disk boots alone through Limine and the planned user logs in; no `@swap` and no `resume=` parameter, and the snapshot entries of the baseline are listed |
| `ext4` | `ext4-systemd-boot`, hibernation on, root account `password` | `installed`, exit `0`; the disk boots alone and the planned user and `root` log in; the engine resolved a `resume_offset` and the boot entry carries `resume=` and `resume_offset=` |
| `btrfs-rescue` | `btrfs-rescue`, hibernation off, root account `locked` | `installed`, exit `0`; the disk boots alone and the planned user logs in; the observation lists the subvolumes `@`, `@home`, `@log`, `@pkg`, and `@snapshots` without `@swap`, the baseline snapshot, and no `resume=` parameter |
| `failure` | `ext4-systemd-boot`, hibernation off; the live mirror list is made unreachable before the run (the approved fixture write) | `failed`, exit `5`, failed operation `install_packages`, later operations not started |
| `cancel-password` | `ext4-systemd-boot`, hibernation off; Ctrl+C at the password prompt | `cancelled`, exit `3`, no `engine/` evidence, and a disk identical to the one before launch |

In the guest, the trigger runs `discover`, creates the plan with the case's choices through `plan --choices`, applies the fixture write when the case has one, and drives the real `mirroros-install --plan` route in a pty with `TERM=linux` and real Gum. The driver is prompt-driven like the confirmation qualification: it fires a rule only when the rule's strings are on screen and the output has been quiet for 250 ms, so it does not assume the order of the screens. The account password is a random 24-character hexadecimal canary generated per run; it is typed only into the two protected fields. After a successful installation the guest mounts the target read-only to collect observations (partition table, filesystems, `fstab`, boot entries, the file list of the ESP, and the microcode archive listing). The plan must be format 4, the confirmation records format 6, and the engine record format 3. Every successful case must have passed pre-restart base postconditions, recorded `configure_outcome: 0` with `installed`/`0`, and contain the host CPU's AMD or Intel microcode in the installed initramfs; the host CPU must have a recognized vendor because QEMU uses CPU `host`. Rule outcomes and non-blocking warnings remain in the recorded plans for inspection. Other disk observations are informational. The trigger returns one run-bound JSON report over the serial console.

A case that installs boots twice. After the report, QEMU is stopped and its exit confirmed; the disk then boots alone, without the ISO and the NoCloud medium, with a private QEMU monitor socket in a short-lived directory. The harness switches to tty2 with monitor `sendkey ctrl-alt-f2` before typing the user name and the canary, proves each login by making the shell write a marker with its own user name to the serial port, and then logs out. A login that does not succeed within the global deadline yields `4`. After the first successful login, the harness also runs read-only queries through sudo in the guest. Selected first-boot observations are gating: `/dev/zram0` must be active at the planned priority, zswap must report disabled, the four effective memory sysctl values must equal the plan, and active swap must be exactly zram plus the priority-0 swapfile when hibernation is enabled (zram alone otherwise). Missing observations or mismatches yield `4` and prevent counting. The canary travels only host-side and through the monitor; the serial console receives only the login marker and these allowlisted non-secret observations.

The unchanged 2700-second installation deadline applies to the first boot, from QEMU launch to the guest report,
including configure. Record the measured installation duration for each qualification run. If it exceeds the
limit, stop and report the measurement rather than silently increasing the deadline (Story 4.2 DEC-034). A deadline, a QEMU exit before the report, or an invalid or unbound report yields `5`; a case that does not end as expected (exit, outcome, confirmation records format 6, plan format 4, engine record format 3 with passed base postconditions and configure outcome 0 for installed cases, host microcode, resume parameters, `zswap.enabled=0`, private permissions, plain logs) or a failed login or selected first-boot check yields `4`; a changed disk in `cancel-password` yields `4`, and a comparison tool failure yields `5`. For installed and failed runs the disk is expected to differ and is compared only to record the result.

Evidence is written to `evidence/reference-vm/install/<run-id>/` with `0700` directories and `0600` files: `result.json` (kind `installation_qualification`, with the case verdict, the login results, the disk comparison, the scans, and `counted`), `install/` (the run's records, `install.log`, plans, discovery, and `engine/`), `observation/`, `guest-serial.log`, `disk-boot/` (the second boot's serial and QEMU diagnostics), and the redacted Gitleaks reports. Besides the NoCloud and evidence Gitleaks scans, every run scans all evidence for its own canary; a hit keeps the run private and yields `2`. The selected gates above qualify configuration and limited runtime state, not full readiness (Epic 5), physical hardware, or successful hibernation/resume. The first-boot verdict is retained under `boot.first_boot` in `result.json`; the microcode listing is under `observation/microcode.txt`.

Every build, every VM run, and every commit needs explicit authorization before it runs; development runs use `--development-overlay` and are never counted. Rerun all six cases on one clean, overlay-free artifact for Story 2.6 acceptance. The four installing cases now include configure; `failure` and `cancel-password` still stop before configure. For Story 4.2, `default` is mandatory and the remaining cases follow this matrix. A failed base postcondition must withhold completion as `not_verified`/`4` and never invoke configure. Configure failure or interruption must withhold completion as `not_configured`/`4`, retain its outcome and evidence path, and use normal cleanup. Prove these failure paths with engine and assistant doubles; do not add a timing-dependent configure-failure VM case. Attended checks include visible rule outcomes and warnings, configure progress, the success message, and the failure, `not_verified`, and `not_configured` screens at the recorded terminal geometry (no overflowing long lines). Record a private attended verdict under `evidence/`. A persistent Limine restore of `@` and one hibernate/resume cycle remain separate attended observations; no Framework or other physical-hardware run is part of this qualification.

### Story 4.2 graphical and rerun checkpoint

The reference VM configuration remains unchanged. Its disk-only tty2 login and serial marker prove console
access, not graphical usability; no screen capture or automated graphical check is added. Separately, with
explicit authorization, launch a laboratory VM with `--gl` (virtio-vga-gl), a fresh disk, and the new ISO.
Install without manual code delivery, choosing console keymap `es` and a disposable password containing a
layout-sensitive key such as `ñ` or `-`. On a console of at least 80 columns, check that progress and success
texts fit, including the configure-step prefix.

After reboot, verify that SDDM accepts the password typed with the `es` layout, record the selector label, and
open the uwsm Hyprland session. Exercise `SUPER+Return` (foot with bash and Starship), tmux new/detach/attach,
`SUPER+SHIFT+Q`, and `SUPER+SHIFT+E`. A failed `es` login blocks approval; a working login permits recording an
incorrect selector label as cosmetic under SDDM #2149. Record any GPU issue rather than changing the reference
VM configuration.

On the installed system run `sudo mirroros-configure`: require outcome `0`, every step `unchanged`, no pacman
transaction or invocation in `configure.log` (read-only preflight/evidence queries still occur), and the commit
from `identity.json` in the evidence. As a non-gating observation, run `sudo localectl set-x11-keymap es` followed
by `grep XKB /etc/vconsole.conf` and record whether `XKBLAYOUT` was written. Copy configure evidence to the host
and run `gitleaks dir --no-banner --redact <dir>`; no leaks are allowed. Fill the actual selector, `es` login,
`XKBLAYOUT`, and GPU findings in `capabilities/README.md` after the checkpoint. Tests with doubles and a
successful qualification command alone do not approve these graphical and rerun checks.

## Counted discovery, confirmation, and installation runs

A run is counted only when it succeeded, used no overlay, the test checkout is clean, and the bundle was built from a clean tree at the same commit as the test code. Development runs (a dirty tree, a dirty bundle, a different commit, or the overlay) record `counted: false`. The status values follow the normalized outcomes above. The recovery steps for a residual run are the same, using `evidence/reference-vm/discovery/<run-id>/` (or `evidence/reference-vm/install/<run-id>/` for `qualify-install`) as the evidence to keep.
