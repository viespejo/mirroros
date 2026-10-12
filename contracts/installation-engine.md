# Installation engine (`install/engine/apply`)

`ENGINE_RUN_FORMAT_VERSION: 1` and `ENGINE_STATE_FORMAT_VERSION: 1`. `install/engine/apply` applies one approved
[installation plan](installation-plan.md) (format 3) to the confirmed disk with the native Arch commands
selected by [ADR 0002](../docs/adr/0002-installation-engine-selection.md). It is an internal boundary: it is
invoked only by the guided assistant after the bound confirmation, the password entry, and the final
revalidation described in [`installation-confirmation.md`](installation-confirmation.md), and it is not a public
command ([ADR 0008](../docs/adr/0008-installation-engine-execution-boundary.md)). There is no `apply`
subcommand, no non-interactive mode, and no flag that bypasses any of those steps.

The engine is a Bash orchestrator (`install/engine/apply`, `install/engine/lib/*.sh`) with two Node ESM helpers:
`load-plan.mjs` (validation, digest, and the step stream) and `engine-record.mjs` (atomic record writing). It
reuses `install/plan/validate-plan.mjs` and `install/plan/digest-plan.mjs`; it has no second hashing
implementation and no `jq` dependency.

Conventions: JSON fields use `snake_case`; fields that do not apply are omitted. No secret value, hash of a
secret, or length hint appears in any document, log, or record of the engine.

## Invocation and inputs

```text
install/engine/apply --plan <file> --digest <hex> --output <dir>
```

