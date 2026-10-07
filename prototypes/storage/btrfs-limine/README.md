# btrfs-limine

Btrfs/Snapper with Limine snapshot boot entries. Story 2.1, Track 2. Non-production:
production never imports or sources this directory. The provenance review below is Task 1 of
plan 02-02; the question, scenario, attended checklist, and result placeholder follow it.

## Question

Does selecting a snapshot entry in the Limine menu recover the same damage as the control without
rescue media, and what do the AUR tools cost in provenance, build, and ESP occupancy?

## Scenario

[`stage.sh`](stage.sh) uses the shared Btrfs stage ([`../lib/guest/btrfs-stage.sh`](../lib/guest/btrfs-stage.sh))
like [`btrfs-rescue`](../btrfs-rescue/README.md): same layout, mounts, swapfile, Snapper policy, and
`post-install baseline` snapshot. It differs in the boot stage:

- Limine is installed unsigned, on the standard UEFI fallback path (`SKIP_UEFI=yes`), with
  `KERNEL_CMDLINE[default]` holding `root=UUID=`, `rootflags=subvol=@,compress=zstd:1,relatime`, `resume=UUID=`, and
  `resume_offset=` in `/etc/default/limine`.
- [`aur-build.sh`](aur-build.sh) builds the two pinned AUR tools with `makepkg` as the unprivileged
  user `mirrorosbuild` (removed afterwards). `base-devel` and `git` are installed only in this variant.
- The build runs in a private PID and mount namespace with a matching `/proc`, then drops to
  `mirrorosbuild` with `runuser`. Without this, the GraalVM driver PID is absent from `/proc` and
  even a hello-world native image exits with status 30. No VM RAM increase was needed.
- A mkinitcpio drop-in adds the package-provided `sd-btrfs-overlayfs` hook after `filesystems`.
  The package transaction deploys Limine and generates the initramfs and entries.
  `limine-snapper-sync.service` is enabled; after the baseline snapshot, an explicit
  `limine-snapper-sync` invocation populates the snapshot entries before the first disk boot.
- Snapshot boot uses an overlay root. Development D2 run
  `20261007T144407Z-46560415-c03f-4b67-8a1b-8fbf860af244` booted snapshot 1 without rescue media
  and retained the home marker. This proves snapshot boot, not a persistent restore of `@`.
  That earlier run lacked `compress=zstd:1` during snapshot boot and used a relaxed check; it
  does not establish compression compliance. The check is now strict again. Adding
  `compress=zstd:1,relatime` to the live entry's `rootflags` also preserves those flags in the
  generated snapshot entries: the pinned `KernelReader.java` changes only `subvol=`.
  Development D1 run `20261007T150417Z-1de29de1-6daf-43a0-8c5f-f7b97b2fc0c9` passed both the
  normal boot and snapshot-1 verification, including compression on every checked Btrfs mount,
  home-marker survival, and retained diagnostics. Development D2 run
  `20261007T151812Z-63163242-55d9-4dd6-b9a8-8f2058e8f798` also passed with the strict checks
  and updated command line after selecting snapshot 1. Its home marker survived; diagnostics
  of the failed boot were not observable because the kernel never reached userspace.

The verification excludes `storage`, `swap`, and `boot`, and replaces them with the `btrfs_*`,
`snapper_*`, and `limine_*` checks of [`../lib/guest/storage-checks.sh`](../lib/guest/storage-checks.sh).
Recovery is attended: the maintainer selects the snapshot entry over the serial console, and the
verifying boot is that same boot. It is recorded as "observed manually".

## Usage

```bash
prototypes/storage/btrfs-limine/run --scenario install|d1|d2|hibernate|pending BUNDLE_DIRECTORY
```

See [`../lib/README.md`](../lib/README.md) for the scenarios, boots, and deadlines.

## Attended checklist: snapshot selection (D1 and D2)

Record every observation as "observed manually" with the run-id.

1. After the damaged boot is confirmed, the harness starts an attended boot. In the Limine menu on
   the serial console, note which snapshot entries exist.
