# Bar Modules Evaluation — Decision Log

Evaluation of additional MirrorOS bar modules against the Omarchy default bar, before Story 4.5. Omarchy is a
read-only reference at `~/code/omarchy`; boundaries are [ADR 0012](../adr/0012-owned-quickshell-desktop-shell.md)
and [ADR 0025](../adr/0025-shell-panels.md).

## DEC-001
- **Question**: Should the clock calendar popup (Omarchy `shell/plugins/panels/clock/Panel.qml`) enter MirrorOS scope?
- **Context/Nuances**: Omarchy opens a read-only month grid with ISO week numbers on left click of the clock; only
  today is marked and only the visible month changes (chevrons, wheel, arrow keys). It spawns no process, polls
  nothing beyond the clock tick and calls no `omarchy-*` helper. It is independent of the weather panel: the only
  link is a header comment stating a shared visual composition (hero over detail, spacing scale, small-caps
  labels); there are no imports or cross-references. Its `qs.Ui` dependencies (`Panel`, `PanelToolTip`,
  `PanelActionButton`, `PanelKeyCatcher`, `WidgetButton`, `OpticalGlyph`) already exist in MirrorOS. `WallClock.qml`
  (a `Timer` replacing `SystemClock` to avoid a negative-delay log flood in the repeated DST hour) is used by both
  the bar label and the panel. `I18n.*` calls must map to the MirrorOS i18n subset or English literals, as in plan
  02-27. The MirrorOS `Clock.qml` currently leaves left click as an integration point with no action, and
  `ClockModel.js` is already a subset of the same upstream `Model.js`. A new panel is outside ADR 0025's
  "these panels only" list.
- **User Response**: Approved the recommendation.
- **Decision**: Adapt the calendar: read-only, opened by left click inside the shared `Panel` container, with a
  native bar-level `clock` IPC target (open/close/toggle) like the other panels, and `WallClock.qml` adapted with
  it. The middle-click timezone picker is excluded (evaluated as candidate 12). Admission goes through a short ADR
  partially superseding ADR 0025's panel list, following the ADR 0027 and ADR 0028 pattern.
- **Status**: Accepted

## DEC-002
- **Question**: Should Omarchy's StayAwake indicator enter MirrorOS scope?
- **Context/Nuances**: In Omarchy the shell itself is the idle manager (`services/idle/Service.qml`, 342 lines, built
  on Quickshell `IdleMonitor`); StayAwake disables that cycle and persists its state through a `bash -lc` writer
  under `~/.local/state/omarchy/indicators/stay-awake`. In MirrorOS hypridle owns idle detection and lock requests
  (`capabilities/desktop/lock`): lock after 5 minutes idle and before sleep, no DPMS or automatic suspend. The
  shell must not become the idle manager. The adaptation makes the shell one more Wayland idle-inhibit client
  through `Quickshell.Wayland` `IdleInhibitor` bound to the bar window, as browsers do during video playback; no
  new process, polling or `omarchy-*` call. It only suppresses the 5-minute idle lock; locking before sleep and on
  lid close is unchanged. Daily value is medium (presentations, reading, calls in applications that do not inhibit
  idle); the security cost is an unlocked screen if the user forgets to clear it.
- **User Response**: Approved the recommendation.
- **Decision**: Adapt StayAwake as an indicator in `Indicators`, next to Dnd, using the native `IdleInhibitor`.
  Persistence, ADR need and verification are decided in follow-up questions.
- **Status**: Accepted

## DEC-003
- **Question**: Should the StayAwake state persist across shell restarts, logouts and reboots?
- **Context/Nuances**: Omarchy persists the state on disk, so it survives restarts and reboots. In MirrorOS the
  `IdleInhibitor` lives in the shell; without persistence the state returns to off whenever the shell restarts
  (crash or published-tree update), the user logs out or the machine reboots, which restores the idle lock
  automatically. Persisting would need a file under `$XDG_STATE_HOME/mirroros/shell/` and could start a session
  that never idle-locks without the user remembering it.
- **User Response**: Approved the recommendation.
- **Decision**: No persistence. The state is in memory only and starts off on every shell start, consistent with
  the runtime-only mirror toggle (ADR 0027).
- **Status**: Accepted

## DEC-004
- **Question**: How is StayAwake admitted: one combined "bar additions" ADR, routine change without ADR, or a
  dedicated ADR?
- **Context/Nuances**: As a bar indicator it is inside ADR 0012's bar surface and is not a panel, so ADR 0025's
  panel list does not block it. It does, however, create a user-controlled exception to the documented lock
  policy (`docs/mvp-scope.md`: lock after 5 minutes idle; `capabilities/desktop/lock/sources.md`: hypridle owns
  idle inhibition). The ADR README requires an ADR for an exception to the architecture, which is arguable here.
  The recommendation was a single ADR shared with the calendar (DEC-001).
