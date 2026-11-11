# Bar Modules Evaluation — Consolidated Plan

This interview evaluates, one candidate at a time, the Omarchy default-bar modules that MirrorOS lacks after
Story 4.4, and decides what enters a future plan before Story 4.5. Each candidate is judged on daily value and on
fit with [ADR 0012](../adr/0012-owned-quickshell-desktop-shell.md) and [ADR 0025](../adr/0025-shell-panels.md):
open-only polling, no resident processes, owned commands and no `omarchy-*` coupling.

## Clock calendar

The clock gains Omarchy's calendar popup as a read-only month grid with ISO week numbers, where only today is
marked and only the visible month moves. It opens on left click of the clock label inside the shared `Panel`
container and has a native bar-level `clock` IPC target (open, close, toggle), the same pattern the Story 4.4
panels use. The calendar spawns no process and polls nothing beyond the clock tick, so it stays within the shell's
runtime principles. [DEC-001]

The upstream calendar is independent of the weather panel; it only shares a visual composition with it, so no
weather code travels with it. Its `qs.Ui` dependencies already exist in MirrorOS. `WallClock.qml`, the upstream
replacement for `SystemClock` that avoids a log flood in the repeated daylight-saving hour, is adapted with the
panel because both the bar label and the panel use it. Upstream `I18n` calls map to the MirrorOS i18n subset or
English literals, as in plan 02-27. The middle-click timezone picker stays out of this candidate. [DEC-001]

Because ADR 0025 admits only its listed panels, the calendar enters through an ADR that partially supersedes that
list, following the ADR 0027 and ADR 0028 pattern. [DEC-001]

That ADR is shared with weather and, after DEC-020, the world clock: one ADR covering the three panels partially
supersedes ADR 0025's panel list for them and its "Diagnostics" item for the open-meteo traffic only, and its
reversal boundary states that removing one panel does not reopen the others. The MVP scope's "Desktop shell" row lists the new panels as a scope change
citing the ADR, as ADR 0012 requires for a new surface. [DEC-015]

The shared record is ADR 0029, "Clock Calendar, Weather and World Clock Panels", drafted in plan 02-32 and accepted
at a maintainer checkpoint before the calendar and weather are implemented, as plan 02-28 did with ADR 0028. Besides
the panel list and the open-meteo exception, it admits `curl` through `Process` with fixed `https://` URLs and the
world clock's read-only, open-only `date` and `timedatectl` probes, excludes `sudo`/`set-timezone`, wttr.in, IP
auto-detection and GitHub, and records the calendar's opt-in persisted settings. World-clock implementation and
validation remain with plan 02-33, which needs an amendment if it finds a contradiction. ADR 0025 gains only a
forward link, and the ADR index, MVP scope and architecture are updated in the same task. [DEC-037]

Verification tests only what MirrorOS changes. `Panel.qml` and `WallClock.qml` stay byte-identical to upstream,
which the provenance check asserts, and upstream's `clock-test.sh` is copied as `clock-model.test.mjs` minus the
timezone-picker cases, with no new tests for upstream date logic. A static test asserts no `Process` or
`omarchy-*`, the `clock` IPC target, left click opening the panel and middle click doing nothing. The laboratory
checks integration only (click, IPC, Tab switching and the unchanged right-click format cycle), with month
navigation and the marked current day as a visual smoke check. No T14s validation is needed. [DEC-019]

Keeping `Panel.qml` unchanged brings the rest of the upstream panel along: a read-only year progress bar, a
week-start toggle on the grid's "W" heading and an optional memento-mori bar that asks for a birth year and a life
expectancy. The grid itself stays a read-out, but the panel thereby has opt-in settings (`weekStartDay`,
`birthYear`, `lifeExpectancy`) persisted for the clock in `shell.json` through `updateEntryInline`. No personal
data enters the repository, and with per-widget persistence these saves no longer freeze the `center` zone. The
ADR and `UPSTREAM.md` record these features. [DEC-034, DEC-035]

