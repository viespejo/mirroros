# Native Arch prototype

Story 2.1, Track 1. Non-production: production never imports or sources this directory.

## Question

How much MirrorOS-owned code does it take to reproduce the shared installation scenario with plain
Arch commands (`sfdisk`, `pacstrap`, `genfstab`, `arch-chroot`, `bootctl`, `chpasswd`), following the
Arch Installation Guide?

## Scenario

The scenario and its classification are in the matrix of [`../README.md`](../README.md). The postconditions
are checked on the second boot by the shared verification unit (see [`../lib/README.md`](../lib/README.md)).
The guest script is [`guest/install`](guest/install); [`run`](run) only selects it for the shared harness.

Technical choices that go beyond a literal reading of the scenario:

- The ESP is mounted with `umask=0077`, so `bootctl status` does not warn that the random seed is
  world accessible.
- `loader.conf` sets `default arch.conf` in addition to `timeout 3` and `editor no`, so the default
  entry is deterministic.
- `MIRROROS_OMIT_ROOT_PASSWORD=1` skips the root password and leaves root locked. It exists only to
  check the omitted-root-password case at contract level; the harness always delivers both credentials.

## Usage

```bash
prototypes/installation/native-arch/run [--variant normal|unreachable-mirrors] BUNDLE_DIRECTORY
prototypes/installation/native-arch/run --attended BUNDLE_DIRECTORY
```

The default mode is the prototype-only unattended two-boot run. `--attended` runs boot 1 only, on the
serial console, with a minimal typed confirmation (no digest binding).

## Attended checklist

Run on a disposable disk over the serial console, together with the user. Record every observation as
"observed manually" with its run-id.

1. Plan visibility: before the confirmation, is the plan shown (disk, partitions, packages, steps)?
2. Editability: can the plan be changed before confirmation, or only cancelled?
3. Confirmation: which input confirms, and what does any other input do?
4. Rejection: answer anything but `install`. Record the exit status and confirm that the disk has no
   partition table (`sfdisk -d` and `wipefs` on the target).
5. SIGINT: confirm, then press Ctrl-C during `pacstrap`. Record the exit status, the diagnostics left
   on the console, and the partial disk state (partitions, mounts, files under `/mnt`).

## Result

All runs were made at commit `144eff7` with `dirty: false`, against the qualified bundle A.

| Run | Run-id | Provenance | Outcome |
| --- | --- | --- | --- |
| Counted unattended 1 | `20261006T165554Z-f8e92294` | measured | engine exit 0 in 112 s; every postcondition passed |
| Counted unattended 2 | `20261006T165859Z-5c61dee2` | measured | engine exit 0 in 84 s; every postcondition passed |
| Failure injection | `20261006T170130Z-bacdedaf` | measured | engine exit 1 after 1 s, run exit 3; pacman's own error is on the console; the disk is partitioned, formatted, and mounted at `/mnt` |
| Attended: plan and confirmation | `20261006T180251Z-e76ba9b8` | observed manually | the plan and `lsblk` are shown before the typed `install`; the installation finished |
| Attended: rejection | `20261006T181659Z-89c1afbc` | observed manually | answer `no`; exit 1; the disk has no partition table |
| Attended: SIGINT | `20261006T182418Z-9e1ef754` | observed manually | `Interrupt signal received`; the `pacstrap` step fails with status 1; `vda1` and `vda2` stay mounted at `/mnt/boot` and `/mnt` |

The omitted-root-password path is implemented but was not exercised in any run. Only the console and the
serial log hold diagnostics. The comparison with Archinstall is in [`../README.md`](../README.md).

Decision: selected as the installation engine by
[ADR 0002](../../../docs/adr/0002-installation-engine-selection.md). This prototype stays non-production;
`install/engine/apply` is populated later (Story 2.5).
