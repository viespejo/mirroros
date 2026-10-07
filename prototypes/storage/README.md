# Storage and recovery comparison (Story 2.1, Track 2)

Question: does the ext4/systemd-boot control with independent rescue media, Btrfs/Snapper with
rescue-based rollback, or Btrfs/Snapper with Limine snapshot boot entries best recover
reproducible damage on one shared reference-VM scenario, including hibernation?

This comparison is not itself a decision. The outcome is recorded at the maintainer checkpoint,
in an Accepted ADR 0003 or in the next-experiment note of this file. Until then the
ext4/systemd-boot baseline of [`docs/architecture.md`](../../docs/architecture.md) stays normative.

Prototypes:

- `control/`
- `btrfs-rescue/`
- [`btrfs-limine/`](btrfs-limine/README.md)

Shared harness: `lib/`, built on [`prototypes/installation/lib/`](../installation/lib/README.md).

Raw results: `evidence/prototypes/storage/<variant>/<run-id>/` (ignored).

## Variant matrix

| Variant | Layout | Compression | Snapshot policy | Boot loader | Recovery path |
| --- | --- | --- | --- | --- | --- |
| `control` | 1 GiB FAT32 ESP at `/boot`, ext4 root, `/swapfile` | none | none | systemd-boot | Independent rescue media (bundle A ISO) with a recovery script over NoCloud |
| `btrfs-rescue` | 1 GiB FAT32 ESP, one Btrfs filesystem with flat subvolumes `@`, `@home`, `@log`, `@pkg`, `@snapshots`, `@swap` | `compress=zstd:1`, `relatime` | Snapper root configuration for `@` only, snap-pac, no timeline | systemd-boot | Rescue-based rollback of `@` from a snapshot, from the bundle A ISO |
| `btrfs-limine` | Same as `btrfs-rescue` | Same as `btrfs-rescue` | Same as `btrfs-rescue` | Limine (unsigned) with snapshot entries | Attended selection of a snapshot entry over the serial console |

## Criteria

Provenance is one of `measured`, `observed manually`, or `source-reviewed`. Every cell states its
provenance and its evidence run-id (or source revision).

| Criterion | `control` | `btrfs-rescue` | `btrfs-limine` |
| --- | --- | --- | --- |
| D1 recovery (userspace damage inside `@`) | | | |
| D2 recovery (boot path damage on the ESP) | | | |
| Rescue-media need | | | |
| Diagnostics retention | | | |
| `/home` retention | | | |
| Hibernation | | | |
| Dependencies and provenance | | | |
| Maintenance cost | | | |
| ESP occupancy with several snapshots | | | |
| Architecture impact | | | |

## Secondary metrics

Reported as secondary metrics only. They do not rank the variants.

| Metric | `control` | `btrfs-rescue` | `btrfs-limine` |
| --- | --- | --- | --- |
| Space after installation (`compsize` or `df`) | | | |
| Installation duration | | | |

## Installer diff

`guest/install` is derived once from
[`native-arch/guest/install`](../installation/native-arch/guest/install). The common stages
(packages, localization, time, identity, network, accounts, system tweaks) stay identical. Storage,
boot, and snapshot stages route to variant files.

Reproduce the diff with `diff prototypes/installation/native-arch/guest/install
prototypes/storage/guest/install`. Its hunks are, in file order:

1. The header comment states the derivation.
2. The installer sources `support/storage-common.sh` and the variant's `stage.sh` from the NoCloud
   medium (two `shellcheck` directives accompany them).