The calendar lives in `panels/clock/`, where `Panel.qml`, `Model.js` and `WallClock.qml` are copied unchanged from
`v4.5.0`, identical to the clone's current head for these files. The bar's `Clock.qml` imports that `Model.js`,
switches to `WallClock` and opens the panel on left click, so the former `bar/ClockModel.js` subset becomes
redundant and is removed with its provenance row and tests updated. The i18n subset is regenerated from `7075b61`,
which already holds every `clock.*` key, and weather follows the same `panels/weather/` layout. [DEC-038]

## Stay awake

The indicators area gains a StayAwake toggle next to Dnd. Unlike Omarchy, where the shell is the idle manager,
MirrorOS keeps hypridle as the owner of idle detection and lock requests; the shell only acts as one more Wayland
idle-inhibit client through the native `Quickshell.Wayland` `IdleInhibitor` bound to the bar window, the same
mechanism browsers use during video playback. It adds no process, polling or `omarchy-*` call. [DEC-002]

The toggle only suppresses the 5-minute idle lock; locking before sleep and on lid close is unchanged. Its value is
medium (presentations, reading, calls in applications that do not inhibit idle), against the security cost of an
unlocked screen when the user forgets to clear it. [DEC-002]

The state is not persisted: it lives in memory and starts off on every shell start, so a shell restart, logout or
reboot restores the idle lock automatically and a forgotten toggle never carries into a new session. This matches
the runtime-only mirror toggle of ADR 0027 and needs no state file. The need for an ADR and verification remain
open. [DEC-003]

StayAwake is admitted as a routine change inside ADR 0012's bar surface, without an ADR, and is not part of the
calendar ADR. The lock-policy exception is documented in the same change: the lock `sources.md` records the shell
as one more idle-inhibit client while hypridle keeps owning idle detection and locking, the MVP scope's "Screen
lock and idle" row notes that the toggle suspends the idle lock while lock before sleep is unchanged (a reviewed
update), and the shell `UPSTREAM.md` and `docs/attribution.md` record provenance. The maintainer accepts that this
security-relevant exception lives in capability documentation rather than an ADR. [DEC-004, RISK-001]

Verification runs in the laboratory guest with a temporary copy of `hypridle.conf` lowering the timeout to 30 s,
restored afterwards and confirmed unchanged by `configure`. It checks that no idle lock happens while StayAwake is
active, that the idle lock returns when it is cleared, that `loginctl lock-session` and suspend still lock while it
is active, and that the state is off after the shell unit restarts. A static test asserts that `Indicators`
declares the indicator, uses `IdleInhibitor` and contains no `Process` or state write. No T14s validation is
required because the mechanism is the hardware-independent Wayland protocol. [DEC-005]

## Microphone indicator

The bar gains Omarchy's microphone indicator as its own widget in the right section, next to audio. It shows the
default source as open or muted and highlights while an application captures audio from an unmuted source, a
privacy signal MirrorOS lacks today: the `XF86AudioMicMute` key with its OSD and the audio panel's input mute and
open-only peak meter exist, but nothing shows the state without opening the panel. Click toggles mute, the wheel
changes input volume and middle click opens the audio panel. It uses the native Pipewire binding, with no process
or polling. [DEC-006]

The adaptation drops `UntypedInput`, consistent with the audio panel's unavailable state for sources without
`audio`, replaces the upstream `AudioNodes` filter with a minimal exclusion of the shell's own level meter, and
opens the audio panel through the in-shell bar path instead of `omarchy-shell`. [DEC-006]

The indicator appears only when it carries information: while an application captures audio from the default
source, highlighted as in use, or while that source is muted, as a reminder. It is hidden when the source is open
and unused and when no default source exists, so it adds no permanent icon to the already full right section;
outside those states, mute stays on the `XF86AudioMicMute` key and the audio panel. In-use detection excludes the
audio panel's own peak meter so opening the panel never reveals the indicator, and hiding reuses the existing
widget visibility mechanism, as Bluetooth does without an adapter, so neighbouring icons do not jump abruptly.
[DEC-007]

