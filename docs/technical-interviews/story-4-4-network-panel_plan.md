# Story 4.4 Network Panel Planning — Consolidated Plan

This document records the technical interview for plan 02-28, the Story 4.4 network/Wi-Fi panel. It builds on
[ADR 0025](../adr/0025-shell-panels.md), the gate outcome in the
[shell panels prototype procedure](../procedures/shell-panels-prototype.md) and the shared container, bar routing,
IPC and binding conventions delivered by plan 02-27 ([panel infrastructure plan](story-4-4-panel-infrastructure_plan.md)).

## Settled inputs

- The panel adapts Omarchy `v4.5.0` `shell/plugins/panels/network/{Panel.qml,Model.js}` and `shell/Ui/TextField.qml`
  by copy and adaptation, with per-file provenance in the shell `UPSTREAM.md` and `docs/attribution.md`; prototype code
  is not promoted.
- It uses the 02-27 container (`Ui/Panel.qml` with `manageIpc: false`), focused-monitor routing, a plain `network` IPC
  target with only `open`, `close` and `toggle`, the `mirroros:panel.network` global shortcut and the reserved
  `SUPER+CTRL+N` chord; positional `SUPER+CTRL+1..9` numbering shifts with the new visible panel.
- Boundaries: the PSK reaches NetworkManager only through the native API or standard input and is never stored or
  logged; enterprise Wi-Fi goes through the terminal; no `sudo`, `pkexec` or passwordless rule; panel DNS changes only
  the active profile after explicit confirmation, never every profile or the global layer (ADR 0024); no continuous
  probing of a fixed third-party host; QR sharing and speed test are excluded; `iw` becomes a dependency; G14 UI
  requirements apply.
- i18n: the 54 `network.*` keys used by the 4.5 panel all exist in the pinned `7075b61` catalog; only
  `network.openCaptivePortal` differs in value ("Open Captive Portal" at `7075b61`, "Sign into network" at `v4.5.0`).

## Findings raised during planning

- Arch's NetworkManager connectivity URI (`http://ping.archlinux.org/nm-check.txt`, from the `networkmanager`
  package) is under the HSTS-preloaded `archlinux.org` domain, so a browser opening it is forced to HTTPS and a captive
  portal may not intercept it. Omarchy uses its own plain-HTTP endpoint for this reason. The prototype opened the Arch
  URI with `xdg-open`. The browser itself is selected only in Story 4.5.
- Omarchy `v4.5.0` also ships `omarchy-network-password` and `omarchy-network-wifi-connected`; both serve the excluded
  QR sharing feature and are not called by the network panel.

## Scope

Plan 02-28 delivers the network panel without a VPN section; plan 02-30 adds the owned VPN wrapper and the panel's VPN
listing together, so the listing never exists without a valid action. VPN profiles are neither shown as network rows
nor touched by band or DNS actions [DEC-049].

## Use of the prototype

The network prototype from plan 02-26 (`053e7c3`, reviewable in ignored
`evidence/shell-panels-prototype/handoff-053e7c3/review`) is the primary implementation reference. Production redoes
each file on top of Omarchy `v4.5.0`, carrying over the prototype adaptations that remain valid (the `ShellIpc`
replacement, removal of QR sharing and speed test, the missing-provider glyph, `command -v` instead of
`omarchy-cmd-present`, and a DNS helper without the global layer, privilege escalation or VPN profile edits). It also
fixes what the T14s exposed: DNS presets that rewrote every Wi-Fi/Ethernet profile without confirmation, continuous
ping to `1.1.1.1`, an over-sensitive packet-loss indicator, the missing `iw`, indistinct band states and the lack of
double-click protection. Every line is reviewed against `v4.5.0`, so DEC-024's "not promoted as-is" rule holds while
the prototype work is reused [DEC-050].

Provenance remains Omarchy `v4.5.0` in the shell `UPSTREAM.md` and `docs/attribution.md`; the prototype is
MirrorOS-owned and is cited as a design reference only. Its six model test cases (status parsing, throughput, band,
rows, per-connection DNS boundary, no `omarchy-*` calls) seed production tests written to the plan 02-27 pattern
[DEC-050].

## Owned commands and delivery

