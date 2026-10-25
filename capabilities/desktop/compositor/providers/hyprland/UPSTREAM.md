# Hyprland bindings upstream record

## Origin and scope

- **Project:** [Omarchy](https://github.com/omacom/omarchy).
- **Revision:** `7075b61c6aaa5d8589f6e816867508fc96dc49d9` (read-only reference).
- **License (SPDX):** `MIT`; the upstream text is kept unchanged in
  [../../../shell/LICENSE.omarchy](../../../shell/LICENSE.omarchy) and applies to the material listed here.
- **Copyright holder:** David Heinemeier Hansson.
- **Incorporation:** key choices, binding descriptions and Hyprland 0.56 Lua dispatcher argument shapes, selected
  by the maintainer family by family in the Story 4.3 prototype (approved keyboard table, Omarchy-first families
  A-J). No upstream file is copied and no Omarchy script, helper (`o.bind`, `o.workspaces`), plugin host or IPC is
  imported or executed.
- Original MirrorOS code remains `GPL-3.0-only`; upstream material retains its MIT terms.

## Per-file provenance

| Destination | Method | Source | Changes / scope |
|---|---|---|---|
| `shell-bindings.lua` | Adapted | `default/hypr/bindings/utilities.lua` 1-2, 7-10, 24-28, 130; `default/hypr/bindings/input-method.lua` 19-20 | Keys and descriptions for menus, help, notifications and lock; MirrorOS registry helper, native `qs ipc` targets on the installed shell, XKB layout switching instead of fcitx, `loginctl lock-session`. SUPER+D (Apps) and the SUPER+apostrophe / SUPER+Alt+apostrophe Ferris Sweep forms are MirrorOS additions. |
| `window-bindings.lua` | Adapted | `default/hypr/bindings/tiling.lua` 1-2, 5-8, 10, 17-20, 23-27, 30-34, 40-61, 63-76, 78-99, 101-103; `default/hypr/bindings/utilities.lua` 121-128; `default/hypr/bindings/applications.lua` 2, 12; `bin/omarchy-launch-terminal-tmux` | Keys, descriptions and dispatcher shapes; workspaces are global with native dispatchers instead of the per-monitor helper; monitor moves use a direction selector; SUPER+Tab is back-and-forth (`previous`); SUPER+Shift+Tab and SUPER+Ctrl+Tab are not bound; terminals run Foot through `uwsm app`; Alt+Tab and Alt+Shift+Tab are one Lua function each (cycle, then bring to top). |

`hyprland.lua` is original MirrorOS configuration. Its `dwindle.preserve_split = true` follows the observed need of
SUPER+J (togglesplit) and matches Omarchy `default/hypr/looknfeel.lua` 93-95; no other look-and-feel value is taken.

## Registration and reload

The prototype loaded these files into a running session with `hyprctl eval` and removed them with
`MirrorOSKeys.unbind_all()`, which crashed Hyprland 0.56.2 once (cause unknown). Production registers them at
configuration time instead: the managed `hyprland.lua` runs both files with `dofile` at every configuration load.
The registry table is created empty at each load and nothing is unbound by MirrorOS. Basis: the prototype observed
that runtime bindings do not survive a configuration reload, and Omarchy's `default/hypr/bootstrap.lua` clears its
own modules from `package.loaded` at each load, which indicates that the Lua state persists across reloads; `dofile`
therefore runs the files again where `require` would not. A repeated id or chord is a source error caught before
delivery by `tests/capabilities/desktop/hyprland-bindings.test.mjs`. Reload behavior in a real session is verified
only by the separately authorized session test, not by these sources.

## Reserved and unbound

Approved but not bound, because no owner implements the action yet: SUPER+Shift+Space (bar toggle; the shell has no
bar IPC), SUPER+Ctrl+I (idle-lock toggle; no owned hypridle control), SUPER+Shift+T (TUI system monitor not chosen),
SUPER+L / SUPER+Alt+L (workspace layout cycling), SUPER+slash / SUPER+Alt+slash (monitor scaling, Story 4.4), the
Story 4.4 panels, media and lid keys, the Story 4.5 browser, file manager, editor, clipboard and capture keys.
Final binding ownership across slices is Story 4.7.
