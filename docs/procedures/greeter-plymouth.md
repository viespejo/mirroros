# Greeter and boot splash procedure

**Availability:** implemented through configure for installed systems on the three supported storage options.
Automated contracts cover the theme delivery, the boot convergence and its failure paths. Real boot, Esc,
graphical login and attended visual acceptance are the VM qualification of plan 02-20 Task 3 and are not claimed
here. No hardware, target-laptop, hibernation or full-MVP readiness follows from this procedure.

## What is delivered

| Surface | Capability | Effect |
|---|---|---|
| Wordmark | `visual/branding` | `/usr/share/mirroros/branding/mirroros-wordmark.{svg,png}`, the PNG rendered by the installed `rsvg-convert` |
| Greeter | `desktop/login` | The MirrorOS SDDM theme selected by `Current=mirroros`; SDDM, its login proxy and PAM authenticate unchanged |
| Boot splash | `system/boot-splash` | Plymouth with the static MirrorOS theme, the `plymouth` hook and `quiet splash` on the normal boot entry |

Both themes show the same wordmark in `rgb(202, 204, 204)` on `rgb(16, 19, 21)`. The splash has no progress,
animation, password prompt or delay. Configure never restarts SDDM, reloads the desktop or reboots: the greeter
and the splash take effect at the next boot. Sources and ownership: [branding](../../capabilities/visual/branding/sources.md),
[login](../../capabilities/desktop/login/sources.md), [boot splash](../../capabilities/system/boot-splash/sources.md).
Authority: [ADR 0014](../adr/0014-native-login-and-boot-presentation.md), and for keyboard layouts
[ADR 0015](../adr/0015-greeter-keyboard-layout-switching.md).

## Keyboard layout at the greeter

The greeter starts in the layout resolved from `/etc/vconsole.conf`, with the other MirrorOS layouts after it;
the session and its lock screen use the same order. Press `SUPER+I` (or `SUPER+SHIFT+I`) at the greeter to switch
before typing a password; the indicator below the field shows the active layout and the `Super+I` hint. Without the
greeter's state file, the indicator shows the configured layout and no hint. There is no per-account layout.

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
or regeneration. Reboot only after reviewing the outcome and `configure.log`.

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
  overlay.

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