The Omarchy helpers are replaced by owned commands `network-status`, `network-band` and `network-dns`, kept as sources
in `capabilities/system/network/` with an `OMARCHY-LICENSE` copy and `sources.md` provenance, following the plan 02-27
pattern for panel commands rather than the prototype's shell-local `panels/network/bin/`. The existing `system/network`
step delivers them to `/usr/share/mirroros/hardware/` (0755) with postconditions, and the license to
`/usr/share/mirroros/hardware/licenses/omarchy-network`; `iw` joins that step's packages. The panel invokes them by
absolute path as the session user. The step still edits no NetworkManager profile: profile changes happen only at
runtime on an explicit user action, and the step's postcondition comment is clarified accordingly. `CFG_STEPS` stays at
19 [DEC-051].

## DNS from the panel

`network-dns` acts on one explicitly named profile: `network-dns set <connection-uuid> <provider>` and
`network-dns get <connection-uuid>`. The panel passes the UUID of the profile its header shows, the default-route
device's connection reported by `network-status`, so a change made after a roam or band switch cannot land on a
different profile than the one the user confirmed. The command refuses, with a distinct exit code and without
modifying anything, a UUID that is not active at that moment or is not a Wi-Fi or Ethernet profile, which keeps VPN
and other connection types untouched. It modifies only that UUID and reapplies only the device holding it; the
prototype's walk over every saved profile, the root cause of the T14s finding, is removed and no all-profiles mode
exists [DEC-052].

Presets never apply on a single activation. Choosing DHCP, Cloudflare or Google opens an inline confirmation row naming
the provider and the target profile, with Apply and Cancel; focus starts on Cancel so a repeated Enter cannot confirm,
Escape cancels, and the row disappears if the panel closes, the header profile changes or another pill is chosen. The
Custom choice opens `foot` through `uwsm app --` without an in-panel confirmation, since opening a terminal changes
nothing; the terminal names the target profile, treats empty input as cancel and reports Done or Failed as the
prototype did. While a change runs the DNS section is pending, its pills are dimmed and repeated activations are
ignored, meeting G14. These strings are owned English literals in QML rather than new catalog keys [DEC-053].

The presets stay exactly as in Omarchy 4.5: DHCP (DHCP-provided servers, DNS over TLS `default`), Cloudflare and Google
(their IPv4 and IPv6 servers, DNS over TLS `opportunistic`) and Custom (entered servers, `default`), with every
non-DHCP choice setting `ignore-auto-dns` for IPv4 and IPv6 on the target profile; `get` recognises the provider by
matching servers. This stays within ADR 0024 because MirrorOS imposes no provider: DHCP is the default and configure
never edits profiles. The hardware procedure documents the trade-offs the user accepts with a preset: DHCP search
domains are dropped on that profile (short names on a corporate wired LAN may stop resolving), the choice does not
follow to profiles created later, and there is no `FallbackDNS` or global DNS over TLS [DEC-054].

## Diagnostics

The maintainer values knowing internet latency, and internet reachability is already visible in the panel header, so a
separate NetworkManager-derived "Internet" row was rejected as redundant. Keeping Omarchy 4.5's internet ping conflicts
with ADR 0025's "no continuous probing of a fixed third-party host", so the plan opens with ADR 0028, "Network panel
internet latency probe", which partially supersedes only that Diagnostics item: the probe runs only while the network
panel is open and never while it is closed. The ADR is accepted at a checkpoint before any code change, and it records
the costs accepted with it: third-party traffic while the panel is open, meaningless loss on ICMP-filtering networks,
and a destination fixed in code [DEC-055].

The panel keeps the 4.5 measurement (gateway and internet samples, with "Ping" and "Packet loss" describing the
internet samples) but relaxes the loss indicator that was noisy on the T14s: loss is computed over the 24-sample window
(about 36 s) and turns red only once at least 10 samples exist and loss reaches 10 %; otherwise the percentage shows in
the normal colour, and under Portal, Limited or None connectivity both rows show "--" as upstream does. Host and
cadence are separate decisions [DEC-055].

The probe targets `1.1.1.1`, as upstream does: anycast keeps the figure meaningful as internet latency, no DNS lookup is
involved and no divergence is added. The host is a single constant in `network-status` and ADR 0028 names it; Quad9 and
NetworkManager's Arch connectivity host were rejected (no gain over upstream, and a single distant server needing DNS,
respectively) [DEC-056].

The probe keeps the upstream 1.5 s cadence while the panel is open, so the 5-sample latency average stays responsive
and the 24-sample loss window stays near 36 s, but its timeout rises from 1 s to 2 s so Wi-Fi latency spikes register
as latency rather than loss. A tick that finds the previous poll still running is skipped, so probes never overlap;
execution confirms whether the 4.5 `running` guard already does this and adds it if not. ADR 0028 records these values
[DEC-057].

