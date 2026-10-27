# Boot splash sources and ownership

## Theme

`plymouth/mirroros.plymouth` and `plymouth/mirroros.script` are MirrorOS-owned material, written independently in
Plymouth's native script-theme format as bounded by
[ADR 0014](../../../docs/adr/0014-native-login-and-boot-presentation.md), as narrowly amended by
[ADR 0019](../../../docs/adr/0019-shared-symbol-and-live-splash.md). The script draws only the shared 320x320 symbol
PNG of [`visual/branding`](../../visual/branding/sources.md), centered on `rgb(16, 19, 21)` and scaled down with its
aspect ratio to at most 42% of the display width and 22% of its height, never enlarged, the same bound as the greeter
logo. Resizing updates the scale and centering without restarting the animation. Plymouth's native details view
(Esc) shows the boot messages. `plymouth/plymouthd.conf` only selects the theme; Plymouth's distribution defaults
(`/usr/share/plymouth/plymouthd.defaults`, including `ShowDelay=0`) are unchanged.

The symbol fades from zero to full opacity over 400 ms of active elapsed time, then uses
`0.875 + 0.125 * cos((elapsed - 0.4) * pi)` for a smooth two-second 75–100% pulse. The native refresh callback updates
opacity; the boot-progress callback supplies only elapsed `duration`, with the percentage argument ignored. Its
first sample establishes the origin. No frame counting, sleeps, helper processes, shell execution, progress
indicator, password/question/message callbacks, quit callback or completion wait is introduced.

API inspection of upstream Plymouth `main` used the independently written native callback bindings in
[`script-lib-plymouth.c`](https://gitlab.freedesktop.org/plymouth/plymouth/-/blob/main/src/plugins/splash/script/script-lib-plymouth.c),
the nominal 30 Hz duration delivery in
[`ply-boot-splash.c`](https://gitlab.freedesktop.org/plymouth/plymouth/-/blob/main/src/libply-splash-core/ply-boot-splash.c),
and the active elapsed clock in
[`ply-progress.c`](https://gitlab.freedesktop.org/plymouth/plymouth/-/blob/main/src/libply/ply-progress.c).
The refresh callback receives no clock argument; native timing pauses freeze duration and are excluded on resume.
Rendering is sampled, not a hard real-time guarantee. No upstream source is copied.

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

The regeneration identity is the SHA256 of the scheme, the delivered theme, selection, drop-in and symbol PNG,
and the resulting command line. It is recorded as `mirroros-boot-splash` in `sources.tsv` and in the state file as
`pending <identity>` before a rebuild and `complete <identity>` after the generated artifacts pass inspection.
Every normal image must contain the symbol, as well as the script, theme selection and native script plugin;
retaining the historical wordmark alone is insufficient. Tracked theme updates retain local-edit protection.

## Verification limits

`tests/capabilities/system/boot-splash/presentation.test.mjs` adapts the production script's bounded expression
subset to JavaScript and supplies recording native-API doubles with controllable duration. It covers fade endpoints,
pulse extrema and period, percentage independence, dropped refreshes, active-time pauses, resize bounds and the
absence of blocking completion logic. It does not execute Plymouth's parser or native renderer. Configure contracts
cover regeneration identity, unchanged reruns, missing-symbol failure and retry, and edited-theme protection.
Real Plymouth timing, pause/resume lifecycle, Esc, fast-boot completion and matching SDDM presentation remain pending
separately authorized attended boots. Physical-hardware qualification remains separate.
