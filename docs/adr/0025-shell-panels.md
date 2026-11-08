# ADR 0025: Shell Panels

## Identifier and title

- **Identifier:** `0025`
- **Title:** Shell Panels

## Status

`Accepted`

The maintainer accepted this architectural decision on 2026-11-07 after a dedicated review. Implementation remains
subject to the scoped review of production plans 02-27 to 02-30; per-panel hardware validation stays with them.

## Date

`2026-11-07`

## Context and question

Story 4.4 makes shell panels the primary graphical interface for Wi-Fi and Bluetooth, with the terminal as the
permanent fallback, and the maintainer recorded the intent to provide Omarchy-style bar panels in the shell (Story 4.3
DEC-016). Plan 02-25 delivered the hardware and connectivity capabilities through owned commands and terminal paths
and deferred the panels.

[ADR 0012](0012-owned-quickshell-desktop-shell.md) bounds the owned shell to the bar, launcher, notifications, OSD and
session menu; it excludes control-panel and background-management functionality and never admits authentication in
project-owned QML. Panels that select audio devices, join Wi-Fi networks, pair Bluetooth devices, change outputs and
power profiles, and give access to a corporate VPN are outside that surface and touch credentials and privileged
system state. The questions are:

1. Should the shell admit bar-anchored panels, and which ones?
2. Where are the credential, privilege, persistence and service boundaries for those panels?
3. How are the shell media service (Story 4.4 DEC-008) and graphical VPN access resolved?

## Constraints and decision criteria

- NFR37: custom code needs a documented recurring need that simpler supported mechanisms cannot meet.
- PRD exclusions: no general control panel, welcome application or background management service.
- Authentication (screen lock, polkit agent, user credentials) is never project-owned QML.
- NetworkManager owns DNS policy ([ADR 0024](0024-networkmanager-resolved-dns-integration.md)); private VPN DNS is
  received dynamically and profile DNS is not rewritten globally.
- No resident shell daemon or additional background service owned by the shell.
- Sustainability for a single maintainer: per-panel cost must be measured, not assumed.
- Licensing: MirrorOS is `GPL-3.0-only`; copied material needs recorded provenance and attribution.
- The terminal paths delivered by plan 02-25 remain the permanent fallback.

## Alternatives considered

1. **Adapt the Omarchy 4.5 panels in the owned shell (selected).** Omarchy (MIT) is the closest functional reference,
   uses the same Quickshell services and command-helper pattern as the MirrorOS shell, and its upstream components
   already underlie the bar. It brings large files (the network panel is about 2,100 lines) and upstream helpers that
   must be replaced.
2. **Another Quickshell shell (Caelestia, illogical-impulse, Dux Modular Shell).** Caelestia and illogical-impulse are
   smaller but cover fewer functions; Dux Modular Shell's richest functions depend on its resident `dms` daemon, which
   ADR 0012 excludes.
3. **Omarchy community plugins.** The shortlisted plugins depend on a systemd user service or cover single functions.
4. **Dedicated tools (network-manager-applet, Blueman, pavucontrol and similar).** Supported upstream and they
   include interactive agents, but they reintroduce the separate-component appearance ADR 0012 rejected and add
   resident applets.
5. **No panels; terminal paths only.** Lowest cost, but does not meet the Story 4.4 primary-interface decision.

## Evidence

The [shell panels prototype procedure](../procedures/shell-panels-prototype.md) records:

- The signature-verified Omarchy 4.5 reference, the per-panel inventory and the 4.0.6 to 4.5 differences.
- The license-filtered alternatives shortlist approved by the maintainer and the per-panel comparison matrix.
- A laboratory guest prototype of the shared container, the audio panel and the network panel, handed off as a
  verified bundle: container behaviour, device switching, the unavailable state without audio hardware, and measured
  reuse and cost.
- Supervised, non-qualifying T14s evidence: PSK entry through the prototype panel without privilege prompts, the
  missing `iw` dependency, DNS presets that rewrote every saved profile, a noisy packet-loss indicator, and BlueZ
  `NoInputNoOutput` and `KeyboardDisplay` pairing behaviour. Legacy PIN pairing was not exercised.
- The maintainer gate decisions on 2026-11-07.

Display and power were not prototyped; they rely on the inventory and the plan 02-25 T14s evidence. The Framework
Laptop 13 Pro has not been tested.

## Decision

Extend the owned Quickshell shell with bar-anchored panel popouts in one shared container, for these panels only:

- **Audio:** output and input selection, levels, mute and mute-all, an input peak meter active only while the panel
  is open, a per-application mixer labelled with PipeWire names, and an unavailable state without fabricated values.
- **Network/Wi-Fi:** wired and Wi-Fi state, scan, connect with a passphrase, disconnect, forget, band selection,
  per-connection DNS within the boundary below, connectivity check and captive-portal action, and details.
  NetworkManager VPN profiles are listed and opened through the owned VPN wrapper.
- **Bluetooth:** power, discovery, pair, connect, disconnect, forget, and switching to a new Bluetooth audio output.
- **Display:** brightness, output enable and disable with a last-display guard, and scale.
- **Power:** battery state and AC and battery power profiles.

Each panel has an open/toggle IPC target, one per shell. The panels adapt Omarchy 4.5 panels with per-file provenance
in the shell `UPSTREAM.md` and `docs/attribution.md`; prototype code is not promoted and production reimplements or
adapts under its own review. Omarchy remains a design and source reference, not a vendored shell.

Boundaries:

- **Remaining exclusions:** a general control panel, a welcome application, background management services, a
  resident shell daemon, authenticating QML, and the extra Omarchy panels (QR network sharing, speed test, CPU and
  memory statistics, text size, DSP and EasyEffects sink resolution, and others) stay excluded.
