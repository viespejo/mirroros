# ADR 0009: Storage Option Promotion and ESP Size

## Identifier and title

- **Identifier:** `0009`
- **Title:** Storage Option Promotion and ESP Size

## Status

`Accepted`

## Date

`2026-10-12`

## Context and question

[ADR 0003](0003-storage-and-recovery-baseline.md) offers three storage and boot options with support tiers:
`ext4-systemd-boot` as default and normative, `btrfs-rescue` as supported, and `btrfs-limine` as experimental
with no support commitment until four conditions are met. It also fixes the ESP at 1 GiB, and any change to it
requires an ADR.

Story 2.5 installs all three options for the first time. The maintainer expects `btrfs-limine` to be the option
used in their own installations, because it recovers `@` from a snapshot entry in the bootloader menu without
rescue media, and wants the experimental label and the ESP question settled in this story rather than carried
forward. The questions are:

1. Which tier does each option have after Story 2.5, and which is the default?
2. What ESP size applies, and how is it decided without the measurement ADR 0003 asked for?
3. How are ADR 0003's four promotion conditions closed?

## Constraints and decision criteria

- The root filesystem remains unencrypted; no Secure Boot, qgroups, `compress-force`, `noatime`, timeline
  snapshots, or `@home` snapshots (ADR 0003 constraints still stand).
- Every external package is pinned and reviewed; the architecture treats AUR packages as explicitly reviewed
  external sources.
- Promotion must not claim more than the evidence supports; accepted risks are written down, not hidden.
- Policy changes are limited to values: the installation plan format stays `3`.
- The 20 GiB minimum disk requirement and the layout-fit validation remain in force.
- The decision must be consistent with the Omarchy 4.0.4 observations recorded in DEC-015 only as patterns; no
  code is copied.

## Alternatives considered

1. **Keep ADR 0003 tiers and add only the engine.** `btrfs-limine` stays experimental and ext4 stays default.
   Rejected by the maintainer: the maintainer's preferred option would remain labelled unsupported.
2. **Promote `btrfs-limine` after measuring ESP occupancy and validating every ADR 0003 condition first.**
   Strongest evidence, but delays the engine story on measurements whose failure mode is mild (see Evidence).
3. **Limine as the only option, as Omarchy offers.** Rejected: it removes the supported ext4 and rescue paths
   that ADR 0003 deliberately keeps.
4. **Promote `btrfs-limine` to default, keep the others as supported, 2 GiB ESP for all options (chosen).**
5. **Keep the 1 GiB ESP.** The prototype reached four snapshot entries on 1 GiB. Rejected: it limits snapshot
   history for the preferred option and a larger value costs little on the disk sizes in scope.
6. **A 4 GiB ESP.** A maintainer recollection that could not be verified. Not adopted without evidence.

## Evidence

- ADR 0003's evidence: the three prototypes recovered both damages (D1 userspace in `@`, D2 boot path on the
  ESP), with `btrfs-limine` recovering by selecting a snapshot entry and no rescue media; hibernation cycles
  resumed in every variant. See [`prototypes/storage/README.md`](../../prototypes/storage/README.md).
- The prototype produced four snapshot entries on a 1 GiB ESP. `limine-snapper-sync` stops adding entries at 85%
  ESP usage and prunes older ones, so an undersized ESP yields fewer entries rather than a broken system.
- Omarchy 4.0.4 uses a 2 GiB ESP without published measurement, offers only Limine with Btrfs and Snapper,
  builds UKIs, disables Btrfs quotas, keeps a read-only `@factory` snapshot, and encrypts by default
  (observations only, from DEC-015).
- Limits: ESP occupancy was not measured; the ESP size is decided by reasoning, not measurement. One reference
  VM; nothing about the target laptop.

## Decision

### Tiers and default

`btrfs-limine` becomes the default storage option (tier `default`). `ext4-systemd-boot` and `btrfs-rescue`
become tier `supported` and remain selectable. This supersedes ADR 0003's tier classification: ext4 is no longer
the default and normative option, and the Limine option is no longer experimental. The `storage_option_experimental`
warning no longer applies to any option.

### ESP size