The indicator is a routine change inside ADR 0012's bar surface and needs no ADR, because it changes no documented
policy and adds no process, dependency or provider. The same change records provenance in the shell `UPSTREAM.md`
and `docs/attribution.md` and mentions the indicator in the MVP scope's "Desktop shell" row as a reviewed update.
[DEC-008]

Verification uses the input source the laboratory VM already exposes through QEMU's emulated audio device, so no
virtual source is needed. A Node static test asserts that the widget has no `Process`, `UntypedInput`,
`AudioNodes` or `omarchy-*` reference, is wired in `defaults.json` and the `Bar.qml` component map, and keeps the
peak-meter exclusion. In the laboratory session the indicator is hidden while the source is open and unused,
visible and highlighted while `pw-record /dev/null` captures, visible when muted through `volume mic-mute` or a
click, adjusts input volume with the wheel, stays hidden when the audio panel opens without other capture, and
opens the audio panel on middle click. The no-default-source case is covered statically and by review. A real
call and the physical mute key are checked on the T14s, supervised and non-qualifying. [DEC-009]

## Weather

The bar gains a weather pill for an active location, adapted from Omarchy's weather widget and panel. The pill
refreshes every 30 minutes, pauses while the session is locked or suspended, and refreshes on resume and when the
panel opens. The user keeps several saved locations, one of them active and shown in the bar, and switches the
active one from the panel; the non-active locations are fetched only while the panel is open, in one combined
request. open-meteo is the only provider: wttr.in and IP-based auto-detection are dropped. Upstream supports a
single location, so multi-location support is MirrorOS-owned design on an adapted base. [DEC-010]

Requests carry the chosen locations' coordinates, not the user's, and expose the client IP as any HTTP request
does, which the maintainer accepts. What remains is periodic contact with a fixed third-party host, which ADR 0025
avoided for diagnostics, so weather is admitted through the shared calendar and weather ADR, which supersedes
that item for weather only. [DEC-010, DEC-015]

The product ships no personal locations, consistent with the rule against committing personal configuration;
locations live only in user state. Elsewhen stays a separate candidate, so the rows show no local time.
[DEC-011, DEC-010]

Locations are stored as settings of the weather bar entry in the user's `shell.json` (a `locations` list of name,
latitude and longitude plus an `active` index), written through the existing sparse-override preference mechanism
the clock format already uses, with its resolver and validation. `defaults.json` ships none, and no helper or
separate state file is added. With per-widget persistence they live in `bar.widgets["omarchy.weather"]`, so
saving them never freezes `centerEnd`. [DEC-012, DEC-035]

With no saved location, as on a new installation, the pill stays visible with a neutral weather glyph and no
temperature, and clicking it opens the panel with an empty "No location" hero and the search ready; the first
location added becomes active automatically. No network request is made until a location exists. [DEC-014]

The panel keeps Omarchy's weather layout on top, always for the active location: hero icon and temperature, the
pinned location name, feels, wind and humidity, and the three-day forecast. Clicking the pinned name opens the
upstream open-meteo geocoder search, which runs only while the user types in the open panel, and replaces only
the active record. Below it, the other saved locations appear in saved order as compact Elsewhen-style rows with
name, current temperature and icon but no local time or daylight strip; clicking a row makes it active, moving it
into the hero and the bar while the previous active location joins the list. A "+ Add location" button at the end,
styled like Elsewhen's "Add a city", opens the same search and appends a record without changing the active one.
[DEC-013]

Removal follows Elsewhen: a hover-only circular "×" at a list row's top-right corner removes that record. The
active location has no "×" and is removed by activating another one first, so the last location can never be
removed. Because the row and button designs come from Elsewhen (MIT, Jason Fried), provenance cites both Omarchy
origins. [DEC-013]

Requests keep upstream `curl` through `Process`, with argument vectors and fixed `https://` URLs built in the
model, the same mechanism the world clock reuses; `curl` is declared in the shell `packages` file. [DEC-016]

