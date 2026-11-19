# Hyprland bindings upstream record

## Screenshot core additions (plan 02-40)

`omasnap/screenshot-bindings.lua` adapts PRINT, SUPER+CTRL+ALT+C and SUPER+CTRL+C from Omarchy
`520c3ed969d30b58defe03eb19d603f32b4cb002`, `default/hypr/bindings/utilities.lua` (MIT, David Heinemeier Hansson).
MirrorOSKeys and the neutral screenshot command replace Omarchy helpers; Capture uses existing `menu open capture`
IPC. The Omasnap layer rule follows v1.26.2's README, without `no_screen_share`. The exact `^mirroros-menu$`
rule adapts `default/hypr/apps/omarchy-shell.lua` at the same Omarchy revision: `no_anim=true`, `animation="none"`.
It prevents a closing-menu fade from entering the capture in the approved bounded VM selector/export check,
without a menu dispatch delay or global animation change. The provider owns the reviewed
Omasnap recipe with the explicitly approved two-file Save As portal patch, backend, user INI and runtime recent-document environment; see
[omasnap/sources.md](omasnap/sources.md) for source/recipe pins, Arch dependency observations, license and theme
contract/update requirements. Live campaign acceptance is pending; no screenshot qualification is implied here.

## Direct capture extras (plan 02-41)

