# Greeter and boot splash procedure

**Availability:** implemented through configure for installed systems on the three supported storage options,
and through container-local profile preparation for the live ISO.
Automated contracts cover the theme delivery, the boot convergence and its failure paths. The shared symbol and
fade-plus-pulse extension under ADR 0019 have automated checks only; their real Plymouth timing, Esc access,
fast-boot completion, native timing pauses and attended greeter appearance remain pending individually authorized
boots. Plan 02-20 Task 3 qualified the historical static wordmark, with the limits in the
[VM qualification record](#vm-qualification-record); it does not qualify this extension. No hardware, target-laptop,
hibernation or full-MVP readiness follows from this procedure.

## What is delivered

| Surface | Capability | Effect |
|---|---|---|
| Shared symbol | `visual/branding` | `/usr/share/mirroros/branding/mirroros-symbol.{svg,png}`, the 320x320 PNG rendered by the installed `rsvg-convert`; historical wordmark retained |
| Greeter | `desktop/login` | The MirrorOS SDDM theme selected by `Current=mirroros`; SDDM, its login proxy and PAM authenticate unchanged |
| Boot splash | `system/boot-splash` | Plymouth with the animated MirrorOS symbol theme, the `plymouth` hook and `quiet splash` on the normal boot entry |

Both themes show the same square symbol in `rgb(202, 204, 204)` on `rgb(16, 19, 21)`, centered without upscaling,
bounded by 42% of display width and 22% of height. The greeter stays static. The splash fades in once over 400 ms,
then pulses smoothly between 75% and 100% opacity every two seconds of active elapsed time. Plymouth's duration
callback supplies time only, never its progress percentage; native timing pauses freeze the effect. Sampled
updates do not promise hard real-time precision. Fast boots may finish before the fade: no animation cycle is
awaited and no progress, password prompt or boot delay is added. Configure never restarts SDDM, reloads the desktop
or reboots: the greeter and the splash take effect at the next boot. Sources and ownership: [branding](../../capabilities/visual/branding/sources.md),
[login](../../capabilities/desktop/login/sources.md), [boot splash](../../capabilities/system/boot-splash/sources.md).
Authority: [ADR 0014](../adr/0014-native-login-and-boot-presentation.md), and for keyboard layouts
[ADR 0015](../adr/0015-greeter-keyboard-layout-switching.md). Confirmed greeter power requests are bounded by
[ADR 0016](../adr/0016-greeter-power-actions.md). The shared symbol and bounded active-time animation are governed
by [ADR 0019](../adr/0019-shared-symbol-and-live-splash.md).

## Live splash preparation and recovery

The live profile declares official-repository `plymouth`. Construction installs `librsvg` only in the build
container, copies read-only `/profile` to `/live-profile` after the Limine payload is ready, renders and validates
the shared branding delivery with `install-assets`, and copies the exact shared Plymouth theme and selection
configuration from the captured capabilities snapshot. `mkarchiso` uses only the writable copy. No configure
command runs on live, and preparation failure blocks construction with stage diagnostics retained. Details:
[build preparation](build.md#construction-and-timeouts). Generated PNGs are not source files.

The live initramfs hook follows `udev`; other hooks stay ordered as before. Normal systemd-boot and retained GRUB
lines carry `quiet splash` without altering root discovery, serial/NoCloud paths, font/display policy, or the
automatic tty1 installer welcome. The theme has the same active-time animation as the installed splash.

- **Details:** press Esc during Plymouth. `quiet` reduces kernel verbosity but does not remove native diagnostics.
- **One-boot no-splash:** enter the existing live systemd-boot menu editor with `e`, remove `splash` and `quiet`
  from the normal entry, and boot it. In retained GRUB use its existing `e` editor, remove those words from the
  `linux` line, and boot with Ctrl+X/F10. Edits last only for that boot. The profile does not disable the live
  systemd-boot editor; no editor policy is changed. Installed systemd-boot still uses its no-splash fallback
  instead of enabling its disabled editor. GRUB/Ventoy remains unqualified.
- **Preparation failure:** retain `logs/live-splash-preparation.log` and execution evidence, fix the reported
  input/renderer failure and explicitly rerun construction. Do not bypass validation or invoke `mkarchiso`
  against the incomplete copy. Existing [build recovery controls](build.md#recovering-a-previous-run) apply.

**Pending, individually authorized checks:** rebuild an ISO and inspect the actual package manifest/initramfs
for Plymouth, the symbol and exact theme; attend a normal UEFI boot and confirm centering, the 400 ms fade,
two-second 75–100% pulse, native pauses and prompt completion without waiting for a cycle; exercise Esc and
one-boot no-splash recovery; confirm tty1 welcome, cancellation to shell and seeded serial/NoCloud behavior.
Installed greeter appearance, login/layout behavior and power-menu cancellation require separately authorized
installed-system checks. None is established by static profile tests, a browser preview, or native-API/renderer
and builder doubles. Physical-hardware qualification is a separate pending gate.

## Keyboard layout at the greeter

The greeter starts in the layout resolved from `/etc/vconsole.conf`, with the other MirrorOS layouts after it;
the session and its lock screen use the same order. Press `SUPER+I` (or `SUPER+SHIFT+I`) at the greeter to switch
before typing a password; the indicator below the field shows the active layout and the `Super+I` hint. Without the
greeter's state file, the indicator shows the configured layout and no hint. There is no per-account layout.

## Restart and shutdown at the greeter

The discreet power icon at the bottom right opens **Restart** and **Shut down**, limited to actions SDDM reports
as available. Tab reaches the power icon; Enter/Space opens it. Use Up/Down arrows or Tab/Shift+Tab to cycle through
the available options, and Enter/Space to select. Selecting an action opens a confirmation with **Cancel**
focused by default; arrows or Tab/Shift+Tab move between its buttons. Escape, Cancel or clicking outside dismisses the panel without
requesting an operation. The password is cleared when opening the menu, and power actions are disabled during
authentication. SDDM handles requests under the existing system policy; no forced fallback or automatic retry occurs.

Apply through configure as described below; no SDDM restart is performed. The historical VM qualification record
below predates this extension. Before qualifying it, use a disposable VM to check the icon and panel at 800x480
and 1280x800, keyboard-only navigation, cancellation without a transition, real restart returning to the greeter,
and shutdown stopping the VM. Automated proxy doubles do not establish these outcomes or inhibitor behavior.

## Base installation and configure overlay

The installation engine writes the base boot configuration from the approved plan, and the base postconditions
verify it exactly before configure runs ([engine, configure phase](../../contracts/installation-engine.md#configure-phase)).
Configure then adds the splash overlay; the plan, its `kernel_cmdline` and the base policy are unchanged.

| Storage option | Boot loader | Overlay written by configure | Regeneration |
|---|---|---|---|
| `ext4-systemd-boot` | systemd-boot | `quiet splash` appended to `options` of `/boot/loader/entries/mirroros.conf`; the fallback entry keeps the base line | `mkinitcpio -p linux` (default and fallback images) |
| `btrfs-rescue` | systemd-boot | As above; `rootflags=subvol=@` is kept | `mkinitcpio -p linux` |
| `btrfs-limine` | Limine | `quiet splash` appended to `KERNEL_CMDLINE[default]` in `/etc/default/limine`; `limine.conf` is rewritten only by the tool | `limine-update` |

All three also receive `/etc/mkinitcpio.conf.d/90-mirroros-plymouth.conf` and the theme files. Root UUID,
subvolume, `zswap.enabled=0`, `resume=` and `resume_offset=` keep their values; no `loglevel` or other logging
parameter is added. Limine snapshot entries created before the overlay keep their command line and are never
edited; snapshots taken later copy the current entry. The editor, timeout, boot loader and Secure Boot policy are
unchanged. See [Boot splash overlay](configure.md#boot-splash-overlay) for recognition and conflicts.

## Applying to an existing installation

The configure copy that the installer left in `/usr/local/lib/mirroros/` is a snapshot of the installer's code and
never updates itself; `sudo mirroros-configure` from an older installation does not contain these steps.

Preferred: run configure from a reviewed checkout at the intended commit. Its evidence records the Git identity.

```bash
git -C ~/code/mirroros fetch && git -C ~/code/mirroros switch --detach <reviewed-commit>
sudo ~/code/mirroros/operations/configure
```

Alternatively, replace the whole installed snapshot deliberately, so that `mirroros-configure` and its recorded
identity match the code it runs. Never copy single files into the snapshot.

```bash
src=~/code/mirroros dest=/usr/local/lib/mirroros
commit=$(git -C "$src" rev-parse HEAD)
dirty=$([[ -z $(git -C "$src" status --porcelain) ]] && echo false || echo true)
sudo rm -rf -- "$dest.new"
sudo install -d -m 0755 -- "$dest.new/operations/lib"
sudo cp -- "$src/operations/configure" "$dest.new/operations/configure"
sudo cp -- "$src/operations/lib/lifecycle-discovery.sh" "$dest.new/operations/lib/"
sudo cp -R -- "$src/capabilities" "$dest.new/"
printf '{\n  "commit": "%s",\n  "dirty": %s\n}\n' "$commit" "$dirty" | sudo tee "$dest.new/identity.json" > /dev/null
sudo find "$dest.new" -type d -exec chmod 0755 {} +
sudo find "$dest.new" -type f ! -perm /111 -exec chmod 0644 {} +
sudo find "$dest.new" -type f -perm /111 -exec chmod 0755 {} +
sudo chown -R 0:0 -- "$dest.new"
sudo mv -T -- "$dest" "$dest.old" && sudo mv -T -- "$dest.new" "$dest"
sudo mirroros-configure
```

Keep `$dest.old` until the run is reviewed. A first run installs `plymouth` (a package transaction, subject to the
pending-upgrade guard), publishes the themes, applies the overlay and regenerates the boot images once; installing
the package may itself trigger the distribution's initramfs rebuild before the overlay exists. A second unchanged
run reports `system/boot-splash: unchanged` and performs no package transaction, asset publication, entry rewrite
or regeneration. An intact historical theme delivery migrates; local edits remain a conflict. The symbol raster
participates in regeneration identity and must be present in every normal boot image. Reboot only after reviewing
the outcome and `configure.log`.

## Diagnostic access

- **Esc during the splash** switches Plymouth to its native details view with the boot messages. `quiet` reduces
  console verbosity only; the journal keeps the full boot log (`journalctl -b`).
- **systemd-boot without splash:** select `MirrorOS (fallback initramfs)` in the boot menu (press a key during the
  timeout). It keeps the base command line without `splash`; it boots the fallback initramfs without
  `autodetect`. The `editor no` policy stays in force; do not enable the editor to remove the splash.
- **Limine without splash:** the pinned Limine tools keep the menu editor enabled
  ([engine, Limine options](../../contracts/installation-engine.md#mapping-of-bootloader_options)). Select the
  normal entry, edit it, remove `splash` (and `quiet` if desired) from `cmdline:` for this boot only, and boot it.
  Do not use a snapshot entry for this: it boots an older root.
- **Independent rescue path:** boot the MirrorOS live medium, mount the installed root at `/mnt` (Btrfs:
  `-o subvol=@`) and the ESP at `/mnt/boot`. For systemd-boot remove ` quiet splash` from the `options` line of
  `/mnt/boot/loader/entries/mirroros.conf`; for Limine remove them from `KERNEL_CMDLINE[default]` in
  `/mnt/etc/default/limine` and run `arch-chroot /mnt limine-update`. To also drop the hook, move
  `/mnt/etc/mkinitcpio.conf.d/90-mirroros-plymouth.conf` aside and regenerate (`arch-chroot /mnt mkinitcpio -p linux`
  or `limine-update`). This is a diagnostic state, not a supported opt-out: the next configure run restores the
  overlay. `boot-splash.state` may still read `complete` meanwhile; configure checks the effective entry, not the
  state, so the restore rewrites only what was removed.

## Recovery after a failed regeneration

Configure writes `pending <identity>` to `/var/lib/mirroros/configure/boot-splash.state` before rebuilding and
`complete <identity>` only after it has inspected the effective parameters, the referenced boot files and the theme
inside every normal boot image. A failed rebuild ends with outcome `5` (the tool's own diagnostics are in
`configure.log`); a rebuild that reports success without the theme ends with `4`; an interruption ends with `3`
or `5`. In every case the state stays `pending` and the next run rebuilds once more; nothing is retried
automatically.

1. Read the step's lines in `configure.log` of the failed run; resolve the cause (ESP not mounted or full, a
   mkinitcpio hook error, a missing Limine tool).
2. Do not reboot while the state is `pending` unless necessary: the normal image may be incomplete.
3. Rerun configure. If the system no longer boots normally, use the systemd-boot fallback entry, or the live medium:
   mount as above, regenerate with `arch-chroot /mnt mkinitcpio -p linux` or `arch-chroot /mnt limine-update`, boot,
   then rerun configure so that it verifies the images and records completion.

A boot image changed behind configure (for example rebuilt without the hook) fails the step's postcondition with
`4` even when every recorded hash matches; rerunning after restoring the drop-in rebuilds it.

## Evidence

Each run's evidence is under `/var/log/mirroros/configure/<run-id>/` ([configure evidence](configure.md#evidence)):
`packages.tsv` records the installed `plymouth`, `librsvg` and `sddm` versions, and `sources.tsv` records
`mirroros-branding`, `mirroros-sddm-theme` and `mirroros-boot-splash` with their delivery identities. VM
qualification evidence belongs under `evidence/greeter-plymouth/` on the development host, outside source control,
allowlisted and scanned with `gitleaks dir --no-banner --redact <evidence-dir>`; it must not contain credentials or
private screens.

## VM qualification record

This historical record predates the shared symbol and animation. Synthetic SDDM and Plymouth doubles do not extend
its qualification. For the new presentation, separately authorize attended installed-system boots for each storage
option: compare symbol proportions and centering at small and large display sizes, observe the fade and pulse
without prolonging a fast boot, exercise Esc and the existing no-splash path, and verify greeter login, logout,
layout switching and power-menu cancellation without requesting a power operation. Native timing pauses and
completion must be observed in real Plymouth. Physical-hardware checks are a separate qualification.

Plan 02-20 Task 3 qualified commit `c595a09` (clean) in disposable QEMU/UEFI VMs (4 GiB, 2 vCPUs, virtio-vga).
Clean installs used the final-source ISO `dist/20261026T151813Z-73344428-54e5-43c3-9629-3ceb35f1c9cc/`
(`mirroros-2026.10.26-x86_64.iso`, SHA-256 `945dbe0fbd3ce82984c266bf49ad6a872426c40fde0ed86efab8907277ac3cff`;
all build controls passed; `plymouth` absent from the live package list). Installed versions: `plymouth`
26.134.222-3, `librsvg` 2:2.63.4-1, `sddm` 0.21.0-7, `qt6-declarative` 6.12.0-2, `hyprland` 0.56.2-4, `uwsm`
0.27.1-1, `mkinitcpio` 42.2-1, `linux` 7.2.11.arch1-1, `limine` 12.9.4-1, `limine-mkinitcpio-hook` 1.40.0-1,
`limine-snapper-sync` 1.32.1-1, `systemd` 262.1-1. Disposable passwords and accounts only; no credential was
recorded.

| Check | Observed outcome |
|---|---|
| Automated contracts at `c595a09` | Node 44/44; branding, login, boot-splash, layout-indicator and lock Bats 47/47; mechanism 86/86 (`--jobs 1`); target, operations, engine apply and image 111/111. `bash -n` clean; ShellCheck clean except the pre-existing SC2034 in `capabilities/configure-steps`. Selected suites, not the whole repository. |
| `btrfs-limine`, hibernation on, `es` | Installed, base postconditions passed, target configure 12 changed. `quiet splash` once on the normal entry; root, `zswap.enabled=0`, `resume=`, `resume_offset=` and `subvol=@` kept; the baseline snapshot entry keeps its original command line and historical initramfs. Hooks `base systemd plymouth … sd-btrfs-overlayfs fsck`; the normal image contains the theme and wordmark. |
| `ext4-systemd-boot`, hibernation on | Same base and overlay results. Fallback entry keeps the base line; preset `default` and `fallback` kept; both images contain the theme; `editor no` and `timeout 3` unchanged. |
| `btrfs-rescue`, hibernation off | Same results without resume parameters; `rootflags=subvol=@` kept; fallback entry unchanged. |
| Attended boot and login, all three | Splash visible, Esc shows boot messages, greeter shows `Spanish`, login with a password containing `ñ`, logout returns to the themed greeter, login again. |
| Unchanged running configure, all three | All 12 steps `unchanged`, outcome 0, no package, render, install, regeneration or `systemctl` command; boot files, images, state and service PIDs identical before and after. |
| Existing installation | Copy of a pre-change (`8c51c7d`) `btrfs-limine` installation updated from a checkout: first run installed `plymouth`, published the themes and regenerated once, no service restart; reboot with splash, Esc, login and logout; reruns all unchanged. Repeated for `c595a09` (theme and bindings republished only). |
| Attended greeter review | On the updated installation at `c595a09`: logo and splash agreement, field, selected user and indicator, keyboard-only switch to a second account with password cleared, generic failure and `Authenticating…` on a wrong password, `ñ` password failing in English (US) and passing after `SUPER+I`, lock starting in the resolved layout and restoring the previous one, small window usable. |
| No-splash paths | Limine: editing the normal entry for one boot removed `quiet splash`; next boot had the splash again. systemd-boot: the fallback entry booted without splash. Live rescue on `btrfs-rescue`: removing `quiet splash` from the entry booted without splash; the next configure changed only `system/boot-splash`, rewrote the entry and did not regenerate the image. |
| Secrets and whitespace | `gitleaks` found no leaks in the evidence directory or in commits `8c51c7d..c595a09`; `git diff --check` clean. |

Evidence: `evidence/greeter-plymouth/20261026T134735Z/reports/` (`btrfs-limine-*`, `ext4-systemd-boot-*`,
`btrfs-rescue-*`, `existing-update/`). Earlier smoke runs under `evidence/greeter-plymouth/20261026T100647Z/`
used a superseded development ISO and are not qualification evidence; the defects they found were fixed and
retested.

### Not performed and limits

- Not performed: a hibernate and resume cycle, a Limine snapshot boot, a real interrupted or failed
  regeneration (automated contracts only), `qmllint` against the installed Qt 6.12 (the reviewed baseline uses
  host qmllint 6.8.2; SDDM loaded the theme in every VM), and any physical hardware.
- hyprlock follows only the first layout change while locked, so layout switching is not offered at the lock; the
  bar briefly shows the configured layout while locking when another layout is active.
- SDDM stores no per-account layout; the greeter starts in the configured layout.
- Inherited: snap-pac prints `fatal library error, lookup self` in the installer's chroot; Limine installations
  keep an unreferenced `/boot/initramfs-linux.img` without the hook; a running-context package transaction lets
  snap-pac snapshot the pre-overlay image; user edits under a managed header in `~/.config/foot/foot.ini` are
  restored without notice.

This is VM evidence only. It makes no target-laptop, hardware-hibernation, full-MVP or release claim.
