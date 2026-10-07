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

## Counted runs

All counted runs use commit `331155d7fee84c0d19ab7c87523a925ea4b80231` (commit 1) with `dirty: false`.
Cells below cite the short run-id (timestamp and first UUID group); the full run-id names the ignored
evidence directory `evidence/prototypes/storage/<variant>/<run-id>/`.

| Variant | Scenario | Short run-id | Full run-id |
| --- | --- | --- | --- |
| control | D1 | `20261007T155452Z-9db16ef8` | `20261007T155452Z-9db16ef8-cc56-42fa-b006-1cdefbcdef66` |
| control | D2 | `20261007T160124Z-46c3c2c4` | `20261007T160124Z-46c3c2c4-6c4e-4462-943b-b42edbad5ca3` |
| control | hibernation cycle | `20261007T160807Z-068dd7f5` | `20261007T160807Z-068dd7f5-afb5-4396-aeac-0cd6c3044796` |
| control | pending image (attended) | `20261007T191629Z-ee1b3c98` | `20261007T191629Z-ee1b3c98-3f23-4ac4-a7aa-cf728db73dc8` |
| btrfs-rescue | D1 | `20261007T161057Z-99b85d90` | `20261007T161057Z-99b85d90-36ed-4259-9d68-c302aea9ef0c` |
| btrfs-rescue | D2 | `20261007T161735Z-5e1e7a85` | `20261007T161735Z-5e1e7a85-f50f-42dc-ad86-68f83455b3bc` |
| btrfs-rescue | hibernation cycle | `20261007T162419Z-696e5e5a` | `20261007T162419Z-696e5e5a-d272-4f41-9fd6-bdb7e96973ba` |
| btrfs-rescue | pending image (attended) | `20261007T193917Z-792f4175` | `20261007T193917Z-792f4175-c0ee-4238-9112-b42c8e9088db` |
| btrfs-limine | D1 | `20261007T181105Z-1b4408a0` | `20261007T181105Z-1b4408a0-c952-4aa3-879a-f304e4ca0744` |
| btrfs-limine | D2 | `20261007T183708Z-0ddfe7ea` | `20261007T183708Z-0ddfe7ea-271e-431d-bf84-3bef7b14ee2f` |
| btrfs-limine | hibernation cycle | `20261007T162711Z-d0a9bcc1` | `20261007T162711Z-d0a9bcc1-130a-4e5e-a7d4-0a2bf1e245d2` |
| btrfs-limine | pending image (attended) | `20261007T195628Z-e239b0d8` | `20261007T195628Z-e239b0d8-cd3a-4a9b-8745-f6120c7ba260` |

The development runs listed above are not counted and are not cited in the criteria table.

## Criteria

Provenance is one of `measured`, `observed manually`, or `source-reviewed`. Every cell states its
provenance and its evidence run-id (or source revision). Run-ids are the short ids of the table above.