The pill sits in the bar's `centerEnd` section in `defaults.json`, next to the clock and its calendar, as in
Omarchy. Any click toggles the panel; the upstream right-click notification is dropped with its helper. A native
`weather` IPC target provides open, close and toggle like the other panels, and units keep the upstream logic
(the entry's `unit` setting, otherwise locale and country). [DEC-017]

Locking and suspend reuse the lock marker and `lockChanged` signal the notifications already rely on: hypridle
locks before sleep, so pausing while locked also covers suspend and the unlock acts as the resume refresh, with no
separate suspend watcher. [DEC-018]

Upstream's `weather-test.sh` is copied as `weather-model.test.mjs` minus the wttr.in, location-file and IP
auto-detection cases. New Node tests cover only MirrorOS behaviour: the location list operations, including that
the active and last location are never removed, the `shell.json` shape through `ShellPreferences`, the fixed
`https://` combined-request URL and the scheduler (30 minutes, paused while locked, refresh on unlock and panel
open, nothing without a location). A static test asserts that weather files contain no `omarchy-*`, request only fixed `https://` open-meteo
URLs, sit in `centerEnd` and expose the `weather` IPC target. In the laboratory, the no-network behaviour is checked
with the interface down (previous value kept, no error loop), the full editing flow is exercised from the empty state while checking `shell.json` after each step, traffic
to `api.open-meteo.com` is observed with `ss` or `tcpdump` (none without a location, only the active one while the
panel is closed, one combined request on open), and no request happens while locked. No T14s validation is needed.
[DEC-018]

## World clock

The bar gains Omarchy's Elsewhen world clock as a panel, because the maintainer works daily with people in
different time zones. The panel keeps the city rows (time, date, offset, daylight strip), removal and the "Add a
city" search, and drops the spinnable globe with its moon mode. Changing the system time zone through
`sudo -n timedatectl set-timezone` is excluded, since ADR 0025 forbids sudo and passwordless rules for panels. The
world clock joins the shared calendar and weather ADR, and real line counts are measured during adaptation; at
about 7,000 upstream lines it is the largest module in this evaluation. [DEC-020, DEC-015]

QML has no `Intl`, so zone times need an external `date` probe, which upstream runs only on panel open and every
five minutes while open. That mechanism is reused unchanged: one argument-vector `bash -c` loop of `TZ=<zone>
date` probes plus `timedatectl show` for the local zone, and `timedatectl list-timezones` with the upstream city
aliases for the search, all read-only, unprivileged and only while the panel is open. [DEC-020, DEC-023]

The hover greetings, drag reordering and daylight-strip scrubbing stay unchanged, since they are QML only and
scrubbing answers the daily "what time is it there when it is 16:00 here" question. The globe stays out: the
upstream `globeEnabled` setting is fixed to `false`, `MiniGlobe` remains a static ornament in the hero title, and
the globe files and their `world.json` and `cities.json` data are not delivered, avoiding the panel's most complex
rendering code and its per-frame repaint cost; `Sun.js` stays for the daylight strip. [DEC-024]

Per-city temperature reuses Elsewhen's upstream path unchanged: one batched open-meteo forecast for all rows and a
geocode per row without coordinates, only while the panel is open, cached in memory (geocodes for the session,
weather for 20 minutes), with network input validated, the `zone1970.tab` coordinates as offline fallback and the
previous value kept on failure. It uses `curl` through `Process`, like weather, and keeps its own model rather than
a module shared with weather, so both stay close to upstream. `curl` and `tzdata` are declared in the shell
`packages` file, code tied to removed features is dropped, and the shared ADR names these requests alongside
weather's. [DEC-022, DEC-016, DEC-015]

Rows carry no people: the hover "account-plus" button, the inline people field, the extra row line, GitHub
avatars and the `people` key are all dropped, so no second third party is involved. [DEC-021]

A new installation starts as upstream does: the first time the panel opens it writes the home city, derived at
runtime from the system time zone, plus four well-known destinations spread at least three hours apart, as a normal
`cities` list in `shell.json`. This ships no personal data, since the home city comes from the installation's time
zone and the destinations are computed from generic well-known cities, consistent with DEC-011. [DEC-025]

In the bar, `centerEnd` holds the world clock and then weather, in Omarchy's order, keeping the upstream
`omarchy.elsewhen` id like the other widgets. Its globe icon toggles the panel on any click, and a native
`worldclock` IPC target provides open, close and toggle. The entry keeps the upstream `hour24`, `offsetMode` and
`units` settings and stores `cities` through the existing `updateEntryInline` mechanism; `globeEnabled` is fixed
off and not exposed, and the other globe settings are dropped. [DEC-026]

Verification tests only what MirrorOS changes. Files kept unchanged are not retested; the provenance check asserts
they are byte-identical to upstream, which keeps upstream's own tests valid for them. The upstream model test is
copied as `world-clock-model.test.mjs`, minus the cases for dropped features, because the adapted `Model.js`,
`Panel.qml`, `CityRow.qml` and `HeroTitle.qml` touch shared row and first-run code. A MirrorOS static test asserts
the removed boundaries (no `sudo`, `set-timezone`, GitHub, `omarchy-*` or globe files, `globeEnabled` off), the
`worldclock` IPC target, the `centerEnd` order and the `curl` and `tzdata` package declarations. The laboratory
checks integration only: click, IPC and Tab, `shell.json` writes for the first run and list edits, no traffic while
closed and no error loop offline, with scrubbing, greetings and search as a visual smoke check. No T14s validation
is needed. [DEC-027]

## Reminders

MirrorOS adapts Omarchy's quick reminders, which fit the maintainer's workflow: relative and ephemeral ("in N
minutes, remind me of X"), without absolute times, recurrence or dates. A prompt asks for minutes and an optional
message, a notification confirms the time, and the bar indicator in `Indicators` shows the pending count; bindings
open the prompt, list and clear reminders. Each reminder is a transient systemd user timer with its message under
`$XDG_RUNTIME_DIR`, so reminders end with the session and no reminder daemon exists. An owned `reminder` command
replaces `omarchy-reminder` and its `omarchy-*` helpers over the MirrorOS notification service. [DEC-028]

Reminders enter as a scope change without an ADR, because they add no daemon, privilege, network or provider and
only use surfaces ADR 0012 admits. The MVP scope gains a "Quick reminders" row in the Desktop table and a "Set a
reminder" frequent action, and provenance is recorded in the shell `UPSTREAM.md`, `docs/attribution.md` and the
capability's `sources.md`. [DEC-030]

A new `capabilities/desktop/reminders/` capability owns the Bash `reminder` command, installed at
`/usr/share/mirroros/reminders/reminder` like other owned commands, with its `apply`, `packages`
(`sound-theme-freedesktop`, `jq`) and `sources.md`. The command keeps upstream's interface (`<minutes> [message]`,
`show [--json]`, `clear`, `-i`), schedules `mirroros-reminder-<min>m-<epoch>` units through `systemd-run --user
--on-active`, keeps messages under `$XDG_RUNTIME_DIR/mirroros/reminders/` and passes them only as arguments, and asks
the shell through IPC to refresh the indicator after every change. The prompt adapts upstream `ReminderFlow.qml` in
the shell behind a native `reminders` IPC target, and Omarchy's three bindings (`SUPER+CTRL+R` set,
`SUPER+CTRL+ALT+R` show, `SUPER+SHIFT+CTRL+R` clear) are declared in the shell bindings layer and the keybinding
help. [DEC-031]

