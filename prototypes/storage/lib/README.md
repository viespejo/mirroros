# Storage prototype harness

Shared, prototype-owned harness for Story 2.1, Track 2. The three variants (`control`,
`btrfs-rescue`, `btrfs-limine`) run through it, so the storage, boot, snapshot, and recovery stages
are the only difference between them. It is non-production: production paths never source it.

## Reuse of the 02-01 harness

`harness.sh` sources [`prototypes/installation/lib/harness.sh`](../../installation/lib/README.md)
as it is and defines only what differs. Nothing is copied. The reused modules cover the bundle
admission, preconditions, run identity, private run directories, the synthetic credentials and the
canary search, the NoCloud medium, the QEMU launch, stop and cleanup, and the evidence retention.

What this track adds:

| File | Purpose |
| --- | --- |
| `config.sh` | Track segment `storage` for the build and evidence paths and the deadlines of the new boots |
| `harness.sh` | The multi-boot orchestrator: scenarios, stages, and the stage record in `result.json` |
| `damage-packages.sh` | Builds the synthetic damage packages D1 and D2 and records them |
| `guest/storage-action.sh`, `guest/mirroros-storage-action.service` | Action runner installed in the guest (see below) |
| `guest/storage-common.sh` | Installer helper that installs the action runner and the storage checks |
| `guest/storage-checks.sh` | Checks that replace the groups excluded from `verify-postconditions.sh` |
| `guest/btrfs-stage.sh` | Shared Btrfs stage sourced by both Btrfs variants: layout, mounts, swapfile, Snapper, baseline |

### Parameters added to `prototypes/installation/lib/`

Every parameter defaults to the 02-01 behavior. Track 1 is unchanged unless a parameter is set.

| Module | Parameter | Default | Use here |
| --- | --- | --- | --- |
| `resources.sh`, `stop-cleanup.sh` | `PROTO_TRACK` | `installation` | `storage`: paths under `build/prototypes/storage/` and `evidence/prototypes/storage/` |
| `nocloud.sh` | `PROTO_NOCLOUD_BASENAME` | `nocloud` | One medium per boot (`nocloud-<boot>`) |
| `nocloud.sh` | `PROTO_NOCLOUD_ENGINE_SCRIPT` | `install` | `recover` for rescue boots (written to `seed.env` only when set) |
| `nocloud.sh` | `PROTO_NOCLOUD_EXTRA_SEED_ENV` | none | Variant, scenario, damage, action, marker value, seed label |
| `guest/runner.sh` | `MIRROROS_ENGINE_SCRIPT` (from `seed.env`) | `install` | Runs `engine/recover` instead of `engine/install`; every `seed.env` variable is exported |
| `launch.sh` | fourth argument of `launch_wait_report` | `MIRROROS-REPORT` | `MIRROROS-ACTION` reports |
| `evidence.sh` | `PROTO_RESULT_EXTRA_JSON`, `PROTO_METADATA_EXTRA_JSON` | `{}` | Stage record and track data merged into `result.json` and `run-metadata.json` |
| `guest/verify-postconditions.sh` | `MIRROROS_VERIFY_EXCLUDE_GROUPS` | none | Check groups dropped from the report |
| `guest/verify-postconditions.sh` | `MIRROROS_VERIFY_SWAPFILE`, `MIRROROS_VERIFY_SWAP_OFFSET_TOOL` | `/swapfile`, `filefrag` | `/swap/swapfile` and `btrfs inspect-internal map-swapfile -r` |
| `guest/verify-postconditions.sh` | `MIRROROS_VERIFY_EXTRA_CHECKS` | none | Script sourced before the report |

`verify-postconditions.sh` also strips the `[/subvolume]` suffix that `findmnt` appends to a Btrfs
root source, so the disk lookup works on Btrfs (a no-op on ext4). The `evidence.sh` change required
repeating the canary negative control (`installation/lib/negative-control.sh`).

## Variant contract

A variant's `run` sets `PROTO_ENGINE_NAME` (the variant name), `PROTO_ENGINE_DIR` (the `storage/`
directory, which holds `guest/`), `STORAGE_VARIANT_DIR` (its own directory), and
`STORAGE_RECOVERY_KIND` (`rescue` or `menu`), sources `lib/harness.sh`, and calls `storage_main "$@"`.

`guest/install` sources the variant's `stage.sh`, which defines this interface:

| Name | Kind | Purpose |
| --- | --- | --- |
| `VARIANT_PACKAGES` | array | Packages appended to the common `pacstrap` list |
| `variant_plan_lines` | function | The storage, swap, and boot lines of the attended plan |
| `variant_install_storage` | function | Partitioning, filesystems, and mounts under `/mnt` |
| `variant_configure_swap_and_boot` | function | Swapfile, resume parameters, and the boot loader configuration |
| `variant_finalize` | function | Last stage, after the verification and action units: snapshots and loader entries |
| `MIRROROS_STORAGE_EXCLUDE_GROUPS` and related | variables | Check groups excluded from `verify-postconditions.sh` (see below) |

The harness stages one engine directory per run and every NoCloud medium of the run carries it:

| Path in `engine/` | Source |
| --- | --- |
| `install` | `storage/guest/install`, the installer derived once from `native-arch/guest/install` |
| `variant/` | every file of the variant directory except `README.md` and `run` (`stage.sh` is required) |
| `recover` | the variant's `recover` script, or a stub for variants without a rescue script |
| `support/` | `guest/storage-*.sh`, `guest/btrfs-stage.sh`, and the action unit |
| `packages/` | the damage packages built for the run |