- **Network credential entry:** the Wi-Fi passphrase field is admitted as network credential entry, not user
  authentication. The passphrase reaches NetworkManager only on standard input or through the native API, never on
  a command line, and the shell never stores or logs it. Enterprise Wi-Fi authentication goes through the terminal.
  ADR 0012's rule that authentication is never project-owned QML is otherwise unchanged.
- **PSK storage:** NetworkManager's default system-wide profile with the secret in its root-only keyfile; no keyring
  dependency.
- **Privilege:** panels act as the session user through unprivileged NetworkManager, BlueZ, PipeWire and owned
  commands; no `sudo`, `pkexec` or passwordless rule is added for them.
- **DNS:** a panel DNS change applies only to the active profile after explicit confirmation; never to every saved
  profile and never to the global NetworkManager or systemd-resolved layer ([ADR 0024](0024-networkmanager-resolved-dns-integration.md)).
  VPN profiles are untouched.
- **Bluetooth pairing:** the existing `bt-agent -c NoInputNoOutput` from `bluez-tools` runs as a user unit and covers
  "Just Works" pairing, without man-in-the-middle protection. Numeric comparison, passkey and legacy PIN pairing use
  the documented terminal fallback, `bluetoothctl` with a `KeyboardDisplay` agent. No pairing agent runs in QML.
- **Media service:** none. The `playerctl` command boundary from plan 02-25 stays; MPRIS labels are deferred.
- **Graphical VPN access:** an owned Bash wrapper in `capabilities/system/vpn`, reimplemented from the OpenConnect
  helper prototype, runs only in the local graphical session, verifies the effective state after disconnecting and
  keeps preferences under `$XDG_STATE_HOME/mirroros/`. The network panel opens it in a terminal; no VPN credential
  passes through QML.
- **Power watcher:** stays outside the shell.
- **Diagnostics:** no continuous probing of a fixed third-party host; panels use the gateway and NetworkManager's
  connectivity check.

This ADR amends ADR 0012's surface list and control-panel exclusion only for these panels. Its other exclusions,
authentication rules and QML and compositor-provider boundaries remain in force, as does
[ADR 0020](0020-wallpaper-selection.md). The MVP scope records the panels under Story 4.4, and the architecture
references this amendment.

## Consequences and trade-offs

- The shell gains a shared container and five panels, a substantial QML and helper code base, and their IPC targets.
  The cost is accepted for the Story 4.4 primary-interface decision and a coherent appearance with the bar.
- Copied upstream material must be tracked per file and kept in step with Omarchy where it is reused.
- `iw` becomes a dependency of the network panel.
- Passkey and PIN pairing stay on the terminal, so Bluetooth devices that need them are not paired from the panel.
- Without a media service, the mixer shows PipeWire stream names rather than player metadata.
- Delivery is split into production plans 02-27 (container, audio, display, power, IPC and panel bindings), 02-28
  (network/Wi-Fi), 02-29 (Bluetooth and pairing agent) and 02-30 (graphical VPN access).

## Replacement or reversal boundary

Reconsider this decision through a new ADR if the panels grow into a general control panel or require a resident
shell daemon, if a credential must be stored or handled beyond the boundaries above, if per-panel maintenance or
upstream breakage proves recurring, or if a supported tool meets the requirements with materially lower maintenance.
Removing a panel in favour of its terminal path does not require reopening the remaining panels.

## Required validation

Before deployment of each panel, in its production plan:

- Provenance and attribution recorded for every copied or adapted file.
- Tests for the panel models and helpers, including the credential and DNS boundaries and the absence of
  `omarchy-*` calls.
- The unavailable state is exercised without the relevant hardware or service.
- Real-hardware validation per panel in an authorized session, including Wi-Fi, Bluetooth pairing, outputs and power
  profiles; T14s results are non-qualifying and the Framework Laptop 13 Pro validation remains pending.
- Atomic publication of the shell tree, persistence of default device selection across sessions, and the UI
  requirements recorded in the procedure (pending states, distinct current, chosen and focused states, no repeated
  actions).

## References

- [Shell panels prototype procedure](../procedures/shell-panels-prototype.md)
- [Story 4.4 shell panels technical interview log](../technical-interviews/story-4-4-shell-panels_log.md)
- [Story 4.4 hardware connectivity technical interview log](../technical-interviews/story-4-4-hardware-connectivity_log.md)
- [Story 4.3 guest-host technical interview log](../technical-interviews/story-4-3-guest-host_log.md), DEC-016
- [ADR 0012: Owned Quickshell Desktop Shell](0012-owned-quickshell-desktop-shell.md)
- [ADR 0020: Wallpaper Display and Selection](0020-wallpaper-selection.md)
- [ADR 0024: NetworkManager and systemd-resolved DNS Integration](0024-networkmanager-resolved-dns-integration.md)
- [Hardware procedure](../procedures/hardware.md)
- [Architecture](../architecture.md)
- [MVP scope and change control](../mvp-scope.md)
- [Attribution](../attribution.md)

## Superseded by

Partially superseded by [ADR 0026](0026-mpris-player-names-and-advanced-audio-tool.md), which supersedes only the
media service item's deferral of MPRIS labels and the matching consequence that the mixer shows PipeWire stream names,
and records `pavucontrol` with an audio panel button. The rest of this decision is unchanged.

Partially superseded by [ADR 0027](0027-display-panel-mirror-toggle.md), which supersedes only the "Display"
panel-content item, extending it with a runtime-only mirror toggle over the existing `display mirror` command. The rest
of this decision is unchanged.