2. Select the entry of the snapshot that precedes the damage (the pre snapshot of the damaging
   `pacman -U`, or the `post-install baseline`) and let the system boot.
3. Wait for the verification and action reports, then quit QEMU with Ctrl-A x.
4. Record whether the system booted, how many selections and keystrokes it took, and whether the
   snapshot is read-only or writable.
5. For D2, record whether the snapshot entry boots even though the ESP holds the damaged initramfs of
   the live entry (snapshot entries carry their own copies of the kernel and initramfs).

## Attended checklist: recovery with a pending hibernation image

Run the `pending` scenario. After the hibernation boot powers off, the maintainer gets a rescue
session from the ISO on the serial console.

1. Log in on the serial console and run `bash /run/mirroros-attended.sh`.
2. Power off, boot from disk, and in the Limine menu select a snapshot entry instead of the live one.
3. Record what happens: resume of the pending image, a failed resume, or a normal boot that discards
   it, and whether `@swap` (outside every snapshot) still holds the image.

## Result

To be recorded in Task 9, with provenance and run-id for every cell.

## Limine snapshot tooling: provenance review

Provenance of every package this variant installs. Provenance of every cell
below is **source-reviewed** (review date 2026-10-07). Nothing here was built or
run yet.

### Official repositories

| Package | Repository | Version seen | Use |
| --- | --- | --- | --- |
| `limine` | extra | 12.9.3-1 | Boot loader, installed unsigned |
| `snapper` | extra | 0.13.2-1 | Snapshot management |
| `snap-pac` | extra | 3.0.1-3 | pacman pre/post snapshots |
| `compsize` | extra | 1.5-2 | Compression metrics |
| `btrfs-progs` | core | 7.1-1 | Btrfs tooling (also on the ISO) |
| `efibootmgr`, `mkinitcpio`, `gettext` | core | 18, 42.2, 1.0 | Runtime or build dependencies of the AUR tools |
| `libnotify` | extra | 0.8.8-1 | Runtime dependency of `limine-snapper-sync` |
| `gradle` | extra | 9.8.0-1 | Build dependency (pulls `java-environment>=21`) |
| `base-devel` (group), `git` | core, extra | n/a | `makepkg` prerequisites, present only in this variant |

### AUR packages (origin: AUR, maintainer Zesko)

Neither tool is in an official repository. Both are AUR `PKGBUILD`s that build
upstream sources from GitLab, so each is pinned twice: the AUR packaging commit
and the upstream source commit.

| Tool | AUR package | AUR commit | Upstream | Upstream tag | Upstream commit |
| --- | --- | --- | --- | --- | --- |
| Snapshot entry generator | `limine-snapper-sync` 1.32.1-1 | `b3c82aded52032687a76922f2dee9497600818f2` | `https://gitlab.com/Zesko/limine-snapper-sync` | `1.32.1` | `b4c0da2d4532a993809219f9e5d51a1fa85fcb93` |
| Kernel and initramfs installer for Limine | `limine-mkinitcpio-hook` 1.40.0-1 (provides `limine-entry-tool`) | `94ffde9c60808595b287edf9d4219da202a85a7a` | `https://gitlab.com/Zesko/limine-entry-tool` | `1.40.0` | `35dab4b732861f5e8d307a1a7873856a877913aa` |

- The `PKGBUILD` sources use `#tag=`. Both upstream tags are annotated tags
  that resolve to the commits above. The implementation must build from the AUR
  commit and replace `#tag=` by `#commit=<upstream commit>` so the source is
  pinned by commit rather than by a movable tag.
- `limine-mkinitcpio-hook` was chosen over `limine-entry-tool` alone because
  the system uses `mkinitcpio`. The two packages conflict and both provide
  `limine-entry-tool`, so only one is installed.
- `limine-snapper-sync` lists `limine-mkinitcpio-hook` as an optional
  dependency, which is the pairing used here.

### Review notes (sources at the pinned commits)

- **Repositories required:** none beyond Arch `core` and `extra`. No CachyOS
  repository and no Chaotic-AUR reference in either `PKGBUILD`, the sources, or
  the shipped configuration.
