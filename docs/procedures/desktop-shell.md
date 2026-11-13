# Desktop shell procedure

**Availability:** production source and configure delivery are integrated (plan 02-19 Tasks 1/2). Task 3 has
clean-reference target/running evidence and bounded attended session results at candidate
`8c3c3cccc46421598b1fce47a330452c78230a80`; the maintainer accepted this bounded Task 3 result with its listed
limits. Mouse drag and quiet-runtime failures remain recorded under scoped exceptions. Nothing here claims a
ready complete Story 4.3 environment or laptop qualification.

The historical laboratory recipe and results remain in
[desktop-shell-prototype.md](desktop-shell-prototype.md); this procedure does not replace that record.

## Source layout

- `capabilities/desktop/shell/`: the owned Quickshell runtime with explicit composition in `shell.qml`
  (bar, menu with Apps launcher and selector, notifications, OSD, session actions). No plugin host,
  supervisor, Omarchy IPC, authentication or lock code ([ADR 0012](../adr/0012-owned-quickshell-desktop-shell.md)).
- [`UPSTREAM.md`](../../capabilities/desktop/shell/UPSTREAM.md): per-file provenance at the pinned Omarchy
  revision, license texts and open items.
- [`sources.md`](../../capabilities/desktop/shell/sources.md): ownership of defaults, preferences and
  private state, and the format justification.
- `tests/capabilities/desktop/shell/`: MirrorOS tests and tooling; not delivered with the runtime.

## Session delivery and lifecycle

`sudo operations/configure` (running system) or the installer's target-root run delivers the session; see the
[configure procedure](configure.md) for outcomes and conflicts.

| Concern | Owner | Delivered as |
|---|---|---|
| Shell runtime | `desktop/shell` | `/usr/share/mirroros/shell`, one manifest-checked tree |
| Shell startup and restarts | `mirroros-shell.service` user unit | `/etc/systemd/user/`, enabled per user, bound to the uwsm graphical session |
| Idle and lock requests | packaged `hypridle.service` + MirrorOS drop-in | `~/.config/hypr/hypridle.conf` |
| Lock surface and authentication | hyprlock + system PAM | `~/.config/hypr/hyprlock.conf` |
| Bindings and keyboard help registry | Hyprland configuration | `/usr/share/mirroros/hypr/{shell,window}-bindings.lua` |
| Terminal for `Terminal=true` entries | Foot | `~/.config/xdg-terminals.list` |

- The shell unit is the only startup owner (no Hyprland autostart, no supervision script). It restarts on
  failure at most five times a minute; then it stays failed: `journalctl --user -u mirroros-shell.service`.
- The shell and the lock are independent: hyprlock is started by hypridle's `lock_cmd`, never by the shell, so
  `systemctl --user restart mirroros-shell.service` leaves an active lock and hypridle running.
- Configure never starts or restarts anything. On a running session, either log out and in, or deliberately run
  `systemctl --user daemon-reload` and `systemctl --user restart mirroros-shell.service` (and
  `systemctl --user restart hypridle.service` only while unlocked).
- Keyboard: the session has the resolved layout first, then `us,es` without duplicates (`SUPER+I` /
  `SUPER+SHIFT+I`; [ADR 0015](../adr/0015-greeter-keyboard-layout-switching.md)), Compose on Right Alt, and every
  lock starts in the resolved layout and restores the previous one after unlocking; `SUPER+I` does not switch it
  at the lock screen (hyprlock follows only the first switch after locking), and the bar may briefly show the
  resolved layout while locking. The approved key table is registered at each configuration load; nothing is unbound
  at runtime. Keyboard help (`SUPER+K`) reads the registry the bindings export.
- Approved keys without an owner yet stay unbound and documented in the
  [Hyprland bindings record](../../capabilities/desktop/compositor/providers/hyprland/UPSTREAM.md): bar toggle,
  idle-lock toggle, TUI system monitor, layout cycling, monitor scaling and later-story keys.

Open risks: Failure of hypridle while
locked remains untested: its packaged control-group kill mode could end its hyprlock child; no safe outcome is
claimed. Task 3 inspected the real packaged unit and verified `Terminal=true` through uwsm, Foot and a real TTY
without foot-server; a maintainer-attended synthetic window confirmed the launch.

The shell does not hot reload (`settings.watchFiles: false` in `shell.qml`, DEC-049 in the
[panel infrastructure log](../technical-interviews/story-4-4-panel-infrastructure_log.md)): a running shell keeps
its loaded runtime after configure publishes a new one, and the new runtime takes effect at the next restart of
`mirroros-shell.service` or the next session. Quickshell's in-process reload keeps the inline component names a
file had when it was first loaded, so a reload after a file gained one failed with "`StreamRow` is not a type" in
plan 02-27 (laboratory and T14s), while a clean start loaded the same tree. A file the running shell first loads after
a publication may come from the new runtime (untested).

New Hyprland bindings delivered under `/usr/share/mirroros/hypr/` also require a new login or an explicitly
maintainer-authorized `hyprctl reload`; configure does not reload the compositor. Plan 02-28 verified this for
`SUPER+CTRL+N`. A shell restart alone does not load the compositor's new bindings.

## Shell panels

[ADR 0025](../adr/0025-shell-panels.md) panels (network, audio, display, power) open from their bar icon. Keyboard and
scripted requests use native Quickshell interfaces only; there is no own socket or CLI:

```bash
qs ipc -p /usr/share/mirroros/shell call audio toggle     # also open, close; targets bluetooth, network, audio, display, power, clock, weather, worldclock
hyprctl dispatch 'hl.dsp.global("mirroros:panel.audio")'  # GlobalShortcut, appid mirroros
```

