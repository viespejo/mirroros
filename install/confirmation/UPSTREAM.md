# Guided installer presentation upstream record

## Origin

- **Upstream project:** `omacom/omarchy-iso` (the Omarchy ISO builder), as shipped in the Omarchy 4.0.4 ISO.
- **Adapted material:** the presentation of the guided live installer's screens: the `step()` screen
  (logo, blank line, title, blank line), the Tokyo Night virtual-console palette, the centering of the logo
  and the guide as one block, the Gum widget color settings, and the wording and widget layout of the
  screens. Sources reviewed: `/root/configurator` and `/root/.automated_script.sh` of the ISO.
- **Reference copy:** the frozen reference at [`prototypes/frontend/guided-installer/`](../../prototypes/frontend/guided-installer/README.md)
  (see its [`UPSTREAM.md`](../../prototypes/frontend/guided-installer/UPSTREAM.md) for the ISO identity,
  hashes, palette, geometry, console font, and Gum version of the tested ISO). It is a visual and behavioral
  reference only.
- **Production implementation:** reimplemented under `install/confirmation/` (`lib/ui.sh`, `lib/live.sh`,
  `lib/screens.sh`, `banner.txt`, `instructions/live-wifi.txt`). Nothing at runtime sources the prototype,
  `/root/configurator`, or any other Omarchy file; no Omarchy file is required on the MirrorOS ISO.
- **Upstream version caveat:** the published upstream source was not extracted from the exact tested ISO.
  Newer upstream behavior must not be substituted silently.

## Licensing

- **License (SPDX):** `MIT`, Copyright (c) 2025 Anton Hvornum, preserved unchanged in
  [`LICENSE-ISO`](LICENSE-ISO).
- **Scope:** the notice accompanies the presentation material adapted from `omacom/omarchy-iso`. Original
  MirrorOS material in this directory remains under `GPL-3.0-only`; incorporation does not relicense the
  upstream material. The `LICENSE` of the Omarchy project itself stays with the reference copy, which is not
  shipped on the ISO.

## Differences from the reference

The only intended differences are listed in
[`contracts/installation-confirmation.md`](../../contracts/installation-confirmation.md#differences-from-the-reference)
(D1 to D14). The production assistant additionally shows three short gray status lines while a read-only
phase runs, in the style of the reference's "Checking internet connection...": "Checking system clock...",
"Inspecting this machine...", and "Checking the machine and plan again...". It also shows the failed-input
reason of the plan component in red below a hostname the plan component rejects. These are listed for the
maintainer's review.