## Captive portal

A captive portal blocks internet access until the user signs in on a page it serves by intercepting plain HTTP;
NetworkManager's connectivity check detects it and reports Portal, which drives the header and bar. The panel's button,
shown only in that state and acting only on an explicit click, opens `http://neverssl.com/` with
`uwsm app -- xdg-open` and the default browser. The URL must be plain HTTP and outside HSTS preload: Arch's
connectivity host, used by the prototype, sits under the preloaded `archlinux.org` (verified 2026-11-08), so a browser
would upgrade it to HTTPS and the portal could not intercept it. Opening a third-party page only on that click is not
probing and stays within ADR 0025. None of the 4.5 helper's Chromium web app, window rules, automatic close or Tailscale
handling is carried over; the panel closes after launching, and the 10 s recheck while in Portal updates the header and
bar after sign-in. If no browser can be opened the panel stays open with "Could not open a web browser", and the
procedure notes that a browser must be installed until Story 4.5 selects one. The button keeps the pinned catalog text
"Open Captive Portal"; the URL and text divergences are recorded in the shell `UPSTREAM.md` [DEC-058].

The maintainer uses Tailscale and expects to add it. An active exit node routes the portal page into a tunnel the portal
blocks, so Omarchy pauses it during sign-in; that integration, and the operator privilege it needs, are deferred until
Tailscale becomes a MirrorOS capability [TODO-023]. Meanwhile the hardware procedure documents disabling the exit node
manually before signing in and re-enabling it afterwards [DEC-058].

So that TODO-023 surfaces when Tailscale is added, a Node test in the network panel suite fails as soon as any
`capabilities/**/packages` file declares `tailscale`, naming TODO-023 and this log; the commit adding Tailscale must
then implement the exit-node pause or consciously update the guard. The shell `UPSTREAM.md` captive-portal row and the
hardware procedure's manual note also cite TODO-023, and a local, non-authoritative `.pi/todos` reminder tagged
`tailscale` complements them [DEC-059].

## Enterprise Wi-Fi and the Advanced action

Enterprise Wi-Fi gives each user their own credentials checked by a RADIUS server and is safe only when the profile
pins the CA certificate and server domain. Omarchy 4.5's in-panel path hard-codes PEAP/MSCHAPv2 with neither, which both
limits the methods it supports and lets an evil-twin access point harvest corporate or university credentials, so the
panel drops it entirely (identity field, enterprise connect process and script), in line with ADR 0025's terminal route
[DEC-060].

In its place the panel gains an "Advanced…" button at its end, mirroring the audio panel, that opens `nmtui` in `foot`
through `uwsm app --` and closes the panel; it needs no package and no ADR because `nmtui` is the existing terminal
fallback rather than a new graphical tool. An unsaved enterprise network shows "Enterprise network: use Advanced…" and
opens the same tool when activated, while a saved enterprise profile behaves like any known network through the native
API and falls back to the same hint if its secrets are missing. The hardware procedure explains 802.1X setup with the
CA certificate and domain, and a test asserts that no enterprise credential path remains in the panel [DEC-060].

## Wi-Fi band

`network-band` follows the same explicit-target rule as DNS: `network-band set <device> <connection-uuid> <band>` and
`network-band get <device>`, with the panel passing the connected Wi-Fi device and its profile UUID and the command
refusing a stale pair. A band change needs no confirmation because it is reversible, reverts on failure and only
reconnects briefly. To meet G14 the chosen band (profile setting or Auto) is the only filled pill, the radio's current
band is a small marker beside its label, and keyboard focus is an outline. During a switch the target pill reads
"Switching…", all band pills are dimmed and further activations are ignored until the command exits, without publishing
the empty status seen mid-reconnect. Reactivation is bounded with `nmcli --wait 30`, after which the existing revert
applies, and the band section is hidden when `iw` is missing or reports no band data [DEC-061].

## Files and provenance

