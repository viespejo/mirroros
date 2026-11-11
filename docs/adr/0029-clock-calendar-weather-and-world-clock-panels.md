# ADR 0029: Clock Calendar, Weather and World Clock Panels

## Identifier and title

- **Identifier:** `0029`
- **Title:** Clock Calendar, Weather and World Clock Panels

## Status

`Accepted`

The maintainer accepted this architectural decision on 2026-11-11 at the plan 02-32 acceptance checkpoint, after the
bar-modules evaluation interview (DEC-015, DEC-037). Calendar and weather implementation and validation remain with
plan 02-32; world-clock implementation and validation remain with plan 02-33.

## Date

`2026-11-11`

## Context and question

[ADR 0025](0025-shell-panels.md) extends the owned shell with bar-anchored panels "for these panels only": audio,
network/Wi-Fi, Bluetooth, display and power. Its Decision also states "**Diagnostics:** no continuous probing of a
fixed third-party host; panels use the gateway and NetworkManager's connectivity check".
[ADR 0028](0028-network-panel-internet-latency-probe.md) already superseded that item for the open-only network
ping. [`docs/adr/README.md`](README.md) forbids rewriting an accepted decision.

The bar-modules evaluation compared the MirrorOS bar with the Omarchy `v4.5.0` default bar and selected three
panels of daily value, all outside ADR 0025's list:

- **Clock calendar** (Omarchy `shell/plugins/panels/clock`): a month grid with ISO week numbers opened from the bar
  clock, a year progress bar, a week-start toggle and an optional memento-mori bar. It is QML only, spawns no process
  and calls no `omarchy-*` helper; its week start, birth year and life expectancy are opt-in settings written
  through `updateEntryInline`.
- **Weather** (Omarchy `shell/plugins/panels/weather`): a bar pill and panel that upstream feed from wttr.in and
  open-meteo through `curl`, every 15 minutes, for one location with IP-based auto-detection and `omarchy-weather-*`
  helpers. It contacts a fixed third-party host periodically, which ADR 0025's "Diagnostics" item avoided.
- **World clock** (Omarchy Elsewhen, `shell/plugins/panels/elsewhen`, MIT, Jason Fried): one row per city with time,
  offset, daylight strip and temperature. QML has no `Intl`, so zone times come from `TZ=<zone> date` and
  `timedatectl` probes, and temperatures from open-meteo through `curl`; upstream also fetches GitHub avatars, draws
  a 3D globe and changes the system time zone through `sudo -n timedatectl set-timezone`.

The question is: may the shell admit these three panels, and within which network, process, privilege and
persistence boundaries?

## Constraints and decision criteria

- ADR 0012 and ADR 0025 remain in force outside the items superseded here: no resident shell daemon, no background
  service, no authenticating QML, and no `sudo`, `pkexec` or passwordless rule for panels.
- AGENTS.md forbids personal configuration in the repository, so the product ships no personal locations or cities.
- Third-party contact must be bounded: one provider, fixed `https://` URLs, no traffic without a user-chosen
  location, and a refresh interval matched to the provider's update rate.
- Stay close to Omarchy `v4.5.0` to keep the adaptation reviewable; copy files unchanged where possible.
- User settings use the existing sparse `shell.json` preference mechanism (plan 02-27 DEC-024/025), stored per
  widget id under `bar.widgets.<id>` (plan 02-32 DEC-035/039); no helper or separate state file.
- Sustainability for a single maintainer: each panel must be removable on its own.

## Alternatives considered

1. **One ADR admitting the three panels with open-meteo as the only provider (selected).** Covers the shared
   network and process boundary once; each panel keeps its own model as upstream does.
2. **Separate ADRs per panel.** Repeats the same `curl` and open-meteo boundary three times for related panels.
3. **Calendar only.** Within the shell's process boundaries, but drops weather and the world clock, which the
   maintainer asked for (daily work across time zones, occasional weather).
4. **Weather through wttr.in as upstream.** Adds a second provider and IP-based location without need.
5. **Native QML `XMLHttpRequest` instead of `curl`.** Avoids `curl`, but diverges from upstream and gives two
   error and timeout paths, while the world clock needs `Process` for its zone probe anyway.
6. **Full Elsewhen with people, GitHub avatars, globe and time-zone change.** Adds a second third party, a heavy
   canvas and a privileged system change that ADR 0025 forbids.

## Evidence

- The [bar-modules evaluation technical interview log](../technical-interviews/bar-modules-evaluation_log.md)
  records DEC-001, DEC-010 to DEC-027 and DEC-034 to DEC-039.
- The Omarchy `v4.5.0` (`ac2690cd7be4f47e4a255f5e2e78d904d436b068`) sources
  `shell/plugins/panels/{clock,weather,elsewhen}`, read from the pinned read-only upstream reference, define the
  process, network and settings behaviour described above.
- The shell's existing lock marker (`$XDG_RUNTIME_DIR/mirroros-shell-locked`, `lockChanged` IPC from hypridle, which
  locks before sleep) gives the lock and resume signal without a separate watcher.

No laboratory or hardware evidence exists yet; validation belongs to plans 02-32 and 02-33.

