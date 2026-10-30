# Installation postconditions (`install/postconditions/check`)

`POSTCONDITIONS_FORMAT_VERSION: 1`. `install/postconditions/check` verifies, read-only, that the target
configuration written by the [installation engine](installation-engine.md) is complete and internally
consistent. It is invoked by the engine after the last operation of the approved
[installation plan](installation-plan.md) (format 5) and before the engine's terminal cleanup, while the target
is still mounted at `/run/mirroros/target`. It is an internal boundary like the engine: it is not a public
command and `operations/install` exposes no subcommand for it
([ADR 0008](../docs/adr/0008-installation-engine-execution-boundary.md)).

The suite checks **configuration**. The installed system has never booted at this point, so runtime state
(active zram, effective sysctl values, network connectivity, real hibernation and resume) is outside it: the
reference-VM qualification observes those after the first boot, and full readiness verification belongs to the
runtime `verify/` stage of Epic 5. A passing suite therefore means "the installed configuration is complete and
consistent", never "the system will boot and every capability works".

The checker is a Bash component (`install/postconditions/check`, `install/postconditions/lib/*.sh`) for native
inspection, with one Node ESM helper (`evaluate.mjs`) for structured comparison and the result document. It reuses
`install/plan/validate-plan.mjs` and `install/plan/digest-plan.mjs`; it has no second hashing implementation, no
`jq` dependency, and never opens `install/plan/policy.json`.

Conventions: JSON fields use `snake_case`; fields that do not apply are omitted. No secret value, hash of a
secret, or length hint appears in any output of the checker.

## Invocation

```text
install/postconditions/check --plan <file> --digest <hex> --target-root <dir> [--untouched-partitions-before <file>]
```

| Input | Description |
| --- | --- |
| `--plan <file>` | The approved `installation-plan.json` the engine applied. The checker validates it (format 5, digest recomputed and equal to `--digest`) before reading the target. |
| `--digest <hex>` | The confirmed digest. Integrity binding, not authorization. |
| `--target-root <dir>` | The mounted target root. The engine passes `/run/mirroros/target`. |
| `--untouched-partitions-before <file>` | Required evidence in replacement mode: the engine's `untouched-partitions-before.json`, captured before destruction. Missing, unreadable or invalid evidence fails `untouched_partitions`; whole-disk mode does not consume it. |

Standard input is `/dev/null`. An unknown option, a missing option, or an unreadable plan exits `2` on stderr. The
checker takes no password and no file descriptor other than the standard ones. The root UUID, partition devices,
ESP PARTUUID, UEFI entries and swapfile `resume_offset` are derived again from the target and live environment.
Replacement preservation compares fresh `sfdisk --dump` and `lsblk` observations against the engine's pre-run
record, not against the engine's after-record or its verification flag. The baseline contains the dump with
the two target partition lines excluded and normalized non-target partition identities (including geometry,
partition types, filesystem UUIDs and labels when available). This proves table/identity preservation, not
byte-for-byte preservation of partition contents.