## Boots and stages

One run is one scenario of one variant. A run has no automatic retries.

| Scenario | Boots in order |
| --- | --- |
| `install` | `install`, `prepare` |
| `d1`, `d2` | `install`, `prepare`, `damage`, `confirm`, then `recover` and `final` (rescue) or the attended `final` (menu) |
| `hibernate` | `install`, `prepare`, `hibernate`, `resume` |
| `pending` | `install`, `prepare`, `hibernate`, an attended `pending` rescue session, `resume` (observed only) |

| Boot | Medium | Event the harness waits for |
| --- | --- | --- |
| `install` | ISO and seed | The guest powers off after the installer (the 02-01 stage) |
| `prepare` | disk and seed | The verification report, then power-off. The action writes the `/home` marker |
| `damage` | disk and seed | Power-off. The action runs `pacman -U` on the damage package and reports its exit status and the Snapper snapshot counts |
| `confirm` | disk only | No verification report may arrive: a missing report, or a guest that stops, confirms the failure. A report means the damage was not effective (status 6) |
| `recover` | ISO and seed | Power-off. The recovery script runs over NoCloud; its report carries the exit status and duration |
| `final` | disk and seed | The verification report, then power-off. The action checks the marker and the journal |
| `hibernate` | disk and seed | Power-off after the hibernation image is written |
| `resume` | disk and the same seed | The `MIRROROS-ACTION` report of the resumed system |

The `confirm` boot has no serial console on the kernel command line, so it cannot show why the
system failed; the evidence is the absence of the report within the deadline. The Limine `menu`
recovery runs `final` as an attended boot on the terminal (Ctrl-A x quits QEMU) and is recorded as
"observed manually".

### Deadlines

Inherited from `installation/lib/config.sh`: installation 1800 s and verification 600 s.
New, in `config.sh`:

| Deadline | Seconds | Scope |
| --- | --- | --- |
| Power-off after a report | 120 | Time from the report to the guest power-off |
| Action boots (`damage`, `hibernate`) | 300 | Time until the guest powers off |
| Confirm | 180 | Observation window of the damaged boot |
| Recovery (`recover`) | 900 | Time until the rescue boot powers off |
| Resume | 600 | Time until the resumed action reports |
| Attended boots | 7200 | Documented limit, not enforced by a timer |

## The action runner

The installed system carries `mirroros-storage-action.service`, which runs after the 02-01
verification unit. It mounts the NoCloud medium by label, reads `MIRROROS_ACTION` from `seed.env`,
performs it, and prints one run-bound JSON report between `MIRROROS-ACTION-BEGIN/END` lines. Without
the medium it does nothing. It is prototype-only contamination, like the verification unit, and must
not be treated as part of any installation plan.

| Action | Effect |
| --- | --- |
| `prepare` | Writes the `/home/mirroros/.mirroros-marker` file, then powers off |
| `damage` | `pacman -U` of the `mirroros-damage-d1` or `mirroros-damage-d2` package, then powers off |
| `post-check` | Reports marker presence and content, the journal boot count, and whether the journal is persistent, then powers off |
| `hibernate` | Writes a state file and a random token, requests hibernation, and after a resume reports `resumed` with the same token. A fresh boot that finds the state file reports `not_resumed` |

The process that requested hibernation continues after a resume, so `resumed` means the image was
restored. This is a prototype of the observation, not a claim about target-laptop hibernation.

## Damage packages

Built locally with `tar` and `zstd` (no network, no `makepkg`), installed with `pacman -U`, and
listed with hashes in `damage-packages.json`:

- `mirroros-damage-d1` (D1, userspace inside `@`): a failing unit required by `local-fs.target`.
  The next boot stops in emergency mode before login.
- `mirroros-damage-d2` (D2, boot path on the ESP): a `post_install` scriptlet overwrites
  the active initramfs with a non-archive: `/boot/initramfs-linux.img` for systemd-boot, or
  `/boot/<machine-id>/linux/initramfs` for Limine. It fails explicitly if the expected file is
  missing and leaves Limine's per-snapshot copies in `limine_history` untouched. The ESP is
  outside every snapshot.

## Check exclusion and replacement (DEC-010)

| Variant | Excluded groups | Replacement |
| --- | --- | --- |
| `control` | none | the 02-01 checks run unchanged |
| `btrfs-rescue` | `storage`, `swap` | `btrfs_*` and `snapper_*` checks |
| `btrfs-limine` | `storage`, `swap`, `boot` | the same, plus `limine_*` checks |

A group is the id prefix before the first underscore, so `swap_resume_match` (recorded inside
`check_boot`) is excluded with the `swap` group. The report lists every excluded group under
`excluded_groups` with the ids of the checks that replaced it, and a group without any replacement
check makes the report fail.

## Evidence

Under `evidence/prototypes/storage/<variant>/<run-id>/`, with directories at 0700 and files at 0600,
and only these files retained: the 02-01 allowlist, plus `serial-<boot>.log`,
`qemu-<boot>-diagnostics.log`, `verify-report-<boot>.json`, `action-report-<boot>.json`,
`gitleaks-nocloud-<boot>.json`, and `damage-packages.json`. `result.json` adds `track`, `scenario`,
`recovery_kind`, `stages`, and the facts of the run (`baseline`, `damage`, `confirm`, `recovery`,
`survival`, `hibernation`, `verify_excluded_groups`). Every record stores the commit and `dirty`.

The synthetic credentials follow the 02-01 rules. Each boot's NoCloud medium carries them (a
read-only medium under `build/`, deleted with the run), and the canary search covers all the evidence.