The ESP is 2 GiB for all options, FAT32, mounted at `/boot`. The value is decided by reasoning: it matches the
reference model's choice, and `limine-snapper-sync` limits its own use of the ESP and prunes entries, so the
failure mode of a too-small ESP is fewer snapshot entries. It is a single `esp.size_bytes` policy value; the
generator does not change. This supersedes ADR 0003's 1 GiB ESP constraint.

The 20 GiB minimum disk stays. A hibernation-enabled layout needs a 2 GiB ESP, a 15 GiB root minimum, and a
RAM-sized swapfile; on a small disk with much memory the existing layout-fit validation can reject the plan
(`plan_size_does_not_fit`). The size is never silently reduced and hibernation is never silently disabled.

### ADR 0003's promotion conditions

| Condition | Resolution |
| --- | --- |
| ESP occupancy measured and size decided | Closed by this decision: 2 GiB by reasoning, no measurement. |
| Persistent restore of `@` from a snapshot entry | Validated once in the attended qualification of plan 02-09 on the installed default VM. |
| Recovery with a pending hibernation image | Accepted, documented risk: do not boot a snapshot while a hibernation image is pending. Not validated. |
| AUR dependencies pinned and reviewed, including Gradle versions | Accepted limitation referred to Story 3.2: the tools are pinned by AUR and upstream commits and prebuilt in the artifact (see [ADR 0008](0008-installation-engine-execution-boundary.md)), but Gradle dependencies remain pinned by version only. |

### Not adopted

- **UKI.** The initramfs policy stays `mkinitcpio-default-hooks-no-uki`. The prototype validated Limine without
  UKI, a UKI brings no benefit without Secure Boot, and UKIs enlarge every per-snapshot copy on the ESP.
- **LUKS.** The architecture and Story 2.5 require an unencrypted root.
- **Limine as the only option.** All three options stay.
- **`@factory` snapshot.** A read-only factory-reset snapshot is new scope, recorded as a follow-up for Epic 5/6.

### Counted qualification

Counted qualification must cover `btrfs-limine` as the default path, with and without hibernation, plus
`ext4-systemd-boot` and `btrfs-rescue`, as defined by plan 02-09.

## Consequences and trade-offs

- The architecture's normative ext4 and systemd-boot baseline statement changes: the default is Btrfs with
  Snapper and Limine, and the other options are supported alternatives. This needs the architecture, PRD, and
  epics amendments listed in plan 02-09.
- Recovery documentation and qualification follow the default option first.
- The default option depends on two single-maintainer AUR packages (prebuilt and pinned) and on `limine`. Their
  update path after installation falls to Story 3.2.
- A 2 GiB ESP reduces the space left for root and swapfile on the smallest disks.
- Booting a Limine snapshot entry while a hibernation image is pending can discard or corrupt state; the risk is
  documented, not mitigated.
- No claim is made about the target laptop.

## Replacement or reversal boundary

Revisit this decision if any of the following occurs:

- The persistent restore of `@` fails or cannot be made reliable.
- The pinned Limine tools cannot be rebuilt, become unmaintained, or require the CachyOS repository or
  Chaotic-AUR.
- Measured ESP occupancy shows that 2 GiB does not hold a useful snapshot history for the default option.
- A pending hibernation image is shown to cause data loss in normal use of snapshot entries.
- Evidence from the target laptop contradicts the VM results.
- Maintaining three options costs more than the maintainer accepts.

## Required validation

- Before adoption: the maintainer reviews this ADR with the amended architecture, PRD, epics, and plan contract
  statements.
- After adoption: automated tests cover the new default, tiers, and ESP size; counted VM qualification installs
  and boots `btrfs-limine` with and without hibernation, `ext4-systemd-boot` with hibernation, and
  `btrfs-rescue` without hibernation.
- One attended persistent restore of `@` from a Limine snapshot entry and one hibernate and resume cycle on the
  default path are recorded as observations.

## References

- [Architecture](../architecture.md)
- [ADR 0003](0003-storage-and-recovery-baseline.md)
- [ADR 0007](0007-zram-and-hibernation-policy.md)
- [ADR 0008](0008-installation-engine-execution-boundary.md)
- [Storage and recovery comparison](../../prototypes/storage/README.md)
- [Installation plan contract](../../contracts/installation-plan.md)
- [Story 2.5 interview plan](../technical-interviews/story-2-5-base-system-install_plan.md) and [log](../technical-interviews/story-2-5-base-system-install_log.md)

## Superseded by

`None`