- **Dependencies:** all runtime and build dependencies of the two packages are
  in `core` or `extra` (table above). `gettext` is only a build dependency of
  `limine-snapper-sync`.
- **Build:** both compile a native binary with Gradle and GraalVM
  `native-image`. This is heavy: it needs network access at build time, a JDK,
  and noticeable memory and time. Treat it as a measured cost of this variant.
- **Build inputs and pinning:**
  - Packaging source: AUR commit (pinned above).
  - Upstream source: upstream commit (pinned above).
  - GraalVM JDK: downloaded by the `PKGBUILD` from
    `github.com/graalvm/graalvm-ce-builds` release `graal-25.2.4`
    (`graalvm-community-jdk-25i2-25.0.4_linux-x64_bin.tar.gz`), verified by the
    `PKGBUILD` with sha256
    `3f4a89de8eaa96f2ed677f09957c7e872cd8467aad3537f8b5394c1b8c4b942e`.
  - Gradle dependencies from Maven Central are pinned by version only
    (`org.graalvm.buildtools.native` plugin `1.1.14`; `jackson-databind` `3.2.3`
    for `limine-snapper-sync`). The sources ship no Gradle dependency
    verification metadata and no lockfile, so these artifacts are **not**
    checksum-pinned. This is a recorded provenance limitation, not a stop
    condition: the sources themselves are pinned by commit.
- **Subvolume layout:** `limine-snapper-sync` reads the root and `/.snapshots`
  subvolumes from `/proc/mounts` and detects the Snapper configuration with
  `snapper list-configs`. The default restore method (`replace`) does not require
  the openSUSE layout. A flat `@snapshots` mounted at `/.snapshots`, as MirrorOS
  plans, is compatible. `ROOT_SUBVOLUME_PATH` and `ROOT_SNAPSHOTS_PATH` can be
  set in configuration if detection fails. The openSUSE-style restore method
  (`snapper`) is not used.
- **ESP usage:** the tools discover the ESP at `/efi`, `/boot`, `/boot/efi`, or
  `/limine` and copy per-snapshot kernels and initramfs there. Defaults:
  `LIMIT_USAGE_PERCENT=85` stops adding snapshot entries when the FAT32
  partition is 85% full, and `MAX_SNAPSHOT_ENTRIES=auto` prunes older entries.
  ESP occupancy with several snapshots is measured in Task 9 and a shortfall is a
  finding, not an in-flight change. Deduplication of copied files uses a hash
  function; `b3sum` and `xxhash` are optional and not installed, so the
  default hashing is used.
- **Hooks:** pacman hooks `10-limine-snapper-lock` (pre-transaction wait for
  `limine-snapper-sync`), `60-limine-mkinitcpio-remove-pre`,
  `80-limine-efi-deploy`, `90-limine-mkinitcpio-remove-post`, plus a systemd
  service `limine-snapper-sync.service` and a drop-in for
  `snapper-cleanup.service`. A generic pre/post hook directory under
  `/etc/boot/hooks/` is used by the tools; the shipped symlinks are for config
  enrollment, which stays disabled.
- **Secure Boot and enrollment:** `ENABLE_ENROLL_LIMINE_CONFIG` defaults to
  `no`, `sbctl` is optional and not installed. Limine is installed unsigned
  because Secure Boot remains deferred by the architecture.
- **Network behavior at runtime:** no HTTP access found in the runtime sources
  or scripts beyond documentation links.

### Gate verdict (AC-5, DEC-006)

- Origin confirmed: AUR, single maintainer, upstream on GitLab.
- Every used AUR tool is pinned to an exact commit with a recorded review.
- No CachyOS repository or Chaotic-AUR requirement found.
- Verdict: `btrfs-limine` is **supported** for implementation. The stop
  condition does not apply.
- Caveats carried into the comparison as dependency and provenance cost:
  AUR-only origin with a single maintainer; a Gradle/GraalVM native build with
  network access at build time; Maven Central dependencies pinned by version
  only; adoption would route AUR provenance through Story 3.2 (DEC-006).
