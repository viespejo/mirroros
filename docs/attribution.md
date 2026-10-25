# Attribution

## Policy

This index covers all externally incorporated material in the repository. Each entry records the project, its SPDX license identifier, the material incorporated into MirrorOS, and a link to a detailed provenance record. Version-specific values belong in that provenance record and are not duplicated in this index.

Original MirrorOS material is licensed under `GPL-3.0-only` unless a document states otherwise. Incorporated material keeps its own license terms and required notices; incorporation does not convert it to the MirrorOS license.

At this baseline there is no external incorporation entry. The applicable entry is added with the first vendor merge, together with its detailed provenance record.

## Entry format

Add one entry per externally incorporated project:

```markdown
### <Project name>

- **License (SPDX):** `<SPDX identifier>`
- **Incorporated material:** <paths or other material included in MirrorOS>
- **Detailed provenance:** [<provenance record>](<relative path>)
```

Keep this index stable and concise. Record changing tags, commits, package versions, digests, dates, acquisition methods, and integrity evidence only in the linked provenance record.

### Archiso

- **License (SPDX):** `GPL-3.0-or-later`
- **Incorporated material:** Official `releng` profile at `image/archiso/`, locally modified for MirrorOS installer integration, reviewed live-package reduction, UEFI-only media and live branding; upstream license and technical references remain intact
- **Detailed provenance:** [Archiso upstream record](../image/archiso/UPSTREAM.md)

### Omarchy ISO configurator presentation

- **License (SPDX):** `MIT`
- **Incorporated material:** Presentation function, palette, and layout adapted from the Omarchy ISO configurator, preserved as a reference at `prototypes/frontend/guided-installer/` (never sourced by production) and reimplemented at `install/confirmation/`
- **Detailed provenance:** [Guided installer reference upstream record](../prototypes/frontend/guided-installer/UPSTREAM.md) and [Guided installer presentation upstream record](../install/confirmation/UPSTREAM.md)

### Omarchy desktop shell fragments

- **License (SPDX):** `MIT`
- **Incorporated material:** Selective menu (including the Apps launcher and selector), bar, notification and OSD fragments copied or adapted into the owned shell at `capabilities/desktop/shell/`; key choices, binding descriptions and dispatcher shapes adapted into `capabilities/desktop/compositor/providers/hyprland/shell-bindings.lua` and `window-bindings.lua` (no upstream file copied); copyright holders David Heinemeier Hansson and Neil Jagdish Patel (Omapager notification-engine origin)
- **License texts:** Omarchy's MIT text and Omapager's complete MIT text (Copyright (c) 2026 Neil Jagdish Patel) are retained unchanged as `LICENSE.omarchy` and `LICENSE.omapager` in `capabilities/desktop/shell/`; the Omapager text was verified externally as license evidence only (not a code-source pin or full license audit)
- **Detailed provenance:** [Desktop shell upstream record](../capabilities/desktop/shell/UPSTREAM.md) and [Hyprland bindings upstream record](../capabilities/desktop/compositor/providers/hyprland/UPSTREAM.md)

### Tokyo Night terminal palette

- **License (SPDX):** `MIT` for the explicitly licensed terminal extra; other upstream repository material has its own terms
- **Incorporated material:** Palette translated to Foot at `capabilities/desktop/terminal/foot.ini`, with reviewed bright-color overrides, and to the Tmux theme at `capabilities/workflow/tmux/tmux.theme.conf`; no upstream Lua code
- **Detailed provenance:** [Terminal sources and notice scope](../capabilities/desktop/terminal/sources.md) and [MIT notice](../capabilities/desktop/terminal/LICENSE.tokyonight)

### Prezto history options

- **License (SPDX):** `MIT`
- **Incorporated material:** History option choices adapted into the `setopt` block of `capabilities/workflow/shell/zshrc`; no other Prezto code
- **Detailed provenance:** [Shell sources and notice scope](../capabilities/workflow/shell/sources.md) and [MIT notice](../capabilities/workflow/shell/LICENSE.prezto)

### vim-tmux-navigator pane navigation

- **License (SPDX):** `MIT`
- **Incorporated material:** Neovim-aware pane navigation bindings adapted into `capabilities/workflow/tmux/tmux.navigator.conf`; the plugin itself is not installed
- **Detailed provenance:** [Tmux sources and notice scope](../capabilities/workflow/tmux/sources.md) and [MIT notices](../capabilities/workflow/tmux/LICENSE.notices)

### catppuccin-tmux status layout

- **License (SPDX):** `MIT`
- **Incorporated material:** Status and window layout of the omerxx fork reproduced in `capabilities/workflow/tmux/tmux.theme.conf`; the plugin itself is not loaded
- **Detailed provenance:** [Tmux sources and notice scope](../capabilities/workflow/tmux/sources.md) and [MIT notices](../capabilities/workflow/tmux/LICENSE.notices)

### Sesh and the sesh-bin recipe

- **License (SPDX):** `MIT` for Sesh; the AUR recipe it derives from declares no separate license
- **Incorporated material:** Recipe adapted from the AUR package `sesh-bin` into `capabilities/workflow/tmux/sesh/PKGBUILD`, keeping its maintainer line; the upstream release binary is downloaded and checksum-verified at build time, not stored
- **Detailed provenance:** [Tmux sources and notice scope](../capabilities/workflow/tmux/sources.md)