## Decision

Admit three bar-anchored panels in the shared panel container, each with a native bar-level IPC target (open, close,
toggle) and Tab switching like the ADR 0025 panels:

- **Clock calendar:** upstream `Panel.qml`, `Model.js` and `WallClock.qml` copied unchanged, opened by left click on
  the bar clock and through a `clock` IPC target. Middle click has no action (the timezone picker is excluded); right
  click keeps the format cycle. The week-start toggle and the optional memento-mori bar are opt-in persisted
  settings (`weekStartDay`, `birthYear`, `lifeExpectancy`); with no birth year the memento-mori bar stays hidden.
- **Weather:** a bar pill in `centerEnd` and a panel adapted from upstream, toggled by any click and through a
  `weather` IPC target. Several saved locations (`{ name, latitude, longitude }`) with one active, edited only in the
  panel; the product ships no locations. Without a location the pill shows a neutral glyph and nothing is fetched.
- **World clock:** adapted from Elsewhen without people, GitHub avatars, globe or time-zone change, with a
  `worldclock` IPC target. Its implementation and validation remain with plan 02-33.

Boundaries:

- **Provider:** open-meteo only (`https://api.open-meteo.com` forecast, `https://geocoding-api.open-meteo.com`
  geocoder), for the weather pill and panel and the world-clock temperatures. wttr.in, IP-based auto-detection and
  GitHub are excluded.
- **Mechanism:** `curl` through Quickshell `Process` with argument vectors and fixed `https://` URLs built in the
  panel models; no shell interpolation of user input. `curl` is declared in the shell `packages` file.
- **Weather schedule:** while the panel is closed, only the active location is fetched, every 30 minutes; opening the
  panel refreshes all saved locations in one combined request. Requests pause while the session is locked (which
  also covers suspend, since hypridle locks before sleep) and refresh on unlock. The geocoder runs only while the user
  types in the open panel. A failed request keeps the previous value and starts no retry loop.
- **World-clock probes:** read-only, unprivileged and only while its panel is open: `TZ=<zone> date`,
  `timedatectl show` and `timedatectl list-timezones`. Its geocoding and temperature requests are open-only. No
  `sudo`, `set-timezone` or passwordless rule.
- **Persistence:** panel settings (calendar options, weather locations, world-clock cities) are stored per widget id
  under `bar.widgets.<id>` in the user's `shell.json` through `updateEntryInline`; no helper, daemon or separate
  state file, and no personal data in the repository.

This ADR supersedes only ADR 0025's panel list, for these three panels, and its "Diagnostics" item, for open-meteo
traffic only. Every other part of ADR 0025 remains in force, as does ADR 0028 for the network panel.

## Consequences and trade-offs

- With at least one saved location, the shell contacts open-meteo about every 30 minutes while the session is
  unlocked, including on metered networks; every request exposes the client IP to the provider.
- The calendar's opt-in settings and the weather locations live in the user's `shell.json`; without per-widget
  storage they would have frozen whole layout zones.
- The calendar stays byte-identical to upstream and can be updated by copying; weather and the world clock are
  adapted and need review on upstream changes.
- `curl` becomes an explicit shell dependency.
- The world-clock rules are accepted before its implementation; plan 02-33 may need an amendment if adaptation
  contradicts them.

## Replacement or reversal boundary

Reconsider through a new ADR if a panel needs another provider or third party, traffic while the session is locked
or for non-active locations while the panel is closed, a privileged action, a helper, daemon or separate state
file, or if open-meteo's terms or availability change. Removing one of the three panels does not require reopening
the others.

## Required validation

In plan 02-32 (calendar and weather), after acceptance:

- Provenance: the copied calendar files are byte-identical to `v4.5.0`; adapted files are recorded in `UPSTREAM.md`
  and `docs/attribution.md`, with the weather rows citing Omarchy and Elsewhen.
- Node tests: the ported upstream clock and weather model tests, weather location operations, the combined request
  URL, the scheduler decisions, and static checks for no `omarchy-*`, only fixed `https://` open-meteo URLs and the
  IPC targets.
- Laboratory guest: open and close by click and IPC, Tab switching, `shell.json` holding only `bar.widgets` keys,
  no open-meteo traffic without a location, only the active location while closed, one combined request on open, no
  request while locked and a refresh on unlock, and the previous value kept offline.

In plan 02-33 (world clock): the equivalent provenance, model, static and laboratory checks, including no `sudo`,
`set-timezone`, GitHub or globe files and no traffic or probe while its panel is closed.

No T14s validation is required: the panels are hardware-independent.

## References

- [ADR 0025: Shell Panels](0025-shell-panels.md)
- [ADR 0028: Network Panel Internet Latency Probe](0028-network-panel-internet-latency-probe.md)
- [ADR 0012: Owned Quickshell Desktop Shell](0012-owned-quickshell-desktop-shell.md)
- [Bar-modules evaluation technical interview log](../technical-interviews/bar-modules-evaluation_log.md)
- [Desktop shell procedure](../procedures/desktop-shell.md)
- [MVP scope and change control](../mvp-scope.md)
- [Attribution](../attribution.md)

## Superseded by

`None`