`capture-extras/{ocr,qr}-backend` adapt Omarchy's `bin/omarchy-capture-text` and `bin/omarchy-capture-qr` at
[`520c3ed969d30b58defe03eb19d603f32b4cb002`](https://github.com/omacom/omarchy/tree/520c3ed969d30b58defe03eb19d603f32b4cb002).
They retain separate `hyprpicker -r -z`, startup wait, `slurp` and streamed `grim` flows, with cleanup on exit.
MirrorOS checks tool and copy failures, uses controlled journal messages and notifications, validates the selected
Tesseract models, and disables zbar D-Bus output. QR decoding is QR-only and never opens the result; the
clipboard copy remains sensitive. OCR uses the ordinary clipboard and preserves upstream recognition options.
Plan 02-42 adopts the reviewed Quattro delivery policy: the internal MirrorOS sender emits low-urgency transient
notices for successful OCR/QR copies and QR misses. The default sender identity bypasses Do Not Disturb.

`capture-extras/color-backend` retains `pkill hyprpicker || hyprpicker -a` from
`default/hypr/bindings/utilities.lua` (toggle introduced by
[`7540bddee`](https://github.com/omacom/omarchy/commit/7540bddee1503a79c213bb667cdf749bb55608cd)).
This toggle can also stop the freeze process used by OCR or QR; the cross-tool behavior requires live verification.
`omasnap/screenshot-bindings.lua` adapts SUPER+PRINT (Color) and SUPER+CTRL+PRINT (direct OCR) from the
same upstream bindings file, registering them through MirrorOSKeys and dispatching the neutral commands.
QR is menu-only. Existing screenshot bindings and layer rules are unchanged.
See [MIT notice](capture-extras/LICENSE.omarchy) and [capture command sources](../../../screenshot/sources.md).

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
| `shell-bindings.lua` | Adapted | `default/hypr/bindings/utilities.lua` 1-2, 7-10, 130; `default/hypr/bindings/input-method.lua` 19-20 | Keys and descriptions for menus, help, notifications and lock; MirrorOS registry helper, native `qs ipc` targets on the installed shell, XKB layout switching instead of fcitx, `loginctl lock-session`. SUPER+D (Apps) and the SUPER+apostrophe / SUPER+Alt+apostrophe Ferris Sweep forms are MirrorOS additions. Panel chords SUPER+Ctrl+A/B/D/N/P and SUPER+Ctrl+1..9 follow Omarchy v4.5.0 (`ac2690c`) `default/hypr/bindings/utilities.lua` 113-115, 118, 119, 122-131, dispatched through `hl.dsp.global("mirroros:<name>")` to the shell's GlobalShortcut set instead of `omarchy-shell`; The six notification comma chords follow Omarchy v4.5.0 (`ac2690c`), `default/hypr/bindings/utilities.lua` 24-29, through MirrorOS notification IPC, including manual silencing instead of a panel. SUPER+Ctrl+Alt+D (calendar, plan 02-32) follows the same file, line 116; SUPER+Ctrl+Alt+E (world clock, plan 02-33) follows the same file, line 117; SUPER+Ctrl+Alt+W (weather panel) is a MirrorOS assignment (Omarchy 4.5 line 110 sends a weather notification through `omarchy-*`). SUPER+Ctrl+R, SUPER+Ctrl+Alt+R and SUPER+Shift+Ctrl+R (set, show and clear reminders, plan 02-34) follow the same file, lines 104-106: set opens the shell's `reminders` IPC prompt instead of the Omarchy menu, and show/clear run the owned `/usr/share/mirroros/reminders/reminder` instead of `omarchy-reminder`. |
| `window-bindings.lua` | Adapted | `default/hypr/bindings/tiling.lua` 1-2, 5-8, 10, 17-20, 23-27, 30-34, 40-61, 63-76, 78-99, 101-103; `default/hypr/bindings/utilities.lua` 121-128; `default/hypr/bindings/applications.lua` 2, 12; `bin/omarchy-launch-terminal-tmux`; `applications.lua` 4-5 and `bin/omarchy-cmd-terminal-cwd` at `origin/quattro` `2d33fd5973eb349c3f7e3ae56e6c293516cc4e18` | Keys, descriptions and dispatcher shapes; the file manager keys run Strata through `uwsm app` and the owned `/usr/share/mirroros/files/files-cwd` (desktop/files) instead of Omarchy commands; workspaces are global with native dispatchers instead of the per-monitor helper; monitor moves use a direction selector; SUPER+Tab is back-and-forth (`previous`); SUPER+Shift+Tab and SUPER+Ctrl+Tab are not bound; terminals run Foot through `uwsm app`; Alt+Tab and Alt+Shift+Tab are one Lua function each (cycle, then bring to top). |
| `clipboard-bindings.lua` | Adapted | `default/hypr/bindings/clipboard.lua` at `quattro` `520c3ed969d30b58defe03eb19d603f32b4cb002` (MIT) | Universal SUPER+A/C/V/X and SUPER+Ctrl+V; explicit `send_key_state` down/up with a 50 ms oneshot timer and no window target; terminal tag detection strips one trailing `*`. MirrorOS registry ids replace `o.bind`; history dispatches `hl.dsp.global("mirroros:clipboard")` instead of an Omarchy panel; no Omarchy universal-paste export. |

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
SHIFT+XF86AudioMute ("Switch audio output", `locked`) follows the same media.lua chord and calls the owned
`audio-device cycle` instead of `omarchy-audio-output-switch` (plan 02-27).
No Omarchy helper or shell service is imported. Keyboard-backlight bindings are omitted: supervised T14s
exploration on 2026-11-03 found firmware-handled Fn+Space and no delivered `XF86Kbd*` keys.

`display` is original MirrorOS Bash integration over native `hyprctl monitors all -j` and `hyprctl eval`
(`hl.monitor`). It follows Omarchy 4.0.6's connector allowlist, internal-panel identification and clean-scale
preset behavior, inspected read-only in the ISO package's `usr/bin/omarchy-hyprland-monitor-{internal,
internal-mirror,scaling,clamshell}`. It does not adopt their persistent toggle files, configuration parsing,
monitor-file edits, audit logging or reloads. `jq` from the signed Arch **extra** repository is a provider-owned
runtime dependency for parsing and validating the monitor JSON; `hyprland` also comes from **extra**.
No downloaded executable or additional package source is used.

## Story 4.5 portal additions

The provider owns `xdg-desktop-portal-hyprland` (**extra**), the Screenshot and ScreenCast backend whose package
also ships `hyprland-share-picker`, and `grim` (**extra**), which that backend requires for the Screenshot portal; it
is a backend dependency, not a capture tool. `xdph.conf` is delivered to `~/.config/hypr/xdph.conf` with
`cfg_user_file`, because the backend reads only `$XDG_CONFIG_HOME/hypr/xdph.conf` or `~/.config/hypr/xdph.conf`; a
copy without the MirrorOS marker is user-owned and preserved. It sets only `allow_token_by_default = true`, so the
picker's restore-token box starts checked: Chromium's preview and share sessions then reuse one choice instead of
prompting twice, while every new share still prompts. This amends DEC-012 after the Story 4.5 laboratory and adapts
Omarchy `origin/quattro` (`2d33fd5973eb349c3f7e3ae56e6c293516cc4e18`, MIT) `config/hypr/xdph.conf` without its
`custom_picker_binary`. `hyprland-portals.conf` is original MirrorOS configuration delivered to
`/etc/xdg/xdg-desktop-portal/`, which replaces the `hyprland` package's
`/usr/share/xdg-desktop-portal/hyprland-portals.conf` whole. It keeps that file's `default=hyprland;gtk`, routes
`org.freedesktop.impl.portal.Secret` to the `gnome-keyring` declared by `desktop/portal`, and sets the FileChooser
backend selected by the Story 4.5 laboratory evaluation. The frontend and the GTK backend belong to `desktop/portal`.

The `mirroros-portal-dialogs` window rule in `defaults.lua` floats and centers the `xdg-desktop-portal-gtk`,
`hyprland-share-picker` and `io.github.lgse.Strata.FileChooser` classes (DEC-020). It adapts Omarchy
`origin/quattro` (`2d33fd5973eb349c3f7e3ae56e6c293516cc4e18`, MIT, the attribution above)
`default/hypr/apps/system.lua`, which floats every `xdg-desktop-portal-gtk` window through its `o.window` helper.
MirrorOS calls the native `hl.window_rule` API directly, checked against the Hyprland 0.57.1 stubs
(`/usr/share/hypr/stubs/hl.meta.lua`), and adds the share picker and the Strata chooser. The separate
`mirroros-portal-gtk-size` rule gives `xdg-desktop-portal-gtk` windows Omarchy's 875×600 floating-window size,
because the GTK file chooser otherwise requests a height above the reference VM's 1536×864 logical screen. It does
not import the Omarchy floating-window tag or the helper. Window classes are confirmed in the laboratory.

Command interface (active graphical session required):

- `display laptop` toggles the internal panel, refusing to disable it without an active external display.
- `display mirror` toggles mirroring on the first active external output; the internal source is explicitly
  enabled first. Turning mirroring off returns to extended mode. Starting a mirror records the external output's
  mode, position and scale in `$XDG_RUNTIME_DIR/mirroros-display-mirror.json` (mode 0600, session runtime state,
  not configuration); detaching that mirror, from the toggle or before disabling its source, reapplies a valid
  record and removes it. Without a valid record the mirror is only detached (ADR 0027).
  Hyprland 0.57.0 leaves a stale hardware cursor image on the mirror output (observed on the T14s with amdgpu;
  software cursors set while already mirrored do not clear it). Starting a mirror therefore also records
  `cursor:no_hardware_cursors` (`hyprctl -j getoption`, `.int` 0, 1 or 2) and sets it to 1 in the same
  `hyprctl eval`, before the mirror; detaching with a valid record restores the recorded value. If the setting
  cannot be read the cursor is left untouched; if Hyprland accepts the mirror but does not confirm it in time,
  no record is written and software cursors stay until the session reloads its configuration.
- `display scale up|down` steps the focused output through clean equivalents of 1, 1.25, 1.6, 2, 3 and 4.
- `display scale <value>` applies an absolute scale (1..4) to the focused output only if it is already clean for
  that mode (whole logical pixels in 1/120 steps, within 0.005 of the request); other values are refused (2).
- `display output <name> on|off` enables or disables one connector. `off` first detaches outputs mirroring `<name>`
  and refuses (4) when no independent enabled output would remain; an output that mirrors another source is not
  independent (DEC-042).
- `display state` prints JSON for the display panel: `focused`, `internal`, `external`, `backlight` (display
  backlight percentage from `brightnessctl --class=backlight`, or `null`) and `outputs` with name, enabled,
  focused, width, height, scale, internal and mirror source. It is read-only and takes no lock.
- `display clamshell close|open` handles the lid switches (not launchable from keyboard help). Close disables
  only the internal panel when an external output is active; undocked close leaves suspend and lock to logind
  and hypridle. Open explicitly restores the panel with `disabled = false`. Mirrors are detached before their
  source is disabled so the external output remains usable.

Every mutating action runs under one `flock` on `$XDG_RUNTIME_DIR/mirroros-display.lock` (10 s wait, otherwise
unavailable); the monitor state is read, validated and applied in a single `hyprctl eval` inside the lock, so
concurrent invocations cannot each disable a different last output (DEC-042). Hyprland applies monitor changes
asynchronously, so after the `eval` the action keeps the lock and polls `hyprctl monitors all -j` (up to 2 s) until
the requested enabled state or scale is reported; otherwise it exits 5 (not confirmed). The next action therefore
re-reads settled state, and the panel's refresh on exit shows the result (laboratory finding, plan 02-27). The
`output`, absolute `scale` and
`state` forms follow the Omarchy v4.5.0 (`ac2690c`) monitor panel's runtime `hl.monitor` disable/enable expression,
`bin/omarchy-hyprland-monitor-scaling` clean-scale rule and `bin/omarchy-monitor-state` fields as behavior
references only; no upstream code, text-size, DDC, Apple or audit-log path is incorporated.

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

## Story 4.5 clipboard additions

`clipboard-bindings.lua` follows the separate Omarchy revision in its per-file row, under the MIT attribution
above. The `mirroros-terminal` window rule in `defaults.lua` follows that revision's
`default/hypr/apps/terminals.lua` `+terminal` tag convention, but matches only
`^(foot|org\.codeberg\.dnkl\.foot)$`; no other terminal is selected. The binding module loads with `dofile`
after hardware bindings and before personal layers finalize and export the staged registry.

SUPER+A/C/V/X and SUPER+Ctrl+V are now bound as `clipboard.select-all`, `clipboard.copy`, `clipboard.paste`,
`clipboard.cut` and `clipboard.history`. Copy and paste send CTRL+SHIFT+C/V to terminal-tagged windows and
CTRL+C/V otherwise; select-all and cut always send CTRL+A/X. Omitting the window target also reaches focused
shell panels. The shell clipboard consumer is delivered separately in plan 02-38 Task 3.

`prepare-hyprland` migrates only the exact previous hardware entry point (SHA-256
`996c1273d5ad4ac3ecd69dcd3264eb3cb352a03afa2418b973ca48577a2546b3`) in addition to its earlier reviewed
hashes. Edited configurations and symbolic links remain user-owned; configure does not reload the session.

Known risk (#114): a Hyprland update can cause stuck synthetic modifiers or key-not-found errors. Release and
re-press the modifiers; if necessary, run `hyprctl reload`. Native CTRL+C/V and Foot CTRL+SHIFT+C/V remain the
permanent fallback. The down/up split follows upstream's workaround for
[Hyprland discussion #14099](https://github.com/hyprwm/Hyprland/discussions/14099), not a runtime guarantee.
Automated tests cover mapping, deferred release, registry export and exact migration; graphical behavior in Foot,
applications and shell panel fields remains subject to the plan's laboratory checkpoint.

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
configuration time instead: the managed `hyprland.lua` loads provider `defaults.lua`, which runs shell and window bindings with `dofile` at every configuration load; the entry point then runs hardware and clipboard bindings with `dofile` before personal layers.
The registry table is created empty at each load; session bindings are staged until the personal binding layer finishes, and nothing is unbound by MirrorOS. Basis: the prototype observed
that runtime bindings do not survive a configuration reload, and Omarchy's `default/hypr/bootstrap.lua` clears its
own modules from `package.loaded` at each load, which indicates that the Lua state persists across reloads; `dofile`
therefore runs the files again where `require` would not. A repeated id or chord is a source error caught before
delivery by `tests/capabilities/desktop/hyprland-bindings.test.mjs`. Reload behavior in a real session is verified
only by the separately authorized session test, not by these sources.

## Reserved and unbound

Approved but not bound, because no owner implements the action yet: SUPER+Shift+Space (bar toggle; the shell has no
bar IPC), SUPER+Ctrl+I (idle-lock toggle; no owned hypridle control), SUPER+Shift+T (TUI system monitor not chosen),
SUPER+L / SUPER+Alt+L (workspace layout cycling), and the Story 4.5
browser and editor keys and ALT+PRINT. The file manager keys SUPER+Shift+F and SUPER+Alt+Shift+F are bound
to Strata (plan 02-35, DEC-015). SUPER+Ctrl+B is bound to the Bluetooth panel (plan 02-29,
last reserved Story 4.4 panel chord). SUPER+Ctrl+N is bound to the network panel (plan 02-28; DEC-038 replaces
DEC-006's W with N, as in Omarchy 4.5); SUPER+Ctrl+W stays unbound. Hardware exclusions remain unbound:
SHIFT+XF86AudioPause / SHIFT+XF86AudioPlay (media source switching, TODO-013),
XF86TouchpadToggle / XF86TouchpadOn / XF86TouchpadOff (outside the slice), XF86Eject (outside the slice), and
XF86KbdBrightnessUp / XF86KbdBrightnessDown / XF86KbdLightOnOff (not delivered by the explored keyboard).
Final binding ownership across slices is Story 4.7.
