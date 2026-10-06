# Archinstall JSON/CLI prototype

Story 2.1, Track 1. Non-production: production never imports or sources this directory.

## Question

How much MirrorOS-owned adaptation does it take to reproduce the shared installation scenario with
the packaged `archinstall` CLI, a configuration JSON, and a protected `--creds` file, plus one bounded
native finalization step for what the configuration cannot express?

## Scenario

The scenario and its classification are in the matrix of [`../README.md`](../README.md). The postconditions
are checked on the second boot by the shared verification unit (see [`../lib/README.md`](../lib/README.md)).

| File | Role |
| --- | --- |
| [`run`](run) | Selects this engine for the shared harness |
| [`guest/install`](guest/install) | Builds the configuration and credentials, runs `archinstall`, calls the finalization, checks for credential leaks |
| [`guest/config.template.json`](guest/config.template.json) | Archinstall 4.5 configuration; only the device and the root partition size are filled in at run time |
| [`guest/finalize`](guest/finalize) | The bounded native finalization (no credentials) |

Archinstall is invoked only through its packaged CLI (`archinstall --config … --creds … [--silent]`).
No Python API, no plugin, and no project-owned Python are used. If an item would need any of them, it is
marked `unsupported` instead.

## Pinned source review

- Package in the qualified bundle: `archinstall 4.5-1` (with `python 3.14.7-1`).
- Source reviewed: upstream tag `4.5`, commit `78982a624824aa415f59bf88c515676a589e3c55`
  (`archlinux/archinstall`). Files read: `archinstall/lib/args.py`, `installer.py`, `scripts/guided.py`,
  `models/{locale,pacman,network,bootloader,users,authentication,application,device}.py`,
  `pacman/{pacman,config}.py`.

Source-reviewed expectations. They are not results: the matrix in [`../README.md`](../README.md) is filled
from the counted runs.

| Scenario item | Expected class | Why (source) |
| --- | --- | --- |
| GPT, 1 GiB FAT32 ESP at `/boot`, ext4 root | JSON/CLI | `disk_config` with `manual_partitioning`; the ESP is mounted with `fmask=0177,dmask=0077` |
| `fstab` by UUID | JSON/CLI | `genfstab -pU` |
| Zram disabled | JSON/CLI | `swap.enabled = false` |
| `LANG`, console keymap | JSON/CLI | `locale_config` |
| Second locale `es_ES.UTF-8` | native finalization | `sys_lang` takes one value |
| Packages, NetworkManager, time zone, NTP, hostname, `ParallelDownloads`, `Color` | JSON/CLI | `packages`, `network_config`, `timezone`, `ntp`, `hostname`, `pacman_config` |
| `systemd-boot-update.service` | JSON/CLI | `services` |
| `fstrim.timer` | JSON/CLI | enabled by default on ext4 |
| `bootctl install`, default entry | JSON/CLI | `bootloader_config` (`Systemd-boot`, `uki = false`) |
| User in `wheel`, shell `bash`, passwords | JSON/CLI | `--creds`: `users[].groups`, `enc_password`, `root_enc_password`; `sudo = false` avoids a per-user sudoers rule |
| `%wheel` sudoers drop-in | native finalization | archinstall writes only per-user rules |
| Hardware clock in UTC | native finalization | archinstall never runs `hwclock` |
| Default systemd-based initramfs hooks | native finalization | `Installer.mkinitcpio` rewrites `systemd` to `udev` without a FIDO2 device |
| `/swapfile` 4 GiB and resume parameters | native finalization | `Installer.add_swapfile` is not reachable from the configuration |
| `root=UUID=`, `resume=`, `resume_offset=` in the entry | native finalization | the entry is written with `root=PARTUUID=` and no resume |
| Fallback entry, `editor no`, `timeout 3` | native finalization | one default entry only; `loader.conf` comes from `bootctl install` |
| `kernel.sysrq = 1` | native finalization | no option |
| `VerbosePkgLists`, `ILoveCandy` | native finalization | `pacman_config` has only `parallel_downloads` and `color` |
| Mirrorlist inherited from the live environment | JSON/CLI | no `mirror_config`, so `pacstrap` copies the live mirrorlist |

Other source-reviewed observations, to be confirmed by the runs:

- Credentials: the non-deprecated forms are hashes (`enc_password`, `root_enc_password`), so the guest
  hashes the synthetic passwords with `openssl passwd -6 -stdin`. The plaintext keys (`!password`,
  `!root-password`) are marked deprecated upstream and are not used. The plaintext never reaches the
  `--creds` file, which is 0600, lives under `/run`, and is removed after the leak check.
- `user_configuration.json` (saved under `/var/log/archinstall/`) is built from `safe_config()` and is
  not expected to list users or hashes. `guest/install` checks this and searches the logs and the target
  for the plaintext and the hashes, printing only the outcome.
