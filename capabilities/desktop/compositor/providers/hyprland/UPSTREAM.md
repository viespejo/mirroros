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

`hyprland.lua`, `defaults.lua` and `personal-loader.lua` are original MirrorOS configuration. The provider's `dwindle.preserve_split = true` follows the observed need of
SUPER+J (togglesplit) and matches Omarchy `default/hypr/looknfeel.lua` 93-95. The active border uses the
reviewed fixed theme accent `#509475`; the inactive border uses Hyprland's native `rgba(595959aa)` default.
The provider retains those literals as fallback and optionally resolves the reviewed product theme, loads its
Lua as text with an empty global environment, and validates both border values before applying them. A missing,
untrusted or invalid theme leaves the fallback. Checks are point-in-time and cannot protect against concurrent
privileged changes; an empty environment is not a resource sandbox. The provider separately sets a 2 px border,
active opacity 0.985, inactive opacity 0.96 and disables blur, without application-specific exceptions. Configure
migrates only exact previous Tokyo Night, jade or themed `hyprland.lua` deliveries; modified files and links are preserved.
A pre-existing `hyprland.conf` is also left untouched. The accent must stay in sync with the fixed palette.
The entry point loads product defaults, then existing user-owned `~/.config/hypr/{monitors,input,looknfeel,bindings,autostart}.lua` in that order. These are executable personal Lua, not trusted product theme files; configure creates commented monitor and bindings templates only when absent and never overwrites personal layers or links. Missing files are ignored, errors are reported and later layers continue, but changes made before an error are not rolled back. Use `MirrorOSKeys.bind` for new registered personal bindings; it rejects duplicate registered chords. Use `MirrorOSKeys.replace(id, description, dispatcher)` in personal `bindings.lua` to replace an existing registered action without changing its chord or options. Unknown ids, repeated replacements and invalid dispatchers are rejected. Bindings are staged until the personal binding layer has run, then registered and exported, including after a personal-file error; earlier personal changes are not rolled back. Direct `hl.bind` can bypass that registry and create duplicate chords. The shell leaves rows sharing a registered id non-launchable; an attended guest test confirmed that two direct bindings on the same chord both dispatched; graphical help with duplicate bindings remains unverified. Isolated config verification covers loading and fallback.

## Monitor defaults

`monitors.lua` is original MirrorOS configuration, using `HL.MonitorSpec` and `hl.monitor` from the installed
Hyprland 0.56.2 Lua API (`/usr/share/hypr/stubs/hl.meta.lua`). No upstream configuration is copied. Session and
greeter load the same file with `dofile` on every configuration load. A general rule requests preferred mode,
automatic position and scale 1; a specific rule requests `Virtual-1` at 1920x1080@60, automatic position and
scale 1.6. The local QEMU lab advertises that mode, but any other connector with the same name also matches.
The user session sets `GDK_SCALE=1`; the greeter does not load that setting. No kernel, firmware or live-console
mode is changed by these rules.

## Registration and reload

The prototype loaded these files into a running session with `hyprctl eval` and removed them with
`MirrorOSKeys.unbind_all()`, which crashed Hyprland 0.56.2 once (cause unknown). Production registers them at
configuration time instead: the managed `hyprland.lua` loads provider `defaults.lua`, which runs both files with `dofile` at every configuration load.
The registry table is created empty at each load; session bindings are staged until the personal binding layer finishes, and nothing is unbound by MirrorOS. Basis: the prototype observed
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