| Input | Description |
| --- | --- |
| `--plan <file>` | The `installation-plan.json` of the confirmed `plans/NN/` directory of the run. Read once into memory; the engine works from that copy only. |
| `--digest <hex>` | The digest confirmed by the user. It is integrity binding, not authorization: root on the live system can call the engine directly, and authorization rests on the single tested path of [ADR 0008](../docs/adr/0008-installation-engine-execution-boundary.md). |
| `--output <dir>` | The `engine/` directory of the run. Created with `0700` when missing; it must not already contain `engine-run.json`. |
| fd 3 | The `account_password`, one line, written by the assistant (see [Password](#password)). |
| fd 4 | The inherited installer lock (see [Run exclusion](#run-exclusion)). |

Standard input is `/dev/null`: the engine never prompts and never returns control to ask for anything. An unknown
option, a missing option, or an unreadable plan exits `2` on stderr, before anything else.

Neither `install/plan/policy.json` nor any other mutable source is ever opened by the engine. Its values come
only from the plan's `parameters` and `resolved_at_apply` entries, from values resolved during apply, and from
the engine constants enumerated per kind below. Constants are fixed in code, recorded in `engine-run.json`, and
bound to the plan by the code identity check.

## Run exclusion

The assistant takes a non-blocking exclusive lock on `/run/mirroros/install.lock` (tmpfs) right after its
terminal gate and before its own-mount cleanup, discovery, and run-directory creation, and holds it until the
flow and the engine end. The engine inherits the descriptor as fd 4 and verifies in its first step that fd 4 refers
to that file and that `flock -n` on it succeeds, so it holds the lock. Invoked without fd 4 it opens and tries to
lock the file itself. When another process holds the lock, the engine exits `2` with `install_already_running`
on stderr only: no output directory, no record, and no mount touched. Neither fd 3 nor fd 4 is inherited by the
external commands the engine runs, so a dying engine releases the lock. `discover` and `plan` take no lock.

## Pre-check order

One order, fixed. Steps 1 to 6 write nothing to the target disk; a failure at any of them leaves the disk
untouched and the password discarded.

| # | Step | Failure |
| --- | --- | --- |
| 1 | Inherited or self-taken installer lock (above). | `install_already_running`, exit `2`, stderr only. |
| 2 | Code identity. The plan is read once into memory. The engine reads its own embedded `identity.json` (the same reading as `install/discovery/discover`) and requires the plan's `facts_binding.commit` and `facts_binding.dirty` to equal it. | `engine_version_mismatch`, `blocked`, exit `2`. A missing or unreadable identity is exit `6`. |
| 3 | Plan validation with `validate-plan.mjs` (format 3), digest recomputed and equal to `--digest`, and rejection of any unknown kind and of any operation set or order other than the plan contract's for the plan's storage option and hibernation state. | `digest_mismatch`: `invalidated`, exit `2`. Validator codes pass through: `blocked`, exit `2`. |
| 4 | Keyring ready, without waiting: `pacman-init.service` is `active`. The engine never waits; the wait belongs to live preparation. | `live_keyring_not_ready`, `blocked`, exit `2`. |
| 5 | The password is read once from fd 3 and fd 3 is closed. It must be present, non-empty, a single line, and free of NUL. | `password_unavailable`, `blocked`, exit `2`. |
| 6 | Final block, immediately before the first destructive operation: (a) re-read the disk with the read-only `install/discovery/discover-storage` collector and compare the identity (`path`, `by_id`, `wwn`, `serial`, `model`, `size_bytes`), `current_layout`, and eligibility with the plan by reusing `install/confirmation/compare-safety.mjs`; (b) check occupancy: no partition of the disk is mounted or used as swap, and neither the disk nor its partitions have holders (empty `/sys/block/<dev>/holders` and `/sys/class/block/<part>/holders`, no `lvm`, `crypt`, or `raid*` children in `lsblk`). A leftover mount of the engine's own target mount point on the disk counts as in use. | (a) `target_identity_changed` or `target_layout_changed`, `invalidated`, exit `2`, password discarded. (b) `target_disk_in_use`, `blocked`, exit `2`, with a `next_step` naming what to release manually. |
| 7 | `wipe_disk_signatures`, the first destructive operation. | See [Failure](#failure-interruption-and-cleanup). |

The engine never unmounts or releases anything outside its own mount point, and it does not unmount at the start
of a direct invocation: the start-of-run cleanup of `/run/mirroros/target` and of a swapfile beneath it belongs
to the assistant (see [`installation-confirmation.md`](installation-confirmation.md#run-exclusion-and-start-of-run-cleanup)).
Anything left mounted by a dead attempt shows up as `target_disk_in_use`, whose `next_step` is to run
`mirroros-install` again.

## Mount point

The target is mounted at `/run/mirroros/target`, created by the engine with mode `0700` on the live tmpfs, owned
by root. Everything beneath it is created by MirrorOS. `/mnt` is not used.

## Execution

Operations run in plan order through a `kind → function` dispatch table, one at a time. A kind absent from the
table is rejected in step 3, never skipped. Native commands run with stdin `/dev/null` and with stdout and stderr
appended to `engine.log`. After each operation the engine checks that operation's immediate effect (the right
column below) and then updates `state.json`.

After `create_partitions` the engine synchronizes before formatting: `blockdev --flushbufs`, `partprobe`, and
`udevadm settle`. Partition device nodes are resolved from the kernel after that, in partition-number order, so
disks named like `nvme0n1` and `vda` are handled alike.

### Operations, values, and checks

The tools used on the live side are the ones the live image already carries (`sfdisk`, `wipefs`, the
filesystem tools, `btrfs-progs`, `arch-install-scripts`, `util-linux`, `e2fsprogs`). Inside the target the
engine uses `arch-chroot` and only tools that `install_packages` has installed, and never a tool before the
operation that installs it.

| Kind | Behavior and engine constants | Immediate-effect check |
| --- | --- | --- |
| `wipe_disk_signatures` | `wipefs --all` over the partitions of the disk and then the disk itself. | `wipefs` finds no signature on the disk. |
| `create_partition_table` | Write an empty GPT. | The disk reports a `gpt` partition table. |
| `create_partitions` | `sfdisk` with one ESP of `esp_size_bytes` (type EFI System) and one root partition on the remaining space (type Linux filesystem). Then the sync steps above. | Exactly two partitions with the expected sizes and types, both nodes present. |
| `format_filesystems` | FAT32 on the ESP and the plan's root filesystem (`ext4` or `btrfs`) on the root partition, with the label `mirroros` on the root. Resolves `partition_uuids` with `blkid`. | The ESP volume id and the root UUID are well formed; the filesystems are of the planned types. |
| `create_btrfs_subvolumes` | Mount the top-level volume, create the plan's `subvolumes` flat at the top level, unmount. `@swap` exists only when the plan lists it. | Every planned subvolume exists. |
| `mount_target` | ext4: root at the mount point, ESP at `/boot` with `umask=0077`. Btrfs: `subvol=@` at the mount point with the plan's `mount_options`; `@home` at `/home`, `@log` at `/var/log`, `@pkg` at `/var/cache/pacman/pkg`, `@snapshots` at `/.snapshots`, `@swap` at `/swap` only when planned; the ESP at `/boot` with `umask=0077`. | Every planned mount is present beneath the mount point. |
| `install_packages` | `pacstrap -K` with the plan's `packages`, using the live mirrorlist unchanged and with signature verification always on. No reflector, no ranking, no `-M`, no `SigLevel` change. After success the engine records the active `Server =` lines of the target mirrorlist and its SHA-256, and stores the target's `pacman -Q` as `target-packages.txt`. `packages_installed` in `state.json` counts the entries of the target's local package database. | `pacstrap` succeeds; the kernel and initramfs files named by the plan exist under `/boot`; the target mirrorlist equals the live one. |
| `configure_zram`, `configure_memory_reclaim` | Copy the allowlisted asset to the plan's `destination` only when the SHA-256 of the source equals the plan's `source_sha256`; otherwise fail before writing. | The destination's SHA-256 equals `source_sha256`. |
| `generate_fstab` | `genfstab -U` into `/etc/fstab`. For Btrfs, `subvolid=` is removed so a rollback of `@` cannot leave a stale subvolume id; subvolume paths stay. | Every planned mount appears by UUID; no `subvolid=`. |
| `create_swapfile` | Only with hibernation. ext4: `/swapfile` created with `mkswap --file` of `size_mib`. Btrfs: `/swap/swapfile` in `@swap`, created with `btrfs filesystem mkswapfile` (NOCOW), because the swap volume is mounted at `/swap`; the plan's `path` is `/swapfile` for every option and the engine places it there on Btrfs. The fstab line carries `pri=<priority>` (`0`). Resolves `resume_offset`: ext4 from the first physical extent reported by `filefrag`; Btrfs from `btrfs inspect-internal map-swapfile -r`. | `resume_offset` is a positive integer; the swapfile has mode `0600` and the expected size; the fstab line is present. |
| `configure_locale_time_console` | Enable the plan's `locales` in `/etc/locale.gen` and run `locale-gen`; write `/etc/locale.conf` from `locale_categories`; write `/etc/vconsole.conf` with `KEYMAP`; link `/etc/localtime` to `timezone`; `hwclock --systohc` for the UTC hardware clock. | The files hold the planned values; the timezone link resolves. |
| `configure_hostname_network` | Write `/etc/hostname`. NetworkManager gets no predefined connection. | `/etc/hostname` holds the hostname. |
| `create_user` | `useradd` with the plan's name, groups, and the shell resolved as `/usr/bin/<shell>`; password set through `chpasswd` (see [Password](#password)). | The user exists in the target with the planned groups and shell and a non-locked password entry. |
| `configure_root_account` | `locked`: `passwd -l root`. `password`: the same password through `chpasswd`. | The root entry is locked, or has a password hash, accordingly. |
| `configure_sudo_sysrq_pacman` | Write the plan's `sudoers` line to `/etc/sudoers.d/10-mirroros-wheel` (mode `0440`, checked with `visudo -cf`); write the plan's `sysrq` line to `/etc/sysctl.d/90-sysrq.conf`; apply `pacman_options` only to the target `/etc/pacman.conf`, never to the live one. | `visudo -cf` passes; each option is active in the target `pacman.conf`. |
| `install_bootloader` | Per option, see [Boot](#boot). | Per option. |
| `install_limine_snapshot_tools` | `btrfs-limine` only, see [Limine](#limine-btrfs-limine). | See there. |
| `configure_snapper` | Btrfs only. Replace the mount of `@snapshots` around `snapper --no-dbus -c root create-config /`, delete the subvolume Snapper created, recreate `/.snapshots` with mode `0750`, and mount `@snapshots` again. Configuration constants: `TIMELINE_CREATE=no`, `NUMBER_CLEANUP=yes`, `NUMBER_LIMIT=10`. Root only, `@` only, no timeline, no `@home` configuration. `snap-pac` stays installed; the engine runs package transactions after this point with `SNAP_PAC_SKIP=y` when they happen inside the chroot. | `/etc/snapper/configs/root` holds the constants as `KEY="value"` lines; `/.snapshots` is the `@snapshots` subvolume. |
| `enable_services` | `systemctl enable` inside the chroot of the plan's `services` (NetworkManager, the time sync service, `fstrim.timer`) plus the option's services: `systemd-boot` options `systemd-boot-update.service`; both Btrfs options `snapper-cleanup.timer` (and `snapper-timeline.timer` disabled); `btrfs-limine` also `limine-snapper-sync.service` (and not `systemd-boot-update.service`). | `systemctl is-enabled` agrees for every service. |
| `create_baseline_snapshot` | Btrfs only. `snapper --no-dbus -c root create --type single --description "post-install baseline"`. | The snapshot is listed. |
| `sync_limine_snapshot_entries` | `btrfs-limine` only, see [Limine](#limine-btrfs-limine). | See there. |

`engine-run.json` records every constant used, per kind, so that a run can be understood without the source at
that commit.

Apply-time values are validated when resolved: UUIDs and volume ids are well formed, and `resume_offset` is a
positive integer. A malformed value fails the operation that resolved it.

### Password

The engine reads fd 3 exactly once, in step 5, into a local non-exported variable, then closes the descriptor.
It reaches the target only on stdin of `chpasswd`, run inside the chroot, through a pipe fed by the `printf`
builtin: `create_user` sends `<user>:<password>`; `configure_root_account` sends `root:<password>` only when the
plan's mode is `password`. The target's `shadow` hashes it with its default method; no hashing happens on the live
side. The value is never placed in argv, in an exported variable, in a file, in `engine.log`, in
`engine-run.json`, or in terminal output. `xtrace` is never enabled. The variable is unset after its last use or
when the engine ends. A password is never retried or re-read.

### Boot

**`ext4-systemd-boot` and `btrfs-rescue` (systemd-boot).** `install_bootloader` runs `bootctl install
--esp-path=/boot` inside the chroot and writes:

- `/boot/loader/loader.conf` with `default mirroros.conf`, `timeout` from the plan's `bootloader_options.timeout`,
  and `editor no` when `bootloader_options.editor` is `false` (`yes` otherwise).
- `/boot/loader/entries/mirroros.conf`: `title MirrorOS`, `linux /vmlinuz-linux`, `initrd /initramfs-linux.img`,
  and `options` set to the plan's `kernel_cmdline` with `<root>` replaced by the root UUID and, only when
  hibernation is enabled, `<resume_offset>` replaced by the resolved offset. For `btrfs-rescue` the options also
  carry `rootflags=subvol=@`. `zswap.enabled=0` is always present.
- When `bootloader_options.fallback_entry` is `true`, `/boot/loader/entries/mirroros-fallback.conf` with the title
  `MirrorOS (fallback initramfs)` and `initrd /initramfs-linux-fallback.img`, with the same options.

Check: the files exist with the expected content, no `resume=` or `resume_offset=` appears when hibernation is
disabled, and `bootctl status` inside the chroot reports the loader installed. The initramfs policy is the
distribution's default mkinitcpio hooks without UKI (`mkinitcpio-default-hooks-no-uki`).

### Limine (`btrfs-limine`)

The plan's order is `install_bootloader`, `install_limine_snapshot_tools`, `configure_snapper`,
`enable_services`, `create_baseline_snapshot`, `sync_limine_snapshot_entries`. Responsibilities are split as
follows, and no operation invokes a Limine or snapshot tool before `install_limine_snapshot_tools` installs it.

- **`install_bootloader`** writes only `/etc/default/limine`: `ESP_PATH="/boot"`, `SKIP_UEFI=yes` (the binary
  goes to the fallback path and no firmware entry is created), and `KERNEL_CMDLINE` set to the plan's
  `kernel_cmdline` (resolved as above) plus `rootflags=subvol=@`, written as the `KERNEL_CMDLINE[default]`
  array entry the tool reads. It deploys no EFI binary, runs no tool, and
  verifies only the content of that file.
- **`install_limine_snapshot_tools`** reads `/usr/local/lib/mirroros/packages/packages.json` of the running
  artifact and verifies the SHA-256 of every listed package file against it, before installing anything. A
  missing or invalid manifest, or a mismatching hash, ends the run `failed` with `engine_asset_mismatch`, exit
  `6`, without installing. It then writes `/etc/mkinitcpio.conf.d/10-mirroros-limine.conf` with
  `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems sd-btrfs-overlayfs fsck)`
  immediately before `pacman -U` of the verified packages inside the chroot with `SNAP_PAC_SKIP=y`. Their runtime
  dependencies come signed from the official repositories; signature verification is never disabled. The
  package transaction regenerates the initramfs, deploys the EFI binary to the fallback path, and writes the
  normal entries of the Limine configuration. The engine then verifies, and fails without trying any other
  mechanism when something is missing:
  - `/boot/EFI/BOOT/BOOTX64.EFI` exists and is not empty;
  - the Limine configuration `/boot/limine.conf` written by the tool contains a normal entry (above the
    `//Snapshots` line) whose `cmdline:` carries `root=UUID=<root>`, `rootflags=subvol=@`, `zswap.enabled=0`,
    and `resume=` and `resume_offset=` only when hibernation is enabled, and a global `timeout:` equal to the
    plan's `bootloader_options.timeout`;
  - the kernel and initramfs files that entry references (`path:` and `module_path:` lines of the form
    `boot():/<machine-id>/linux/...`) exist on the ESP;
  - no unified kernel image exists on the ESP.

  The `/boot/vmlinuz-linux` and `/boot/initramfs-linux.img` files that `pacstrap` leaves on the ESP are not
  referenced by the Limine entries and are neither verified nor removed.

  The engine never calls `limine-update`, never deploys the EFI binary itself, and never writes `limine.conf` by
  hand.
- **`configure_snapper`** and **`enable_services`** behave as for `btrfs-rescue` plus the service constant above.
- **`sync_limine_snapshot_entries`** runs `limine-snapper-sync` after the baseline and verifies at least one
  snapshot entry that points to the baseline snapshot, and that the files it references exist. The snapshot
  entries are written by the tool below the `//Snapshots` line, with `rootflags=subvol=/@snapshots/<N>/snapshot`
  and kernel and initramfs copies under `/boot/<machine-id>/limine_history/`. The service needs `inotifywait`
  (package `inotify-tools`, part of the option's `additional_packages`) to stay active.

The configuration path, the entry syntax, and the behavior described above were observed against the pinned
packages in a development check before this option was implemented.

#### Mapping of `bootloader_options`

| Option | systemd-boot | Limine |
| --- | --- | --- |
| `timeout` | `timeout` in `loader.conf`. | Applies through the tool's default (3 seconds): the engine verifies that the `timeout:` of the generated configuration equals the plan's value and fails the operation otherwise; it does not rewrite the file. |
| `editor` | `editor no` when `false`. | Does not apply: the pinned tools offer no supported key for it, so the Limine menu editor stays enabled. The engine records `not_applicable_to_limine`. |
| `fallback_entry` | A second entry using the fallback initramfs. | Does not apply as an extra entry: the fallback-path binary on the ESP and the snapshot entries are the recovery path of this option, and the pinned tools write no fallback-initramfs entry. The engine records `not_applicable_to_limine`. |

## Evidence and state

The engine writes only inside `--output` (the run's `engine/`), with `0700` directories and `0600` files:

| Path | Content |
| --- | --- |
| `engine.log` | Plain text, no ANSI sequences, no secret. Each operation starts with a `== <id> ==` header; the native stdout and stderr of every command follow, and each logged command line is its argv. Commands that receive the password on stdin are logged by name only. |
| `state.json` | Progress for the assistant; rewritten atomically after each change. |
| `engine-run.json` | The run record, written atomically at the end and on every terminal path. |
| `target-packages.txt` | The target's `pacman -Q` after `install_packages`. A description, not a pinning policy. |

Each JSON file is written to a temporary file in the same directory, re-read, validated, and renamed.

### `state.json`

| Field | Description |
| --- | --- |
| `format_version` | Always `1`. |
| `status` | `running`, `installed`, `failed`, `blocked`, or `invalidated`. |
| `current` | The `id` of the running operation; omitted when none is running. |
| `index` | One-based position of the current operation, or the number completed at the end. |
| `total` | Number of operations of the plan. |
| `operations` | In plan order: `id`, `description` (from the plan), and `status` (`pending`, `running`, `completed`, or `failed`). |
| `packages_installed` | Present only while `install_packages` runs: the count of installed packages. An informational count, never a fraction. |
| `updated_at` | RFC 3339 time of the last update. |

### `engine-run.json`

| Field | Description |
| --- | --- |
| `format_version` | Always `1`. |
| `started_at`, `finished_at` | RFC 3339 times. |
| `plan_digest` | The digest of the plan that was applied. |
| `code_identity` | `commit` and `dirty` of the running artifact. |
| `storage_option`, `hibernation` | From the plan. |
| `outcome` | `installed`, `blocked`, `invalidated`, or `failed`. |
| `exit_status` | The exit status of the engine. |
| `reasons` | Structured reasons as in [Reasons](#reasons); may be empty. |
| `completed`, `not_started` | Operation ids. |
| `failed_operation` | Present on failure: `id`, `command` (argv, non-secret), and `child_exit_status` (the original status). |
| `resolved` | Apply-time values: `partition_uuids` and, when hibernation is enabled, `resume_offset`. |
| `mirrors` | `servers` (the active `Server =` lines) and `mirrorlist_sha256`. |
| `constants` | The engine constants used, per kind. |
| `constants.install_limine_snapshot_tools.package.<name>` | `btrfs-limine` only: the `version` and `sha256` of each verified package. The AUR and upstream pins stay in the embedded `packages.json` and the artifact metadata. |
| `cleanup` | The cleanup actions taken and their results; present when cleanup ran. |

The record contains no secret and no value derived from one.

## Reasons

Every reason uses the architecture's structured error shape: `code`, `stage` (`engine`), `operation` (the
operation or pre-check step), `message`, `next_step`, and `child_exit_status` (only when a child exists).

| Code | Outcome and exit | Condition |
| --- | --- | --- |
| `install_already_running` | exit `2`, stderr only | Another process holds the installer lock. |
| `engine_version_mismatch` | `blocked`, `2` | The plan's code identity differs from the engine's own. `next_step`: generate a new plan with this artifact. |
| `digest_mismatch` | `invalidated`, `2` | The plan fails its digest or differs from `--digest`. |
| Validator codes | `blocked`, `2` | The plan fails `validate-plan.mjs` or the operation set and order rules; the code passes through, including unknown kinds. |
| `live_keyring_not_ready` | `blocked`, `2` | `pacman-init.service` is not active when the engine checks. |
| `password_unavailable` | `blocked`, `2` | fd 3 is missing, empty, multi-line, or invalid. |
| `target_identity_changed` | `invalidated`, `2` | The disk behind the plan's path no longer matches the confirmed identity. The password is discarded. |
| `target_layout_changed` | `invalidated`, `2` | The disk's layout or eligibility changed. The password is discarded. |
| `target_disk_in_use` | `blocked`, `2` | A partition is mounted or used as swap, or the disk has `lvm`, `crypt`, or `raid*` holders. |
| `engine_asset_mismatch` | `failed`, `6` | A configuration asset or a prebuilt package fails its hash, or the Limine manifest is missing or invalid. Nothing is written or installed from it. |
| `stage_failed` | `failed`, `5` | An operation failed or its immediate-effect check failed; `operation` names it and `child_exit_status` keeps the original status. |
| `engine_interrupted` | `failed`, `128+n` | A signal arrived during the engine. |

## Exit statuses

| Status | Meaning |
| --- | --- |
| `0` | `installed`: every operation of the plan completed with status `0` and its apply-time values were validated. This does not include the pre-restart postcondition suite owned by Story 2.6: the message states "Base system installed. Installation postconditions are not verified in this version (Story 2.6)." |
| `2` | `blocked` or `invalidated` before the first destructive operation, or an argument error. The disk is untouched. |
| `5` | An external tool failed unexpectedly. |
| `6` | Damaged code, embedded identity, configuration asset, or prebuilt package. |
| `128+n` | Termination by signal `n` during the engine. |

## Failure, interruption, and cleanup

The sequence is linear, so the first failing operation stops every later one. `engine-run.json` keeps the original
status, the failed operation, the child command, and the completed and not-started operations. Nothing hides or
overwrites the original failure.

When the failure happens after `wipe_disk_signatures` started, the user-facing message states that the disk was
partially modified and that installation did not complete. A failure before that point states that the disk is
untouched.

On a failure or a signal the engine runs best-effort, non-destructive cleanup: `swapoff` of an active swapfile
beneath the mount point and `umount -R` of the mount point. It never wipes again, never undoes changes, and never
touches a mount outside its own. A cleanup failure is recorded without masking the original error.

SIGINT, SIGTERM, and SIGHUP received by the engine run that cleanup and end the run `failed` with
`engine_interrupted` and the status `128+n`. The assistant starts the engine in its own process group, forwards
those signals to it during the engine phase, and waits for its cleanup.

There is no automatic retry and no resume from an operation. Retrying is a new run: `mirroros-install` cleans its
own leftovers, rediscovers the disk (which now shows the new layout), generates a new plan, and requires a new
confirmation and password.

## Out of scope

Pre-restart postcondition verification (Story 2.6), encryption, Secure Boot, unified kernel images, kernels other
than `linux`, an offline package repository, and a read-only factory snapshot are not part of the engine.
`SigLevel = Never` is not used anywhere.