The checker prints exactly one JSON document, the [result](#result), on stdout and writes nothing else. The engine
stores that document in `engine-run.json`; the checker writes no file.

## Read-only rule

The checker never modifies the target or the live system. In particular it does not:

- write, create, rename, delete, or change the mode, owner, or attributes of any file or directory, including
  temporary files beneath the target root;
- mount, unmount, remount, or change any mount option, enable or disable any service, run `mkinitcpio`,
  `pacman` in a mutating mode, `bootctl install`, `limine-update`, or any snapshot tool, or regenerate anything;
- open or report `/etc/shadow`, `/etc/gshadow`, any password hash, or any file that may hold a credential.

Allowed native queries are read-only by construction: file reads and `stat`; `findmnt`; `blkid -p` on a block
device; `pacman --root <target> -Q`; `systemctl --root=<target> is-enabled`; listing the early archive of an
initramfs with `lsinitcpio` (decompressing into a pipe, never to disk); `filefrag` and
`btrfs inspect-internal map-swapfile -r` on the swapfile; `lsattr`; `efibootmgr -v`;
`sfdisk --dump`; `lsblk --json --tree --bytes` with explicit columns; and `readlink` of the installed launcher.
No UEFI mutation or partition-table write is allowed. When the target's own tool must run, it runs
under `arch-chroot` only for such a query and only when no `--root` form exists. A test with read-only doubles
asserts that no mutating command is ever invoked and that the target tree is byte-identical before and after.

## Checks

Every check has a stable `id`. All applicable checks run on every invocation, in the order below, even after a
failure: a check whose input cannot be read fails with that fact in its `detail`; no check is skipped and none is
retried. A check that does not apply to the plan (for example swapfile checks without hibernation) is absent from
the result rather than reported as passed, except where the table states that its absence is itself verified.

| Id | Applies to | Passes when |
| --- | --- | --- |
| `kernel_installed` | all | `/boot/vmlinuz-linux` and `/boot/initramfs-linux.img` exist, are regular files, and are not empty; with `ext4-systemd-boot` or `btrfs-rescue` and `bootloader_options.fallback_entry` `true`, `/boot/initramfs-linux-fallback.img` also exists and is not empty. The package `linux` is installed in the target database. |
| `mounts_active` | all | Every mount the plan's `mount_target` lists is present beneath the target root with the planned source filesystem type; for Btrfs the planned subvolume and `mount_options` (`@`, `@home`, `@log`, `@pkg`, `@snapshots`, and `@swap` only with hibernation); the ESP is mounted at `/boot` with `umask=0077`, accepting VFAT's equivalent effective options `fmask=0077,dmask=0077`; missing or incorrect effective masks and contradictory mask options fail the check. |
| `fstab_by_uuid` | all | `/etc/fstab` lists the root, the ESP, and every planned mount by `UUID=`; the UUIDs equal the ones read from the devices; no `subvolid=` appears; with hibernation exactly one swap line exists, for the swapfile with `pri=0`; without hibernation no swap line exists. |
| `bootloader_systemd_boot` | `ext4-systemd-boot`, `btrfs-rescue` | `/boot/loader/loader.conf` holds `default mirroros.conf`, the planned `timeout`, and `editor no` when `editor` is `false`; `/boot/loader/entries/mirroros.conf` holds `title MirrorOS`, `linux /vmlinuz-linux`, `initrd /initramfs-linux.img`, and an `options` line equal to the plan's resolved `kernel_cmdline` (plus `rootflags=subvol=@` for `btrfs-rescue`); the fallback entry exists with the fallback initramfs exactly when `fallback_entry` is `true`; `/boot/EFI/systemd/systemd-bootx64.efi` and `/boot/EFI/BOOT/BOOTX64.EFI` exist and are not empty. |
| `bootloader_limine` | `btrfs-limine` | `/etc/default/limine` holds `ESP_PATH="/boot"`, `SKIP_UEFI=yes`, and the resolved `KERNEL_CMDLINE[default]`; `/boot/EFI/BOOT/BOOTX64.EFI` exists and is not empty; `/boot/limine.conf` has a global `timeout:` equal to the planned `timeout` and a normal entry above `//Snapshots` whose `cmdline:` equals the plan's resolved command line plus `rootflags=subvol=@`; the kernel and initramfs files that entry references exist on the ESP; no unified kernel image exists on the ESP; at least one snapshot entry exists below `//Snapshots`. |
| `uefi_boot_entry` | all | Exactly one UEFI entry matches the independently observed ESP PARTUUID and the selected loader path from `register_uefi_boot_entry`; its boot number is first in a valid `BootOrder`. Matching is case-insensitive and restricted to the device path, not the description. Missing or unreadable entries, duplicate matches, malformed ordering and a replacement ESP PARTUUID differing from the approved target fail the check. |
| `boot_first_delivered` | all | `/usr/local/bin/mirroros-boot-first` is the exact symbolic link to `/usr/local/lib/mirroros/operations/boot-first`; that command and `operations/lib/uefi-boot-entry.sh` beneath the same MirrorOS library directory are regular, nonempty, non-symlink files with modes `0755` and `0644`, respectively. Absolute launcher links are inspected without resolving them in the live root. |
| `untouched_partitions` | replacement only | Fresh filtered partition-table lines and normalized non-target partition identities equal the engine's pre-run record. Missing, unreadable or invalid evidence fails; the check is absent in whole-disk mode. |
| `boot_root_uuid` | all | The `root=UUID=` value of every normal boot entry (`systemd-boot` entries, or the Limine normal entry) equals the UUID that `blkid -p` reads from the device mounted at the target root. |
| `boot_zswap_disabled` | all | `zswap.enabled=0` is present in the command line of every normal boot entry. |
| `boot_resume_parameters` | all | With hibernation: every normal boot entry carries `resume=UUID=<root UUID>` and `resume_offset=<n>`, and `<n>` equals the offset computed again from the swapfile (`filefrag` for ext4, `btrfs inspect-internal map-swapfile -r` for Btrfs). Without hibernation: no boot entry, snapshot entry, or `/etc/default/limine` carries `resume=` or `resume_offset=`. |
| `swapfile` | hibernation enabled | The swapfile exists (`/swapfile` for ext4; `/swap/swapfile` in `@swap` for Btrfs), is a regular file with mode `0600` and size `swapfile_size` MiB, and, for Btrfs, carries the NOCOW attribute and lies on the `@swap` subvolume; `resume_offset` is a positive integer. |
| `swap_absent` | hibernation disabled | No swapfile exists beneath the target root, no `@swap` subvolume is mounted, and no swap entry is present in `/etc/fstab`. |
| `zram_configuration` | all | `zram-generator` is installed in the target database; the plan's zram `destination` exists and its SHA-256 equals `source_sha256`; the file contains the planned `zram-size`, `compression-algorithm`, and `swap-priority`. |
| `memory_sysctl_configuration` | all | The plan's memory-reclaim `destination` exists, its SHA-256 equals `source_sha256`, and it contains the four planned `vm.*` values. |
| `network_manager_enabled` | all | `networkmanager` is installed in the target database and `systemctl --root=<target> is-enabled NetworkManager.service` reports enabled; `/etc/NetworkManager/system-connections` holds no predefined connection; `/etc/hostname` holds the planned hostname. |
| `microcode_selection` | all | The set of microcode packages installed in the target equals the plan's rule packages that are microcode packages (`amd-ucode` or `intel-ucode`, or none). When one is planned, the early archive of `/boot/initramfs-linux.img` contains `kernel/x86/microcode/AuthenticAMD.bin` or `kernel/x86/microcode/GenuineIntel.bin` accordingly, and the fallback initramfs too when it exists. When none is planned, the early archive contains no microcode image. |

The Limine check also covers the Limine snapshot entries as written by the engine; the baseline-snapshot and
Snapper checks stay with the engine's immediate-effect checks and are not repeated here.

The checker runs before configure, so these checks compare the base boot configuration exactly with the plan. The
boot-splash overlay that configure adds afterwards (`quiet` and `splash`, the `plymouth` hook drop-in and the
regenerated images) is verified by configure's own postconditions, not here, and no check above accepts additional
command-line tokens ([engine, configure phase](installation-engine.md#configure-phase)).

### Cross-component consistency

Several checks compare two components rather than one file with the plan, because each can be internally valid
while the installation is unusable:

- the root UUID in the boot entries against the UUID of the mounted root filesystem and against `/etc/fstab`
  (`boot_root_uuid`, `fstab_by_uuid`);
- the `resume_offset` in the boot entries against the offset recomputed from the actual swapfile
  (`boot_resume_parameters`);
- the `resume=` UUID against the root UUID (`boot_resume_parameters`);
- the planned microcode package against the content of the generated initramfs (`microcode_selection`);
- the hibernation state of the plan against the presence of the swapfile, the `@swap` mount, the swap line in
  `/etc/fstab`, and the resume parameters (`swapfile`, `swap_absent`, `fstab_by_uuid`, `boot_resume_parameters`).

The checker never repairs a mismatch and never assumes which side is correct: it reports both observed values.

## Result

One JSON document with these fields:

| Field | Description |
| --- | --- |
| `format_version` | Always `1`. |
| `status` | `passed` when every check passed, `failed` otherwise. |
| `checks` | The applicable checks in the declared order. |
| `failed_checks` | The ids of the failed checks, in order; empty when `status` is `passed`. |

Each entry of `checks`:

| Field | Description |
| --- | --- |
| `id` | The check id above. |
| `status` | `passed` or `failed`. |
| `detail` | Present only when `status` is `failed`: one line of non-secret text stating what was expected and what was observed, within the limits below. |

The validator `install/postconditions/evaluate.mjs` rejects unknown fields, an unknown check id, a `detail` on a
passed check, a `status` that disagrees with `failed_checks`, and a document in which a check that applies to the
plan is missing.

### Non-secret detail

`detail` is diagnostic text for the maintainer and is shown on screen. It may contain: a path relative to the
target root, a check-specific expected and observed value of a non-secret kind (a UUID, a kernel command-line
fragment, a `resume_offset`, a file size or mode, a SHA-256 of a project-owned asset, a package name, a boolean),
and a short cause. It never contains the content of `shadow`-class files, a password, a hash or length derived
from one, an environment dump, or a Wi-Fi credential. A boot command line is allowed because MirrorOS builds it
from the plan and it holds no secret. A `detail` is a single line of at most 512 characters; longer text is cut
with a trailing `...`. The terminal presentation wraps it to the terminal width (see
[`installation-confirmation.md`](installation-confirmation.md)); the stored text has no embedded line breaks.

## Exit statuses

| Status | Meaning |
| --- | --- |
| `0` | `status` `passed`: every applicable check passed. |
| `2` | Argument error, unreadable or invalid plan, or digest mismatch. Nothing was inspected. |
| `4` | `status` `failed`: at least one check failed. The result document is on stdout. |
| `6` | Damaged checker code, or a result document that fails its own validator. |

The engine maps `0` to `installed`/`0`, `4` to `not_verified`/`4`, and any other status to `failed`/`5` with the
reason `stage_failed`, operation `postconditions`, and the checker's status in `child_exit_status`. See
[`installation-engine.md`](installation-engine.md#postconditions).

## Out of scope

Runtime readiness, first-boot observation, network connectivity, hibernation and resume behavior, graphics
behavior, Snapper or snapshot content beyond the Limine entries, package-set pinning, any repair or retry, and the
configure-owned boot-splash overlay.
Reuse of this component by the runtime verification stage of Epic 5 is intended, but its runtime checks are not
defined here.
