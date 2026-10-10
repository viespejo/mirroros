# Guided installer reference upstream record

## Origin

- **Local source:** `tmp/mirroros-ux-demo/omarchy-style/` (ignored local prototype copy, unchanged).
- **Entry point:** `guest-demo.sh`.
- **Presentation sources:** the `step()` function of the Omarchy ISO `/root/configurator`, plus the
  Tokyo Night console palette, centering, and table presentation adapted from the same ISO's
  `/root/.automated_script.sh` and configurator (`omacom/omarchy-iso`).
- **Licenses preserved unchanged:** `LICENSE-ISO` (MIT, Copyright (c) 2025 Anton Hvornum) and
  `LICENSE` (MIT, Copyright (c) David Heinemeier Hansson).
- **License scope:** upstream notices remain with the incorporated material. Original MirrorOS
  material in this directory remains under `GPL-3.0-only`; incorporation does not relicense upstream code.
- **Upstream version caveat:** published upstream source reviewed during the technical interview was not
  extracted from the exact tested ISO. Newer upstream behavior must not be substituted silently.

## Reference evidence: Omarchy 4.0.4 ISO

Inspected read-only on the maintainer's host. The ISO was not booted, its launcher was not used,
and no writable lab disk was attached. Files were extracted from `/arch/x86_64/airootfs.sfs` into a
temporary directory outside the repository.

- **ISO file:** `omarchy-4.0.4.iso`, 6185304064 bytes, SHA-256
  `ddeded2758c48318d201dfdac905ecb28f570441883f0c052ea3cd5d05acf92d`, volume id `OMARCHY_202609`.
- **`/root/configurator`:** SHA-256 `990fdb246045eb679872e9872ab44fa08f68d124aef59f0b9991a7c92af146d1`
  (image timestamp 2026-09-15).
- **Presentation function:** `step()` calls `clear_logo`, prints a blank line, prints the text with
  `gum style --padding "0 0 0 $PADDING_LEFT"`, then a blank line. `clear_logo` is defined by the
  guide, not by the ISO configurator's extracted function.
- **Palette:** Tokyo Night, set on the VT with `\e]P0..\e]PF`
  (`1a1b26 f7768e 9ece6a e0af68 7aa2f7 bb9af7 7dcfff a9b1d6 414868 f7768e 9ece6a e0af68 7aa2f7 bb9af7 7dcfff c0caf5`)
  by `/root/.automated_script.sh`. Gum confirm colors: prompt 6, selected 0 on 2, unselected 7 on 0.
- **Geometry:** no fixed size. The configurator measures width with `stty size`/`tput cols`
  and centers the logo block; `COLUMNS` and `LINES` are exported from `tput`.
- **Console font:** the ISO ships no `FONT=` setting. `/etc/vconsole.conf` is absent and the factory
  `/usr/share/factory/etc/vconsole.conf` contains only a commented `#KEYMAP=us`. The GRUB command line
  sets no font or video parameter beyond `quiet splash`. The console therefore uses the kernel
  default font and the mode chosen by the firmware/virtual display. No explicit console font is
  documented by the reference.
- **Gum:** `/usr/bin/gum` reports `gum version 2.0.0 (4d089f9)`.
- **Startup:** autologin as root on tty1 (`agetty --autologin root`); `.automated_script.sh` exits
  unless the terminal is `/dev/tty1`.

## Limitations

- The guide's logo coloring, margins, and widget settings come from the preserved scripts, which the
  maintainer exercised on the ISO. Their pixel-level appearance was not captured by an automated check.
- The exact console resolution of the maintainer's trial was not recorded.
- Console font reproduction therefore means "kernel default"; any additional font choice requires
  maintainer approval (plan 02-07, Task 9).