- Archinstall exits 0 when the menu is cancelled and warns without failing when a step is missing, so
  `guest/install` never infers success from its exit status alone (`require_installation`).
- Without `--silent`, `pacstrap` failures prompt for a download retry (`Pacman.ask`). Unattended runs
  always use `--silent`, so no retry happens.
- `_verify_service_stop` waits for NTP synchronization and for `archlinux-keyring-wkd-sync`; the
  installation deadline of the harness bounds it. `--skip-ntp` and `--skip-wkd` are not used.

## Usage

```bash
prototypes/installation/archinstall-json-cli/run [--variant normal|unreachable-mirrors] BUNDLE_DIRECTORY
prototypes/installation/archinstall-json-cli/run --attended BUNDLE_DIRECTORY
```

The default mode is the prototype-only unattended two-boot run (always `--silent`). `--attended` runs
boot 1 only, on the serial console; then, in the guest, `bash /run/mirroros-attended.sh [ARGUMENT]`
starts the engine with:

| Argument | Behavior |
| --- | --- |
| none | `archinstall` with its menu and confirmation |
| `--silent` | `archinstall --silent`: no menu and no confirmation |
| `--contract-check` | `archinstall --silent --dry-run` twice, with and without a root password; the disk is untouched |

`MIRROROS_OMIT_ROOT_PASSWORD=1` omits `root_enc_password` so that root stays locked. It exists only to
check the omitted-root-password case at contract level; the harness always delivers both credentials.

## Attended checklist

Run on a disposable disk over the serial console, together with the user. Record every observation as
"observed manually" with its run-id.

1. Contract check: run `--contract-check`. Record whether archinstall accepts a configuration without a
   root password when a user in `wheel` exists, and both exit statuses.
2. Plan visibility, with the menu: is the plan shown (disk layout, packages, users) before confirmation?
   Does the configuration preview at confirmation list the users and the root password state?
3. Plan visibility, with `--silent`: what is shown before the disk is modified (the countdown)?
4. Editability: can the plan be edited in the menu before confirmation? In `--silent`, only by editing
   the configuration file.
5. Confirmation: which input confirms in the menu, and what happens in `--silent`?
6. Rejection: answer "No" at the confirmation, then quit the menu. Record archinstall's exit status
   (cancelling the menu is expected to exit 0), the exit status of `guest/install`, and confirm that the
   disk has no partition table (`sfdisk -d` and `wipefs` on the target).
7. SIGINT: confirm, then press Ctrl-C during package installation. Record the exit status, the
   diagnostics left under `/var/log/archinstall/` and on the console, and the partial disk state
   (partitions, mounts, files under `/mnt`).
8. Does the menu render and respond over the serial console? Record any workaround that was needed.

## Result

All runs were made at commit `144eff7` with `dirty: false`, against the qualified bundle A (`archinstall
4.5-1`, source commit `78982a624824aa415f59bf88c515676a589e3c55`).

| Run | Run-id | Provenance | Outcome |
| --- | --- | --- | --- |
| Counted unattended 1 | `20261006T170225Z-04586fed` | measured | engine exit 0 in 110 s; every postcondition passed |
| Counted unattended 2 | `20261006T170512Z-ace9ccf1` | measured | engine exit 0 in 121 s; every postcondition passed |
| Failure injection | `20261006T170810Z-64e01275` | measured | engine exit 1 after 7 s, run exit 3; the console shows a generic message, not pacman's error; the disk has no partition table |
| Attended: contract check | `20261006T182807Z-c79529a2` | observed manually | `--silent --dry-run` exits 0 with and without a root password |
| Attended: menu, rejection | `20261006T183152Z-9d7e7092` | observed manually | archinstall exits 0, the wrapper reports that no installed system is mounted and exits 1; the disk has no partition table |
| Attended: `--silent` | `20261006T184058Z-ffad3fa7` | observed manually | a 5-second countdown, no confirmation; the installation and the finalization finished |
| Attended: menu, SIGINT | `20261006T184658Z-bf5a1940` | observed manually | `KeyboardInterrupt` traceback; archinstall exit 1, wrapper exit 1; `/var/log/archinstall/` keeps four files; `vda1` and `vda2` stay mounted. Evidence incomplete: four result files are empty |

The leak check found no plaintext credential and no hash in the Archinstall logs; whether the saved
configuration lists users was recorded as `unknown`. The menu rendered and responded over the serial
console in the recorded sessions; the evidence does not record a workaround. The comparison with the
native path is in [`../README.md`](../README.md).

Decision: not selected ([ADR 0002](../../../docs/adr/0002-installation-engine-selection.md)). This
prototype remains as evidence only.
