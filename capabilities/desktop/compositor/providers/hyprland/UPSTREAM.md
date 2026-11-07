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

## Wallpaper alignment additions

The maintainer approved `SUPER+Ctrl+Space` ("Background switcher") for `wallpaper open` IPC, superseding its
Story 4.3 exclusion when backgrounds were not in the menu model. The source is installed Omarchy `4.0.6-1`
`default/hypr/bindings/utilities.lua:17`, SHA-256
`60b4ad67084d71222f04b118d6b5df0da7bc7b48169655674b84ae6d2f36b5ff`. This newer installed reference is not assigned
the global Git revision above. No default `next` or theme-switcher chord is added.

`defaults.lua` also adopts `disable_hyprland_logo = true` and `disable_splash_rendering = true` from installed
Omarchy `4.0.6-1` `default/hypr/looknfeel.lua:106-107`, SHA-256
`d257ea9864abb9cac124083bef88374659e759144a3d2028ec9486e578978804`, so an unavailable shell wallpaper exposes the
plain compositor background. The package's Git revision is unverified. These additions were deployed in the
reference VM; the chord and valid-background behavior received bounded attended checks. Missing/corrupt startup
presentation and real multi-output lifecycle are not visually qualified by those checks.

## Story 4.4 hardware additions

`hardware-bindings.lua` adapts the chords, descriptions and `locked`/`repeating` options from Omarchy
**4.0.6** (MIT), [media.lua](https://github.com/basecamp/omarchy/blob/v4.0.6/default/hypr/bindings/media.lua)
and [utilities.lua](https://github.com/basecamp/omarchy/blob/v4.0.6/default/hypr/bindings/utilities.lua).
This reference is distinct from the older global revision above. The MIT license and copyright attribution
above apply to these adaptations. All dispatchers call owned `/usr/share/mirroros/hardware/` commands;
media uses the approved `playerctl` command boundary instead of an Omarchy shell media service.
No Omarchy helper or shell service is imported. Keyboard-backlight bindings are omitted: supervised T14s
exploration on 2026-11-03 found firmware-handled Fn+Space and no delivered `XF86Kbd*` keys.

`display` is original MirrorOS Bash integration over native `hyprctl monitors all -j` and `hyprctl eval`
(`hl.monitor`). It follows Omarchy 4.0.6's connector allowlist, internal-panel identification and clean-scale
preset behavior, inspected read-only in the ISO package's `usr/bin/omarchy-hyprland-monitor-{internal,
internal-mirror,scaling,clamshell}`. It does not adopt their persistent toggle files, configuration parsing,
monitor-file edits, audit logging or reloads. `jq` from the signed Arch **extra** repository is a provider-owned
runtime dependency for parsing and validating the monitor JSON; `hyprland` also comes from **extra**.
No downloaded executable or additional package source is used.

Command interface (active graphical session required):

- `display laptop` toggles the internal panel, refusing to disable it without an active external display.
- `display mirror` toggles mirroring on the first active external output; the internal source is explicitly
  enabled first. Turning mirroring off returns to extended mode.
- `display scale up|down` steps the focused output through clean equivalents of 1, 1.25, 1.6, 2, 3 and 4.
- `display clamshell close|open` handles the lid switches (not launchable from keyboard help). Close disables
  only the internal panel when an external output is active; undocked close leaves suspend and lock to logind
  and hypridle. Open explicitly restores the panel with `disabled = false`. Mirrors are detached before their
  source is disabled so the external output remains usable.

All actions are runtime-only and disappear on reload or reboot. No monitor configuration is written, no
session process is restarted or reloaded, and no persistent layout manager or hotplug watcher is introduced.
Native monitor-rule defaults apply to omitted fields; runtime layout changes are not a backup of personal rules.
Unsafe connector names and invalid arguments are rejected before mutation; absent hardware is unavailable.
The explicit restore and mirror-source ordering follow the approved T14s exploration evidence
(`evidence/hardware/exploration-20261103T200419Z/`, ignored). Automated contracts cover bindings, connector
validation, display actions and exact entry-point migration; attended graphical acceptance remains Task 7.

`hyprland.lua` loads hardware bindings after product defaults initialize the staged registry and before personal
layers finalize it. `prepare-hyprland` additionally migrates only the exact prior layered entry point
(SHA-256 `0275ff2835bcd0fe6983fdc1bddf2420a8d16d29ce1bfff2ad38d3b5dd4ca924`); edited files and links remain
user-owned. This narrowly scoped migration lets existing managed sessions load the delivered hardware bindings
at their next configuration load without configure triggering that load.

## Update news

`defaults.lua` sets `ecosystem.no_update_news = true` to suppress Hyprland's own update-news popup in the
managed user session, including subsequent logins. This is original MirrorOS configuration using the native
option defined in [Hyprland v0.57.0 ConfigValues.cpp](https://github.com/hyprwm/Hyprland/blob/v0.57.0/src/config/values/ConfigValues.cpp)
and documented in the [Hyprland configuration options](https://wiki.hypr.land/configuring/core/config-options/).
No upstream code is copied. Donation prompts, permission controls, configuration errors and the greeter's
configuration are unchanged; no private version-tracking state is written by MirrorOS. Personal layers can
override this default. The regression test executes the defaults twice with a stubbed Lua API; attended
logout/login validation remains pending.

## Monitor defaults

`monitors.lua` is original MirrorOS configuration, using `HL.MonitorSpec` and `hl.monitor` from the installed
Hyprland 0.56.2 Lua API (`/usr/share/hypr/stubs/hl.meta.lua`). No upstream configuration is copied. Session and
greeter load the same file with `dofile` on every configuration load. A general rule requests preferred mode,
automatic position and scale 1; a specific rule requests `Virtual-1` at 1920x1080@60, automatic position and
scale 1.6. The local QEMU lab advertises that mode, but any other connector with the same name also matches.
The user session sets `GDK_SCALE=1`; the greeter does not load that setting. No kernel, firmware or live-console
mode is changed by these rules.

The QEMU-only `quirks.skip_non_kms_dmabuf_formats = false` in `defaults.lua` is original MirrorOS configuration;
no upstream configuration is copied. See
[Virtual display defaults](../../../../../docs/procedures/configure.md#virtual-display-defaults).

## Registration and reload

The prototype loaded these files into a running session with `hyprctl eval` and removed them with
`MirrorOSKeys.unbind_all()`, which crashed Hyprland 0.56.2 once (cause unknown). Production registers them at
configuration time instead: the managed `hyprland.lua` loads provider `defaults.lua`, which runs shell and window bindings with `dofile` at every configuration load; the entry point then runs hardware bindings with `dofile` before personal layers.
The registry table is created empty at each load; session bindings are staged until the personal binding layer finishes, and nothing is unbound by MirrorOS. Basis: the prototype observed
that runtime bindings do not survive a configuration reload, and Omarchy's `default/hypr/bootstrap.lua` clears its
own modules from `package.loaded` at each load, which indicates that the Lua state persists across reloads; `dofile`
therefore runs the files again where `require` would not. A repeated id or chord is a source error caught before
delivery by `tests/capabilities/desktop/hyprland-bindings.test.mjs`. Reload behavior in a real session is verified
only by the separately authorized session test, not by these sources.

## Reserved and unbound

Approved but not bound, because no owner implements the action yet: SUPER+Shift+Space (bar toggle; the shell has no
bar IPC), SUPER+Ctrl+I (idle-lock toggle; no owned hypridle control), SUPER+Shift+T (TUI system monitor not chosen),
SUPER+L / SUPER+Alt+L (workspace layout cycling), the Story 4.4 panels deferred to plans 02-27 to 02-30, and the Story 4.5
browser, file manager, editor, clipboard and capture keys. Hardware exclusions remain unbound:
SHIFT+XF86AudioMute (audio output switching), SHIFT+XF86AudioPause / SHIFT+XF86AudioPlay (media source switching),
XF86TouchpadToggle / XF86TouchpadOn / XF86TouchpadOff (outside the slice), XF86Eject (outside the slice), and
XF86KbdBrightnessUp / XF86KbdBrightnessDown / XF86KbdLightOnOff (not delivered by the explored keyboard).
Audio output/source switching belongs to plan 02-27. Final binding ownership across slices is Story 4.7.