Bats tests cover the command's arguments, unit names, message quoting, JSON listing, clearing and delivery with
doubles for `systemd-run`, `notify-send` and `pw-play`; `ReminderFlowModel.js` is covered by Node, copying an upstream
test where one exists. The laboratory checks creating, listing and clearing reminders, delivery with sound and under
Do Not Disturb, and that nothing survives logout. [DEC-031]

A delivered reminder must be noticed. It is a Critical notification under the app name `reminder`, which the
MirrorOS service keeps on screen until dismissed in the urgent colour, and `reminder` joins `bypassesQuiet` so a
self-set reminder passes Do Not Disturb and snoozes. The command also plays the freedesktop
`alarm-clock-elapsed` sound with `pw-play`, even under Do Not Disturb and silenced only by system mute, with
`sound-theme-freedesktop` declared; the shell gains no sound support and no resident process. [DEC-029]

## Active window

The bar gains Omarchy's ActiveWindow widget, which is not in its default bar, because in the tiling layout it is
sometimes unclear which application is focused, for example in a viewer. Upstream shows only the window title,
which often does not name the application, so MirrorOS shows the application name first and then the title (for
example `Image Viewer · photo.png`), resolving the name from the `appId` through the desktop entries the launcher's
`AppLibrary.qml` already handles and falling back to the raw `appId`. The tooltip shows the full text. It uses the
native `ToplevelManager` binding, with no process or polling, and sits in the left section after the workspaces.
[DEC-032]

