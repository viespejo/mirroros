# UEFI boot entry and boot-first contract

Governed by [ADR 0022](../docs/adr/0022-installer-coexistence-and-uefi-boot-entry.md).
This is a command/library contract, not a versioned data format. Implementation is owned by MirrorOS;
no external source or package is copied. Native integration uses the already selected `efibootmgr`
and util-linux tools; this task adds no package dependency.

## Installed command

`sudo mirroros-boot-first` explicitly restores the running installation's UEFI entry to first in
`BootOrder`. It has no target override or automatic service. `--help` is read-only and unprivileged.
Other arguments are rejected. The installed launcher is `/usr/local/bin/mirroros-boot-first`, linked
to `/usr/local/lib/mirroros/operations/boot-first`; its adjacent `lib/uefi-boot-entry.sh` is required.
Delivery by the installation engine is a separate integration step.

Before even reading NVRAM, the command requires root and checks:

- `/boot` is an actual vfat mount, not merely a directory on `/`.
- The running root is an ext4 or Btrfs Linux-filesystem GPT partition labelled `mirroros`; `/boot`
  is an ESP-type GPT partition on the same disk. Mapper, encrypted and non-partition roots are rejected.
- Root and ESP volume UUIDs are unique on that disk. The running root's `/etc/fstab` has exactly one
  UUID-bound `/` entry and exactly one UUID-bound `/boot` entry matching the mounted partitions.
- Exactly one supported boot configuration is present: `/boot/limine.conf` on Btrfs, or
  `/boot/loader/entries/mirroros.conf` on ext4 or Btrfs. Its native `cmdline:` or `options` records
  reference the running root's `root=UUID=`; conflicting root parameters are rejected. Comments and
  title strings do not establish a binding. Missing or conflicting configurations are rejected.
- The selected EFI loader binary exists and is nonempty; the ESP PARTUUID and partition number are valid.

No filesystem is mounted or written by this inspection. Invalid identity, missing configuration,
ambiguous volumes, or non-root execution returns nonzero without NVRAM changes.

| Bootloader | Created label | Accepted loader path |
| --- | --- | --- |
| Limine | `Limine MirrorOS` | `\EFI\BOOT\BOOTX64.EFI` |
| systemd-boot | `MirrorOS` | `\EFI\systemd\systemd-bootx64.efi` |

Neither label matches `^Omarchy([[:space:]]|$)`. The fallback file remains the installer's responsibility.

## Shared Bash library

`operations/lib/uefi-boot-entry.sh` does not execute operations when sourced or change shell options.
Callers validate privileges, device identity and authorization; the live engine must resolve the ESP
against the approved plan before calling. Functions return status explicitly and work under `set -Eeuo pipefail`.

- `uefi_read_entries`: snapshot `efibootmgr -v` into `UEFI_ORDER`, parallel arrays `UEFI_IDS`,
  `UEFI_GUIDS`, `UEFI_PATHS`. Non-GPT entries remain represented with empty GPT identity/path.
  Reject malformed/duplicate boot numbers or ambiguous, malformed, duplicate or dangling BootOrder.
  Missing or empty BootOrder means an empty order.
- `uefi_select_loader <limine|systemd-boot>`: set `UEFI_LABEL` and `UEFI_LOADER`.
- `uefi_find_entry <esp-partuuid> <loader-path>`: search the current snapshot, set `UEFI_MATCH`
  to the boot number or empty if missing. Compare full GPT PARTUUID and complete File device path,
  case-insensitively with slash normalization, not label or substring. Multiple matches return `2`.
- `uefi_ensure_first <disk> <esp-number> <esp-partuuid> <bootloader>`: read and validate before
  mutation; refuse duplicates without creating, reordering or deleting. Create missing entries with
  `--create-only`; verify creation did not change BootOrder. Prepend the matching entry to the prior
  BootOrder with its old occurrence removed, preserving every other's relative order. Do not add
  previously unordered unrelated entries to BootOrder. An already-first entry needs no write.
  Verify the final unique match, exact order and survival of every pre-existing boot number.
  Print before/after BootOrder; never delete entries.
- `uefi_remove_partuuids <pre-wipe-partuuid>...`: reserved for the whole-disk engine. Validate the
  entire argument set before mutation, then delete only entries whose GPT HD device-path PARTUUID
  exactly belongs to it. Loader path/label does not restrict stale cleanup. Keep all other boot
  numbers and their relative order, and verify removal and preservation. An empty set does nothing.
- `uefi_identify_running <boot-mount> <fstab>`: perform the read-only binding checks above; leave
  `UEFI_RUNNING_DISK`, `UEFI_RUNNING_PART`, `UEFI_RUNNING_GUID`, `UEFI_RUNNING_LOADER` for the command.
  Explicit file paths support isolated tests, not an installed-command target override.

No function clears NVRAM, invokes `--delete-bootorder`, or deletes duplicates. Cleanup is never
called by `boot-first`. A failure after a successful mutation is reported, not automatically retried
or rolled back; retain upstream diagnostics and inspect firmware state manually. Firmware writes
are not transactional, and simultaneous external firmware writers are outside this command's control.
Firmware or another OS may reorder BootOrder later (RISK-001); rerun the explicit command if needed.

## Outcomes and verification

- `0`: requested state verified.
- `2`: invalid input, ambiguous state or unmet precondition.
- `5`: `efibootmgr` failure; upstream stderr is preserved.
- `6`: missing library or observed postcondition/invariant failure.

The command normalizes identity-inspection failures to `2`. No persistent evidence directory is
created; stdout reports orders and stderr reports failures. Contract tests use an isolated stateful
`efibootmgr` double logging every invocation, plus mount/device doubles and relocated inspection
paths in a temporary command copy. They never write real firmware or block devices.

```sh
bats tests/operations/uefi-boot-entry.contract.bats tests/operations/boot-first.contract.bats
shellcheck operations/boot-first operations/lib/uefi-boot-entry.sh
```