- **User Response**: Option (b), routine change without ADR.
- **Decision**: StayAwake is a routine change inside ADR 0012's bar surface, with no ADR. The lock-policy exception
  is documented in the same change: `capabilities/desktop/lock/sources.md` records the shell as one more
  idle-inhibit client while hypridle keeps owning idle detection and locking; the `docs/mvp-scope.md` "Screen lock
  and idle" row notes that the shell StayAwake toggle suspends the idle lock while lock before sleep is unchanged
  (reviewed update, not a scope change); `capabilities/desktop/shell/UPSTREAM.md` and `docs/attribution.md` record
  provenance. The calendar keeps its own ADR (DEC-001); StayAwake is not part of it.
- **Status**: Accepted

## RISK-001
- **Risk**: The StayAwake lock-policy exception is not recorded in an ADR, only in capability sources and the MVP
  scope.
- **Mitigation**: Accepted by the maintainer (DEC-004); the documentation is updated in the same change.

## DEC-005
- **Question**: How is StayAwake verified?
- **Context/Nuances**: Realistic verification waits for hypridle's 5-minute timeout. The laboratory guest supports
  a graphical session on a recoverable snapshot (Story 4.3 protocol). Checks needed: no idle lock while active, the
  idle lock returns when cleared, locking before sleep still works while active, and the state resets after a
  shell restart (DEC-003).
- **User Response**: Approved the recommendation.
- **Decision**: In the laboratory guest, temporarily lower the hypridle timeout to 30 s with a copy of
  `hypridle.conf` and restart hypridle; then restore the managed file and confirm `configure` leaves it unchanged.
  Check: no idle lock while active; idle lock returns when cleared; `loginctl lock-session` and suspend still lock
  while active; state is off after `systemctl --user restart` of the shell. Add a static test that `Indicators`
  declares the indicator, uses `IdleInhibitor`, and has no `Process` or state write. No T14s validation is
  required, because the mechanism is the Wayland protocol and is hardware-independent.
- **Status**: Accepted