3. `PACKAGES` appends `"${VARIANT_PACKAGES[@]}"`.
4. In `confirm_plan`, the three storage, swap, and boot plan lines become `variant_plan_lines`.
5. `install_storage` and `configure_swap_and_boot` leave the file and become
   `variant_install_storage` and `variant_configure_swap_and_boot` in each variant's `stage.sh`
   (the control's are the 02-01 functions moved without changes).
6. Two `shellcheck` directives mark `ESP_PARTITION` and `ROOT_PARTITION` as used by the stage files.
7. `main` calls the variant functions, then `mirroros_storage_install_support` and `variant_finalize`
   after the verification unit, so the `post-install baseline` snapshot holds the complete system.
8. Before `umount -R`, the installer stops the `gpg-agent` that `pacstrap` leaves running (`gpgconf
   --kill all` on the target keyring, then `pkill -x gpg-agent`). On the current Arch repositories the
   agent keeps `/mnt` busy, so the unmodified `native-arch/guest/install` fails at its last step in
   the unattended boot with exit status 32 (`umount: /mnt: target is busy`). Diagnosed with
   `fuser -vm /mnt` in a development run (`control`, `20261007T092852Z-1c084301`, observed in the
   guest serial log). The same failure occurs on a clean `HEAD`, so it is upstream drift and not a
   change of this plan. `native-arch` stays untouched (ADR 0002 pins it to `144eff7`).

Every other function (`run`, `put`, `set_password`, `install_base`, localization, time and identity,
system tweaks, and accounts) is identical to the original.

## Development validation (Task 5; not counted)

All runs below are development evidence at commit `7423b2e` with `dirty: true`, not counted
comparison runs. Full run IDs identify the ignored evidence directories under
`evidence/prototypes/storage/<variant>/` (or `installation/native-arch/` for the regression).

| Variant | Scenario | Run ID | Result |
| --- | --- | --- | --- |
| control | install | `20261007T093711Z-3e29508c-0d25-4274-8cd3-fe380716abd3` | passed |
| control | D1 | `20261007T094005Z-4bc493b7-43d5-4c20-82f3-31d906256851` | passed |
| control | D2 | `20261007T094632Z-f501f128-2c30-4a9b-8e81-5c1924e0badd` | passed |
| control | hibernate | `20261007T100722Z-7a5ca3c0-6807-4f8d-b20e-a2cacdaac8d4` | resumed |
| btrfs-rescue | install | `20261007T102453Z-4c3128ed-d2db-4dd0-8f42-f6adb218b1c0` | passed |
| btrfs-rescue | D1 | `20261007T102742Z-e0b65681-19a6-4c91-8ce1-6541c4714e1c` | passed |
| btrfs-rescue | D2 | `20261007T103427Z-f78a5e37-257a-40e1-bb74-fac8f4d2b84a` | passed |
| btrfs-rescue | hibernate | `20261007T104119Z-e8c80f33-06b7-4254-ac27-25a02e261ac7` | resumed |
| btrfs-limine | install | `20261007T125501Z-d50ca1df-ec10-455b-a4d3-e0c2cb201376` | passed; before final rootflags change |
| btrfs-limine | D1 | `20261007T150417Z-1de29de1-6daf-43a0-8c5f-f7b97b2fc0c9` | passed, including install and strict compression checks; snapshot 1 selected over serial |
| btrfs-limine | D2 | `20261007T151812Z-63163242-55d9-4dd6-b9a8-8f2058e8f798` | passed, including install and strict compression checks; snapshot 1 selected over serial |
| btrfs-limine | hibernate | `20261007T130323Z-04684774-9dfb-498a-bf86-a8750fcf2c53` | resumed; before final rootflags change |
| native-arch | attended install and disk verification | `20261007T153119Z-a40be836-f260-4040-aa1d-ba522cabdd8e` | 35 postconditions passed with default verification parameters |

The maintainer approved using an attended native-arch regression instead of the blocked unattended
path, without changing its installer. An in-memory host wrapper calls the original attended stages
and then `proto_stage_verify` before cleanup; no repository harness file is changed by the wrapper.
Installation exit 0 is recorded in the serial console (the attended result has no engine exit field).
The maintainer powered off the live guest to start disk verification. This verifies the default
postconditions but does not establish that the unattended installation failure has been resolved.

Development fixes include stopping the residual target gpg-agent before unmount, disabling the
Snapper timeline timer, detecting resume through the systemd-sleep journal, giving GraalVM a matching
PID namespace and `/proc`, adding the snapshot overlay hook and explicit entry sync, removing Limine
path verification hash suffixes before filesystem checks, targeting the active Limine initramfs for
D2, and retaining compression through rootflags. Earlier failures remain in the development evidence;
a snapshot-mode compression exception was removed rather than carried into the final checks.

The canary negative control passed (clean: 0, planted: 1). Redacted Gitleaks scans of `build/`,
storage evidence, and the attended regression evidence returned zero findings. Snapshot boot proves
a usable temporary overlay, not a persistent restore of `@`. Pending-image sessions and counted
runs remain later tasks; the final Limine rootflags configuration still needs a hibernation cycle.

## Evidence limits

To be recorded with the comparison: VM only, one run per case, attended observations, and any
`blocked_external` case.
