# Story 4.4 Panel Infrastructure Planning — Consolidated Plan (seed)

This document seeds the technical interview for plan 02-27, the first Story 4.4 production plan for shell panels. It
continues the [shell panels plan](story-4-4-shell-panels_plan.md) after plan 02-26 closed with
[ADR 0025](../adr/0025-shell-panels.md) Accepted. It records only settled inputs and open questions; decisions are
added by the interview, with IDs continuing from DEC-028 and TODO-009.

## Settled inputs

Plan 02-27 delivers the shared panel container, the audio, display and power panels, an open/toggle IPC target for
every panel including notifications, and the panel key bindings. Network/Wi-Fi (02-28), Bluetooth and its pairing
agent (02-29) and graphical VPN access (02-30) follow in their own plans.
[Gate G5 in the [prototype procedure](../procedures/shell-panels-prototype.md#production-plan-split-g5-todo-006)]

Each panel adapts the Omarchy 4.5 panel by copying and adapting it, with per-file provenance in the shell
`UPSTREAM.md` and `docs/attribution.md`. Prototype code is not promoted; the verified prototype bundle in ignored
`evidence/shell-panels-prototype/handoff-053e7c3/` is design reference only. Omarchy 4.5 is re-extracted read-only
with the procedure's extraction method. [ADR 0025, G3, G4, DEC-024]

Panel functions are fixed by the gate (G2): audio with output and input selection, levels, mute, mute-all, an input
peak meter while open, a per-application mixer with PipeWire names and an unavailable state; display with brightness,
output enable and disable with a last-display guard, and scale; power with battery state and AC and battery power
profiles. Excluded: DSP and EasyEffects sink resolution, untyped virtual inputs, text size, CPU and memory statistics,
a shell media service and the power watcher. [ADR 0025, DEC-008, DEC-015]

Production requirements from the evidence apply: one IPC target per shell, not per bar instance; atomic publication
of the shell tree; distinct current, chosen and focused states with pending actions not repeated; per-panel
real-hardware validation, with the T14s non-qualifying and the Framework Laptop 13 Pro pending. Panels act as the
session user without `sudo`, `pkexec` or a passwordless rule. [ADR 0025, G14]

The terminal paths and owned commands from plan 02-25 (`/usr/share/mirroros/hardware/{volume,media,brightness,power-profile}`
and the Hyprland `display` command) remain the fallback. [DEC-006]

## Decisions

Omarchy material is read from a full, clean clone at `~/code/omarchy`, outside the repository and unversioned, used
read-only through `git show <tag>:<path>`. Omarchy 4.5 material is pinned to tag `v4.5.0`
(`ac2690cd7be4f47e4a255f5e2e78d904d436b068`), the same kind of Git pin as the shell's current `7075b61`. The tag is
unsigned; its correspondence rests on a cross-check against the signature-verified 4.5 ISO, where all 873 package
files under `usr/share/omarchy/` are byte-identical to the tag, and that cross-check is recorded in the procedure and
the shell `UPSTREAM.md`. The older partial clone under `evidence/` is left untouched; its three unexplained local
modifications are only recorded. [DEC-028, TODO-009]

The shared container moves to Omarchy 4.5: `Ui/KeyboardPanel.qml` and `Ui/PanelSlider.qml` are copied byte-for-byte
from `v4.5.0`, and `Ui/Panel.qml` is adapted from it with Omarchy's `ShellIpc` removed, so the panels use native
Quickshell IPC only and no `IpcRegistry` or `omarchy-shell` coupling enters the shell. The audit of `7075b61..v4.5.0`
found no new Omarchy coupling in the container; its only hard requirement is an `easeOut` token added to the adapted
`Commons/Style.qml`. The 4.5 container calls the bar's card and panel-switching functions only when they exist, so it
runs without morph or switching until the bar provides them. The notification panel, the container's only current
consumer, must pass its existing checks unchanged; any regression is fixed in `NotificationPanel`, never by forking
the container. [DEC-029]

Panels are reached the way Omarchy 4.5 reaches them, minus its private socket. Key presses go through a native
Quickshell `GlobalShortcut` (`appid: "mirroros"`) fired by Hyprland's `global` dispatcher, so no process is spawned
per press, and the adapted bar routes each request to the focused monitor's panel with the ported 4.5
`summonBarWidget`/`findPanelWidget` and `pickPanelSlot` logic, which MirrorOS can host because it already keeps one
`Bar` object with a slot registry across screens. Scripts and tests use one native `IpcHandler` per panel, declared
once in the bar with plain names (`audio`, `display`, `power`, later `network` and `bluetooth`) and only `open`,
`close` and `toggle`. Omarchy's own socket and `omarchy-shell` CLI exist to save ~40 ms per call on its script-heavy
paths (auto-repeating OSD keys, theme polling, refresh-after-toggle); panel opening has no such path, so no socket is
built and proposing one would need an ADR. Notifications keep their existing target and only gain a binding. Moving
the existing shell bindings to `GlobalShortcut` and measuring OSD latency under key repeat stay outside this plan.
[DEC-030, TODO-010, TODO-011]

The bar port is complete rather than minimal, so no panel behaviour from Omarchy 4.5 is lost: besides focused-monitor
routing, the adapted `bar/Bar.qml` and `bar/BarModel.js` gain Tab / Shift+Tab switching between panels of the same
bar section and the card morph between them, about 150 lines of QML and JavaScript with no new service. The pure
selection functions in `BarModel.js` get new Node tests, and the bar keeps its closed component map without the
plugin host, widget dragging or dock. [DEC-031]

The audio panel keeps everything Omarchy 4.5 offers on the supported hardware. Most of it is native Quickshell, and
copying the upstream panel also keeps its guard against PipeWire node removal crashing the shell. The three functions
that need helpers — moving already-playing streams to a newly chosen device, hiding unplugged ports, and cycling
outputs from the keyboard — move into a new owned `system/audio` command, `audio-device`, with `libpulse` declared
for `pactl`. The gate's exclusions stay: speaker-tuning DSP has no profile for the T14s or the Framework, and the
EasyEffects and untyped virtual-input paths only matter if those tools are in use. Because the panel cannot replace
what the maintainer uses `pavucontrol` for (per-application routing, card profiles such as HDMI or Bluetooth
A2DP/HFP, port selection, balance), `pavucontrol` is installed as the advanced audio tool and reached from an
"Advanced…" button in the panel. The mixer also shows MPRIS player names through the native Quickshell module, which
only improves generic stream names and needs no media service. [DEC-032, TODO-012, TODO-013]

Both additions go beyond ADR 0025, which defers MPRIS labels, so the plan carries an ADR 0026 that supersedes only
that item and records `pavucontrol` and its button; neither is implemented before the maintainer accepts it, and the
scope document changes in its own commit. [DEC-033]

The display panel reaches hardware only through owned commands, extended rather than replaced. `brightness` gains an
absolute value and a no-OSD mode for the slider, and the Hyprland `display` helper gains output on/off with the
last-display guard enforced in the command itself, an absolute scale and a JSON state query, all runtime-only like
the rest of the helper. The panel's scale therefore does not survive a reload or reboot and does not set `GDK_SCALE`;
that is the price of never rewriting the user's monitor rules, and persistence is left for a governed follow-up.
External monitors show the upstream fixed-brightness state because DDC would need I²C device access. Text size stays
excluded: it rewrites GTK and terminal configuration owned elsewhere, so it belongs to a future cross-capability
appearance preference. [DEC-034, TODO-014, TODO-015, TODO-016]

The power panel loses nothing visible. Basic battery state comes from native UPower, and a new read-only
`battery-status` command supplies power draw, capacity, cycles, charge limit and the holding state, which also
explains the T14s charge thresholds. Profiles are read natively without Python, but always written through the owned
`power-profile` command, so the per-source memory and the power watcher keep the user's choice when the power source
changes. The upstream panel's CPU and memory statistics were never displayed, so dropping that residual call removes
only a background process. [DEC-035]

The i18n catalog keeps its current source. The `7075b61` catalog already holds every key the shell and the new panels
use, with values identical to `v4.5.0`, so the existing generator regenerates it unchanged; the prototype only failed
because 4.5 dropped the old notification keys. MirrorOS-owned panel text stays as English literals in QML, as the
shell already does, and moving the catalog pin later would need its own plan for the notification keys.
[DEC-036, TODO-017]

Provenance keeps the shell's existing format and only learns about a second revision: copied 4.5 files stay
headerless with a revision-prefixed source in `UPSTREAM.md`, adapted files keep the established header and cite both
revisions when they now mix `7075b61` and `v4.5.0` code, and owned commands keep their one-line attribution plus
capability `sources.md` entries. The provenance check, which already fails on a pre-existing 4.0.6 copy, learns
per-row revisions read from the history clone; the one failing copy is re-pinned to `v4.0.6`, whose bytes match, and
no other existing row changes. [DEC-037]

Key bindings follow Omarchy 4.5 letters: `SUPER+CTRL+A`, `D` and `P` open audio, display and power now, while `N` and
`B` are held for the network and Bluetooth plans, so DEC-006's `W` gives way to 4.5's `N`. The numbered
`SUPER+CTRL+1..9` chords are kept because they are upstream behaviour, accepting that their numbers follow the
visible icons and shift as later plans add panels. The notification panel, which 4.5 no longer has, gets
`SUPER+CTRL+ALT+comma` within the existing comma family, and the reserved `SHIFT+XF86AudioMute` finally cycles
audio outputs through the owned command. Story 4.7 still owns the final binding map. [DEC-038]

The default audio device persists the standard way: the owned command sets it with `wpctl set-default` and
WirePlumber keeps it in its own state, so the panel stores nothing and cannot disagree with the audio stack. The open
question from the prototype becomes a validation step, in the laboratory across a session restart and on the T14s
across a reboot and an absent-then-returning device; a failure is a finding for `system/audio`, not a reason for
panel state. [DEC-039]

Delivery adds no configure step: four existing steps change and the shell keeps its existing atomic publication.
Validation follows ADR 0025 panel by panel. Product tests replace the prototype's local ones — Bats for the owned
commands, Node for the bar selection logic, panel models, bindings, provenance and the absence of `omarchy-*` calls,
and a session check for opening, switching and unavailable states, with the notification checks unchanged. The
laboratory covers what emulated audio and a single display can show; the supervised T14s covers what needs real
devices — wired and Bluetooth headphones, an external monitor for routing and the output guard, and the battery's
charge limit and profile memory across power-source changes — and the hardware matrix records each panel with the
Framework still pending. [DEC-040]

All of this stays in one plan, because splitting it would renumber plans that the accepted ADR 0025 already cites and
the pieces depend on one another. Checkpoints keep it reviewable: the infrastructure is shown working with
notifications intact before any panel lands, every product test passes before laboratory validation, and the MPRIS
and `pavucontrol` additions wait for ADR 0026. A possible stale sentence in `docs/architecture.md` about control
panels is noted but left out of scope. [DEC-041]

A review of the materialized plan tightened three owned-command contracts. Display mutations are serialized under a
runtime lock and re-read the monitor state inside it, and turning an output off first detaches its mirrors and refuses
to leave no independent output lit, so neither a mirror source nor two racing requests can blank the screen
[DEC-042]. `audio-device` addresses nodes by name and resolves the PipeWire id itself, because `pactl` indexes are
object serials rather than the ids `wpctl` expects; a failed resolution is reported instead of being masked by a
second path, and persistence is checked after the cycle shortcut too [DEC-043]. Stream moves only touch application
streams, leaving loopback and filter-chain internals in place even without DSP integration [DEC-044].

The same review exposed that upstream's opened-first panel selection contradicts opening on the focused monitor. Since
only one panel can be open at a time and focus follows the mouse, keyboard and IPC requests now let the focused monitor
win: opening or toggling brings the panel to where the user works, moving it if needed, closing acts wherever it is,
and a mere focus change moves nothing. This diverges from Omarchy at the cost of a second press when closing a panel
left on another monitor. [DEC-045]

## Open questions for the interview

1. **i18n catalog source.** *(Settled by DEC-036.)* The Omarchy 4.5 catalog lacks the notification keys present in the 4.0.6-derived
   `Commons/i18n-en.json`, so `tests/capabilities/desktop/shell/i18n-subset.mjs` cannot regenerate it from 4.5 alone.
   Merge both sources, pin per key, or own the catalog?
2. **Key bindings.** *(Settled by DEC-038.)* DEC-006 reserves `SUPER+CTRL+W/B/A/P`; Omarchy 4.5 binds audio `A`, Bluetooth `B`, display `D`,
   network `N` and power `P`, plus `SUPER+CTRL+<1-9>` for bar panels, and reassigned `W`. Which chord opens display,
   whether network keeps `W`, whether the numbered chords are adopted, and how collisions with the existing hardware
   bindings (`SUPER+CTRL+Delete`) and Story 4.7 ownership are handled.
3. **Notifications IPC.** *(Settled by DEC-030: existing target kept, binding only.)* The notifications panel has no open/toggle function. Target name, actions and how it fits
   the existing `IpcHandler` in `notifications/Service.qml`.
4. **Container version.** *(Settled by DEC-029 and DEC-030.)* MirrorOS `Ui/KeyboardPanel.qml` (453 lines, 4.0.6) differs from 4.5 (575 lines: card
   publication, morph animation, `heldTarget` hand-over). Adopt the 4.5 container, keep 4.0.6, or adapt selectively;
   and whether `Ui/Panel.qml` replaces `ShellIpc` with a plain `IpcHandler` as in the prototype.
5. **Provenance format.** *(Settled by DEC-028 and DEC-037.)* The prototype's copied QML and JavaScript carried no provenance header. Per-file headers,
   `UPSTREAM.md` entries only, or both; and how 4.5-derived and 4.0.6-derived files are cited side by side.
6. **Owned commands versus upstream helpers.** *(Settled: audio DEC-032/DEC-033, display DEC-034, power DEC-035.)* Whether the display and power panels call the plan 02-25 owned
   commands (`brightness`, `power-profile`, Hyprland `display`) or Quickshell services and `powerprofilesctl`
   directly, and how the last-display guard relates to the existing `display` command.
7. **Default-device persistence.** *(Settled by DEC-039.)* Whether the native default sink and source selection persists across sessions
   through WirePlumber state, and what the panel does if it does not.
8. **Delivery and validation.** *(Settled by DEC-040.)* Which `configure` steps change, which product tests replace the prototype-local model
   tests, and the laboratory (`--audio` and without) and supervised T14s checks per panel.

## References

- [ADR 0025: Shell Panels](../adr/0025-shell-panels.md)
- [Shell panels prototype procedure](../procedures/shell-panels-prototype.md)
- [Story 4.4 shell panels log](story-4-4-shell-panels_log.md)
- [Story 4.4 hardware connectivity log](story-4-4-hardware-connectivity_log.md)
- [Hardware procedure](../procedures/hardware.md)