The network panel follows the power panel's plan 02-27 pattern. `bar/widgets/Network.qml` becomes the panel adapted
from `v4.5.0:shell/plugins/panels/network/Panel.qml` on the shared `Ui/Panel.qml` with `manageIpc: false`, retaining the
MirrorOS missing-provider glyph and tooltip and the current OWE and signal handling; its `UPSTREAM.md` row records every
divergence decided here (no QR or speed test, no enterprise path plus the Advanced action, DNS by UUID with confirmation,
G14 band states, relaxed loss and timeout, portal URL, owned commands, IPC in the bar). The bar-only `bar/NetworkModel.js`
is removed in favour of `panels/network/Model.js`, adapted from `v4.5.0`, and `Ui/TextField.qml` is copied byte for byte
and registered in `Ui/qmldir`. The three owned commands are recorded as adapted from `v4.5.0` in
`capabilities/system/network/sources.md`, and `docs/attribution.md` is updated. Catalog keys enter through
`i18n-subset.mjs` regeneration from the pinned `7075b61`, checked with `--check`, with `UPSTREAM.md` noting that only
`network.openCaptivePortal` differs from `v4.5.0`. The existing provenance checker and no-Omarchy-coupling test extend to
the new files unchanged [DEC-062].

## IPC, shortcut and bar integration

The panel applies the plan 02-27 conventions without extension: one `network` IPC target in `Bar.qml` with only open,
close and toggle and focused-monitor routing (the 4.5 extras are dropped), a `panel.network` global shortcut in
`shell.qml`, and `SUPER + CTRL + N` bound in `shell-bindings.lua`, with N moving from reserved to bound in the Lua
comment, the Hyprland `UPSTREAM.md` and the binding tests while B stays reserved for plan 02-29. A click on the bar icon
toggles the panel. Because the network icon sits before audio in the default right section, positional chords become
network 1, audio 2, display 3 and power 4; the shell procedure and `panelWidgetIdAt` tests record the shift.
`check-panels.sh` covers the network panel by IPC, global shortcut, Tab switching and the unavailable state with
NetworkManager stopped [DEC-063].

## Validation

The laboratory guest covers what a wired-only machine without a browser can show: wired metrics and the relaxed loss
indicator, no probe left running after the panel closes, the unavailable state with NetworkManager stopped and its
recovery, the absent Wi-Fi section, DNS confirmation and Custom entry with an all-profiles comparison proving that only
the active profile changed (a dummy second Ethernet profile and a dummy VPN profile stay intact), the Advanced action,
and a simulated captive portal from a temporary guest-only connectivity drop-in that exercises the button and its
no-browser failure path before being removed [DEC-064].

The supervised T14s session (maintainer acts, agent verifies read-only) covers Wi-Fi itself: scanning, forgetting and
reconnecting with a PSK including a wrong-passphrase re-prompt, disconnecting, band switching with `iw` and the G14
states, DNS confirmation limited to the active profile and restored to DHCP, the corporate VPN profile left intact,
ping and loss without false alarms, the Advanced action, any visible enterprise hint, and a NetworkManager journal audit
proving session-user operations without privilege prompts. Real captive portals, enterprise networks, 6 GHz and
Tailscale are out of scope. The hardware procedure gains network panel matrix rows with the Framework Laptop 13 Pro
pending, and redacted evidence stays in ignored `evidence/shell-panels/{lab,t14s}-02-28/` with a clean Gitleaks scan
[DEC-064].

## Retained upstream functions

Everything else in the 4.5 panel is kept as is: the Wi-Fi radio toggle, scanning only while open, the sorted saved and
available network lists, passphrase-free open and OWE connection and PSK connection through native `connectWithPsk`
with re-prompt on failure, disconnect and forget with their in-progress guard and safety timeout, the header phrases
and band/speed detail, the IP, gateway and throughput grid, active-AP signal through `nmcli`, and full keyboard
navigation. The one change among them is clipboard copy, which calls `wl-copy` with the non-secret value as an argv
argument instead of building a `bash -c` pipeline [DEC-065].

## Tests

Product tests follow plan 02-27. Bats with doubles in `tests/capabilities/system/hardware-network-commands.bats` pin the
command boundaries: `network-dns` acts only on an active Wi-Fi or Ethernet UUID, reapplies only its device, uses the
exact preset values, cancels Custom on empty input and never writes the global layer, escalates privilege or walks
saved profiles; `network-band` rejects a stale device-UUID pair, bounds activation with `--wait 30`, reverts on failure
and copes without `iw`; `network-status` pings only the gateway and the single `1.1.1.1` constant with a 2 s timeout. A
Node suite covers the adapted model points (loss threshold, Portal/Limited/None placeholders, band states, DNS
confirmation lifetime, portal URL, absent enterprise script). Static checks assert there is no enterprise credential
path, that the PSK only reaches `connectWithPsk`, that no `omarchy-*` call remains, and the Tailscale guard. Binding,
bar-panel, configure contract, provenance, i18n, qmllint (guest) and `check-panels.sh` suites are updated, alongside
ShellCheck, `git diff --check`, Gitleaks and link checks [DEC-066].