## DEC-006
- **Question**: Should Omarchy's microphone bar widget enter MirrorOS scope?
- **Context/Nuances**: Omarchy `bar/widgets/Microphone.qml` (75 lines) shows open or muted microphone glyphs and is
  highlighted while an application captures audio and the source is not muted (a "microphone in use" privacy
  signal). Click toggles mute, wheel changes input volume, middle click opens the audio panel through
  `omarchy-shell`. It uses the native Pipewire binding (no process, no polling) but depends on `UntypedInput`
  (`wpctl` path for virtual sources) and `AudioNodes` (filters the shell's own level meters and platform audio),
  both removed by MirrorOS in plan 02-27. MirrorOS already has `XF86AudioMicMute` → `volume mic-mute` with OSD and
  input mute plus an open-only peak meter in the audio panel, but nothing shows mute or in-use state without
  opening the panel. Daily value is medium-high for calls, including corporate calls over VPN.
- **User Response**: Approved the recommendation.
- **Decision**: Adapt the microphone indicator as its own widget in the right section next to audio: drop
  `UntypedInput` (consistent with the audio panel's unavailable state for sources without `audio`), replace the
  `AudioNodes` filter with a minimal exclusion of the shell's own meter, and open the audio panel through the
  in-shell bar/IPC path on middle click. Visibility and admission route are decided in follow-up questions.
- **Status**: Accepted

## DEC-007
- **Question**: When is the microphone indicator visible?
- **Context/Nuances**: Omarchy shows it whenever a default source exists. The MirrorOS right section already holds
  seven items. Options were always visible with a source, visible only when relevant, or always visible including
  an unavailable state.
- **User Response**: Option (b), visible only when relevant.
- **Decision**: The indicator is visible only while an application captures audio from the default source
  (highlighted as in use) or while the default source is muted (reminder). It is hidden when the source is open
  and unused, and when no default source exists. While visible it keeps click (mute), wheel (input volume) and
  middle click (audio panel). Otherwise mute stays on the `XF86AudioMicMute` key and the audio panel. In-use
  detection must exclude the audio panel's own peak meter so opening the panel does not reveal the indicator.
  Hiding reuses the existing widget visibility mechanism (as Bluetooth without an adapter) so other icons do not
  jump abruptly.
- **Status**: Accepted

## DEC-008
- **Question**: How is the microphone indicator admitted: routine change or part of the calendar ADR?
- **Context/Nuances**: It is a bar widget, not a panel, inside ADR 0012's bar surface; ADR 0025's panel list does
  not apply. It changes no documented policy (input mute already exists through the key and the audio panel) and
  adds no process, dependency or provider.
- **User Response**: Option (a), routine change.
- **Decision**: Routine change without ADR. In the same change, `capabilities/desktop/shell/UPSTREAM.md` and
  `docs/attribution.md` record provenance of the adapted `bar/widgets/Microphone.qml`, and the `docs/mvp-scope.md`
  "Desktop shell" row mentions the bar microphone indicator as a reviewed update, not a scope change. It is not
  part of the calendar ADR (DEC-001).
- **Status**: Accepted

## DEC-009
- **Question**: How is the microphone indicator verified?
- **Context/Nuances**: The maintainer confirmed that both the Omarchy and MirrorOS laboratory VMs already expose an
  input source: the QEMU-emulated audio device, which PipeWire presents as a normal ALSA source with `audio`,
  volume and mute. No virtual source is needed and the removed `UntypedInput` path does not apply. The T14s has a
  real microphone and mute key with LED, but its validation is supervised and non-qualifying.
- **User Response**: Approved the corrected recommendation.
- **Decision**: A Node static test asserts that the widget uses no `Process`, `UntypedInput`, `AudioNodes` or
  `omarchy-*`, is present in `defaults.json` and the `Bar.qml` component map, and contains the peak-meter
  exclusion. In the MirrorOS laboratory VM, with the emulated source: hidden while open and unused; visible and
  highlighted while `pw-record /dev/null` (or another application) captures; visible when muted through
  `volume mic-mute` or click, with the wheel changing input volume; hidden when the audio panel opens with no other
  capture; middle click opens the audio panel. The no-default-source case is covered by the static test and code
  review unless the VM is started without an audio device. On the T14s, supervised and non-qualifying: physical
  mute key and a real call.
- **Status**: Accepted

## DEC-010
- **Question**: Should weather enter MirrorOS scope, and in what shape?
- **Context/Nuances**: Omarchy's weather pill and panel (`panels/weather`, about 1,350 lines) use wttr.in plus
  open-meteo with `curl`, refresh every 15 minutes by default, support a single location, fall back to IP-based
  auto-detection and depend on `omarchy-weather-location`, `omarchy-weather-status` and
  `omarchy-notification-send`. The maintainer wants occasional access to weather, a bar pill for an active
  location and several saved locations. The requests carry the chosen location's coordinates, not the user's, but
  every HTTP request exposes the client IP, which the maintainer accepts as inherent to any HTTP request. The
  remaining concern is periodic contact with a fixed third-party host, which ADR 0025's "Diagnostics" item avoided.
  A 5-minute interval was proposed and rejected as excessive because open-meteo updates current conditions every
  15 minutes.
- **User Response**: Accepted the bar pill, a 30-minute interval, several saved locations with one active, and
  keeping Elsewhen as a separate candidate.
- **Decision**: Adapt weather with a bar pill for the active location, refreshed every 30 minutes, paused while
  the session is locked or suspended and refreshed on resume and when the panel opens. Several saved locations
  exist, one active (shown in the bar) and selectable from the panel; non-active locations are fetched only while
  the panel is open, in one combined request. open-meteo is the only provider; wttr.in and IP-based
  auto-detection are dropped. Multi-location support is MirrorOS-owned design on an adapted single-location base.
  Elsewhen is not absorbed: rows show no local time, and Elsewhen is evaluated as candidate 8. Periodic
  third-party contact requires an ADR.
- **Status**: Accepted

## DEC-011
- **Question**: Should the product ship the maintainer's own locations as weather defaults?
- **Context/Nuances**: `AGENTS.md` forbids committing personal configuration; the maintainer's home or work cities
  are personal data and a product default is visible in the repository and in every installation.
- **User Response**: Understood; not done.
- **Decision**: The product ships no personal locations. Personal locations live only in user state, outside the
  repository.
- **Status**: Accepted

## TODO-001
- **Item**: Weather location storage, editing and the empty state when no location is saved.
- **Status**: Pending

## TODO-002
- **Item**: Weather ADR shape: dedicated or shared with the calendar ADR (DEC-001).
- **Status**: Pending

## DEC-012
- **Question**: Where are weather locations stored?
- **Context/Nuances**: MirrorOS already resolves shell preferences from sparse user overrides in
  `$XDG_CONFIG_HOME/mirroros/shell.json` over the versioned `defaults.json` (`ShellPreferences.js`, plan 02-27
  DEC-024/025); the clock already persists its format there through `updateEntryInline`. Omarchy uses a separate
  state file written by `omarchy-weather-location`.
- **User Response**: Option (a).
- **Decision**: Locations are settings of the weather bar entry in `shell.json`, for example
  `{ "id": "omarchy.weather", "locations": [{ "name", "latitude", "longitude" }], "active": 0 }`, written through
  the existing preference mechanism with its resolver and validation. `defaults.json` ships no locations (DEC-011).
  No helper or separate state file is added. Resolves the storage part of TODO-001; editing and the empty state
  remain open.
- **Status**: Accepted

## DEC-013
- **Question**: How are weather locations edited, added, activated and removed in the panel?
- **Context/Nuances**: The maintainer shared screenshots of the Omarchy weather panel (hero with icon and
  temperature, pin and location name, feels/wind/humidity, three-day forecast) and the Elsewhen world clock (city
  rows and a "+ Add a city" button). Upstream weather edits its single location by clicking the name, which opens
  a debounced open-meteo geocoder search (`geocoding-api.open-meteo.com`, one request at a time, only while
  typing in the open panel). Elsewhen removes a city through a circular "×" button at the row's top-right corner,
  shown only on hover (`removeCityAt`), and never removes the last city.
- **User Response**: Confirmed the described layout and asked to remove locations the same way as the World Clock.
- **Decision**: The upper part of the panel stays as upstream and always shows the active location (the one in
  the bar); clicking its pinned name opens the upstream geocoder search and replaces only that record. Below it,
  a list of the other saved locations in compact Elsewhen-style rows without local time or daylight strip (name,
  current temperature and icon), in saved order; clicking a row makes it active, moving it into the hero and the
  bar while the previous active location joins the list. At the end, a "+ Add location" button styled like
  Elsewhen's "Add a city" opens the same search and appends a new record without changing the active one. Removal
  follows Elsewhen: a hover-only circular "×" at each list row's top-right corner removes that record; the active
  location has no "×" and is removed by activating another first, so the last location can never be removed.
  List rows are fetched only while the panel is open, in the DEC-010 combined request. Row and button designs come
  from Elsewhen (MIT, Jason Fried), so provenance in `UPSTREAM.md` and `docs/attribution.md` cites both origins.
- **Status**: Accepted

## DEC-014
- **Question**: How does weather behave when no location is saved?
- **Context/Nuances**: The product ships no locations (DEC-011), so a new installation has none; Omarchy falls
  back to IP-based auto-detection, which MirrorOS drops (DEC-010).
- **User Response**: Option (a).
- **Decision**: The bar pill stays visible with a neutral weather glyph and no temperature. Clicking it opens the
  panel with an empty hero ("No location") and the search ready to add the first location, which becomes active
  automatically. With no location saved, no network request is made. Together with DEC-012 and DEC-013 this
  resolves TODO-001.
- **Status**: Accepted

## TODO-001 (update)
- **Status**: Resolved by DEC-012, DEC-013 and DEC-014.

## DEC-015
- **Question**: How is the ADR for the new panels structured?
- **Context/Nuances**: The calendar (DEC-001) is a new panel and partially supersedes ADR 0025's panel list.
  Weather (DEC-010) is also a new panel and adds periodic contact with a fixed third-party host, so it also
  partially supersedes ADR 0025's "Diagnostics" item (ADR 0028 already did so for the open-only network ping).
  ADR 0012 requires a scope change in `docs/mvp-scope.md` for any surface outside its list.
- **User Response**: Option (a).
- **Decision**: One ADR, "Clock calendar and weather panels", partially superseding ADR 0025's panel list for both
  panels and its "Diagnostics" item for weather only. Its reversal boundary states that removing one of the two
  panels does not reopen the other, as ADR 0025 does. The `docs/mvp-scope.md` "Desktop shell" row lists both panels
  as a scope change citing the ADR. Resolves TODO-002.
- **Status**: Accepted

## TODO-002 (update)
- **Status**: Resolved by DEC-015.

## DEC-016
- **Question**: Which mechanism performs weather and geocoder requests?
- **Context/Nuances**: Omarchy runs `curl -fsS --max-time 5` through `Process` for the forecast and the geocoder,
  and Elsewhen uses the same mechanism for open-meteo. The world clock needs `Process` anyway for its `date` zone
  probe (QML has no `Intl`) and reuses its upstream `curl` requests (DEC-022), so one mechanism for both panels
  keeps the diff with upstream small and avoids two error and timeout paths for the same provider.
- **User Response**: Approved.
- **Decision**: Weather keeps upstream `curl` through `Process`, with argument vectors and fixed `https://` URLs
  built in the model. `curl` is declared in the shell `packages` file.
- **Status**: Accepted

## DEC-017
- **Question**: How does weather integrate into the bar (position, pill interaction, IPC, units)?
- **Context/Nuances**: Omarchy places weather in `centerEnd` next to the clock; MirrorOS `centerEnd` is empty. The
  upstream pill opens the panel on left click and sends an `omarchy-weather-status` notification on right click,
  which MirrorOS drops. Units come from `shouldUseImperial` (the `unit` setting, else locale and country). MirrorOS
  panels have native bar-level IPC targets and Tab switching.
- **User Response**: Approved.
- **Decision**: Weather sits in `centerEnd` in `defaults.json`, next to the clock. Any click on the pill toggles the
  panel; there is no right-click action. A native `weather` IPC target provides open, close and toggle like the
  other panels. Units keep the upstream logic unchanged.
- **Status**: Accepted

## DEC-018
- **Question**: How is weather verified, and how are lock and suspend detected?
- **Context/Nuances**: The shell already tracks the lock state through `$XDG_RUNTIME_DIR/mirroros-shell-locked`
  and the `lockChanged` IPC function that hypridle calls for the notifications while-away count. hypridle locks
  before sleep (`before_sleep_cmd`), so pausing while locked also covers suspend and unlocking acts as resume.
- **User Response**: Approved.
- **Decision**: Lock and suspend reuse the existing lock marker and `lockChanged` signal: requests pause while
  locked and refresh on unlock; no separate suspend watcher. Verification:
  - Upstream `weather-test.sh` is copied as `tests/capabilities/desktop/shell/weather-model.test.mjs`, removing
    only the wttr.in, location-file and IP auto-detection cases, with provenance in `UPSTREAM.md`.
  - New Node tests only for MirrorOS behaviour: list operations (add, replace active, activate, remove; the
    active and last location are never removed), `shell.json` shape through `ShellPreferences`, combined
    multi-coordinate request URL (fixed `https://` only), scheduler (30 minutes, paused while locked, refresh on
    unlock and on panel open, no request without a location). Units are covered by the upstream test.
  - Static test: no `omarchy-*` in weather files; requests only to fixed `https://` open-meteo URLs; entry in
    `centerEnd`; `weather` IPC target.
  - Laboratory: no-network behaviour with the interface down (previous value kept, no error loop); full flow (empty state, first location, more locations, activate from the list, edit
    the active one, remove with "×") checking `shell.json` after each step; traffic to `api.open-meteo.com`
    observed with `ss` or `tcpdump` (none without a location, only the active location while the panel is closed,
    one combined request on open); no requests while locked and a refresh on unlock.
  - No T14s validation: weather is hardware-independent.
- **Status**: Accepted

## DEC-019
- **Question**: How is the clock calendar verified?
- **Context/Nuances**: The calendar is QML only, with no network or process. Date logic lives in upstream
  `Model.js` (ISO weeks, locale first weekday, month grid), partly already in MirrorOS `ClockModel.js`.
  `WallClock.qml` replaces `SystemClock` because of the repeated daylight-saving hour. Upstream covers this logic
  in `clock-test.sh` (228 lines); the maintainer prefers testing only what is not upstream (as in DEC-027).
- **User Response**: Approved.
- **Decision**:
  - Files kept unchanged (`Panel.qml`, `WallClock.qml`) get no MirrorOS tests; `check-provenance.mjs` asserts
    they are byte-identical to upstream.
  - Upstream `clock-test.sh` is copied as `tests/capabilities/desktop/shell/clock-model.test.mjs`, removing only
    cases for dropped features (timezone picker), with provenance in `UPSTREAM.md`; no new tests for upstream
    date logic.
  - Static test: no `Process` or `omarchy-*`; `clock` IPC target; left click on the clock opens the panel; middle
    click has no action (timezone picker excluded).
  - Laboratory, integration only: open and close by click and IPC; Tab between panels; the right-click format
    cycle still works. Month navigation and today's mark are a visual smoke check.
  - No T14s validation.
- **Status**: Accepted

## DEC-020
- **Question**: Should Elsewhen (Omarchy world clock, MIT, Jason Fried) enter MirrorOS scope, and in what shape?
- **Context/Nuances**: About 7,000 lines: a bar globe icon and a panel with one row per city (time, date, offset,
  daylight strip with time scrubbing, temperature, people), drag reordering, "×" removal, "Add a city" search and a
  spinnable 3D globe with moon mode. It uses `timedatectl list-timezones` and `TZ=… date` probes through `bash -c`
  (QML has no `Intl`, so IANA zone times need an external probe; it runs on open and every 5 minutes while open),
  `curl` to open-meteo for geocoding and batched per-city temperature (open-only, cached 20 minutes), GitHub avatars
  for people given by handle, `sudo -n timedatectl set-timezone` through an Omarchy sudoers rule, and
  `omarchy-shell`. Its timers run only while the panel is open. People are an optional per-city list (names or
  `@github` handles, up to 12) shown as discs on an extra row line, used to see who is in which zone and what time
  it is for them; names need no network, handles fetch avatars from a second third party. Per-city temperature uses
  the same provider and endpoint as weather but a separate location list. The maintainer works daily with people in
  different time zones.
- **User Response**: Wants the panel without the globe; wants to understand people before deciding; wants to keep
  temperature.
- **Decision**: Adapt Elsewhen as a panel without the globe (`Globe`, `MiniGlobe`, `GlobeModel`, moon mode). It
  joins the shared ADR (DEC-015), which now covers three panels: clock calendar, weather and world clock. Changing
  the system time zone (`sudo -n timedatectl set-timezone`) is excluded because ADR 0025 forbids sudo and
  passwordless rules for panels. Real line counts are measured during adaptation.
- **Status**: Accepted

## TODO-003
- **Item**: World clock people: plain names and/or GitHub avatars.
- **Status**: Pending

## TODO-004
- **Item**: World clock per-city temperature: mechanism and relation to weather.
- **Status**: Pending

## TODO-005
- **Item**: Time-zone probe mechanism (no `Intl` in QML).
- **Status**: Pending

## TODO-006
- **Item**: Further trimming: greetings, drag reordering, daylight-strip scrubbing.
- **Status**: Pending

## DEC-021
- **Question**: Should world clock rows carry people (plain names and/or GitHub avatars)?
- **Context/Nuances**: Elsewhen shows a hover "account-plus" button beside "×" that opens an inline field for
  comma-separated names or `@github` handles, stored per city in `shell.json`; handles fetch avatars from GitHub
  (second third party, image cache, `jq`). Options were names only, names plus avatars, or no people.
- **User Response**: Option (c).
- **Decision**: No people. The "account-plus" button, the inline people field, the extra row line, avatars and
  the `people` key are dropped. Resolves TODO-003.
- **Status**: Accepted

## TODO-003 (update)
- **Status**: Resolved by DEC-021.

## DEC-022
- **Question**: How does the world clock provide per-city temperature?
- **Context/Nuances**: Elsewhen's temperature path is self-contained and open-only: `Model.forecastUrl`,
  `weatherKind`, an in-memory `facts` cache (geocodes for the session, weather for 20 minutes), geocoding by row
  label for cities without coordinates, network-input validation, the `/usr/share/zoneinfo/zone1970.tab` fallback
  read through `FileView`, and the previous value kept on failure. It fetches with `curl` through `Process`, and
  `geoProc` uses the argument-vector `bash -c` pattern MirrorOS already uses in `Menu.qml`, `AppLibrary.qml` and
  `ShellConfig.qml`.
- **User Response**: Reuse upstream as is.
- **Decision**: Reuse the upstream temperature path unchanged, without a module shared with weather: each panel
  keeps its own model as upstream does. `curl` (core) and `tzdata` (core) are declared in the shell `packages`
  file; `jq` is not needed. Code tied to removed features (people, globe, `timezoneCommand`, `omarchy-shell`) is
  dropped. The shared ADR (DEC-015) names the world clock's open-only open-meteo geocoding and forecast requests
  alongside weather's. Resolves TODO-004.
- **Status**: Accepted

## TODO-004 (update)
- **Status**: Resolved by DEC-022.

## DEC-023
- **Question**: Which mechanism provides zone times for the world clock?
- **Context/Nuances**: QML has no `Intl`. Upstream `Model.probeCommand` runs one argument-vector
  `bash -c 'for z in "$@"; do TZ="$z" date "+$z|%Z|%z"; done' bash <zones…>`, plus
  `timedatectl show -p Timezone --value` for the local zone, on panel open and every 5 minutes while open; the
  search uses `timedatectl list-timezones` with the upstream city aliases, also only while open. All are read-only
  and unprivileged.
- **User Response**: Option (a).
- **Decision**: Reuse the upstream probe and time-zone list mechanism unchanged. Resolves TODO-005.
- **Status**: Accepted

## TODO-005 (update)
- **Status**: Resolved by DEC-023.

## DEC-024
- **Question**: Which further Elsewhen pieces are trimmed, and is the globe enabled?
- **Context/Nuances**: Greetings (`Greetings.js`, about 980 lines of static data shown on row hover), drag
  reordering (persisted to `shell.json`) and daylight-strip scrubbing (holding and dragging one strip moves every
  row to that hour) are QML only, with no network, process or privilege. Enabling the globe would add about 1,270
  lines (`Globe`, `GlobeModel`, `GlobeFooter`, `MoonDot`, `Arc`, `ArcText`), `world.json` (Natural Earth 110m,
  public domain) and `cities.json` with their provenance, a full-canvas repaint of 7–14 ms per frame while it
  moves, a 20 s repaint and 5-minute probe while visible, and the highest breakage and verification cost of the
  panel, for little daily information beyond the rows. It is loaded only on demand, and upstream already has a
  `globeEnabled` setting.
- **User Response**: Keep the three pieces; agrees to keep the globe out.
- **Decision**: Keep greetings, drag reordering and daylight scrubbing unchanged. The globe stays out (DEC-020):
  `globeEnabled` is fixed to `false`, `MiniGlobe` stays as a static ornament of the hero title, and `Globe`,
  `GlobeModel`, `GlobeFooter`, `MoonDot`, `Arc`, `ArcText`, `world.json` and `cities.json` are not delivered.
  `Sun.js` stays because the daylight strip uses it. Resolves TODO-006.
- **Status**: Accepted

## TODO-006 (update)
- **Status**: Resolved by DEC-024.

## DEC-025
- **Question**: How does the world clock start on a new installation?
- **Context/Nuances**: Upstream writes a starting list the first time the panel opens: the user's city, derived
  at runtime from the system time zone (`timedatectl`), plus four well-known destinations spread at least three
  hours apart around the clock relative to it, stored as a normal `cities` list in `shell.json`. No personal data
  is in the repository: the home city comes from the installation's time zone and the destinations are generic,
  computed from a list of well-known cities, so DEC-011 holds.
- **User Response**: Option (a).
- **Decision**: Keep the upstream first run unchanged: home city plus four computed destinations, written to the
  world clock entry's `cities` in `shell.json` on first open.
- **Status**: Accepted

## DEC-026
- **Question**: How does the world clock integrate into the bar (position, icon, IPC, settings)?
- **Context/Nuances**: Omarchy's default `centerEnd` is `elsewhen`, `weather`, `system-update`. MirrorOS already
  writes entry settings, including lists, through `updateEntryInline` (`ShellConfig.qml`, `shell.qml`, used by
  Tray), and upstream stores `cities` inline on the entry. MirrorOS panels have native bar-level IPC targets.
- **User Response**: Approved.
- **Decision**: `centerEnd` in `defaults.json` holds `omarchy.elsewhen` then `omarchy.weather`, in Omarchy's order;
  the upstream id is kept like the other widgets. The upstream globe icon toggles the panel on any click. A native
  `worldclock` IPC target provides open, close and toggle. Upstream entry settings `hour24`, `offsetMode`
  (home/utc) and `units` are kept, and `cities` is written through `updateEntryInline`; `globeEnabled` is fixed
  to `false` and not exposed, and `smoothMotion` and other globe settings are dropped.
- **Status**: Accepted

## DEC-027
- **Question**: How is the world clock verified, given that most of it is reused from upstream?
- **Context/Nuances**: Upstream ships Bash-wrapped Node tests (`elsewhen-model-test.sh` 504 lines, plus sun,
  greetings, pointer, globe and arc tests) that depend on its `base-test.sh` and repository layout, so they cannot
  run directly from `~/code/omarchy`. The maintainer prefers testing only what is not upstream.
- **User Response**: Approved.
- **Decision**:
  - Unchanged files (for example `Greetings.js`, `Sun.js`, `DaylightStrip.qml`) get no MirrorOS tests;
    `check-provenance.mjs` asserts they are byte-identical to upstream ("Copied"), which keeps upstream's testing
    valid.
  - Adapted files (`Model.js`, `Panel.qml`, `CityRow.qml`, `HeroTitle.qml`): the upstream model test is copied as
    `tests/capabilities/desktop/shell/world-clock-model.test.mjs`, removing only cases for dropped features
    (people, globe, `timezoneCommand`), with provenance in `UPSTREAM.md`; no new tests for upstream logic.
  - MirrorOS-only static test: no `sudo`, `set-timezone`, GitHub or `omarchy-*`; no globe files; `globeEnabled`
    fixed `false`; `worldclock` IPC target; `centerEnd` with the world clock before weather; `curl` and `tzdata`
    in `packages`.
  - Laboratory, integration only: open and close by click and IPC and Tab switching; first run and add, remove and
    reorder written correctly to `shell.json` through MirrorOS `updateEntryInline`; no traffic while closed; no
    error loop without network. Scrubbing, greetings and search are a visual smoke check only.
  - No T14s validation.
- **Status**: Accepted

## DEC-028
- **Question**: Should Omarchy's Reminder (indicator and reminder flow) enter MirrorOS scope?
- **Context/Nuances**: Omarchy reminders are relative and ephemeral ("in N minutes, remind me of X"): no absolute
  time, recurrence or dates. `SUPER+CTRL+R` opens a two-step prompt (`ReminderFlow.qml`, 169 lines: minutes, then
  an optional message); a notification confirms the time; on expiry a notification shows the message; the bar
  indicator shows the pending count and a click lists them; further bindings show (`SUPER+CTRL+ALT+R`) and clear
  (`SUPER+SHIFT+CTRL+R`) reminders. Each reminder is a transient systemd user timer (`systemd-run --user
  --on-active`), with the message in `$XDG_RUNTIME_DIR`, so reminders are lost on logout or reboot and no
  reminder daemon exists. The indicator refreshes on change notifications from the command, not by polling. It
  depends on `omarchy-reminder`, `omarchy-notification-send`, `omarchy-i18n`, `omarchy-shell` and `jq`.
  PasswordlessSudo and RemoteSession were discarded in the same review and are not recorded.
- **User Response**: Fits the maintainer's workflow.
- **Decision**: Adapt Reminder with an owned `reminder` command replacing `omarchy-reminder` over the MirrorOS
  notification service, the reminder prompt, the three bindings and the `Indicators` entry. Admission route and
  command design are decided in follow-up questions.
- **Status**: Accepted

## DEC-029
- **Question**: How does a delivered reminder draw attention?
- **Context/Nuances**: Omarchy sends a normal, timed notification without sound. The MirrorOS notification
  service keeps Critical urgency on screen until dismissed (`durationFor` returns 0) with the theme's urgent
  colour, and `Delivery.js` `bypassesQuiet` lets only `notify-send` critical notifications through Do Not Disturb
  and snoozes, so a notification sent under its own app name would be silenced. The shell plays no sounds;
  `pw-play` ships with PipeWire and `alarm-clock-elapsed.oga` belongs to `sound-theme-freedesktop`.
- **User Response**: Approved.
- **Decision**: A delivered reminder is a Critical notification under the app name `reminder`, which stays until
  dismissed with the urgent colour; `reminder` is added to `bypassesQuiet` so it passes Do Not Disturb and
  snoozes. On expiry the command also plays `/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga` with
  `pw-play`, also under Do Not Disturb, silenced only by system mute; `sound-theme-freedesktop` is declared. No
  shell sound support and no resident process are added.
- **Status**: Accepted

## TODO-007
- **Item**: Reminder admission route (scope change, ADR need) and owned command design.
- **Status**: Pending

## DEC-030
- **Question**: How is Reminder admitted?
- **Context/Nuances**: Reminder is a new desktop capability, not only a bar piece; `docs/mvp-scope.md` classifies
  adding a capability as a scope change. It uses surfaces ADR 0012 already admits (bar indicator, notifications,
  menu or launcher for the prompt); the `bypassesQuiet` change adjusts notification policy inside the shell. No
  ADR trigger applies: no daemon, privilege, network or new provider, only base pieces (systemd user timers,
  PipeWire, the freedesktop sound theme).
- **User Response**: Option (a).
- **Decision**: Scope change without ADR: a new "Quick reminders" row in the `docs/mvp-scope.md` Desktop table
  (provider: owned `reminder` command over systemd user timers and shell notifications), a new frequent action
  ("Set a reminder"), and provenance in `capabilities/desktop/shell/UPSTREAM.md`, `docs/attribution.md` and the
  capability's `sources.md`. Resolves the admission part of TODO-007; command design remains open.
- **Status**: Accepted

## DEC-031
- **Question**: How are the reminder command, prompt, bindings and verification designed?
- **Context/Nuances**: Owned commands install to `/usr/share/mirroros/<area>/<command>` from their capability's
  `apply` (for example `/usr/share/mirroros/hardware/volume`); `jq` is already declared by other capabilities. The
  MirrorOS menu has an `input` dmenu mode but no product command-line client (`check-dmenu.sh`); upstream
  `ReminderFlow.qml` (169 lines) is its own overlay on `OverlayWindow`, which MirrorOS already has. None of
  Omarchy's reminder bindings is taken in MirrorOS.
- **User Response**: Approved.
- **Decision**:
  - New capability `capabilities/desktop/reminders/` with the Bash `reminder` command installed at
    `/usr/share/mirroros/reminders/reminder`, `apply`, `packages` (`sound-theme-freedesktop`, `jq`) and
    `sources.md`.
  - Interface as upstream: `reminder <minutes> [message]`, `reminder show [--json]`, `reminder clear`, and
    `reminder -i` opening the prompt through IPC.
  - Implementation: units `mirroros-reminder-<min>m-<epoch>` through `systemd-run --user --on-active`; messages
    under `$XDG_RUNTIME_DIR/mirroros/reminders/`, always passed as arguments, never inside script text; delivery
    sends the Critical `-a reminder` notification and runs `pw-play` (DEC-029); every change asks the shell
    through IPC to refresh the indicator.
  - Prompt: upstream `ReminderFlow.qml` adapted in the shell with a native `reminders` IPC target (`open`)
    replacing `omarchy-shell summon`; confirming runs `reminder <min> <msg>` with separate arguments.
  - Bindings: Omarchy's `SUPER+CTRL+R` (set), `SUPER+CTRL+ALT+R` (show) and `SUPER+SHIFT+CTRL+R` (clear), declared
    in the shell bindings layer and listed in the keybinding help.
  - Verification: Bats for the command (arguments, unit names, message quoting, `show --json`, `clear`, delivery
    with `systemd-run`, `notify-send` and `pw-play` doubles); Node for `ReminderFlowModel.js`, copying an upstream
    test if one exists; laboratory create, list and clear, delivery with sound and under Do Not Disturb, and
    nothing surviving logout.
  - Resolves TODO-007.
- **Status**: Accepted

## TODO-007 (update)
- **Status**: Resolved by DEC-030 and DEC-031.

## DEC-032
- **Question**: Should Omarchy's ActiveWindow bar widget (not in its default bar) enter MirrorOS scope?
- **Context/Nuances**: The maintainer sometimes cannot tell which application is focused in the tiling layout,
  for example in a viewer. Upstream `ActiveWindow.qml` (65 lines) shows the focused toplevel's title, or its
  `appId` without a title, after the workspaces, capped at 280 px and elided; it uses native Quickshell
  `ToplevelManager.activeToplevel` (no process, polling or `omarchy-*`); left click activates the window, and
  middle or right click closes it; it hides without a focused window or on a vertical bar. Titles often do not
  name the application (an image viewer shows `photo.png`).
- **User Response**: Approved.
- **Decision**: Adapt ActiveWindow showing the application name first, then the title (`Image Viewer ·
  photo.png`); the name is resolved from the `appId` through the desktop entries MirrorOS `AppLibrary.qml` already
  handles, falling back to the raw `appId`. The tooltip shows the full text. Left click focuses the window; middle
  and right click do not close it, to avoid closing unsaved work by accident. It sits in `left` after the
  workspaces. Admission is routine inside ADR 0012's bar surface, like the microphone indicator: provenance in
  `UPSTREAM.md` and `docs/attribution.md`, and a mention in the `docs/mvp-scope.md` "Desktop shell" row.
- **Status**: Accepted

## DEC-033
- **Question**: How is the accepted scope split into plans?
- **Context/Nuances**: Accepted modules: StayAwake, microphone and ActiveWindow (routine), clock calendar, weather
  and world clock (shared ADR), reminders (scope change, new capability). Together they are too large for one
  plan, as in Story 4.4 (plans 02-27 to 02-30).
- **User Response**: Approved; materialize the first plan directly without a draft.
- **Decision**: Four plans: 02-31 routine bar indicators and widgets (StayAwake, microphone, ActiveWindow;
  ActiveWindow verified like the microphone with a static test and laboratory checks); 02-32 shared ADR plus clock
  calendar and weather; 02-33 world clock under the ADR accepted in 02-32; 02-34 reminders. 02-31 and 02-34 are
  independent, 02-33 depends on 02-32, and none depends on Story 4.5. This `/plan:save` run materializes 02-31 only.
- **Status**: Accepted
