# Boot splash sources and ownership

## Theme

`plymouth/mirroros.plymouth` and `plymouth/mirroros.script` are MirrorOS-owned material, written independently in
Plymouth's native script-theme format as bounded by
[ADR 0014](../../../docs/adr/0014-native-login-and-boot-presentation.md). The script draws only the shared wordmark
PNG of [`visual/branding`](../../visual/branding/sources.md), centered on `rgb(16, 19, 21)` and scaled down with its
aspect ratio to at most 42% of the display width and 22% of its height, the same bound as the greeter logo. It
registers no refresh, progress, password, question or message callback and adds no delay; Plymouth's native details
view (Esc) shows the boot messages. `plymouth/plymouthd.conf` only selects the theme; Plymouth's distribution defaults
(`/usr/share/plymouth/plymouthd.defaults`, including `ShowDelay=0`) are unchanged.

No external material is incorporated. Omarchy's Plymouth theme (revision
`1801adc1983b06f6ab218f8060e430cb3477d8d0`, `default/plymouth/omarchy.script`) was consulted as an idea reference
only; its progress, password dialogue and assets are not adopted. The hook ordering and kernel parameters follow the
[Arch Wiki Plymouth article](https://wiki.archlinux.org/title/Plymouth).

## Packages and observed tools

`plymouth` from `extra` provides the daemon, the script plugin and the `plymouth` mkinitcpio hook. The development
inspection used `plymouth` 26.134.222-3 (hook `/usr/lib/initcpio/install/plymouth` copies the selected theme
directory and its `ImageDir`, `/etc/plymouth/plymouthd.conf` and the base plugins into the image) and the pinned
Limine packages `limine-mkinitcpio-hook` 1.40.0-1 and `limine-snapper-sync` 1.32.1-1 (`limine-update` runs
`limine-install --no-efi-register` and `limine-mkinitcpio`; `/etc/default/limine` has the highest configuration
priority; its exit status does not reliably report a failed rebuild). These are observations, not pins; the
installed versions are recorded in `packages.tsv` of each run.

## Delivery

| Item | Location | Owner |
|---|---|---|
| Theme | `/usr/share/plymouth/themes/mirroros/mirroros.{plymouth,script}` | MirrorOS, tracked files |
| Theme selection | `/etc/plymouth/plymouthd.conf` | MirrorOS, tracked file; the comment-only file shipped by `plymouth` 26.134.222-3 is migrated |
| Hook drop-in | `/etc/mkinitcpio.conf.d/90-mirroros-plymouth.conf` | MirrorOS, tracked file derived from the recognized hook sequence |
| Kernel parameters | `options` of `/boot/loader/entries/mirroros.conf`, or `KERNEL_CMDLINE[default]` of `/etc/default/limine` | Base installation plus the `quiet splash` overlay |
| Regeneration state | `/var/lib/mirroros/configure/boot-splash.state` | MirrorOS |
| Delivery records | `/var/lib/mirroros/configure/delivered/` | MirrorOS |

The drop-in repeats the recognized base sequence (the distribution `HOOKS` of `/etc/mkinitcpio.conf` for
systemd-boot, the installer's `10-mirroros-limine.conf` for Limine) with `plymouth` after `systemd` (or `udev`) and
before `filesystems`. When the base sequence changes, the intact previous drop-in is updated and the images are
regenerated once.

The regeneration identity is the SHA256 of the scheme, the delivered theme, selection, drop-in and wordmark PNG,
and the resulting command line. It is recorded as `mirroros-boot-splash` in `sources.tsv` and in the state file as
`pending <identity>` before a rebuild and `complete <identity>` after the generated artifacts pass inspection.