Left click focuses the window as upstream, but middle and right click no longer close it, so a stray click on the
bar cannot discard unsaved work. Admission is routine inside ADR 0012's bar surface, like the microphone
indicator, with provenance in the shell `UPSTREAM.md` and `docs/attribution.md` and a mention in the MVP scope's
"Desktop shell" row. [DEC-032]

## Inline setting persistence

Inline widget settings stop freezing whole bar zones. Today `updateEntryInline` rewrites the widget's entry inside
its `bar.layout` zone array, and because arrays are single override leaves, the first saved setting copies the
whole zone into `shell.json`; later default changes to that zone, such as new widgets, never reach the user, and
`configure` cannot repair user state. Settings are therefore stored per widget id in a `bar.widgets.<id>` object
that merges key by key, so only changed keys are recorded. `updateEntryInline` keeps its API, which keeps the
upstream clock panel byte-identical; widgets receive their layout entry's settings merged with `bar.widgets[id]`,
and validation accepts the new object. `bar.layout` overrides remain only for layouts the user writes by hand.
Existing frozen zone overrides stay valid and are removed manually as the shell procedure documents, with no
automatic migration. The `shell.json` format comes from plan 02-27, not from an ADR, so no ADR is needed.
[DEC-035]

Precedence runs from the defaults entry, through an entry in a hand-written `bar.layout`, to `bar.widgets[id]`.
`updateEntryInline` always writes `bar.widgets[id]`, even when the user wrote a layout by hand, records only keys
that differ from the value without the override, and resets a key that is no longer sent; the unused `plugins[]`
path stays as it is. Node tests in `config-overrides.test.mjs` cover sparse per-widget writes, a later default
layout change still reaching the user, the precedence, honoured legacy zone overrides, key reset and rejection of a
non-object `bar.widgets`; a static test asserts that no widget writes `bar.layout`. The laboratory checkpoint
inspects `shell.json` after the format cycle, the week-start toggle and a saved weather location, and the shell
procedure documents manual cleanup of legacy zone overrides; no T14s validation is needed. [DEC-039]

## Plan sequence

The accepted scope is delivered in four plans. Plan 02-31 delivers the routine bar pieces (StayAwake, the
microphone indicator and ActiveWindow, the latter verified like the microphone with a static test and laboratory
checks). Plan 02-32 first changes inline setting persistence, then drafts and accepts the shared ADR and delivers
the clock calendar and weather [DEC-036]. Plan 02-33
delivers the world clock under that ADR. Plan 02-34 delivers reminders. Plans 02-31 and 02-34 are independent,
02-33 depends on 02-32, and none depends on Story 4.5. [DEC-033]

Plan 02-32 closes with a commit task once the laboratory checkpoint is approved: five Conventional Commits split by
concern (per-widget persistence, ADR 0029, calendar, weather, and the interview and validation records), with shared
files split by hunk so tests pass at each commit, candidate refs deleted afterwards and no push; `.agents/` and
generated outputs are never committed. [DEC-040]