Global shortcuts are `mirroros:panel.bluetooth`, `panel.network`, `panel.audio`, `panel.display`, `panel.power`, `panel.clock`, `panel.weather`, `panel.worldclock`, `panel.notifications` and
`panel-at-1` to `panel-at-9` (the Nth panel of the focused monitor's right bar section). The IPC result is
`opened`, `closed` or `unavailable` (no panel instance, for example the power panel without a battery). Requests
follow "focused monitor wins": `open` shows the panel on the focused monitor, moving it there if needed; `close`
closes it wherever it is; `toggle` closes it only when open on the focused monitor; a focus change alone moves
nothing. Inside an open panel, Tab and Shift+Tab move to the next or previous panel of the same bar section.
The panel chords are `SUPER+CTRL+B` (Bluetooth), `SUPER+CTRL+N` (network), `SUPER+CTRL+A` (audio), `SUPER+CTRL+D`
(display), `SUPER+CTRL+P` (power), `SUPER+CTRL+ALT+D` (calendar) and `SUPER+CTRL+ALT+W` (weather). Default positional numbering is Bluetooth 1, network 2, audio 3, display 4,
power 5; without a Bluetooth adapter its icon is not drawn and the numbering stays network 1, audio 2, display 3,
power 4. The `bluetooth` and `network` IPC targets expose only `open`, `close` and `toggle`.
Later panels follow the same convention. Panel actions run
owned commands in `/usr/share/mirroros/hardware/` as the session user; see the
[hardware procedure](hardware.md).

The Bluetooth panel's "Advanced…" action opens `uwsm app -- foot -e bluetoothctl --agent KeyboardDisplay` and closes
the panel; any mouse button on its icon toggles the panel and there is no right-click radio action.
The network panel's "Advanced…" action opens `uwsm app -- foot -e nmtui` and closes the panel. Enterprise setup
stays in that terminal path; PSKs use the native API. See the hardware procedure for DNS confirmation/trade-offs,
band states, diagnostics and the browser requirement for captive portals. The plan 02-26 network prototype
`053e7c3` was a design reference, not promoted code or copied tests; production was re-reviewed against Omarchy
`v4.5.0` (DEC-050 in the [network interview log](../technical-interviews/story-4-4-network-panel_log.md)).
Its VPN section (plan 02-30) opens `vpn-connect` in Foot; see [Connect and disconnect](hardware.md#connect-and-disconnect).

## Bar additions

Plan 02-31 adds three bar pieces adapted from Omarchy `v4.5.0` (see `UPSTREAM.md`); none starts a process.

- **Stay Awake** (indicator next to Dnd): a native Wayland idle inhibitor on a live bar window suspends the idle
  lock while active. It is runtime-only: off on every shell start, never written to disk. hypridle still owns idle
  detection and locking; `loginctl lock-session` and lock before sleep are unchanged.
- **Microphone** (before audio): visible only while an application captures the default source or the source is
  muted; the shell's own level meters are ignored. Click toggles mute, the wheel changes input volume by 5 % within
  0–100 %, middle click toggles the audio panel. Hidden, it leaves no gap.
- **Active window** (after the workspaces): "<application name> · <title>", only the name when the title is empty
  or equals it ignoring case, the raw app id without a desktop entry; full text in the tooltip. Left click focuses;
  no click closes a window.

Laboratory checkpoint (2026-11-10/11, guest `mirroros-ref`, final candidate `cf36bef`, temporary refs
`refs/mirroros-candidates/02-31-lab-{a,b,c,d}`): configure exit 0 with an unchanged rerun; qmllint passes with the
reviewed baseline (1910 keys, no new category); `check-panels`, `check-notifications` and `check-bar` pass. Stay
Awake held off a 30 s test timeout, also with a fullscreen window; clearing it, `lock-session` and a shell restart
restored locking, and no file or process appeared. Real suspend was not exercised (graphical resume fails in this
VM); hypridle's logind sleep delay lock with Stay Awake active was the approved substitute. All microphone and
active window states and clicks passed. The checkpoint fixed two defects that were also latent upstream (missing
`tooltipHovered`, an `implicitWidth` binding loop) and made the title comparison case-insensitive. Hazard: restarting
hypridle while locked kills hyprlock (it runs in the hypridle unit); recovery needed
`hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'`. Evidence: `evidence/bar-additions/lab-02-31/checkpoint.md`
(ignored).

Supervised T14s microphone checkpoint (2026-11-11, non-qualifying, candidate `cf36bef` in a fresh checkout):
configure exit 0 with an unchanged rerun. The physical mic-mute key showed the muted glyph with the LED on, and the
LED also followed mute from the bar; with a capture client the indicator was highlighted and muting from the bar
silenced its recording. No call client was installed, so a `pw-record` capture with per-second levels was the
approved substitute for a real call; wheel and middle click were not exercised there. Finding: a persisted inline
setting (here power `showPercentage`) stores the whole layout zone in `$XDG_CONFIG_HOME/mirroros/shell.json`, and
since arrays replace defaults, later default widgets such as the microphone do not appear; removing a redundant
`bar.layout` override restores them. Evidence: `evidence/bar-additions/t14s-02-31/checkpoint.md` (ignored).

## Clock calendar

Plan 02-32 adds Omarchy's calendar panel under [ADR 0029](../adr/0029-clock-calendar-weather-and-world-clock-panels.md):
`panels/clock/{Panel.qml,Model.js,WallClock.qml}` are unchanged `v4.5.0` copies, hosted by the bar clock. Left
click on the clock and `qs ipc -p /usr/share/mirroros/shell call clock open|close|toggle` open or close it in the
shared panel container; Tab and Shift+Tab move between it and the other panels of the center section. Right click
still cycles the label format; middle click has no action (the timezone picker is excluded). The panel runs no
process.

Inside the panel, the arrow keys, `[`/`]` and `{`/`}` step months and years, `t` returns to today and `w` (or
a click on the "W" heading) toggles the week start. Double-clicking the year bar asks for a birth year and a life
expectancy; only then does the memento-mori bar appear, and double-clicking it clears the birth year. These
opt-in settings are stored per widget like any inline setting (see [Inline settings](#inline-settings)):

```json
{
  "version": 1,
  "bar": { "widgets": { "omarchy.clock": { "weekStartDay": "sunday", "birthYear": 1979, "lifeExpectancy": 85 } } }
}
```

Without `weekStartDay` the week starts on the locale's first day. Deleting a key restores its default.

## Weather

Plan 02-32 adds a weather pill and panel adapted from Omarchy under
[ADR 0029](../adr/0029-clock-calendar-weather-and-world-clock-panels.md). The pill sits in `centerEnd`, after the
clock; any click on it and `qs ipc -p /usr/share/mirroros/shell call weather open|close|toggle` open or close the
panel, which joins Tab switching in the center section. No location ships: until one is saved the pill shows a
neutral glyph without a reading, the panel shows a "No location" hero with the city search focused, and nothing
is requested.

The hero reports the active location (temperature, pinned name, feels, wind, humidity, three-day forecast).
Clicking the pinned name opens the city search, which replaces the active location. The other saved locations
follow under a "SAVED LOCATIONS" header as compact rows in saved order: clicking a row makes it active and the previous active one returns to the
list; the circular "×" shown on hover removes a non-active row, so the active and the last location stay.
"+ Add location" appends a location without changing the active one; the first location added becomes active.
Keys follow Elsewhen's list: `j`/`k` or the arrows move a highlight over the hero, the rows and "+ Add location"
(wrapping round); Return or Space activates the highlighted row, opens the add search on the button or the
replace search on the hero; `x` or Delete removes a highlighted non-active row; `a` or `+` adds a location; Tab
and Shift+Tab switch panels, also from a search field.
The list is stored like any inline setting (see [Inline settings](#inline-settings)):

```json
{
  "version": 1,
  "bar": { "widgets": { "omarchy.weather": {
    "locations": [{ "name": "Oslo", "latitude": 59.91273, "longitude": 10.74609 }], "active": 0 } } }
}
```

Units follow an optional `"unit": "metric"` or `"imperial"` in the same object, otherwise the POSIX measurement
locale: `LC_ALL` overrides `LC_MEASUREMENT`, which overrides `LANG` (fallback: `C`). For example, `LANG=en_US.UTF-8`
with `LC_MEASUREMENT=es_ES.UTF-8` shows Celsius and km/h without changing the English UI. This applies to the
pill, current and feels-like temperatures, saved-location rows, forecast and wind; it changes no stored settings
or requests. `LC_TIME` and `LC_NUMERIC` alone do not select measurement units. Requests
go only to fixed `https://api.open-meteo.com` and `https://geocoding-api.open-meteo.com` URLs, through `curl`
(declared in the shell `packages` file) with argument vectors and a 5-second limit. While the panel is closed
only the active location is fetched, every 30 minutes; opening the panel fetches every location in one combined
request. Nothing is fetched while the session is locked (hypridle's lock marker, as for notifications), and
unlocking refreshes. The city search runs only while typing in the open panel. A failed request keeps the
previous values and is not retried before the next scheduled refresh.

Laboratory checkpoint (plan 02-32, 2026-11-11, guest `mirroros-ref`, final candidate `11e2921`, temporary refs
`refs/mirroros-candidates/02-32-lab-{a..h}`): configure exit 0 with unchanged reruns; qmllint passes with the
reviewed baseline (2254 keys, no new category); `check-panels`, `check-notifications` and `check-bar` pass.
Starting without `shell.json`, every inline setting (clock format, week start, birth year, weather locations) was
written only under `bar.widgets.<id>`, never `bar.layout`. Calendar click, IPC, Tab switching and opt-in settings
passed. Weather made no request without a location; the geocoder ran only while typing; a closed panel fetched
only the active location; opening fetched all locations in one request; nothing ran while locked and unlocking
refreshed the active location; offline, one failed request kept the previous values with no retry. The 30-minute
tick was not observed at runtime (test-level only). The checkpoint fixed Tab being trapped in the weather search,
and added Elsewhen's list keys, the "×" overhang and the "SAVED LOCATIONS" header to the weather panel, and the
`SUPER+CTRL+ALT+D`/`SUPER+CTRL+ALT+W` panel shortcuts (after configure, a maintainer-authorized `hyprctl reload`
loads them). Evidence: `evidence/calendar-weather/lab-02-32/checkpoint.md` (ignored).

## World clock

Plan 02-33 adds Omarchy's Elsewhen world clock (MIT, Jason Fried) under
[ADR 0029](../adr/0029-clock-calendar-weather-and-world-clock-panels.md). Its globe icon sits in `centerEnd`,
before the weather pill; any mouse button on it and `qs ipc -p /usr/share/mirroros/shell call worldclock
open|close|toggle` open or close the panel, which joins Tab switching in the center section. Tab and Shift+Tab
also switch panels while typing in a search field.

Each row shows a city's time, date, UTC or home offset, daylight strip and open-meteo temperature; hovering shows
a local greeting (Han, Kana and Hangul greetings use `noto-fonts-cjk`, declared in the shell `packages` file). Dragging a row reorders it, the hover "×" removes it (the last city stays), "+ Add a city"
searches zones and geocoder places, and dragging along a daylight strip (or the left and right arrows) shifts every
row's time; a drag returns to now shortly after release, the arrows hold until Escape or close. Clicking a time toggles 24-hour time, an offset toggles UTC and home offsets,
and a temperature toggles Celsius and Fahrenheit. No city ships: on the first open the panel writes the home city
(from the system zone) plus four computed destinations. The list and toggles are stored like any inline setting
(see [Inline settings](#inline-settings)) under `bar.widgets["omarchy.elsewhen"]`, for example
`"cities"`, `"here"`, `"hour24"`, `"offsetMode"` and `"units"`.

Clicking the hero caption opens "Where are you?", which names the city that represents the machine. It offers only
zones and places in the machine's own zone; the system time zone is never changed, and a stored choice resets on
its own when the zone changes by other means.

Nothing runs while the panel is closed. Opening it probes zone offsets with `TZ=<zone> date` and
`timedatectl show` (repeated every five minutes while open), loads `timedatectl list-timezones` for the search and
requests temperatures: one batched `https://api.open-meteo.com` forecast for the rows whose reading is older than
20 minutes (checked on open and every 15 minutes while open) and `https://geocoding-api.open-meteo.com` lookups only for rows without coordinates, through `curl` with
argument vectors. A failed lookup falls back to `/usr/share/zoneinfo/zone1970.tab` coordinates (`tzdata`, declared
in the shell `packages` file); a failed forecast keeps the previous temperatures and starts no retry. There are no
people, GitHub avatars, big globe or panel-own IPC; clicking the hero mini globe opens nothing.

Laboratory checkpoint (plan 02-33, 2026-11-11, guest `mirroros-ref`, final candidate `b229266`, temporary refs
`refs/mirroros-candidates/02-33-lab-{a..g}`): configure exit 0 with unchanged reruns; qmllint passes with the
reviewed baseline (2436 keys, new category `id-shadows-member` from upstream `Panel.qml`); `check-panels`,
`check-notifications` and `check-bar` pass. With the panel closed after a shell restart, no `date` or `timedatectl`
ran and no `cities` were written; the first open wrote the home city plus four destinations under
`bar.widgets["omarchy.elsewhen"]`, never `bar.layout`, with read-only `timedatectl` probes, geocoder lookups for
rows without coordinates and one batched forecast. Click, IPC, `SUPER+CTRL+ALT+E` (after a maintainer-authorized
`hyprctl reload`), Tab and the `centerEnd` order passed; adding, removing, reordering, scrubbing, greetings and
search passed; "Where are you?" offered only the machine's zone and no `sudo`, `set-timezone` or notification
helper ran; no people button, and the mini globe opened nothing. Offline with fresh readings, the open panel kept
its temperatures and made no request; a failing request and the `zone1970.tab` fallback were not exercised. Rows
without stored coordinates are geocoded again on each open (upstream behaviour). The checkpoint fixed the panel's
sibling types (directory import in the host), Tab being trapped in the search fields and missing CJK glyphs
(`noto-fonts-cjk`), and aligned bar glyphs with Omarchy v4.5.0 (`OpticalGlyph.qml`, `paintedSize`). Evidence:
`evidence/world-clock/lab-02-33/checkpoint.md` (ignored).

## Reminders

Plan 02-34 adds Omarchy's quick reminders as a scope change without an ADR (DEC-030): no daemon, privilege,
network or provider. A reminder is relative and ephemeral ("in N minutes, remind me of X") and ends with the
session. The owned command `/usr/share/mirroros/reminders/reminder` (capability `desktop/reminders`, see its
[sources](../../capabilities/desktop/reminders/sources.md)) schedules a transient systemd user timer
`mirroros-reminder-<minutes>m-<epoch>-<pid>`; a message is kept only in
`$XDG_RUNTIME_DIR/mirroros/reminders/<unit>.message`, never on the unit's command line.

- **Set:** the shell prompt asks for a positive whole number of minutes, then an optional message, and runs
  `reminder <minutes> [message]` with an argument vector; `reminder <minutes> [message]` works from a terminal too.
  Invalid minutes give a transient "Invalid reminder" notice and schedule nothing; an empty first step closes the
  prompt. A transient confirmation states the due time.
- **Indicator:** the bar's `Reminder` indicator (default indicators `Reminder`, `Dnd`, `StayAwake`) shows the
  pending count in its tooltip on every bar. The shell's `mirroros.reminders` service runs `reminder show --json`
  once at shell start and once per `reminders refresh` IPC call, which the command makes after it sets, delivers or
  clears a reminder; nothing polls. A click runs `reminder show` when reminders are pending, otherwise it opens
  the prompt.
- **Show and clear:** `reminder show` sends one transient "Upcoming reminders" notification; `reminder clear`
  stops every `mirroros-reminder-*` timer, removes their message files and shows a transient notice.
- **IPC:** `qs ipc -p /usr/share/mirroros/shell call reminders open|refresh` (both return `ok`); `reminder -i`
  calls `open`.
- **Bindings:** `SUPER+CTRL+R` opens the prompt (`reminders open`), `SUPER+CTRL+ALT+R` runs `reminder show` and
  `SUPER+SHIFT+CTRL+R` runs `reminder clear` (Omarchy `utilities.lua` 104-106). They are registry entries, so the
  `SUPER+K` keybinding help lists "Set reminder", "Show reminders" and "Clear reminders".
- **Delivery:** a Critical, non-transient "Reminder" notification from app `reminder` that stays until dismissed
  and remains in history, with the freedesktop `alarm-clock-elapsed` sound through `pw-play` (silenced only by
  system mute; a sound failure does not block the notification).
- **Do Not Disturb:** only the Critical delivery passes quiet mode and snoozes (`Delivery.bypassesQuiet`). The
  confirmation, listing, clear and invalid-input notices are normal-urgency transient notifications: they are
  silenced like any other and do not enter history, so they are invisible while Do Not Disturb is on.
- **Session end:** timers, their services and `$XDG_RUNTIME_DIR` go away with the user manager at logout; no
  reminder is delivered in a later session.

Checks: `systemctl --user list-timers 'mirroros-reminder-*'` lists pending reminders, `systemctl --user cat
<unit>.service` must not contain a message, and `reminder show --json` returns `{count, active, tooltip,
reminders[]}`.

Laboratory checkpoint (plan 02-34, 2026-11-11, guest `mirroros-ref`, final candidate `b42c74e`, temporary refs
`refs/mirroros-candidates/02-34-lab-{a,b}`): configure exit 0 with an unchanged rerun (20/20); qmllint passes with
the reviewed baseline (2447 keys, no new category); `check-notifications` and `check-bar` pass. A reminder set
from the prompt kept its message, quotes and `$(…)` included, verbatim in the 0600 message file and off the unit;
delivery came from the user manager as a Critical notification that stayed until dismissed, stayed in history and
played the alarm sound, also with Do Not Disturb on, where the confirmation was silenced and kept out of history.
The indicator, the click (listing, or the prompt at zero), the three bindings, `clear`, the invalid-input notice and
the `SUPER+K` help passed. Executions were counted with an `inotifywait` open watch on the command: one
`show --json` per set, delivery, clear or shell start, none while idle. Logout stopped the user manager with a
reminder pending; the next login had no unit, no message directory and no delivery. Delivery may lag the shown
time by up to a minute (systemd's default timer accuracy). Logout only ends reminders when no other session of the
user survives: in the guest, `inotifywait` processes leaked by the check scripts had kept old SSH sessions in
`closing` and were removed first. Evidence: `evidence/reminders/lab-02-34/checkpoint.md` (ignored).

## Fixed palette

At startup the shell invokes the fixed product resolver for `$XDG_STATE_HOME/mirroros/current/theme`
(falling back to `~/.local/state`). The resolver accepts any published product theme whose palette is trusted (only
the reviewed default is published today); missing, unknown or untrusted selections warn and use the default after
its palette path is checked. If the resolver or the trusted
default is unavailable, the shell keeps its built-in palette. While resolution runs, built-in colors are used.
The shell reads `foreground`, `background`, `accent`, `muted` and `red` from the resolved product palette;
`red` supplies the urgent role. Each must occur once as a
quoted `#RRGGBB` string. If the file cannot be read or any required value is absent, duplicated or invalid,
the shell logs a warning and retains its complete built-in palette. Other entries are ignored. This is a
restricted reader, not general TOML or third-party theme support. The shell also reads the supported surface
settings from the product `shell.toml` only when its path, owners and permissions pass the product trust check,
otherwise it warns and uses fallback settings. This check is point-in-time and does not prevent concurrent
privileged changes. It also reads optional `$XDG_CONFIG_HOME/mirroros/shell.toml` (defaulting to
`~/.config`); personal settings take precedence per key. Supported sections and keys are listed in
`Commons/SurfacePalette.js`. Colors accept quoted `#RRGGBB`, palette roles (`foreground`, `text`, `background`,
`accent`, `urgent`, `muted`), `transparent`, and references to supported color settings such as
`hyprland.active-border`; alpha values are finite decimals from 0 to 1. Invalid, duplicate, unknown-alias or
cyclic settings are omitted individually with a bounded warning; missing files are optional. Unknown sections and
keys are ignored. Theme and personal files are never written or watched, and this is not general TOML or Omarchy
theme compatibility. With a valid product palette, tooltip background alpha is 0.97 and menu selected-border alpha
is 0.25; otherwise the previous built-in values 1.0 and 0.0 apply unless personally overridden.

## Wallpaper interface (deployment validation pending)

[ADR 0020](../adr/0020-wallpaper-selection.md) extends the shell with bounded wallpaper display and selection.
The aligned source is not permanently deployed or visually qualified. After deliberate publication and loading:

```bash
qs ipc -p /usr/share/mirroros/shell call wallpaper open
qs ipc -p /usr/share/mirroros/shell call wallpaper close
qs ipc -p /usr/share/mirroros/shell call wallpaper next
qs ipc -p /usr/share/mirroros/shell call wallpaper set '/path/to/existing/image.png'
qs ipc -p /usr/share/mirroros/shell call wallpaper refresh
```

`Super+Ctrl+Space` (Background switcher), Style > Background and double-left-click open the integrated picker.
The chord supersedes its earlier exclusion in the Story 4.3 keyboard table. There is no default `next` chord;
personal bindings can invoke the fixed IPC command. Double-right-click has no action.
`open` uses the focused output, falling back to the first; double-click uses the clicked output. The picker
retains Omarchy's skewed carousel, arrows, Tab/Shift+Tab, Enter, Escape and mouse selection, with thumbnails and
without labels or a filter, matching Omarchy's background invocation. Output removal closes it.

The theme step delivers six numerically prefixed images inside `/usr/share/mirroros/themes/default/backgrounds/`
and initializes `$XDG_STATE_HOME/mirroros/current/background` to the approved logo image (`2-mirroros-jade.png`) only if that path is absent.
Existing links, files and directories are preserved. State falls back to `~/.local/state` when the XDG path is
absent or relative. The shell reads the selection with `readlink -f` at startup and on `refresh`; it does not
choose a startup default or migrate obsolete `selection.json` files. Inspect the current selection with:

```bash
readlink -f "${XDG_STATE_HOME:-$HOME/.local/state}/mirroros/current/background"
```

The catalog reads `current/theme/backgrounds/` and
`$XDG_CONFIG_HOME/mirroros/backgrounds/<resolved-theme-name>/` (fallback `~/.config`). The theme name is the final
component of the resolved `current/theme` target, not a second state file. Directories are resolved before
`find -L`, image extensions are filtered and NUL paths sorted. Missing directories are empty; other scan errors
are reported without acting on stale rows. `next` scans every call, wraps across all entries and starts at the
first when the selection is outside the catalog. An empty scan sends “No background was found for theme” through
the notification service for two seconds. The picker deduplicates by basename, first sorted path wins; `next`
does not, reproducing Omarchy's distinction. Links to individual personal images can still differ from their
saved resolved targets, as in Omarchy.

Install > Style > Background creates the personal directory with `mkdir -p` and opens it with `xdg-open` and fixed
argv; xdg-utils resolves `inode/directory` through desktop/portal's `/etc/xdg/mimeapps.list` to the file manager
delivered by `desktop/files` (Strata), and a user association takes precedence. The shell names no file manager
binary, and no preferences or optional integrations are set by this action. Plan 02-35 confirmed in the reference VM
that the folder opens in Strata ([portals and files](portals-and-files.md)). Personal
images are never copied, modified or deleted. Opening scans and generates missing thumbnails before showing the
picker. Its cache is `$XDG_CACHE_HOME/mirroros/image-selector/` (fallback `~/.cache`), with size/mtime signatures,
index and per-thumbnail locks; libvips generates 1536x864 centre-cropped JPEGs, Q82, metadata stripped.

`set` accepts any existing file, not just catalog entries. The helper resolves it and writes the managed symlink
with plain `ln -nsf` before requesting display. A non-symlink file or real directory at the selection path is a
reported conflict and is not overwritten. There is no selection lock, external-edit detection or atomic rename.
The shared 420 ms reveal starts on the first ready output; it does not wait for every output. There is no load
timeout, rejection/acknowledgement protocol, rollback or fallback. A corrupt existing file is saved: the previous
image stays during that session if the incoming image never becomes ready, but restarting with that selection
leaves the background empty until a valid image is selected. Hyprland's provider disables its logo and splash,
so the compositor's plain background remains visible. No custom fallback color is imposed.

IPC returns `accepted` when starting an asynchronous operation, not when saving, decoding or displaying finishes;
failures are reported in the shell journal. Overlapping operations return a busy error and are not queued. There
is no `status` action. When the shell is absent, `qs ipc` fails; no fallback daemon or state writer runs.
The dependency-gated `wallpaper-applications.test.mjs` probes real libvips decoding/cache reuse for all six product
backgrounds and, since plan 02-35, delegation of the folder action to the real `xdg-open` with a temporary
`inode/directory` association and a fake desktop handler. Its earlier version probed real Nautilus folder opening,
confirmed through its D-Bus OpenLocations property, on private D-Bus and headless Weston with temporary user
directories; the historical evidence below refers to that version. These passed in the reference VM after separately authorized
package installation. Nautilus warned about a missing Mutter-specific service channel; portal dialogs were not
tested. After a separately authorized bounded deployment, installed manifests, tracked Hyprland files, wallpaper
IPC and the registered chord were verified. The maintainer reported the jade background, chord and desktop
double-left-click access, arrow/Enter selection, Escape cancellation and subsequent terminal typing all appeared
OK on the reference VM's single output. This is a bounded attended smoke result, not exhaustive focus or visual
qualification. A subsequent shell-only restart preserved the saved logo selection and restored the active service
and IPC; the maintainer confirmed that the logo remained visible and Install > Style > Background opened Nautilus.
One separately authorized VM reboot also preserved the selection, restored the shell and IPC without Hyprland
configuration errors, and the maintainer confirmed the logo remained visible after login. This does not qualify
arbitrary reboot/logout cycles or laptop behavior. Real multi-output lifecycle/hotplug is blocked because no second
output is available in this context; it is neither passed nor failed and remains a qualification gate. PipeWire
and its socket started after boot and the earlier connection error did not recur; actual audio remains unqualified.
The portal app-ID registration warning recurred. Read-only follow-up confirmed that the main and GTK portal
services were active, Settings reads succeeded and FileChooser was exposed. Duplicate/late registration during
Qt startup is a plausible, unproven explanation; dialogs and the shell's own portal connection remain unqualified.
No provider change or warning suppression was applied. Product backup and rollback material are retained; rollback has not been tested.
See the [research checkpoint](../technical-interviews/wallpaper-selection-research.md#installed-session-and-attended-validation-checkpoint)
for evidence and limits.

## Defaults, preferences and private state

| Item | Path | Owner |
|---|---|---|
| Common defaults | `defaults.json` beside `shell.qml` | MirrorOS, versioned |
| Personal overrides | `$XDG_CONFIG_HOME/mirroros/shell.json` (fallback `~/.config`) | User |
| Notification state | `$XDG_STATE_HOME/mirroros/shell/notifications/` (fallback `~/.local/state`) | Shell, private |
| While-away count | `while-away.json` in the notification state directory | Shell, private |
| Wallpaper selection | `$XDG_STATE_HOME/mirroros/current/background` (fallback `~/.local/state`) | Shell-managed symlink; theme configure initializes only if absent |
| Lock marker | `$XDG_RUNTIME_DIR/mirroros-shell-locked` | hypridle lock hooks |

To keep a device-local exception, set it in the interface or add only that key to `shell.json`, for example:

```json
{
  "version": 1,
  "notifications": { "fontScale": 110 }
}
```

To return to the common default, delete that key (or the whole file). An invalid file is reported in the
shell's log (`Preserving unsupported …`), the defaults apply and the file is left untouched until it is
fixed. To promote a choice for every device, edit `defaults.json` in the repository and review the change.

Notification history keeps 24 hours and at most 100 entries by default and restores active cards (DEC-020).
Its files are private (directory `0700`, files `0600`); never copy them into evidence.

## Inline settings

Settings changed from a bar widget or its panel (clock format, tray pins, power percentage, weather locations, world-clock cities) are stored per widget
id under `bar.widgets` in `shell.json`, holding only the keys that differ from the widget's layout entry
(DEC-035/039). Saving never writes `bar.layout`, so later default layout changes still reach the device:

```json
{
  "version": 1,
  "bar": { "widgets": { "omarchy.clock": { "format": "HH:mm" } } }
}
```

Precedence is the `defaults.json` entry, then a hand-written `bar.layout` entry, then `bar.widgets.<id>`. A key
set back to its layout value, or no longer sent by the widget, removes its override; deleting the widget's object
restores every default. A `bar.widgets` that is not an object of objects makes the file invalid (preserved, not
written).

Files saved before this change may still hold a whole zone under `bar.layout` (for example `bar.layout.right`
with a stored `showPercentage`), which hides widgets later added to that zone by default. There is no automatic
migration: move the setting by hand into `bar.widgets.<id>` and delete the `bar.layout` zone, for example
`"bar": { "widgets": { "omarchy.power": { "showPercentage": true } } }`.

## Behavior notes

- **Selector replacement (DEC-027):** opening another selector or a regular menu completes the pending
  selector request as cancelled: its done file appears and its selection file stays empty.
- **Notification `omarchy-exec-argv`:** preserved. Argv is validated structurally, executed literally with
  fixed positional data and only on a user click. Any same-user session-bus sender can set it; a sandboxed
  application reaching the session bus could therefore have a click run argv outside its sandbox. No sender
  authorization or sandbox guarantee is claimed.
- **Color-only states** follow the Omarchy reference (Story 4.3 criterion aligned under DEC-015/DEC-026).
- **While-away count (DEC-021/022):** notifications that arrive while the session is locked (new,
  non-transient ones; replacements excluded) are counted. The bar's notification indicator shows the count
  on return as a small superscript on the bell (capped at `9+`); unlocking does not clear it. Expanding the panel's history section marks it seen and it clears
  when that panel closes (clearing at once would remove the indicator hosting the open panel). The lock state is the
  lock marker, which hypridle's compositor-backed `on_lock_cmd`/`on_unlock_cmd` create and remove before
  calling the shell's `notifications lockChanged` IPC function; the shell also reads it at startup, so a
  restart during the lock reconciles. hypridle re-emits the lock on startup and its unit removes a stale
  marker before starting. Residual risk: if hypridle stays stopped while the session is unlocked, the
  marker is stale and the count stays hidden until hypridle starts again. The hooks and unit cleanup are
  delivered with the lock configuration (`capabilities/desktop/lock/`); with a user-owned
  `hypridle.conf` without them, the marker never appears and no count is shown. No content reaches the lock surface or the stored state.
- **Known inherited defect, not repaired:** with the notification panel open from the indicator, turning
  Do Not Disturb off (with nothing else active) removes the indicator from the bar's active block and
  destroys the panel; turning it on keeps the panel open. The behavior comes from upstream
  `Indicators.qml`; no data is lost.
- **Visual observation, inherited:** the bell glyph sits about 1-2 px above the clock's capitals; glyphs
  are centered by their painted bounds and the clock as a text line. Global bar alignment belongs to
  Story 4.8 and is not changed here.
- **Known upstream issue:** during the repeated hour of a daylight-saving change, Quickshell's
  `SystemClock` (bar clock) logs `QTimer::start: negative intervals` continuously; it ends with that hour.
  The quiet-log checks fail in that window and must be rerun afterwards.

## Final-source verification checkpoint

Plan 02-19 Task 3 received A (Accept) for its bounded evidence and explicit limits, not complete story readiness.
The reference used a verified base ISO at source `d9edb3d` plus separately
verified candidate inputs at `8c3c3cc`, not an unchanged final-source release ISO. Selected run evidence is under
`evidence/desktop-shell-production/candidate-20261025T032813Z-amended/` (ignored, hash-checked and secret-scanned).

| Check | Observed outcome |
|---|---|
| Clean candidate contracts | Mechanism Bats 85/85 with `--jobs 1`; other five affected contracts 52/52 with `--jobs 8`; Node 27/27; menu model 12/12; provenance 93 files; i18n checks passed. These are selected suites, not the whole repository. |
| Target/running configure | Target all 10 steps changed; first running 9 unchanged/Hyprland changed; identical second running all 10 unchanged. No running package transaction or process restart observed. First-running session-file difference has no established cause. |
| Installed QML | 57 files, 829 reviewed warnings, no new/stale baseline entries; checker 0. This is not zero diagnostics. |
| Selector and dmenu | Selector replacement 17 PASS, exit 0; dmenu 26 PASS, exit 0. Keyboard injection was not run; pointer cancellation remains unverified. |
| Original graphical suites | Menu exit 1 (64 PASS/4 quiet failures); bar exit 1 (5/1); notifications exit 1 (7/1); OSD exit 1 (7/1); while-away exit 1 (17/1). Counts include lint where invoked; early-stopped checks were not passes. |
| Functional continuation | Authorized diagnostic-only copies of bar/notification tests reached their ends: sparse save/no-op, restart, live config, default updates/reset, invalid-file preservation, restored notifications/quiet state/preferences, literal argv after restart, private permissions and retention all passed. Each suite still exited 1 with three quiet failures; no runtime or baseline suppression. |
| Native reload | One `hyprctl reload`, exit 0; same compositor/shell/idle PIDs, no errors, 116 effective bindings, 110 registry entries with unique matches. Post-reload help and terminal passed attended checks. |
| One shell failure | One authorized SIGKILL of the shell main process; automatic on-failure recovery, IPC ready, exactly one restart, compositor/hypridle unchanged. Bar/menu recovery confirmed attended. Start-limit exhaustion was not exercised. |
| Session lifecycle | Attended System logout reached SDDM; selected-user compositor/shell/idle absent and graphical target inactive. New SDDM login started one of each, zero restarts/errors; registry regenerated for the new instance. |
| Lock and counter | Explicit lock from es returned to us, wrong password rejected and private unlock passed. Shell restart while locked left lock and hypridle intact. Named synthetic notifications around a locked shell restart produced count 2, then 0 after history expansion/panel close. |

Specific evidence directories: `terminal-attended-20261025T150349Z/`,
`functional-completion-20261025T143716Z/`, `native-reload-20261025T144305Z-display-exception/`,
`shell-failure-20261025T150613Z/`, `session-lifecycle-20261025T151340Z/`,
`counter-20261025T135921Z/` and `qmllint-20261025T140716Z/`.

The native reload/lifecycle checks preserve a maintainer-owned local `Virtual-1` display exception
(`1920x1080@60.00`, scale `1.2`); it is not a common default and does not explain the earlier configure rewrite.
A temporary unprivileged `systemd-inhibit --what=idle` was authorized for attended testing, bounded to one hour;
its absence was subsequently confirmed. No production timeout was changed and no inhibitor remains claimed active.

### Open failures and limits

- Both SUPER+left drag (move) and SUPER+right drag (resize) fail in the reference. Keyboard resizing works.
  Registered mouse bindings and source inspection do not establish a cause or fix. The maintainer accepted a
  reference-VM-only exception and no repeated identical test (DEC-029); retain both results as failed, not passed.
  QEMU involvement is plausible, not demonstrated. Comparative hardware qualification remains pending; no hardware
  success or blanket Story 4.3 acceptance follows from this exception.
- Quiet checks: DEC-030 is narrowed, not closed. Plan 02-35 delivered the portal stack and reran the eight quiet
  suites and the production journal check in the reference VM (2026-11-12/13). With PipeWire 1.6.10 and UPower
  1.91.5 installed since 2026-11-05, the formerly failing provider suites exit 0; the PipeWire and UPower
  categories are dropped as an observation, without claiming Story 4.4 closure. By explicit maintainer decision the
  exception now covers only these portal diagnostics: the shell's `qt.qpa.services` "Failed to register with host
  portal … already associated with an application ID" (once per shell start, pre-existing) and the frontend's
  "Failed to load RealtimeKit property" (no `rtkit`, pre-existing), both outside this plan's boundaries; the GTK
  chooser's `Could not init tracker3 search engine`, caused by `sudo pacman -Rns nautilus` removing `localsearch`
  (as on an Omarchy fresh install; absent while Strata is the chooser); and the Strata chooser's sporadic GTK4
  frame-timing and SVG warnings, tracing `WARN` lines for unreadable directories and a `strata@` activation unit
  failing when the session ends inside its idle window, accepted with the `strata;gtk` selection. gnome-keyring's
  `discover_other_daemon: 1` is benign. Diagnostics outside this list are not waived, nothing was suppressed, and
  original suite exit 1 states remain visible. `check-selector-replacement` still exits 1 on a pre-existing
  fixture defect (no theme selection link, since `410d4fa`), which is not a portal diagnostic. See the
  [portals and files procedure](portals-and-files.md#laboratory-evidence).
  Private-bus inability to activate the real user manager remains a fixture limitation, not production evidence.
  Production journal checks confirmed the provider-warning categories. The reviewed QML baseline is separate.
- Idle locking was observed repeatedly, but exact 300-second timing and idle-from-es reset remain unverified.
  Tray visibility, multi-output and remaining standard-keyboard family checks are not qualified by other passes.
- No new suspend retest, hardware qualification, actual restart-limit exhaustion or changed-runtime live-reload
  qualification was performed. Original prototype defects and failed attempts remain historical evidence.
- Initial fixtures with overlong IPC paths, invalid counter stimuli, a partial manual command, expired SSH and a
  snapshot requested while still at SDDM remain recorded as such, not product passes. Later corrected evidence
  does not erase their original outcomes.

Final Task 3 review accepted this bounded result and its listed limits. Story 4.3 closure remains unclaimed:
reference-only drag exception DEC-029 and the narrowed portal diagnostic exception DEC-030 do not waive
other requirements. Unverified checks above remain unverified. Publication and laptop migration are separate
operations.

## Verification

Host, no graphical session:

```bash
node --test tests/capabilities/desktop/shell/config-overrides.test.mjs \
    tests/capabilities/desktop/shell/while-away.test.mjs
node --test tests/capabilities/desktop/shell/bar-panels.test.mjs \
    tests/capabilities/desktop/shell/audio-panel-model.test.mjs \
    tests/capabilities/desktop/shell/display-panel-model.test.mjs \
    tests/capabilities/desktop/shell/power-panel-model.test.mjs \
    tests/capabilities/desktop/shell/network-panel-model.test.mjs \
    tests/capabilities/desktop/shell/no-omarchy-coupling.test.mjs \
    tests/capabilities/desktop/shell/bar-additions.test.mjs \
    tests/capabilities/desktop/shell/clock-model.test.mjs \
    tests/capabilities/desktop/shell/calendar-weather.test.mjs \
    tests/capabilities/desktop/shell/world-clock-model.test.mjs \
    tests/capabilities/desktop/shell/world-clock.test.mjs \
    tests/capabilities/desktop/shell/reminders-flow-model.test.mjs \
    tests/capabilities/desktop/shell/reminders.test.mjs \
    tests/capabilities/desktop/shell/shell-lifecycle.test.mjs
node tests/capabilities/desktop/shell/menu-model.test.mjs [<omarchy-src>]
node tests/capabilities/desktop/shell/check-i18n.mjs
node tests/capabilities/desktop/shell/i18n-subset.mjs <omarchy-src> --check
node tests/capabilities/desktop/shell/check-provenance.mjs <omarchy-clone>
shellcheck tests/capabilities/desktop/shell/*.sh capabilities/desktop/shell/services/hidden-entries.sh
```

`<omarchy-src>` is a read-only Omarchy tree at the general revision in `UPSTREAM.md` (for example a
temporary detached worktree of `<omarchy-clone>`). `<omarchy-clone>` is a read-only Omarchy clone with
history; the provenance check reads each row at its stated revision with `git show` (unprefixed rows use the
general revision), byte-compares copied files and refuses when a tag does not resolve to its recorded commit.
The clone is never checked out or modified.

Configure delivery, bindings and lock contracts (host, test doubles, no session):

```bash
bats --jobs "$(nproc)" tests/capabilities/desktop/shell/install-runtime.contract.bats \
    tests/capabilities/desktop/shell/configure.contract.bats tests/capabilities/desktop/lock/configure.contract.bats \
    tests/capabilities/desktop/reminders/
node --test tests/capabilities/desktop/hyprland-bindings.test.mjs
```

Disposable guest with Quickshell, Hyprland and the recorded Qt version only (synthetic data, isolated
HOME/XDG; never on the daily session). `qmllint-check.mjs` compares diagnostics with the reviewed baseline
and needs that environment; its baseline is updated only with `--capture` and an explicit review:

```bash
node tests/capabilities/desktop/shell/qmllint-check.mjs
tests/capabilities/desktop/shell/check-selector-replacement.sh
tests/capabilities/desktop/shell/check-dmenu.sh
tests/capabilities/desktop/shell/check-menu.sh
tests/capabilities/desktop/shell/check-bar.sh
tests/capabilities/desktop/shell/check-notifications.sh
tests/capabilities/desktop/shell/check-osd.sh
tests/capabilities/desktop/shell/check-while-away.sh
tests/capabilities/desktop/shell/check-panels.sh
```

`check-bar.sh`, `check-notifications.sh` and `check-while-away.sh` refuse to run while another
notification daemon owns the bus. The checks need a UTF-8 locale: under a non-interactive SSH session,
export the session's `LANG`, otherwise Quickshell prefixes every IPC reply with a locale warning.
Exit code `2` means blocked, not passed. Input-injecting variants (`--keyboard`) and keyboard-layout checks
need specific authorization.