| Criterion | `control` | `btrfs-rescue` | `btrfs-limine` |
| --- | --- | --- | --- |
| D1 recovery (userspace damage inside `@`) | Recovered. Failure confirmed (no report within the 180 s deadline); rescue boot 49 s, script 0 s, 3 steps (`pacman --root /mnt -Rns`); verifying boot passed. Measured, `…155452Z-9db16ef8`. | Recovered. Failure confirmed; rescue boot 49 s, script 1 s, 4 steps (restore `@` from the baseline snapshot, keep damaged `@`); verifying boot passed. Measured, `…161057Z-99b85d90`. | Recovered by selecting a snapshot entry; failure confirmed; attended session 350 s (includes human time); verifying boot passed. Observed manually, `…181105Z-1b4408a0`. The snapshot boot is a temporary overlay, not a persistent restore of `@`. |
| D2 recovery (boot path damage on the ESP) | Recovered. Failure confirmed; rescue boot 53 s, script 4 s, 3 steps (`mkinitcpio -P` in a chroot); verifying boot passed. Measured, `…160124Z-46c3c2c4`. | Recovered. Failure confirmed; rescue boot 54 s, script 4 s, 5 steps (restore `@`, then regenerate the initramfs, because the ESP is outside every snapshot); verifying boot passed. Measured, `…161735Z-5e1e7a85`. | Recovered by selecting a snapshot entry (its own kernel and initramfs copies on the ESP); failure confirmed; attended session 116 s; verifying boot passed. Observed manually, `…183708Z-0ddfe7ea`. The damaged initramfs of the live entry is not repaired. |
| Rescue-media need | Needed for D1 and D2. Measured, `…155452Z-9db16ef8`, `…160124Z-46c3c2c4`. | Needed for D1 and D2. Measured, `…161057Z-99b85d90`, `…161735Z-5e1e7a85`. | Not needed for D1 and D2 (bootloader menu only). Observed manually, `…181105Z-1b4408a0`, `…183708Z-0ddfe7ea`. |
| Diagnostics retention | D1: kept (persistent journal holds the failed boot). D2: not observable, the kernel never reached userspace. Measured, `…155452Z-9db16ef8`, `…160124Z-46c3c2c4`. | Same as `control` (`@log`). Measured, `…161057Z-99b85d90`, `…161735Z-5e1e7a85`. | Same as `control` (`@log`). Observed manually, `…181105Z-1b4408a0`, `…183708Z-0ddfe7ea`. |
| `/home` retention | Marker survived D1 and D2. Measured, `…155452Z-9db16ef8`, `…160124Z-46c3c2c4`. | Marker survived D1 and D2 (`@home` is outside the restore). Measured, `…161057Z-99b85d90`, `…161735Z-5e1e7a85`. | Marker survived D1 and D2. Observed manually, `…181105Z-1b4408a0`, `…183708Z-0ddfe7ea`. |
| Hibernation | Configuration postcondition passed; one real cycle resumed. Pending image: after the rescue session the disk boot was a normal boot, with no resume (`not_hibernated` after 180 s). Measured, `…160807Z-068dd7f5`; observed manually, `…191629Z-ee1b3c98`. | Same pattern; the session also restored `@` from the baseline before the disk boot. Measured, `…162419Z-696e5e5a`; observed manually, `…193917Z-792f4175`. | Cycle resumed. Pending image: the session shows no rescue script and a mount listing only; the disk boot was a normal boot, with no resume. Measured, `…162711Z-d0a9bcc1`; observed manually, `…195628Z-e239b0d8`. See [Evidence limits](#evidence-limits). |
| Dependencies and provenance | Official repositories only. Source-reviewed, [`control/stage.sh`](control/stage.sh). | Adds `btrfs-progs`, `snapper`, `snap-pac`, `compsize` (official repositories). Source-reviewed, [`btrfs-rescue/stage.sh`](btrfs-rescue/stage.sh). | Adds `limine` and official dependencies, plus two AUR packages (single maintainer) pinned by AUR and upstream commits, built with Gradle and GraalVM `native-image` over the network; Maven Central dependencies pinned by version only; `base-devel` and `git` present. Source-reviewed, [`btrfs-limine/README.md`](btrfs-limine/README.md#limine-snapshot-tooling-provenance-review) (review date 2026-10-07). |
| Maintenance cost | 150 variant lines (`stage.sh` 72, `recover` 59, `run` 19). Measured by `wc -l`, commit `331155d`. | 162 variant lines (`stage.sh` 50, `recover` 93, `run` 19) plus the 100-line shared Btrfs stage. Measured by `wc -l`, commit `331155d`. | 135 variant lines (`stage.sh` 81, `aur-build.sh` 35, `run` 19) plus the 100-line shared Btrfs stage; no recovery script, but a two-package AUR pin to maintain. Measured by `wc -l`, commit `331155d`. |
| ESP occupancy with several snapshots | Not measured. Snapshots do not exist in this variant. | Not measured. Snapshots stay in `@snapshots`, not on the ESP (design, source-reviewed). | Not measured. The tools copy a kernel and initramfs per snapshot entry to the ESP and stop at `LIMIT_USAGE_PERCENT=85` (source-reviewed, [`btrfs-limine/README.md`](btrfs-limine/README.md)). Snapper held 2 snapshots before and 4 after damage in `…181105Z-1b4408a0` (measured), but the entry count and ESP usage were not collected. |
| Architecture impact | None: this is the current baseline. Source-reviewed, [`docs/architecture.md`](../../docs/architecture.md). | Would amend the ext4 and systemd-boot statements and `docs/epics.md` lines 164 and 519; adds Snapper and a rescue recovery script to later recovery work. Source-reviewed. | Same amendments as `btrfs-rescue`, plus a Limine boot loader and an AUR build path routed through Story 3.2. Source-reviewed. |

## Secondary metrics

Reported as secondary metrics only. They do not rank the variants.

| Metric | `control` | `btrfs-rescue` | `btrfs-limine` |
| --- | --- | --- | --- |
| Space after installation (`compsize` or `df`) | Not measured | Not measured | Not measured |
| Pacman installed size of the install transaction (not the space metric above) | 1291.15 MiB (measured, `…155452Z-9db16ef8`) | 1427.08 MiB (measured, `…161057Z-99b85d90`) | 1917.10 MiB, plus a 766.98 MiB build-dependency transaction (`jdk-openjdk`, `gradle`, …) (measured, `…181105Z-1b4408a0`) |
| Installation duration (counted runs) | 116–136 s (measured, four runs above) | 133–142 s (measured, four runs above) | 441–484 s (measured, four runs above) |

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

## DEC-007 working hypothesis

The hypothesis was: the control repairs both damages from rescue media, Btrfs with rescue rolls back
D1 but still regenerates the initramfs for D2, and Limine recovers both by booting the previous
snapshot. The counted runs are consistent with it, within the limits below:

- `control` recovered D1 and D2 from rescue media (3 steps each).
- `btrfs-rescue` recovered D1 by rollback (4 steps) and needed an extra initramfs regeneration for D2
  (5 steps).
- `btrfs-limine` booted a snapshot entry for both damages without rescue media. That boot is a
  temporary overlay; the damaged live entry and a persistent restore of `@` were not exercised.

## Evidence limits

- VM only (the reference VM); no target-laptop claim, in particular none about laptop hibernation.
- One counted run per case. No case was repeated; none showed an unexpected or inconsistent result.
- `btrfs-limine` D1 and D2 recoveries are attended observations; their session durations include
  human time and are not comparable with the automated rescue boots.
- Failure confirmation is a 180 s deadline without a completion report, not a captured failure
  signature.
- Real hibernation cycles are confirmed by the systemd-sleep journal message; the kernel's
  `Image restored successfully` line was not observed (`kernel_image_restored: false` in all three).
- Pending-image sessions: the harness records that the disk boot afterwards was a normal boot with no
  resume (`not_hibernated`) in all three variants. It does not record whether the image was
  discarded, why, or what a snapshot selection in Limine did; the maintainer's observations beyond
  the serial logs are not in the evidence.
- Not measured: `compsize` or `df` space after installation, and ESP occupancy with several
  snapshots. The harness does not collect them.
- No case was `blocked_external` and no variant was unsupported.

Follow-up, not part of this comparison:

- ESP occupancy with several snapshots and the ESP size stay unmeasured. A larger ESP for
  `btrfs-limine` (for example 4 GiB) is a hypothesis to evaluate in a later experiment; it changes the
  1 GiB FAT32 ESP of the shared scenario and therefore requires an ADR.
- Recovery with a pending hibernation image needs a stricter session (confirm the image exists, record
  the kernel messages of the next boot) and, for the target laptop, its own validation.
